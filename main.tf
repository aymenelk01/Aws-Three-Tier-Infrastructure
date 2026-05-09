# call the vpc module
module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
  aws_region  = var.aws_region
}

# call the security module and pass the vpc id from the vpc module
module "security" {
  source      = "./modules/security"
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}

# call the compute module and pass the necessary variables from the vpc and security modules
module "compute" {
  source                     = "./modules/compute"
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  alb_sg_id                  = module.security.alb_sg_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  private_app_subnet_ids     = module.vpc.private_app_subnet_ids
  ec2_sg_id                  = module.security.ec2_sg_id
  logs_bucket_name           = module.storage.logs_bucket_name
  dynamodb_session_table_arn = module.database.dynamodb_session_table_arn
  dynamodb_user_table_arn    = module.database.dynamodb_user_table_arn
  static_bucket_arn          = module.storage.static_bucket_arn
  logs_bucket_arn            = module.storage.logs_bucket_arn
  aws_region                 = var.aws_region
  static_bucket_name         = module.storage.static_bucket_name
}

# call the database module and pass the necessary variables from the vpc and security modules
module "database" {
  source                = "./modules/database"
  environment           = var.environment
  private_db_subnet_ids = module.vpc.private_db_subnet_ids
  db_username           = var.db_username
  db_password           = var.db_password
  rds_sg_id             = module.security.rds_sg_id
}

# call the storage module 
module "storage" {
  source             = "./modules/storage"
  environment        = var.environment
  static_bucket_name = var.static_bucket_name
  state_bucket_name  = var.state_bucket_name
  logs_bucket_name   = var.logs_bucket_name
  s3_endpoint_id     = module.vpc.s3_endpoint_id
}

# call the cloudfront module
module "cloudfront" {
  source                             = "./modules/cloudfront"
  environment                        = var.environment
  static_bucket_arn                  = module.storage.static_bucket_arn
  static_bucket_regional_domain_name = module.storage.static_bucket_regional_domain_name
  static_bucket_id                   = module.storage.static_bucket_id
  alb_dns_name                       = module.compute.alb_dns_name
  aws_region                         = var.aws_region
}
