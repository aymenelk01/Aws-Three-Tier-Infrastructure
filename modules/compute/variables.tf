# variable of the the environment name
variable "environment" {
    description = "The environment name (e.g., dev, staging, prod)"
    type = string
}

# variable of the vpc id
variable "vpc_id" {
    description = "The ID of the VPC"
    type = string
}

# variable of the security group for the ALB
variable "alb_sg_id" {
    description = "The ID of the security group for the ALB"
    type = string
}

# variable of the public subnet ids
variable "public_subnet_ids" {
    description = "List of public subnet IDs"
    type = list(string)
}   

# variable of the private app subnet ids
variable "private_app_subnet_ids" {
    description = "List of private application subnet IDs"
    type = list(string)
}

# variable of the instance type for the EC2 instances
variable "instance_type" {
    description = "The instance type for the EC2 instances"
    type = string
    default = "t3.micro"
}

# variable of the ec2 security group id
variable "ec2_sg_id" {
    description = "The ID of the security group for the EC2 instances"
    type = string
}