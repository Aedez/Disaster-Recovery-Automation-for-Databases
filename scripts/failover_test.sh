#!/usr/bin/env bash
# =============================================================================
# failover_test.sh
# Implements a periodic failover test by spinning up a temporary read-replica.
# =============================================================================

set -euo pipefail
source "$(dirname "$0")/helpers.sh"

log "Starting failover testing for each RDS instance."

for INSTANCE in "${RDS_INSTANCES[@]}"; do
  log "Initiating read-replica creation for '$INSTANCE' in $SECONDARY_AWS_REGION..."

  # Create read-replica
  REPLICA_ID="${INSTANCE}-dr-replica-$(date +'%s')"
  aws --profile "$AWS_PROFILE" --region "$SECONDARY_AWS_REGION" rds create-db-instance-read-replica \
    --db-instance-identifier "$REPLICA_ID" \
    --source-db-instance-identifier "$INSTANCE" \
    --source-region "$PRIMARY_AWS_REGION" \
    --db-instance-class db.t3.medium \
    --availability-zone "${SECONDARY_AWS_REGION}b" \
    --no-multi-az \
    --publicly-accessible

  # Wait until read-replica is available
  wait_for_rds_available "$REPLICA_ID" "$SECONDARY_AWS_REGION"

  # Fetch endpoint
  REPLICA_ENDPOINT=$(get_rds_endpoint "$REPLICA_ID" "$SECONDARY_AWS_REGION")
  log "Read-replica endpoint: $REPLICA_ENDPOINT"

  # Run a lightweight validation against the replica
  log "Validating read-replica with 'SELECT NOW()' via psql..."
  PGPASSWORD="${DB_PASSWORD:-changeme}" psql -h "$REPLICA_ENDPOINT" -U "$DB_USER" -p "$DB_PORT" -d postgres \
    -c "SELECT NOW();" >/dev/null && \
    log "Replica validation succeeded." || \
    log "ERROR: Replica validation failed."

  # Tear down the read-replica
  cleanup_temp_instance "$REPLICA_ID" "$SECONDARY_AWS_REGION"

  log "Failover test complete for '$INSTANCE'."
done

log "All failover tests completed."
