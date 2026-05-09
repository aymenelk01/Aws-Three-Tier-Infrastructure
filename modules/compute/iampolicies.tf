# attach the AmazonSSMManagedInstanceCore policy to the EC2 SSM role to allow the EC2 instances to access the SSM service
resource "aws_iam_role_policy_attachment" "ec2_ssm_role_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# attach the ssm:getParameters permission to the EC2 SSM role to allow the EC2 instances to access the SSM parameters
resource "aws_iam_role_policy" "ec2_ssm_parameters_policy" {
  name = "EC2SSMParametersPolicy-${var.environment}"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Effect = "Allow"
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/ec2/${var.environment}/cloudwatch-agent-config"
      }
    ]
  })
}

# attach the CloudWatchAgentServerPolicy to the EC2 role to allow the EC2 instances to access the CloudWatch service
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent_role_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "ec2_logs_policy" {
  name = "EC2LogsAccessPolicy-${var.environment}"
  role = aws_iam_role.ec2_role.id
  
  policy = templatefile("${path.module}/policies/logsbucket.json", {
    logs_bucket_arn = var.logs_bucket_arn 
  })
}


# create an IAM policy to allow the EC2 instances to access the static files bucket and attach it to the EC2 role
resource "aws_iam_role_policy" "ec2_static_files_policy" {
  name = "EC2StaticFilesAccessPolicy-${var.environment}"
  role = aws_iam_role.ec2_role.id
  
  policy = templatefile("${path.module}/policies/staticfilesbucket.json", {
    static_bucket_arn = var.static_bucket_arn
  })
}

# create an IAM policy to allow the EC2 instances to access the dynamodb table and attach it to the EC2 role
resource "aws_iam_role_policy" "ec2_dynamodb_policy" {
  name = "EC2DynamoDBAccessPolicy-${var.environment}"
  role = aws_iam_role.ec2_role.id
  
  policy = templatefile("${path.module}/policies/dynamodb.json", {
    dynamodb_session_table_arn = var.dynamodb_session_table_arn
    dynamodb_user_table_arn = var.dynamodb_user_table_arn
  })
}
