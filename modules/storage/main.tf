#1. create a bucket for the static files
resource "aws_s3_bucket" "static_files" {
  bucket = var.bucket_name
  
}