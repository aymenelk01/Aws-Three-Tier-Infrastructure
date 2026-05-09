# Security Module

This module provisions the security groups for the three-tier infrastructure using a chaining pattern — each tier only accepts traffic from the tier directly above it.

---

## Security Group Chain

```
CloudFront (prefix list)
        ↓ port 80
    ALB-SG
        ↓ port 80
    EC2-SG
        ↓ port 3306
    RDS-SG
```

No security group accepts traffic from the public internet except the ALB SG, and only on port 80 from the CloudFront managed prefix list.

---

## Resources Created

### ALB Security Group (`ALB-SG-{environment}`)

| Direction | Port | Source                                       | Notes                                                                            |
| --------- | ---- | -------------------------------------------- | -------------------------------------------------------------------------------- |
| Ingress   | 80   | CloudFront managed prefix list `pl-1bbc5972` | Only CloudFront edge IPs allowed                                                 |
| Ingress   | 443  | `0.0.0.0/0`                                  | Dead code — no HTTPS listener on ALB yet. Reserved for future SSL implementation |
| Egress    | All  | `0.0.0.0/0`                                  | Allow all outbound                                                               |

### EC2 Security Group (`EC2-SG-{environment}`)

| Direction | Port | Source      | Notes                                                                         |
| --------- | ---- | ----------- | ----------------------------------------------------------------------------- |
| Ingress   | 80   | ALB-SG      | Traffic from ALB only                                                         |
| Ingress   | 443  | ALB-SG      | Dead code — ALB sends on port 80 only. Reserved for future SSL implementation |
| Egress    | All  | `0.0.0.0/0` | Allow all outbound                                                            |

### RDS Security Group (`RDS-SG-{environment}`)

| Direction | Port | Source      | Notes                                 |
| --------- | ---- | ----------- | ------------------------------------- |
| Ingress   | 3306 | EC2-SG      | MySQL traffic from EC2 instances only |
| Egress    | All  | `0.0.0.0/0` | Allow all outbound                    |

---

## Known Issues

- **Port 443 rules are dead code** — there is no HTTPS listener on the ALB and no SSL certificate configured. These rules will be activated when ACM + Route 53 are added in a future iteration.
- **ALB SG quota requirement** — the CloudFront managed prefix list counts as 55 rules against the security group limit. The VPC quota for inbound/outbound rules per security group must be increased to 100 before deployment. See root README for the quota increase command.

---

## Inputs

| Variable      | Type   | Description                            |
| ------------- | ------ | -------------------------------------- |
| `environment` | string | Environment name used in resource tags |
| `vpc_id`      | string | VPC ID from the VPC module             |

---

## Outputs

| Output      | Description                                       |
| ----------- | ------------------------------------------------- |
| `alb_sg_id` | ALB security group ID — passed to compute module  |
| `ec2_sg_id` | EC2 security group ID — passed to compute module  |
| `rds_sg_id` | RDS security group ID — passed to database module |
