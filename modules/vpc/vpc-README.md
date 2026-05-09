# VPC Module

This module provisions the full network foundation for the three-tier infrastructure in `eu-south-1`.

---

## Resources Created

- VPC with DNS hostnames and DNS support enabled
- Internet Gateway
- NAT Gateway per AZ (with Elastic IPs)
- 6 subnets across 2 Availability Zones (3 tiers × 2 AZs)
- Route tables per tier with correct routing rules
- VPC Gateway Endpoints for S3 and DynamoDB

---

## Subnet Layout

| Tier          | Subnet Name      | CIDR (AZ-1)    | CIDR (AZ-2)    | Route            |
| ------------- | ---------------- | -------------- | -------------- | ---------------- |
| Public        | PublicSubnet     | `10.0.1.0/24`  | `10.0.2.0/24`  | IGW              |
| App (Private) | PrivateAppSubnet | `10.0.10.0/24` | `10.0.11.0/24` | NAT Gateway      |
| DB (Private)  | PrivateDbSubnet  | `10.0.20.0/24` | `10.0.21.0/24` | No default route |

**DB subnets have no default route** — RDS instances have no internet path at the routing level.

---

## Gateway Endpoints

| Endpoint | Type    | Associated Route Tables |
| -------- | ------- | ----------------------- |
| S3       | Gateway | Public, App, DB         |
| DynamoDB | Gateway | Public, App             |

Traffic to S3 and DynamoDB from private subnets routes through the VPC Gateway Endpoints — never through NAT Gateway or the internet. This eliminates NAT Gateway data processing costs for S3 and DynamoDB traffic.

---

## Inputs

| Variable                   | Type         | Default                            | Description                            |
| -------------------------- | ------------ | ---------------------------------- | -------------------------------------- |
| `environment`              | string       | `dev`                              | Environment name used in resource tags |
| `vpc_cidr`                 | string       | `10.0.0.0/16`                      | CIDR block for the VPC                 |
| `availability_zones`       | list(string) | `["eu-south-1a", "eu-south-1b"]`   | AZs to deploy into                     |
| `public_subnet_cidrs`      | list(string) | `["10.0.1.0/24", "10.0.2.0/24"]`   | Public subnet CIDRs                    |
| `private_app_subnet_cidrs` | list(string) | `["10.0.10.0/24", "10.0.11.0/24"]` | App subnet CIDRs                       |
| `private_db_subnet_cidrs`  | list(string) | `["10.0.20.0/24", "10.0.21.0/24"]` | DB subnet CIDRs                        |
| `aws_region`               | string       | —                                  | AWS region (required, no default)      |

---

## Outputs

| Output                   | Description                    |
| ------------------------ | ------------------------------ |
| `vpc_id`                 | VPC ID                         |
| `internet_gateway_id`    | Internet Gateway ID            |
| `nat_eip_id`             | List of NAT Elastic IP IDs     |
| `nat_gateway_id`         | List of NAT Gateway IDs        |
| `public_subnet_ids`      | List of public subnet IDs      |
| `private_app_subnet_ids` | List of private app subnet IDs |
| `private_db_subnet_ids`  | List of private DB subnet IDs  |
| `availability_zones`     | List of AZs used               |
| `public_route_table_id`  | Public route table ID          |
| `app_route_table_id`     | List of app route table IDs    |
| `db_route_table_id`      | DB route table ID              |
| `s3_endpoint_id`         | S3 Gateway Endpoint ID         |
