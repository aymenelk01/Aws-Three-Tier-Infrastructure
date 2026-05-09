## Create security group for the application load balancer and allow inbound traffic on ports 80 and 443, and allow all outbound traffic
resource "aws_security_group" "alb_sg" {
    name = "ALB-SG-${var.environment}"
    description = "Security group for the Application Load Balancer"
    vpc_id = var.vpc_id
    # allow inbound traffic on port 80
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        prefix_list_ids = ["pl-1bbc5972"] # allow traffic from the AWS-managed prefix list for CloudFront
    }   
    # allow inbound traffic on port 443
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # allow all outbound traffic
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "ALB-SG-${var.environment}"
    }
}

## Create security group for the EC2 instances and allow inbound traffic on ports 80 and 443 from the ALB security group, and allow all outbound traffic
resource "aws_security_group" "ec2_sg" {
    name = "EC2-SG-${var.environment}"
    description = "Security group for the EC2 instances"
    vpc_id = var.vpc_id

    # allow traffic from the ALB security group on port 80
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = [aws_security_group.alb_sg.id] # allow traffic from the ALB security group
    }   
    # allow traffic from the ALB security group on port 443
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        security_groups = [aws_security_group.alb_sg.id] 
    }
    # allow all outbound traffic
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "EC2-SG-${var.environment}"
    }   
}   

## create security group for the RDS instance and allow inbound traffic on port 3306 from the EC2 security group, and allow all outbound traffic
resource "aws_security_group" "rds_sg" {
    name = "RDS-SG-${var.environment}"
    description = "Security group for the RDS instance"
    vpc_id = var.vpc_id

    # allow traffic from the EC2 security group on port 3306
    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = [aws_security_group.ec2_sg.id] # allow traffic from the EC2 security group
    }
    # allow all outbound traffic
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "RDS-SG-${var.environment}"
    }
}   