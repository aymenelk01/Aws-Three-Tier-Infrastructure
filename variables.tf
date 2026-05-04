# variable for the environment name
variable "environment" {
    description = "The environment name (e.g., dev, staging, prod)"
    type = string
}

# variable for the AWS region
variable "aws_region" {
    description = "The AWS region"
    type = string
}

# variable for the database username
variable "db_username" {
    description = "The database username"
    type = string
}
# variable for the database password
variable "db_password" {
    description = "The database password"
    type = string
    sensitive = true
}