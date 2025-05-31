# Disaster Recovery Automation for Databases

This repository demonstrates how to automate database backup, cross-region restoration, and periodic failover testing using Bash, psql, AWS CLI, Amazon RDS, AWS Backup, and Amazon S3. It also includes documentation and training materials for recovery procedures.

## Table of Contents

1. [Overview](#overview)  
2. [Prerequisites](#prerequisites)  
3. [Directory Structure](#directory-structure)  
4. [Scripts](#scripts)  
   - [`backup.sh`](#backupsh)  
   - [`restore_cross_region.sh`](#restore_cross_regionsh)  
   - [`failover_test.sh`](#failover_testsh)  
   - [`helpers.sh`](#helperssh)  
5. [Usage Examples](#usage-examples)  
6. [Cron Scheduling](#cron-scheduling)  
7. [Documentation](#documentation)  
8. [Training Materials](#training-materials)  
9. [License](#license)

---

## Overview

This project automates the following key disaster recovery tasks:

- **Automated Database Backups / Snapshots**  
  - Uses AWS CLI to snapshot Amazon RDS instances (PostgreSQL & MySQL) and store them in the same region.  
  - Leverages AWS Backup service to copy snapshots to a designated S3 vault.  

- **Cross-Region Restoration**  
  - Copies automated snapshots from primary region to secondary region.  
  - Uses `psql` to validate pre- and post-restore connectivity.  

- **Periodic Failover Testing**  
  - Spins up a temporary read-replica in a secondary region.  
  - Runs smoke tests via `psql`/`mysql` to ensure data integrity and connection.  
  - Tears down test instances automatically after validation.  

- **Documentation & Training**  
  - Comprehensive step-by-step disaster recovery procedures.  
  - Training materials for ops teams to run drills manually if needed.

---

## Prerequisites

1. **AWS CLI** installed and configured with IAM credentials that have:  
   - `rds:CreateDBSnapshot`  
   - `rds:CopyDBSnapshot`  
   - `rds:RestoreDBInstanceFromDBSnapshot`  
   - `rds:DeleteDBInstance`  
   - `backup:StartBackupJob`, `backup:CreateBackupVault`  
   - `s3:PutObject`, `s3:GetObject`  
   - `iam:PassRole` (if using a service role for AWS Backup)

2. **psql** (for PostgreSQL) or **mysql client** (for MySQL) installed locally or on a jump server.  
3. **Bash** (version ≥4.0), `jq`, `cron`.  
4. A target **Amazon RDS** instance (Postgres or MySQL) with proper tagging:
   - Tag key: `Environment`, value: `production`
   - Tag key: `Project`, value: `A3-DR`
5. An **AWS Backup Vault** configured in both primary and secondary regions (if using AWS Backup cross-region copy).

---

## Directory Structure

```text
project-3-dr-automation/
├── README.md
├── LICENSE
├── scripts/
│   ├── backup.sh
│   ├── restore_cross_region.sh
│   ├── failover_test.sh
│   └── helpers.sh
├── docs/
│   ├── recovery_procedures.md
│   └── training_materials.md
└── .gitignore
```

- **`scripts/`**: Contains all the Bash automation scripts.  
- **`docs/`**: Contains markdown documentation and training materials.  
- **`LICENSE`**: (e.g., MIT License).  
- **`.gitignore`**: Excludes any credentials or temporary files.

---