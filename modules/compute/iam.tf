# create iam role for the EC2 instances to access the SSM 
resource "aws_iam_role" "ec2_ssm_role" {
  name = "EC2SSMRole-${var.environment}"
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
    Name = "EC2SSMRole-${var.environment}"
  }
}

# attach the AmazonSSMManagedInstanceCore policy to the EC2 SSM role to allow the EC2 instances to access the SSM service
resource "aws_iam_role_policy_attachment" "ec2_ssm_role_attachment" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# create an instance profile for the EC2 instances to use the IAM role
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "EC2SSMProfile-${var.environment}"
  role = aws_iam_role.ec2_ssm_role.name
}