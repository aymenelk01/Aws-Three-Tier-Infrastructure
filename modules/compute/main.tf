## creates an Application Load Balancer (ALB) and a target group for the ALB. It also creates a listener for the ALB that forwards traffic to the target group.

# create an alb in the public subnets
resource "aws_lb" "alb" {
  name               = "ALB-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "ALB-${var.environment}"
  }

}

# create a target group for the ALB
resource "aws_lb_target_group" "target" {
  name        = "TargetGroup-${var.environment}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"

  }
}

# create a listener for the ALB
resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target.arn
  }

}

## create a ec2 launch template for the EC2 instances that will be registered with the target group. The launch template specifies the AMI, instance type, security group, and user data for the EC2 instances.
# Get the recent ami ID for Amazon Linux 2023 in the eu-south-1 region
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# create a launch template for the EC2 instances
resource "aws_launch_template" "ec2_launch_template" {
  name                   = "EC2LaunchTemplate-${var.environment}"
  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.ec2_sg_id]
  user_data              = base64encode(file("${path.module}/user_data.sh"))

  tags = {
    Name = "EC2LaunchTemplate-${var.environment}"
  }

  iam_instance_profile { name = aws_iam_instance_profile.ec2_ssm_profile.name }

}

## create an auto scaling group for the EC2 instances that will be registered with the target group. The auto scaling group specifies the launch template, desired capacity, and target group for the EC2 instances.
resource "aws_autoscaling_group" "ec2_asg" {
  name             = "EC2ASG-${var.environment}"
  max_size         = 4
  min_size         = 1
  desired_capacity = 2
  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }
  vpc_zone_identifier = var.private_app_subnet_ids # specify the private subnets for the EC2 instances
  target_group_arns   = [aws_lb_target_group.target.arn]

  tag {
    key                 = "Name"
    value               = "EC2ASG-${var.environment}"
    propagate_at_launch = true
  }
}
