module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}
module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
}

data "aws_ssm_parameter" "db_password" {
  name = "/threetier/db_password"
}

module "rds" {
  source              = "./modules/rds"
  project_name        = var.project_name
  private_subnet_ids  = module.vpc.private_subnet_ids
  rds_sg_id           = module.security.rds_sg_id
  db_password         = data.aws_ssm_parameter.db_password.value
}
module "ec2" {
  source            = "./modules/ec2"
  project_name      = var.project_name
  public_subnet_ids = module.vpc.public_subnet_ids
  ec2_sg_id         = module.security.ec2_sg_id
}

/*
module "alb" {
 source            = "./modules/alb"
 project_name      = var.project_name
 vpc_id            = module.vpc.vpc_id
 public_subnet_ids = module.vpc.public_subnet_ids
 alb_sg_id         = module.security.alb_sg_id
 asg_name          = module.ec2.asg_name
}
*/