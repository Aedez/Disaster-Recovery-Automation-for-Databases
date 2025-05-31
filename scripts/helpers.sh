#!/usr/bin/env bash
# =============================================================================
# helpers.sh
# Shared variables and helper functions for DR automation.
# =============================================================================

set -euo pipefail

# ---------- CONFIGURABLE VARIABLES (EDIT AS NEEDED) ----------
# AWS Regions
PRIMARY_AWS_REGION="us-east-1"
SECONDARY_AWS_REGION="us-west-2"

# AWS Profile (if using named profiles)
AWS_PROFILE="default"

# RDS Identifiers (can be comma-separated for multiple instances)
RDS_INSTANCES=("prod-db-1" "prod-db-2")  # Example RDS instance identifiers

# AWS Backup Vault Names (for AWS Backup cross-region vault)
BACKUP_VAULT_NAME_PRIMARY="dr-backup-vault-primary"
BACKUP_VAULT_NAME_SECONDARY="dr-backup-vault-secondary"

# S3 bucket for manual backup exports (optional)
S3_BUCKET="my-dr-backups-bucket"

# IAM Role ARN for AWS Backup (if using AWS Backup jobs)
AWS_BACKUP_ROLE_ARN="arn:aws:iam::123456789012:role/AWSBackupServiceRole"

# DB Connection Variables (PostgreSQL example)
DB_USER="postgres"
DB_HOST_TEMPLATE="%s.%s.rds.amazonaws.com"  # Format: <identifier>.<region>.rds.amazonaws.com
DB_PORT=5432

# MySQL Connection Variables (uncomment if using MySQL)
# DB_USER="admin"
# DB_HOST_TEMPLATE="%s.%s.rds.amazonaws.com"
# DB_PORT=3306

# Date format
DATE_STAMP="$(date +'%Y-%m-%d-%H%M')"

# Logging helper
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Check if AWS CLI is installed
if ! command -v aws &>/dev/null; then
  echo "ERROR: aws CLI not found. Install and configure AWS CLI before proceeding."
  exit 1
fi

# Check if jq is installed
if ! command -v jq &>/dev/null; then
  echo "ERROR: 'jq' not installed. Please install 'jq' for JSON parsing."
  exit 1
fi

# Helper to get endpoint of an RDS instance
# Arguments: $1 = instance identifier, $2 = aws region
get_rds_endpoint() {
  local instance_id="$1"
  local region="$2"
  aws --profile "$AWS_PROFILE" --region "$region" rds describe-db-instances \
    --db-instance-identifier "$instance_id" \
    --query "DBInstances[0].Endpoint.Address" --output text
}

# Helper to wait until RDS is available (available status)
# Arguments: $1 = instance identifier, $2 = aws region
wait_for_rds_available() {
  local instance_id="$1"
  local region="$2"
  log "Waiting for RDS instance '$instance_id' in '$region' to become available..."
  aws --profile "$AWS_PROFILE" --region "$region" rds wait db-instance-available \
    --db-instance-identifier "$instance_id"
  log "RDS instance '$instance_id' is now available."
}

# Helper to clean up temporary resources
cleanup_temp_instance() {
  local instance_id="$1"
  local region="$2"
  log "Deleting temporary RDS instance '$instance_id' in '$region'..."
  aws --profile "$AWS_PROFILE" --region "$region" rds delete-db-instance \
    --db-instance-identifier "$instance_id" \
    --skip-final-snapshot \
    --delete-automated-backups
  aws --profile "$AWS_PROFILE" --region "$region" rds wait db-instance-deleted \
    --db-instance-identifier "$instance_id"
  log "Temporary instance '$instance_id' deleted."
}