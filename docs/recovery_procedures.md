# Disaster Recovery Procedures

## Table of Contents

1. [Overview](#overview)  
2. [Triggering an On-Demand Backup](#triggering-an-on-demand-backup)  
3. [Automated Backup Workflow](#automated-backup-workflow)  
4. [Cross-Region Snapshot Copy](#cross-region-snapshot-copy)  
5. [Restoration Procedure](#restoration-procedure)  
   1. [Step 1: Identify Latest Snapshot](#step-1-identify-latest-snapshot)  
   2. [Step 2: Restore DB Instance](#step-2-restore-db-instance)  
   3. [Step 3: Validate Connectivity](#step-3-validate-connectivity)  
   4. [Step 4: Promote Read-Replica (if needed)](#step-4-promote-read-replica-if-needed)  
6. [Failover Testing Procedure](#failover-testing-procedure)  
   1. [Step 1: Create Read-Replica](#step-1-create-read-replica)  
   2. [Step 2: Validate Replica](#step-2-validate-replica)  
   3. [Step 3: Clean Up Replica](#step-3-clean-up-replica)  
7. [Role of AWS Backup Service](#role-of-aws-backup-service)  
8. [Contact & Escalation](#contact-escalation)

---

## Overview

This document outlines the detailed steps for disaster recovery of our production Amazon RDS instances. We employ both **automated snapshots** and **AWS Backup** to ensure cross-region redundancy. We regularly test failover scenarios to guarantee Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO) are being met.

---

## Triggering an On-Demand Backup

1. SSH into the bastion or management server.  
2. Navigate to the repository:  
   ```bash
   cd ~/project-3-dr-automation/scripts
3. Run the backup script:  
   ```bash
   ./backup.sh
   ```
4. Monitor the output for success messages. The script will create a snapshot and copy it to the AWS Backup vault.
5. Verify the snapshot in the AWS Management Console under RDS > Snapshots.
6. Optionally, check the AWS Backup vault for the copied snapshot.
---

## Automated Backup Workflow
- We schedule backup.sh to run daily at 02:00 UTC using a cron job (see Cron Scheduling below). Each run:
- Targets all RDS instances in RDS_INSTANCES array.
- Creates snapshots, waits for completion, and copies them.
- Snapshots are stored with prefix:
<instance>-dr-snapshot-YYYY-MM-DD-HHMM.


## Cross-Region Snapshot Copy
- We rely on the aws rds copy-db-snapshot command to duplicate snapshots from us-east-1 to us-west-2.
- Optionally, AWS Backup jobs can be used to vault snapshots and handle cross-region copy automatically.

## Restoration Procedure
### Step 1: Identify Latest Snapshot
- List available snapshots using the AWS CLI:
  ```bash
  aws --profile <profile> --region <secondary-region> rds describe-db-snapshots \
  --snapshot-type manual \
  --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, '<instance>-dr-snapshot')].[DBSnapshotIdentifier, SnapshotCreateTime]" \
  --output table
  ```
- Identify the latest snapshot based on the `SnapshotCreateTime`.

### Step 2: Restore DB Instance
- Use the latest snapshot to restore the DB instance:
  ```bash
  aws --profile <profile> --region <secondary-region> rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier <temporary-instance-name> \
  --db-snapshot-identifier <snapshot-id> \
  --db-instance-class db.t3.medium \
  --publicly-accessible \
  --availability-zone "<secondary-region>a"
  ```

- Wait for the instance to be available:
  ```bash
  aws --profile <profile> --region <secondary-region> rds wait db-instance-available \
  --db-instance-identifier <temporary-instance-name>
  ```

### Step 3: Validate Connectivity
  ```bash
  aws --profile <profile> --region <secondary-region> rds describe-db-instances \
  --db-instance-identifier <temporary-instance-name> \
  --query "DBInstances[0].Endpoint.Address" --output text
  ```

- Use `psql` or `mysql` to connect and validate:
  ```bash
  psql -h <endpoint> -U <username> -d <database>
  ```

### Step 4: Promote Read-Replica (if needed)
- If the restored instance is a read-replica, promote it to standalone:
  ```bash
  aws --profile <profile> --region <secondary-region> rds promote-read-replica \
  --db-instance-identifier <temporary-instance-name>
  ```

## Failover Testing Procedure
- We perform weekly DR drills to ensure readiness. 
### Step 1: Create Read-Replica
  ```bash
  aws --profile <profile> --region <secondary-region> rds create-db-instance-read-replica \
  --db-instance-identifier <replica-id> \
  --source-db-instance-identifier <primary-instance-id> \
  --source-region <primary-region> \
  --db-instance-class db.t3.medium \
  --publicly-accessible \
  --availability-zone "<secondary-region>b"

  ```

### Step 2: Validate Replica
- Wait for the replica to be available:
  ```bash
  aws --profile <profile> --region <secondary-region> rds wait db-instance-available \
  --db-instance-identifier <replica-id>
  ```

- Retrieve endpoint and run a test query:
  ```bash
  ENDPOINT=$(aws --profile <profile> --region <secondary-region> rds describe-db-instances \
  --db-instance-identifier <replica-id> --query "DBInstances[0].Endpoint.Address" --output text)
    export PGPASSWORD="<password>"
    psql -h "$ENDPOINT" -U "<db_user>" -d "<db_name>" -c "SELECT 1;"
  ```

### Step 3: Clean Up Replica
- After validation, delete the read-replica:
  ```bash
  aws --profile <profile> --region <secondary-region> rds delete-db-instance \
  --db-instance-identifier <replica-id> \
  --skip-final-snapshot \
  --delete-automated-backups
  ```

## Role of AWS Backup Service
- We also configure AWS Backup to automatically vault snapshots and copy them to the secondary region.
- Backup Plan: Daily schedule at 02:30 UTC.
- Backup Vault: dr-backup-vault-primary (primary region) and dr-backup-vault-secondary (cross-region).
- Lifecycle Rules: Transition to cold storage after 30 days; retain for 90 days.
- AWS Backup provides a centralized dashboard for snapshot history and cross-region copy metrics.