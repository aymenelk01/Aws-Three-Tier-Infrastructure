# Compute Module

This module provisions the application tier: Application Load Balancer, Auto Scaling Group, EC2 Launch Template, IAM role, CloudWatch Agent, and SSM Parameter Store configuration.

---

## Resources Created

- Application Load Balancer (ALB) with access logging to S3
- ALB Target Group with health checks
- ALB Listener on port 80 (HTTP)
- EC2 Launch Template (Amazon Linux 2023, dynamic AMI lookup)
- Auto Scaling Group (min: 1, desired: 2, max: 4)
- IAM Role + Instance Profile for EC2
- CloudWatch Log Groups (nginx access, nginx error, system)
- SSM Parameter Store entry for CloudWatch Agent configuration

---

## Architecture

```
CloudFront
    ↓ HTTP :80
   ALB (public subnets, spanning 2 AZs)
    ↓ HTTP :80
   Target Group
    ↓
   EC2 ASG (private app subnets)
```

---

## EC2 Configuration

### AMI

Dynamic lookup via `data "aws_ami"` — always uses the most recent Amazon Linux 2023 x86_64 HVM AMI. No hardcoded AMI ID.

### Instance Type

`t3.micro` (default, configurable via `instance_type` variable)

### User Data (`user_data.sh`)

Executed at instance launch via `templatefile()`. Performs:

1. Installs SSM Agent explicitly (`dnf install -y amazon-ssm-agent`)
2. Installs nginx and CloudWatch Agent
3. Syncs images from S3 static bucket to nginx html directory via cron job (every minute)
4. Creates `index.html` with instance ID from EC2 metadata service (IMDSv2)
5. Fetches CloudWatch Agent config from SSM Parameter Store and starts the agent

### CloudWatch Agent

Config is stored in SSM Parameter Store at `/ec2/{environment}/cloudwatch-agent-config`. Delivered to instances at startup — updatable without instance replacement.

**Log Groups (30-day retention):**

| Log Group           | Source                           |
| ------------------- | -------------------------------- |
| `/ec2/nginx/access` | `/var/log/nginx/access.log`      |
| `/ec2/nginx/error`  | `/var/log/nginx/error.log`       |
| `/ec2/system`       | `/var/log/cloud-init-output.log` |

**Metrics collected (60s interval):**

- CPU: `cpu_usage_idle`, `cpu_usage_user`, `cpu_usage_system`
- Memory: `mem_used_percent`, `mem_available_percent`
- Disk: `disk_used_percent`, `disk_free` on `/`

---

## IAM Role & Permissions

Role: `EC2Role-{environment}`

| Policy                         | Type                   | Purpose                                                             |
| ------------------------------ | ---------------------- | ------------------------------------------------------------------- |
| `AmazonSSMManagedInstanceCore` | AWS Managed            | SSM Session Manager access                                          |
| `CloudWatchAgentServerPolicy`  | AWS Managed            | CloudWatch Agent metrics and logs                                   |
| `EC2SSMParametersPolicy`       | Inline                 | `ssm:GetParameter` scoped to CloudWatch agent config path           |
| `EC2StaticFilesAccessPolicy`   | Inline (JSON template) | `s3:GetObject`, `s3:PutObject`, `s3:ListBucket` on static bucket    |
| `EC2LogsAccessPolicy`          | Inline (JSON template) | `s3:PutObject` on logs bucket                                       |
| `EC2DynamoDBAccessPolicy`      | Inline (JSON template) | DynamoDB actions scoped to session table, user table, and Email GSI |

> `AmazonSSMManagedInstanceCore` does NOT include `ssm:GetParameter` — it is added as a separate inline policy scoped to the CloudWatch agent config parameter path only.

---

## Health Check Configuration

| Parameter           | Value                   |
| ------------------- | ----------------------- |
| Path                | `/`                     |
| Protocol            | HTTP                    |
| Interval            | 30 seconds              |
| Timeout             | 5 seconds               |
| Healthy threshold   | 3 consecutive successes |
| Unhealthy threshold | 2 consecutive failures  |
| Success codes       | `200`                   |

---

## Inputs

| Variable                     | Type         | Default    | Description                    |
| ---------------------------- | ------------ | ---------- | ------------------------------ |
| `environment`                | string       | —          | Environment name               |
| `vpc_id`                     | string       | —          | VPC ID                         |
| `alb_sg_id`                  | string       | —          | ALB security group ID          |
| `ec2_sg_id`                  | string       | —          | EC2 security group ID          |
| `public_subnet_ids`          | list(string) | —          | Public subnet IDs for ALB      |
| `private_app_subnet_ids`     | list(string) | —          | Private subnet IDs for EC2 ASG |
| `instance_type`              | string       | `t3.micro` | EC2 instance type              |
| `static_bucket_name`         | string       | —          | Static files S3 bucket name    |
| `static_bucket_arn`          | string       | —          | Static files S3 bucket ARN     |
| `logs_bucket_name`           | string       | —          | Logs S3 bucket name            |
| `logs_bucket_arn`            | string       | —          | Logs S3 bucket ARN             |
| `dynamodb_session_table_arn` | string       | —          | DynamoDB session table ARN     |
| `dynamodb_user_table_arn`    | string       | —          | DynamoDB user table ARN        |
| `aws_region`                 | string       | —          | AWS region                     |

---

## Outputs

| Output               | Description                                              |
| -------------------- | -------------------------------------------------------- |
| `alb_arn`            | ALB ARN                                                  |
| `alb_dns_name`       | ALB DNS name — passed to CDN module as CloudFront origin |
| `target_group_arn`   | Target group ARN                                         |
| `launch_template_id` | Launch template ID                                       |
| `asg_id`             | Auto Scaling Group ID                                    |

---

## Lessons Learned

### SSM Agent Not Pre-installed on AL2023 AMI in eu-south-1

**Issue:** EC2 instances were not appearing in AWS Systems Manager Fleet Manager despite correct IAM role, instance profile, and network configuration.

**Root Cause:** The Amazon Linux 2023 AMI in `eu-south-1` does not have SSM Agent pre-installed, contrary to AWS documentation which states AL2023 AMIs include SSM Agent by default.

**Debugging Process:**

- Verified IAM role and instance profile were correctly attached
- Verified NAT Gateway routing was correct
- Verified outbound port 443 was open
- Used nginx as a proxy to read instance logs via browser — creative workaround for instances with no direct SSH access
- Discovered `amazon-ssm-agent.service could not be found` confirming the agent was missing entirely

**Solution:** Explicitly install SSM Agent in `user_data.sh`:

```bash
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
```

**Takeaway:** Never assume AMI pre-installation. Always explicitly install and start SSM Agent in user data for reliable Session Manager access, regardless of AMI documentation.
