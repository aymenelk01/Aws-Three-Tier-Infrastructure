# Cost Optimization Study: Log Archiving Strategy

> **Note:** This is a proposed architecture study and is not implemented in this project.
> The current dev environment uses CloudWatch Logs with 30-day retention directly —
> sufficient for debugging with no real traffic. The Kinesis Firehose → S3 Glacier
> pipeline would be implemented when the project moves to production, where log volume
> grows continuously and long-term retention becomes a compliance or cost concern.

---

## 1. Executive Summary

This study proposes a hybrid log archiving architecture that balances operational needs (real-time troubleshooting) with cost efficiency. The proposed system replaces indefinite CloudWatch Logs storage with a tiered pipeline: short-term retention in CloudWatch, automated export via Kinesis Data Firehose, and long-term archival in S3 Glacier.

---

## 2. Problem Statement

CloudWatch Logs charges $0.03/GB per month for storage in `eu-south-1`. In a production environment with continuous nginx access logs, RDS slow query logs, and system logs, storage accumulates silently over time. There is no automatic expiry unless retention policies are explicitly configured. This leads to unbounded growth in the monthly bill with no operational value from logs older than a few days.

---

## 3. Proposed Architecture

```
CloudWatch Logs (Hot Layer — 7 days retention)
        ↓
Kinesis Data Firehose (near real-time streaming)
        ↓
S3 Bucket (Standard storage)
        ↓ S3 Lifecycle Rule (90 days)
S3 Glacier Instant Retrieval (Archive Layer)
        ↓ S3 Lifecycle Rule (365 days)
Expire / Delete
```

**Hot Layer — CloudWatch Logs (7 days)**
Retain only recent logs for immediate troubleshooting and real-time monitoring via CloudWatch Logs Insights. Reduce retention from 30 days to 7 days to minimize storage cost.

**Pipeline — Kinesis Data Firehose**
Streams log events from CloudWatch Logs to S3 in near real-time. Firehose handles batching, compression, and delivery without custom code.

**Archive Layer — S3 + Lifecycle Rules**
Logs land in S3 Standard on arrival. Lifecycle rules automatically transition to S3 Glacier Instant Retrieval after 90 days and expire after 365 days. Glacier Instant Retrieval costs approximately $0.004/GB per month — over 85% cheaper than CloudWatch.

---

## 4. Cost Comparison (Estimated)

| Log Volume | CloudWatch Storage/month | S3 Glacier Storage/month | Monthly Saving |
| ---------- | ------------------------ | ------------------------ | -------------- |
| 10 GB      | $0.30                    | ~$0.04                   | ~$0.26         |
| 50 GB      | $1.50                    | ~$0.20                   | ~$1.30         |
| 100 GB     | $3.00                    | ~$0.40                   | ~$2.60         |
| 500 GB     | $15.00                   | ~$2.00                   | ~$13.00        |

> Savings compound monthly. At production scale with multiple services logging continuously, the annual saving becomes significant.

---

## 5. Technical Benefits

**Cost:** Glacier Instant Retrieval reduces long-term log storage cost by over 85% compared to CloudWatch.

**Compliance:** Logs can be retained for years at negligible cost — satisfies audit and regulatory requirements without significant spend.

**Operational clarity:** CloudWatch UI stays clean with only recent, relevant logs. Reduces noise when debugging.

**Security:** Logs archived in S3 are isolated from the primary operational environment. S3 Object Lock can be applied for tamper-proof retention if compliance requires it.

**Durability:** S3 provides 99.999999999% (11 nines) durability — more reliable long-term storage than CloudWatch.

---

## 6. Implementation Considerations

- Kinesis Data Firehose has a minimum buffer interval of 60 seconds — logs are not real-time in S3, only near real-time.
- Glacier Instant Retrieval has millisecond retrieval latency — suitable for occasional log investigations.
- Firehose delivery costs apply per GB processed — factor this into the cost model for high-volume environments.
- CloudWatch Subscription Filters are required to route log groups to Firehose — one filter per log group.

---

## 7. Alignment with AWS Well-Architected Framework

This proposal is based on the **Cost Optimization** pillar:

- **Manage demand and supply resources** — right-size retention periods to operational needs
- **Optimize over time** — use storage tiering to match cost to access frequency
- **Expenditure awareness** — eliminate silent cost growth from unbounded log accumulation
