#1 tells rds what subnets to use for the database
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

#2 creates the RDS instance
resource "aws_db_instance" "db_instance" {
  identifier              = "${var.environment}-db-instance"
  allocated_storage       = var.allocated_storage
  engine                  = var.db_engine
  engine_version          = "8.0"
  instance_class          = var.instance_class
  db_name                 = "${var.environment}_db"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  skip_final_snapshot    = true
  multi_az                = false # Set to true for production environments so that the database is replicated across multiple availability zones for high availability
  vpc_security_group_ids      = [var.rds_sg_id]

  tags = {
    Name        = "${var.environment}-db-instance"
    Environment = var.environment
  }
}