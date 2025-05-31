#!/usr/bin/env bash
# =============================================================================
# restore_cross_region.sh
# Restores the most recent cross-region snapshot for each RDS instance, then validates with psql.
# =============================================================================

set -euo pipefail
source "$(dirname "$0")/helpers.sh"

log "Starting cross-region restoration process from $SECONDARY_AWS_REGION to new RDS instance."

for INSTANCE in "${RDS_INSTANCES[@]}"; do
  # Determine latest snapshot in secondary region
  SNAPSHOT_PREFIX="${INSTANCE}-dr-snapshot"
  log "Fetching latest snapshot for '$INSTANCE' in region $SECONDARY_AWS_REGION..."
  LATEST_SNAPSHOT_ID=$(aws --profile "$AWS_PROFILE" --region "$SECONDARY_AWS_REGION" rds describe-db-snapshots \
    --snapshot-type "manual" \
    --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, \`${SNAPSHOT_PREFIX}\`)].DBSnapshotIdentifier | sort(@) | [-1]" \
    --output text)

  if [[ -z "$LATEST_SNAPSHOT_ID" || "$LATEST_SNAPSHOT_ID" == "None" ]]; then
    log "No snapshots found for '$INSTANCE' in $SECONDARY_AWS_REGION. Skipping."
    continue
  fi

  log "Latest snapshot for '$INSTANCE': $LATEST_SNAPSHOT_ID"

  # Define a temporary RDS instance identifier
  TEMP_INSTANCE_ID="${INSTANCE}-dr-test-$(date +'%s')"

  # Restore DB instance from the snapshot
  log "Restoring new RDS instance '$TEMP_INSTANCE_ID' from snapshot '$LATEST_SNAPSHOT_ID'..."
  aws --profile "$AWS_PROFILE" --region "$SECONDARY_AWS_REGION" rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier "$TEMP_INSTANCE_ID" \
    --db-snapshot-identifier "$LATEST_SNAPSHOT_ID" \
    --db-instance-class db.t3.medium \
    --availability-zone "${SECONDARY_AWS_REGION}a" \
    --no-multi-az \
    --publicly-accessible

  # Wait for restoration to complete
  wait_for_rds_available "$TEMP_INSTANCE_ID" "$SECONDARY_AWS_REGION"

  # Fetch endpoint
  ENDPOINT=$(get_rds_endpoint "$TEMP_INSTANCE_ID" "$SECONDARY_AWS_REGION")
  log "Temporary RDS endpoint: $ENDPOINT"

  # Validate connectivity & basic query (PostgreSQL example)
  log "Running psql connectivity test to '$ENDPOINT'..."
  PGPASSWORD="${DB_PASSWORD:-changeme}" psql -h "$ENDPOINT" -U "$DB_USER" -p "$DB_PORT" -d postgres \
    -c "SELECT 1;" >/dev/null && \
    log "psql connection to '$ENDPOINT' succeeded." || \
    log "ERROR: psql connection to '$ENDPOINT' failed."

  # Optionally, run a more thorough validation query (e.g., count rows in a key table)
  # log "Running row count test on 'important_table'..."
  # PGPASSWORD="${DB_PASSWORD:-changeme}" psql -h "$ENDPOINT" -U "$DB_USER" -p "$DB_PORT" -d my_database \
  #   -c "SELECT COUNT(*) FROM important_table;" 

  # Clean up: delete temporary instance
  cleanup_temp_instance "$TEMP_INSTANCE_ID" "$SECONDARY_AWS_REGION"

  log "Cross-region restoration & validation complete for '$INSTANCE'."
done

log "All cross-region restores and validations complete."
