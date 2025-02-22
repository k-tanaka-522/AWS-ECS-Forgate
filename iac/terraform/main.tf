terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # これらの値は環境ごとに異なるため、terraform initコマンド実行時に-backendで指定
    # bucket         = "tfstate-bucket-name"
    # key            = "environment/terraform.tfstate"
    # region         = "ap-northeast-1"
    # dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "escforgate"
      ManagedBy   = "terraform"
    }
  }
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "Environment (dev/stg/prd)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "Environment must be one of: dev, stg, prd"
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "escforgate"
}

# Modules
module "network" {
  source = "./modules/network"

  environment = var.environment
  app_name    = var.app_name
  vpc_cidr    = var.vpc_cidr
}

module "database" {
  source = "./modules/database"

  environment = var.environment
  app_name    = var.app_name

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  db_subnet_group_name = module.network.db_subnet_group_name
  db_security_group_id = module.network.rds_security_group_id

  depends_on = [module.network]
}

module "auth" {
  source = "./modules/auth"

  environment = var.environment
  app_name    = var.app_name
}

module "compute" {
  source = "./modules/compute"

  environment = var.environment
  app_name    = var.app_name

  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  ecs_security_group_id = module.network.ecs_security_group_id

  container_image = var.container_image
  container_port  = var.container_port
  desired_count   = var.desired_count

  db_secret_arn        = module.database.db_secret_arn
  cognito_user_pool_id = module.auth.user_pool_id
  cognito_client_id    = module.auth.user_pool_client_id

  depends_on = [module.network, module.database, module.auth]
}

# Additional Variables for Compute Module
variable "container_image" {
  description = "Docker image for the application container"
  type        = string
}

variable "container_port" {
  description = "Port number the application listens on"
  type        = number
  default     = 3000
}

variable "desired_count" {
  description = "Desired number of containers to run"
  type        = number
  default     = 2
}

# Outputs
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.compute.alb_dns_name
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.auth.user_pool_id
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.auth.user_pool_client_id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.database.rds_endpoint
}
