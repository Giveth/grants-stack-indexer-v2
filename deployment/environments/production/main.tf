terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.84.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = "us-east-2"
}


data "aws_caller_identity" "current" {}


module "networking" {
  source          = "../../modules/networking"
  app_environment = var.APP_ENVIRONMENT
  app_name        = var.APP_NAME
  region          = var.AWS_REGION
}

module "iam" {
  source          = "../../modules/iam"
  app_name        = var.APP_NAME
  app_environment = var.APP_ENVIRONMENT
  region          = var.AWS_REGION
  account_id      = data.aws_caller_identity.current.account_id
}

module "storage" {
  source                = "../../modules/storage"
  app_name              = var.APP_NAME
  app_environment       = var.APP_ENVIRONMENT
  region                = var.AWS_REGION
  rds_username          = var.DATALAYER_PG_USER
  rds_password          = var.DATALAYER_PG_PASSWORD
  rds_security_group_id = module.networking.rds_security_group_id
  rds_subnet_ids        = module.networking.private_subnets
  rds_subnet_group_name = module.networking.rds_subnet_group_name
  rds_instance_class    = "db.t4g.micro"
}

# Bastion host removed - will be created dynamically for restore operations

module "simple_load_balancer" {
  source                = "../../modules/simple-load-balancer"
  app_name              = var.APP_NAME
  app_environment       = var.APP_ENVIRONMENT
  vpc_id                = module.networking.vpc_id
  public_subnets        = module.networking.public_subnets
  alb_security_group_id = module.networking.alb_security_group_id
  ssl_certificate_arn   = ""  # SSL certificate not used in simplified deployment
}

module "simple_compute" {
  source                        = "../../modules/simple-compute"
  app_name                      = var.APP_NAME
  app_environment               = var.APP_ENVIRONMENT
  region                        = var.AWS_REGION
  ecr_repository_url            = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.AWS_REGION}.amazonaws.com/${var.APP_NAME}-processing"
  image_tag                     = var.BLUE_API_IMAGE_TAG
  database_url                  = "postgresql://${var.DATALAYER_PG_USER}:${var.DATALAYER_PG_PASSWORD}@${module.storage.rds_endpoint}/${var.BLUE_DATALAYER_PG_DB_NAME}"
  redis_url                     = ""  # Redis not used in simplified deployment
  public_subnets                = module.networking.public_subnets
  api_security_group_id         = module.networking.api_security_group_id
  processing_security_group_id  = module.networking.processing_security_group_id
  api_target_group_arn          = module.simple_load_balancer.api_target_group_arn
  ecs_task_execution_role_arn   = module.iam.api_service_role_arn
  ecs_task_role_arn             = module.iam.processing_service_role_arn
  CHAINS                        = var.BLUE_CHAINS
  coingecko_api_key             = var.BLUE_COINGECKO_API_KEY
  pricing_source                = "coingecko"
  metadata_source               = "public-gateway"
  public_gateway_urls           = ["https://ipfs.io", "https://dweb.link", "https://cloudflare-ipfs.com", "https://gateway.pinata.cloud", "https://ipfs.infura.io", "https://ipfs.fleek.co", "https://ipfs.eth.aragon.network", "https://ipfs.jes.xxx", "https://ipfs.lol", "https://ipfs.mle.party"]
  coingecko_api_type            = "pro"
  log_level                     = "info"
  indexer_graphql_url           = "http://localhost:8080/v1/graphql"
  private_subnets               = module.networking.private_subnets
  target_group_arn              = module.simple_load_balancer.api_target_group_arn
  alb_listener_arn              = module.simple_load_balancer.listener_arn
}

module "api_gateway" {
  source          = "../../modules/api-gw"
  app_name        = var.APP_NAME
  app_environment = var.APP_ENVIRONMENT
  lb_dns_name     = module.simple_load_balancer.load_balancer_dns_name
}
