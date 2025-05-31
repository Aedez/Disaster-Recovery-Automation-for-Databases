# DR Training Materials

These materials are intended for the operations team to run disaster recovery drills and to understand the automated workflows.

---

## 1. Goals of DR Training

- Ensure all team members can run a manual restore from the latest snapshot.  
- Demonstrate how to trigger failover tests and interpret results.  
- Verify that documentation is sufficient for on-call engineers.

---

## 2. Prerequisites

1. AWS CLI configured with proper IAM credentials (`~/.aws/credentials`).  
2. SSH access to the bastion or management workstation.  
3. `psql` or `mysql` client installed.  
4. Basic understanding of Amazon RDS and cross-region replication.

---

## 3. Walk-Through: Manual On-Demand Restore

1. **Log in** to the bastion host.  
2. **Navigate** to the repo directory:  
   ```bash
   cd ~/project-3-dr-automation
3. Identify the latest snapshot:
   ```bash
   aws --profile <profile> --region <secondary-region> rds describe-db-snapshots \
   --snapshot-type manual \
   --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, '<instance>-dr-snapshot')].[DBSnapshotIdentifier, SnapshotCreateTime]" \
   --output table
   ```
4. Run the restore script interactively:
   ```bash
   ./scripts/restore_cross_region.sh
   ```
5. Follow the prompts to select the snapshot and temporary instance name.
6. Monitor the output for success messages. The script will restore the instance and validate connectivity.

## 4. Lab: Failover Drill
1. Trigger failover test manually:
    ```bash
    ./scripts/failover_test.sh
    ```
2. Monitor the creation of the read-replica in the AWS Console.
3. Run manual tests against the replica endpoint (e.g., psql -h <replica-endpoint>).
4. Confirm that the cleanup script deletes the replica afterward.

## 5. Knowledge Check
- Q1: How do you find the latest snapshot ID?
- Q2: Name two differences between using AWS Backup vs. aws rds copy-db-snapshot for cross-region DR.
- Q3: If a restore to db-dr-test fails, where do you look in CloudWatch logs?

## 6. Additional Resources
- [AWS RDS Documentation](https://docs.aws.amazon.com/rds/index.html)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/rds/index.html)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [MySQL Documentation](https://dev.mysql.com/doc/)
- [AWS Backup Documentation](https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html)
- [Bash Scripting Guide](https://tldp.org/LDP/Bash-Beginners-Guide/html/)

