#!/usr/bin/env bash
# =============================================================================
# backup.sh
# Automates RDS DB snapshot creation and optionally copies to AWS Backup or S3.
# =============================================================================

set -euo pipefail
source "$(dirname "$0")/helpers.sh"

log "Starting automated RDS backups in region: $PRIMARY_AWS_REGION"

for INSTANCE in "${RDS_INSTANCES[@]}"; do
  SNAPSHOT_ID="${INSTANCE}-dr-snapshot-${DATE_STAMP}"
  log "Creating snapshot for RDS instance '$INSTANCE' with Snapshot ID: $SNAPSHOT_ID"

  aws --profile "$AWS_PROFILE" --region "$PRIMARY_AWS_REGION" rds create-db-snapshot \
    --db-snapshot-identifier "$SNAPSHOT_ID" \
    --db-instance-identifier "$INSTANCE" >/dev/null

  # Wait for snapshot to complete
  log "Waiting for snapshot '$SNAPSHOT_ID' to complete..."
  aws --profile "$AWS_PROFILE" --region "$PRIMARY_AWS_REGION" rds wait db-snapshot-completed \
    --db-snapshot-identifier "$SNAPSHOT_ID"
  log "Snapshot '$SNAPSHOT_ID' completed successfully."

  # Option A: Copy snapshot to AWS Backup vault (cross-region copy via Backup)
  # Uncomment below to trigger an AWS Backup job
  # log "Starting AWS Backup job for snapshot '$SNAPSHOT_ID'..."
  # aws --profile "$AWS_PROFILE" --region "$PRIMARY_AWS_REGION" backup start-backup-job \
  #   --backup-vault-name "$BACKUP_VAULT_NAME_PRIMARY" \
  #   --resource-arn "arn:aws:rds:${PRIMARY_AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):db:${INSTANCE}" \
  #   --iam-role-arn "$AWS_BACKUP_ROLE_ARN"

  # Option B: Copy snapshot to secondary region for cross-region DR
  log "Copying snapshot '$SNAPSHOT_ID' to region $SECONDARY_AWS_REGION..."
  aws --profile "$AWS_PROFILE" --region "$PRIMARY_AWS_REGION" rds copy-db-snapshot \
    --source-db-snapshot-identifier "arn:aws:rds:${PRIMARY_AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):snapshot:${SNAPSHOT_ID}" \
    --target-db-snapshot-identifier "${SNAPSHOT_ID}-copy-${SECONDARY_AWS_REGION}" \
    --source-region "$PRIMARY_AWS_REGION" \
    --region "$SECONDARY_AWS_REGION"
  log "Snapshot copied to secondary region."

  # Option C (alternate): Export snapshot to S3 (uncomment if needed)
  # log "Exporting snapshot '$SNAPSHOT_ID' to S3 bucket: $S3_BUCKET"
  # aws --profile "$AWS_PROFILE" --region "$PRIMARY_AWS_REGION" rds start-export-task \
  #   --export-task-identifier "${SNAPSHOT_ID}-export" \
  #   --source-arn "arn:aws:rds:${PRIMARY_AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):snapshot:${SNAPSHOT_ID}" \
  #   --s3-bucket-name "$S3_BUCKET" \
  #   --iam-role-arn "$AWS_BACKUP_ROLE_ARN" \
  #   --kms-key-id "alias/aws/rds" \
  #   --export-only "${INSTANCE}"

  log "Backup workflow for '$INSTANCE' completed."
done

log "All automated RDS backups completed."
