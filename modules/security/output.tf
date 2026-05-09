# output for the security group ID of the ALB
output "alb_sg_id" {
    description = "The ID of the security group for the ALB"
    value = aws_security_group.alb_sg.id
}

# output for the security group ID of the EC2 instances
output "ec2_sg_id" {
    description = "The ID of the security group for the EC2 instances"
    value = aws_security_group.ec2_sg.id
}

# output for the security group ID of the RDS instance
output "rds_sg_id" {
    description = "The ID of the security group for the RDS instance"
    value = aws_security_group.rds_sg.id
}