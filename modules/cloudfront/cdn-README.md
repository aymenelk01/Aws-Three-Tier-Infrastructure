# CDN Module

This module provisions the CloudFront distribution, Origin Access Control (OAC), and S3 bucket policy that together form the content delivery and security layer for the infrastructure.

---

## Resources Created

- CloudFront distribution with two origins (S3 and ALB)
- Origin Access Control (OAC) with SigV4 signing
- S3 bucket policy granting CloudFront read access to the static files bucket

---

## Architecture

```
Internet (HTTPS)
      ↓
 CloudFront
      ↓ /static/*              ↓ all other paths
   S3 Origin (OAC)          ALB Origin (HTTP :80)
   static files              application traffic
```

---

## CloudFront Distribution

### Origins

| Origin ID         | Type         | Domain                        | Protocol               |
| ----------------- | ------------ | ----------------------------- | ---------------------- |
| `S3staticOrigins` | S3           | `bucket_regional_domain_name` | Signed via OAC (SigV4) |
| `ALBorigins`      | Custom (ALB) | ALB DNS name                  | HTTP only (port 80)    |

> S3 origin must use `bucket_regional_domain_name`, not `bucket_domain_name`. Using the global domain name causes signature mismatch errors with OAC.

> ALB origin uses `http-only` protocol. SSL terminates at CloudFront — the ALB listener is HTTP port 80 only. There is no SSL certificate on the ALB.

### Cache Behaviors

| Behavior                 | Path Pattern    | Origin | Allowed Methods                              | Query String | Cookies |
| ------------------------ | --------------- | ------ | -------------------------------------------- | ------------ | ------- |
| `ordered_cache_behavior` | `/static/*`     | S3     | GET, HEAD                                    | No           | None    |
| `default_cache_behavior` | All other paths | ALB    | GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE | Yes          | All     |

**S3 behavior** caches GET and HEAD only — static files are read-only, no write operations needed.

**ALB behavior** forwards all HTTP methods — the application requires POST, PUT, PATCH, DELETE for write operations. Query strings and cookies are fully forwarded so the application receives complete requests.

### Viewer Protocol Policy

Both behaviors use `redirect-to-https` — CloudFront accepts HTTP requests and returns an HTTP 301 redirect to the HTTPS equivalent. Users always end up on HTTPS without seeing an error.

### SSL Certificate

Uses `cloudfront_default_certificate = true` — the free AWS-managed certificate for `*.cloudfront.net`. Valid only for the auto-generated CloudFront domain. A custom domain requires an ACM certificate in `us-east-1` and an `aliases` block.

### Geo Restrictions

None — distribution accessible from all countries.

---

## Origin Access Control (OAC)

| Setting          | Value                                    |
| ---------------- | ---------------------------------------- |
| Origin type      | S3                                       |
| Signing behavior | `always` — every request to S3 is signed |
| Signing protocol | `sigv4`                                  |

OAC gives CloudFront a verifiable identity for S3 requests. The S3 bucket stays fully private (Block Public Access enabled) — only CloudFront can read objects, enforced by the bucket policy.

OAC replaced the older OAI (Origin Access Identity) as the recommended method. SigV4 signing is more secure and supports additional S3 features including SSE-KMS encrypted buckets.

---

## S3 Bucket Policy (`s3policy.tf`)

Attached to the static files bucket. Allows `s3:GetObject` only when:

1. The caller is the `cloudfront.amazonaws.com` service principal
2. The `AWS:SourceArn` condition matches this specific CloudFront distribution ARN

The `AWS:SourceArn` condition is critical — without it, any CloudFront distribution in any AWS account could read the bucket. The condition scopes access to this distribution only.

> `s3policy.tf` is defined in the CDN module, not the storage module, because it references `aws_cloudfront_distribution.cdn.arn` which only exists after `main.tf` is applied.

---

## Deployment Notes

- CloudFront distribution takes **5–10 minutes** to deploy globally after `terraform apply`
- After uploading new static files to S3, run a cache invalidation:

```bash
aws cloudfront create-invalidation \
  --distribution-id <cloudfront_distribution_id> \
  --paths "/*"
```

- AWS provides 1000 free invalidation paths per month — `/*` counts as one path

---

## Inputs

| Variable                             | Type   | Description                                            |
| ------------------------------------ | ------ | ------------------------------------------------------ |
| `environment`                        | string | Environment name                                       |
| `aws_region`                         | string | AWS region                                             |
| `static_bucket_regional_domain_name` | string | S3 regional domain name for CloudFront origin          |
| `static_bucket_arn`                  | string | Static bucket ARN for bucket policy resource condition |
| `static_bucket_id`                   | string | Static bucket ID for bucket policy attachment          |
| `alb_dns_name`                       | string | ALB DNS name for CloudFront custom origin              |

---

## Outputs

| Output                       | Description                                                                |
| ---------------------------- | -------------------------------------------------------------------------- |
| `cloudfront_domain_name`     | Distribution URL (`*.cloudfront.net`) — use this to access the application |
| `cloudfront_distribution_id` | Distribution ID — required for cache invalidation                          |

---

## Future Improvements

- Add ACM certificate in `us-east-1` + Route 53 alias record for custom domain
- Attach AWS WAF to CloudFront for SQL injection, XSS, and rate limiting protection
- CloudFront access logging via CloudWatch Logs delivery API (v2) — currently requires all delivery resources to be provisioned in `us-east-1`
  regardless of distribution region, and has known provider bugs in
  `aws_cloudwatch_log_delivery_source` (hanging on apply).
  Deferred until the Terraform AWS provider stabilizes support.
