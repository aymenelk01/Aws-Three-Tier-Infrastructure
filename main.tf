# call the vpc module
module "vpc" {
    source = "./modules/vpc"
    environment = var.environment
}

# call the security module and pass the vpc id from the vpc module
module "security" {
    source = "./modules/security"
    environment = var.environment
    vpc_id = module.vpc.vpc_id
}

# call the compute module and pass the necessary variables from the vpc and security modules
module "compute" {
    source = "./modules/compute"
    environment = var.environment
    vpc_id = module.vpc.vpc_id
    alb_sg_id = module.security.alb_sg_id
    public_subnet_ids = module.vpc.public_subnet_ids
    private_app_subnet_ids = module.vpc.private_app_subnet_ids
    ec2_sg_id = module.security.ec2_sg_id
}

# call the database module and pass the necessary variables from the vpc and security modules
module "database" {
    source = "./modules/database"
    environment = var.environment
    private_db_subnet_ids = module.vpc.private_db_subnet_ids
    db_username = var.db_username
    db_password = var.db_password
    rds_sg_id = module.security.rds_sg_id
}