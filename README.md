# aws-three-tier-infrastructure

A production-grade three-tier AWS infrastructure built with Terraform, deployed in `eu-south-1` (Milan). This project demonstrates infrastructure-as-code best practices across networking, compute, database, storage, and content delivery layers.

---

## Architecture

![Architecture Diagram](architecture.png)

### Traffic Flow

```
Internet (HTTPS)
      ↓
 CloudFront (CDN + SSL termination)
      ↓ /static/*                    ↓ all other paths
 S3 static bucket (via OAC)     ALB (HTTP :80, CloudFront prefix list only)
                                      ↓
                               EC2 Auto Scaling Group
                               (private app subnets)
                                      ↓
                               RDS MySQL (private DB subnets)
```

### Key Design Decisions

| Decision                 | Choice               | Reason                                                                       |
| ------------------------ | -------------------- | ---------------------------------------------------------------------------- |
| Public entry point       | CloudFront only      | ALB restricted to CloudFront managed prefix list — no direct internet access |
| EC2 access               | SSM Session Manager  | No bastion host, no SSH key management                                       |
| S3 access from EC2       | VPC Gateway Endpoint | Traffic never leaves AWS network, no NAT cost                                |
| DynamoDB access from EC2 | VPC Gateway Endpoint | Traffic never leaves AWS network, no NAT cost                                |
| CloudWatch Agent config  | SSM Parameter Store  | Updatable without instance replacement                                       |
| S3 origin authentication | OAC (SigV4)          | Bucket stays fully private, replaces deprecated OAI                          |
| RDS internet access      | None                 | DB route table has no default route                                          |
| SSL termination          | CloudFront           | ALB listener is HTTP :80 only                                                |

---

## Module Structure

```
modules/
├── vpc/          # VPC, subnets, NAT Gateways, route tables, Gateway Endpoints
├── security/     # Security groups: ALB SG → EC2 SG → RDS SG (chained)
├── compute/      # ALB, ASG, EC2 Launch Template, IAM, CloudWatch Agent, SSM
├── database/     # RDS MySQL, DynamoDB tables, CloudWatch log groups
├── storage/      # S3 buckets (static, logs, state), DynamoDB lock table
└── cdn/          # CloudFront distribution, OAC, S3 bucket policy
```

Each module has its own `README.md` with full resource details, inputs, outputs, and known issues.

---

## Infrastructure Details

### Networking

- VPC `10.0.0.0/16` across `eu-south-1a` and `eu-south-1b`
- 6 subnets: 2 public (ALB), 2 private app (EC2), 2 private DB (RDS)
- NAT Gateway per AZ — EC2 outbound internet via NAT, never direct
- DB subnets have no default route — RDS has no internet path at routing level
- VPC Gateway Endpoints for S3 and DynamoDB

### Security Group Chain

```
CloudFront prefix list → ALB SG (port 80)
                              ↓
                         EC2 SG (port 80 from ALB SG only)
                              ↓
                         RDS SG (port 3306 from EC2 SG only)
```

### Compute

- ALB + ASG with Launch Template (Amazon Linux 2023, dynamic AMI lookup)
- EC2: min 1, desired 2, max 4 instances — `t3.micro`
- CloudWatch Agent: nginx access logs, nginx error logs, cloud-init logs, CPU/Memory/Disk metrics
- S3 image sync to nginx via cron job every minute

### Database

- RDS MySQL 8.0, `db.t3.micro`, 20GB, `multi_az = false` (dev)
- Parameter group: `slow_query_log = 1`, `long_query_time = 0.5`
- DynamoDB session table (TTL on `ExpiresAt`) + user table (GSI on `Email`)

### Storage

- Static bucket: AES256, Block Public Access — served via CloudFront OAC only
- Logs bucket: lifecycle STANDARD → IA @ 30d → GLACIER @ 90d → expire @ 365d
- State bucket: versioning enabled, AES256

### CDN

- CloudFront with two origins: S3 (`/static/*`) and ALB (all other paths)
- OAC with SigV4 signing — S3 bucket policy scoped to this distribution ARN only
- `viewer_protocol_policy = redirect-to-https` on both cache behaviors
- Default CloudFront certificate (`*.cloudfront.net`)

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) with AWS provider `~> 6.0`
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured for `eu-south-1`
- AWS account with sufficient IAM permissions

### Required: VPC Security Group Quota Increase

The CloudFront managed prefix list counts as 55 rules. The default VPC quota of 60 rules per security group is insufficient. Request an increase to 100 before deploying:

```bash
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code L-0EA8095F \
  --desired-value 100 \
  --region eu-south-1
```

Wait for `APPROVED` before running `terraform apply`:

```bash
aws service-quotas get-requested-service-quota-change \
  --request-id <request-id> \
  --region eu-south-1 \
  --query 'RequestedQuota.Status'
```

---

## Deployment

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/aws-three-tier-infrastructure.git
cd aws-three-tier-infrastructure
```

### 2. Create `terraform.tfvars`

```hcl
aws_region         = "eu-south-1"
environment        = "dev"
db_username        = "your-db-username"
db_password        = "your-db-password"
static_bucket_name = "your-static-bucket-suffix"
state_bucket_name  = "your-state-bucket-suffix"
logs_bucket_name   = "your-logs-bucket-suffix"
```

> `terraform.tfvars` is listed in `.gitignore` and will not be committed.

### 3. Configure Terraform backend (optional)

To use the S3 remote backend, uncomment the `backend` block in `backend.tf` and update with your bucket and table names:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-state-bucket-name"
    key            = "terraform.tfstate"
    region         = "eu-south-1"
    dynamodb_table = "terraform-lock-dev"
    encrypt        = true
  }
}
```

> Terraform backend blocks do not support variable interpolation — values must be literal strings.

### 4. Initialize

```bash
terraform init
```

### 5. Plan

```bash
terraform plan
```

### 6. Apply

```bash
terraform apply
```

CloudFront takes 5–10 minutes to deploy globally after apply completes.

### 7. Access the application

Use the `cloudfront_domain_name` output to access the application via HTTPS.

---

## Outputs

| Output                           | Description                                         |
| -------------------------------- | --------------------------------------------------- |
| `cloudfront_domain_name`         | CloudFront URL — use this to access the application |
| `aws_cloudfront_distribution_id` | Distribution ID for cache invalidation              |
| `alb_dns_name`                   | ALB DNS name (direct access blocked by SG)          |
| `db_instance_endpoint`           | RDS connection endpoint                             |
| `static_bucket_name`             | S3 static files bucket name                         |
| `logs_bucket_name`               | S3 logs bucket name                                 |
| `state_bucket_name`              | S3 Terraform state bucket name                      |
| `vpc_id`                         | VPC ID                                              |
| `public_subnet_ids`              | Public subnet IDs                                   |
| `private_app_subnet_ids`         | Private app subnet IDs                              |
| `private_db_subnet_ids`          | Private DB subnet IDs                               |

### Cache Invalidation

After uploading new static files to S3:

```bash
aws cloudfront create-invalidation \
  --distribution-id <aws_cloudfront_distribution_id> \
  --paths "/*"
```

---

## Teardown

```bash
terraform destroy
```

---

## Cost Optimization

A cost optimization study is documented in [`cost_optimization.md`](cost_optimization.md).

The proposed architecture replaces long-term CloudWatch log storage with a Kinesis Data Firehose → S3 Glacier pipeline, reducing log storage costs by approximately 86% while maintaining compliance and auditability. Based on the **Cost Optimization** pillar of the AWS Well-Architected Framework.

---

## Known Issues

| Issue                                                   | Status             | Details                                                        |
| ------------------------------------------------------- | ------------------ | -------------------------------------------------------------- |
| RDS auto-creates CloudWatch log groups                  | Workaround applied | See database module README                                     |
| Port 443 on ALB and EC2 SG is dead code                 | Intentional        | No HTTPS listener yet — reserved for future SSL implementation |
| AL2023 AMI in eu-south-1 has no pre-installed SSM Agent | Fixed              | Installed explicitly in `user_data.sh`                         |

---

## Future Improvements

- CI/CD pipeline with GitHub Actions (terraform plan on PR, apply on merge, S3 sync, CloudFront cache invalidation)
- WAF on CloudFront for SQL injection, XSS, rate limiting, and bot protection
- ACM certificate in `us-east-1` + Route 53 custom domain
- RDS `multi_az = true` for production high availability
- ASG instance refresh with rolling update strategy and `min_healthy_percentage = 100`
- CloudWatch alarms with SNS email notifications
- DynamoDB point-in-time recovery for production
- Store `db_password` in AWS Secrets Manager instead of tfvars

---

## Author

**Aymen** — Aspire Junior Cloud Engineer
Preparing for AWS Solutions Architect Associate (SAA-C03)
Based in Italy | [LinkedIn] (https://www.linkedin.com/in/aymen-elkharchi-640a30312)
