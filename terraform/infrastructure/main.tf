# Infrastructure Workspace
# Creates base infrastructure: VPC, ALB, ECS Cluster, ECR, Grafana
# Applied once, rarely changes

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "ha-roy-develeap-dev-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-roy-develeap"
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================================
# NETWORKING
# ============================================================================

module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  # Calculate subnet CIDRs
  public_subnet_cidrs  = [for i in range(length(var.availability_zones)) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs = [for i in range(length(var.availability_zones)) : cidrsubnet(var.vpc_cidr, 8, i + 10)]

  enable_vpc_endpoints = var.enable_vpc_endpoints
  aws_region           = var.aws_region

  common_tags = local.common_tags
}

# ============================================================================
# APPLICATION LOAD BALANCER
# ============================================================================

module "alb" {
  source = "./modules/alb"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  enable_monitoring  = var.enable_monitoring

  common_tags = local.common_tags
}

# ============================================================================
# ECS CLUSTER
# ============================================================================

module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.networking.vpc_id
  private_subnet_ids     = module.networking.private_subnet_ids
  alb_security_group_id  = module.alb.alb_security_group_id

  instance_type    = var.ecs_instance_type
  desired_capacity = var.ecs_desired_capacity
  min_size         = var.ecs_min_size
  max_size         = var.ecs_max_size

  aws_region = var.aws_region

  common_tags = local.common_tags
}

# ============================================================================
# ECR REPOS
# ============================================================================

module "ecr" {
  source = "./modules/ecr"

  project_name   = var.project_name
  environment    = var.environment
  aws_account_id = data.aws_caller_identity.current.account_id

  enable_grafana = var.enable_monitoring

  common_tags = local.common_tags
}

# ============================================================================
# STORAGE (S3 & SQS) - Base Resources
# ============================================================================

module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  environment  = var.environment

  common_tags = local.common_tags
}

# ============================================================================
# IAM TASK ROLES
# ============================================================================

module "iam_roles" {
  source = "./modules/iam-roles"

  project_name  = var.project_name
  environment   = var.environment
  aws_region    = var.aws_region

  # Storage resource ARNs for role policies
  sqs_queue_arn = module.storage.sqs_queue_arn
  s3_bucket_arn = module.storage.s3_bucket_arn

  common_tags = local.common_tags
}

# ============================================================================
# STORAGE POLICIES
# ============================================================================

module "storage_policies" {
  source = "./modules/storage-policies"

  # Storage resources
  sqs_queue_url = module.storage.sqs_queue_url
  sqs_queue_arn = module.storage.sqs_queue_arn

  # Task role ARNs
  service1_task_role_arn = module.iam_roles.service1_task_role_arn
  service2_task_role_arn = module.iam_roles.service2_task_role_arn

  # VPC endpoints
  sqs_vpc_endpoint_id = module.networking.sqs_vpc_endpoint_id
}

# ============================================================================
# MONITORING (GRAFANA) - Optional
# ============================================================================

module "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  source = "./modules/monitoring"

  project_name            = var.project_name
  environment             = var.environment
  cluster_id              = module.ecs_cluster.cluster_id
  capacity_provider_name  = module.ecs_cluster.capacity_provider_name
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn

  grafana_repository_url = module.ecr.grafana_repository_url
  grafana_image_tag      = var.grafana_image_tag
  admin_password         = var.grafana_admin_password

  target_group_arn = module.alb.grafana_target_group_arn

  aws_region = var.aws_region

  common_tags = local.common_tags
}
