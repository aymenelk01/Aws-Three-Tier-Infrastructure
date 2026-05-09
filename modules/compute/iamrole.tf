# create iam role for the EC2 instances 
resource "aws_iam_role" "ec2_role" {
  name = "EC2Role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
    }
  )

  tags = {
    Name = "EC2Role-${var.environment}"
  }
}

# create an instance profile for the EC2 instances to use the IAM role
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2Profile-${var.environment}"
  role = aws_iam_role.ec2_role.name
  
}