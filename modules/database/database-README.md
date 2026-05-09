# Database Module

This module provisions the database tier: RDS MySQL, DynamoDB tables, and CloudWatch log groups for monitoring.

---

## Resources Created

- RDS MySQL 8.0 instance in private DB subnets
- DB subnet group across two AZs
- Custom RDS parameter group with slow query logging
- CloudWatch Log Groups for RDS error and slow query logs (30-day retention)
- DynamoDB session table (TTL enabled, encryption at rest)
- DynamoDB user table (GSI on Email, encryption at rest)

---

## RDS MySQL

| Parameter              | Value                |
| ---------------------- | -------------------- |
| Engine                 | MySQL 8.0            |
| Instance class         | `db.t3.micro`        |
| Allocated storage      | 20 GB                |
| Multi-AZ               | `false` (dev)        |
| Publicly accessible    | `false`              |
| Final snapshot         | Skipped              |
| CloudWatch log exports | `error`, `slowquery` |

### Parameter Group

| Parameter         | Value | Notes                                                                    |
| ----------------- | ----- | ------------------------------------------------------------------------ |
| `slow_query_log`  | `1`   | Enabled                                                                  |
| `long_query_time` | `0.5` | Queries exceeding 500ms are logged as slow queries — production standard |

### CloudWatch Log Groups

| Log Group                                  | Retention |
| ------------------------------------------ | --------- |
| `/aws/rds/instance/{identifier}/error`     | 30 days   |
| `/aws/rds/instance/{identifier}/slowquery` | 30 days   |

---

## DynamoDB Tables

### Session Table (`SessionTable-{environment}`)

| Setting                | Value                                                  |
| ---------------------- | ------------------------------------------------------ |
| Billing                | `PAY_PER_REQUEST`                                      |
| Hash key               | `SessionID` (String)                                   |
| TTL attribute          | `ExpiresAt` — sessions automatically deleted on expiry |
| Encryption             | Enabled (AWS managed key)                              |
| Point-in-time recovery | Disabled (dev)                                         |

### User Table (`UserTable-{environment}`)

| Setting                | Value                                             |
| ---------------------- | ------------------------------------------------- |
| Billing                | `PAY_PER_REQUEST`                                 |
| Hash key               | `UserID` (String)                                 |
| GSI                    | `EmailIndex` — hash key `Email`, projection `ALL` |
| Encryption             | Enabled (AWS managed key)                         |
| Point-in-time recovery | Disabled (dev)                                    |

---

## Known Issues

### RDS Auto-Creates CloudWatch Log Groups

When `enabled_cloudwatch_logs_exports` is set on an RDS instance, AWS automatically creates the CloudWatch log groups if they do not exist. If Terraform attempts to create the same log groups, a `ResourceAlreadyExistsException` error is thrown.

**Root cause:** The `depends_on` block in `rds.tf` that would force Terraform to create the log groups before the RDS instance is currently commented out.

**Workaround applied:** If the error occurs, delete the auto-created log groups from the AWS console and re-run `terraform apply`. Terraform will recreate them with the correct 30-day retention policy.

**Permanent fix (TODO):** Uncomment the `depends_on` block in `rds.tf`:

```hcl
depends_on = [
  aws_cloudwatch_log_group.rds_error_logs,
  aws_cloudwatch_log_group.rds_slowquery_logs
]
```

---

## Inputs

| Variable                | Type         | Default       | Description                          |
| ----------------------- | ------------ | ------------- | ------------------------------------ |
| `environment`           | string       | —             | Environment name                     |
| `private_db_subnet_ids` | list(string) | —             | Private DB subnet IDs                |
| `rds_sg_id`             | string       | —             | RDS security group ID                |
| `allocated_storage`     | number       | `20`          | RDS storage in GB                    |
| `db_engine`             | string       | `mysql`       | Database engine                      |
| `instance_class`        | string       | `db.t3.micro` | RDS instance class                   |
| `db_username`           | string       | —             | Database master username             |
| `db_password`           | string       | —             | Database master password (sensitive) |

---

## Outputs

| Output                       | Description                                  |
| ---------------------------- | -------------------------------------------- |
| `db_instance_name`           | Database name                                |
| `db_instance_endpoint`       | RDS connection endpoint                      |
| `db_instance_arn`            | RDS instance ARN                             |
| `db_instance_id`             | RDS instance ID                              |
| `db_instance_status`         | RDS instance status                          |
| `db_subnet_group_name`       | DB subnet group name                         |
| `db_subnet_group_arn`        | DB subnet group ARN                          |
| `db_subnet_group_id`         | DB subnet group ID                           |
| `dynamodb_session_table_arn` | Session table ARN — passed to compute module |
| `dynamodb_user_table_arn`    | User table ARN — passed to compute module    |

---

## Future Improvements

- Enable `multi_az = true` for production high availability
- Enable `point_in_time_recovery` on both DynamoDB tables for production
- Store `db_password` in AWS Secrets Manager instead of Terraform variables
