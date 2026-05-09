# Useful Commands — aws-three-tier-infrastructure

A reference guide for common AWS CLI and Terraform commands used with this project.

---

## S3

### Upload a single file to static bucket
```bash
aws s3 cp ./path/to/file.jpg s3://your-static-bucket-name/images/file.jpg
```

### Sync local folder to static bucket
```bash
aws s3 sync ./local-folder s3://your-static-bucket-name/ --delete
```

### List objects in a bucket
```bash
aws s3 ls s3://your-static-bucket-name/ --recursive
```

### Delete a specific object
```bash
aws s3 rm s3://your-static-bucket-name/images/file.jpg
```

### Force delete a bucket and all its objects
```bash
aws s3 rb s3://your-bucket-name --force
```

### Upload and invalidate CloudFront cache in one sequence
```bash
aws s3 sync ./local-folder s3://your-static-bucket-name/ --delete && \
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/*"
```

---

## CloudFront

### Create a full cache invalidation
```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/*"
```

### Invalidate a specific path
```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/images/file.jpg"
```

### Check distribution deployment status
```bash
aws cloudfront get-distribution \
  --id YOUR_DISTRIBUTION_ID \
  --query 'Distribution.Status' \
  --output text
```

### List all distributions
```bash
aws cloudfront list-distributions \
  --query 'DistributionList.Items[*].{ID:Id,Domain:DomainName,Status:Status}' \
  --output table
```

---

## EC2 / SSM

### List all running EC2 instances
```bash
aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,IP:PrivateIpAddress,State:State.Name}' \
  --output table \
  --region eu-south-1
```

### Check EC2 instance status
```bash
aws ec2 describe-instance-status \
  --instance-ids YOUR_INSTANCE_ID \
  --region eu-south-1
```

### Start SSM Session Manager session
```bash
aws ssm start-session \
  --target YOUR_INSTANCE_ID \
  --region eu-south-1
```

### List instances registered in SSM
```bash
aws ssm describe-instance-information \
  --query 'InstanceInformationList[*].{ID:InstanceId,Ping:PingStatus,Agent:AgentVersion}' \
  --output table \
  --region eu-south-1
```

### Port forwarding via SSM (for RDS access from local machine)
```bash
aws ssm start-session \
  --target YOUR_INSTANCE_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["your-rds-endpoint"],"portNumber":["3306"],"localPortNumber":["3306"]}' \
  --region eu-south-1
```
Then connect to RDS locally:
```bash
mysql -h 127.0.0.1 -P 3306 -u your-db-username -p
```

---

## RDS

### Check RDS instance status
```bash
aws rds describe-db-instances \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address}' \
  --output table \
  --region eu-south-1
```

### Check RDS parameter group
```bash
aws rds describe-db-parameters \
  --db-parameter-group-name YOUR_PARAMETER_GROUP_NAME \
  --query 'Parameters[?ParameterName==`slow_query_log` || ParameterName==`long_query_time`]' \
  --output table \
  --region eu-south-1
```

---

## CloudWatch

### Tail a log group in real time
```bash
aws logs tail /ec2/nginx/access --follow --region eu-south-1
```

### Tail with filter pattern
```bash
aws logs tail /ec2/nginx/error --follow --format short --region eu-south-1
```

### List all log groups
```bash
aws logs describe-log-groups \
  --query 'logGroups[*].{Name:logGroupName,Retention:retentionInDays}' \
  --output table \
  --region eu-south-1
```

### Get latest log events from a log group
```bash
aws logs get-log-events \
  --log-group-name /ec2/nginx/access \
  --log-stream-name YOUR_LOG_STREAM_NAME \
  --region eu-south-1
```

---

## Terraform

### Initialize
```bash
terraform init
```

### Preview changes
```bash
terraform plan
```

### Apply changes
```bash
terraform apply
```

### Apply a specific module only
```bash
terraform apply -target=module.cdn
```

### Destroy all resources
```bash
terraform destroy
```

### Destroy a specific module only
```bash
terraform destroy -target=module.cdn
```

### Show all outputs
```bash
terraform output
```

### Show a specific output
```bash
terraform output cloudfront_domain_name
```

### Import an existing resource into state
```bash
terraform import module.database.aws_cloudwatch_log_group.rds_error_logs /aws/rds/instance/dev-db-instance/error
```

### List all resources in state
```bash
terraform state list
```

### Show details of a specific resource in state
```bash
terraform state show module.cdn.aws_cloudfront_distribution.cdn
```

### Force unlock state (if stuck)
```bash
terraform force-unlock LOCK_ID
```

### Validate configuration
```bash
terraform validate
```

### Format all Terraform files
```bash
terraform fmt -recursive
```

---

## Service Quotas

### Check current rules per security group quota
```bash
aws service-quotas list-service-quotas \
  --service-code vpc \
  --region eu-south-1 \
  --query "Quotas[?QuotaName=='Inbound or outbound rules per security group'].Value"
```

### Request quota increase
```bash
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code L-0EA8095F \ # this code is for milano region (eu-south-1)
  --desired-value 100 \
  --region eu-south-1
```

### Check quota increase request status
```bash
aws service-quotas get-requested-service-quota-change \
  --request-id YOUR_REQUEST_ID \
  --region eu-south-1 \
  --query 'RequestedQuota.Status'
```
