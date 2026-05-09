# Storage Module

This module provisions three S3 buckets for different purposes and a DynamoDB table for Terraform state locking.

---

## Resources Created

- S3 static files bucket (AES256 encryption, Block Public Access)
- S3 logs bucket (AES256 encryption, Block Public Access, lifecycle policy)
- S3 Terraform state bucket (AES256 encryption, versioning enabled, Block Public Access)
- DynamoDB table for Terraform state locking
- S3 bucket policy for logs bucket (ALB access log delivery)

---

## Buckets

### Static Files Bucket (`{environment}-{static_bucket_name}`)

| Setting             | Value                                   |
| ------------------- | --------------------------------------- |
| Encryption          | AES256 (SSE-S3)                         |
| Block Public Access | All four settings enabled               |
| Public access       | None — accessed only via CloudFront OAC |

Serves static assets (images, CSS, JS) through CloudFront. The bucket policy granting CloudFront read access is defined in the CDN module, not here.

> **Note:** CloudFront must use `bucket_regional_domain_name` as the origin domain, not `bucket_domain_name`. The `static_bucket_regional_domain_name` output provides the correct value.

### Logs Bucket (`{environment}-{logs_bucket_name}`)

| Setting             | Value                                                        |
| ------------------- | ------------------------------------------------------------ |
| Encryption          | AES256 (SSE-S3)                                              |
| Block Public Access | All four settings enabled                                    |
| ALB access logs     | Delivered by ELB service account `635631232127` (eu-south-1) |

**Lifecycle Policy:**

| Stage     | Transition | Storage Class |
| --------- | ---------- | ------------- |
| 0–30 days | —          | STANDARD      |
| 30 days   | Transition | STANDARD_IA   |
| 90 days   | Transition | GLACIER       |
| 365 days  | Expire     | Deleted       |

**Bucket Policy:** Allows `s3:PutObject` from the ELB service account ARN `arn:aws:iam::635631232127:root` — the dedicated AWS account for ALB access log delivery in `eu-south-1`.

### State Bucket (`{environment}-{state_bucket_name}`)

| Setting             | Value                     |
| ------------------- | ------------------------- |
| Encryption          | AES256 (SSE-S3)           |
| Versioning          | Enabled                   |
| Block Public Access | All four settings enabled |

Stores the Terraform remote state file. Versioning protects against accidental state overwrites.

---

## DynamoDB State Lock Table (`terraform-lock-{environment}`)

| Setting  | Value             |
| -------- | ----------------- |
| Billing  | `PAY_PER_REQUEST` |
| Hash key | `LockID` (String) |

Prevents concurrent Terraform operations from corrupting the state file. Referenced in the Terraform backend configuration.

---

## Known Issues

### `s3_endpoint_id` Variable is Unused

The `s3_endpoint_id` variable is declared but not used in any resource. It was originally intended for a VPC endpoint condition in the logs bucket policy — that condition was removed because it blocked both Terraform operations and the ELB service account from writing logs.

The variable can be safely removed in a future cleanup pass.

### ELB Account ID is Region-Specific

The ELB service account ID `635631232127` is specific to `eu-south-1`. If this infrastructure is deployed in a different region, the ELB account ID in `s3policies.tf` must be updated. AWS publishes the full list of ELB account IDs per region in their documentation.

---

## Inputs

| Variable             | Type   | Default | Description                     |
| -------------------- | ------ | ------- | ------------------------------- |
| `environment`        | string | —       | Environment name                |
| `static_bucket_name` | string | —       | Static files bucket name suffix |
| `logs_bucket_name`   | string | —       | Logs bucket name suffix         |
| `state_bucket_name`  | string | —       | State bucket name suffix        |
| `s3_endpoint_id`     | string | —       | Unused — see Known Issues       |

---

## Outputs

| Output                               | Description                                                     |
| ------------------------------------ | --------------------------------------------------------------- |
| `static_bucket_name`                 | Static bucket name — passed to compute module                   |
| `static_bucket_id`                   | Static bucket ID — passed to CDN module for bucket policy       |
| `static_bucket_arn`                  | Static bucket ARN — passed to CDN module and compute module     |
| `static_bucket_regional_domain_name` | Regional domain name — passed to CDN module as S3 origin        |
| `logs_bucket_name`                   | Logs bucket name — passed to compute module for ALB access logs |
| `logs_bucket_arn`                    | Logs bucket ARN — passed to compute module for IAM policy       |
| `state_bucket_name`                  | State bucket name                                               |
| `state_bucket_arn`                   | State bucket ARN                                                |
