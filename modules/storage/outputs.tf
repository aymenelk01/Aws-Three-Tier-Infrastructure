# outputs for the storage module
output "static_bucket_name" {
  description = "The name of the S3 bucket for static files"
  value       = aws_s3_bucket.static_files.bucket
}


output "static_bucket_id" {
  description = "The ID of the S3 bucket for static files"
  value       = aws_s3_bucket.static_files.id
}

output "static_bucket_arn" {
  description = "The ARN of the S3 bucket for static files"
  value       = aws_s3_bucket.static_files.arn
}

output "static_bucket_regional_domain_name" {
  description = "The regional domain name of the S3 bucket for static files"
  value       = aws_s3_bucket.static_files.bucket_regional_domain_name
  
}

output "state_bucket_name" {
  description = "The name of the S3 bucket for state files"
  value       = aws_s3_bucket.state_files.bucket
}

output "state_bucket_arn" {
  description = "The ARN of the S3 bucket for state files"
  value       = aws_s3_bucket.state_files.arn
}

output "logs_bucket_domain_name" {
  description = "The domain name of the S3 bucket for log files"
  value       = aws_s3_bucket.logs.bucket_domain_name
}

output "logs_bucket_name" {
  description = "The name of the S3 bucket for log files"
  value       = aws_s3_bucket.logs.bucket
}

output "logs_bucket_arn" {
  description = "The ARN of the S3 bucket for log files"
  value       = aws_s3_bucket.logs.arn
}

output "logs_bucket_id" {
  description = "The ID of the S3 bucket for log files"
  value       = aws_s3_bucket.logs.id
}
