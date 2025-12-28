# Applications Workspace
# Creates ECS services and task definitions
# Applied by CD pipeline after image builds and pushes

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
    key            = "applications/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-roy-develeap"
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================================
# ECS SERVICES
# ============================================================================

# Service 1 - Web API
module "service1" {
  source = "./ecs-service"

  project_name            = local.project_name
  environment             = local.environment
  service_name            = "service1"
  cluster_id              = local.ecs_cluster_id
  cluster_name            = local.ecs_cluster_name
  capacity_provider_name  = local.ecs_capacity_provider_name
  task_execution_role_arn = local.ecs_task_execution_role_arn

  image_url      = local.ecr_service1_repository_url
  image_tag      = local.service1_image_tag
  container_port = 8080
  cpu            = var.service1_cpu
  memory         = var.service1_memory
  desired_count  = 1

  task_role_policies = {
    sqs = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "sqs:SendMessage",
            "sqs:GetQueueUrl",
            "sqs:GetQueueAttributes"
          ]
          Resource = local.sqs_queue_arn
        }
      ]
    })
    ssm = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ssm:GetParameter",
            "ssm:GetParameters"
          ]
          Resource = "arn:aws:ssm:${local.aws_region}:*:parameter/${local.project_name}/${local.environment}/*"
        }
      ]
    })
  }

  environment_variables = {
    SERVICE_NAME  = "service1"
    SQS_QUEUE_URL = local.sqs_queue_url
    AWS_REGION    = local.aws_region
  }

  expose               = true
  target_group_arn     = local.service1_target_group_arn
  health_check_command = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]

  aws_region = local.aws_region

  common_tags = local.common_tags
}

# Service 2 - Background Worker
module "service2" {
  source = "./ecs-service"

  project_name            = local.project_name
  environment             = local.environment
  service_name            = "service2"
  cluster_id              = local.ecs_cluster_id
  cluster_name            = local.ecs_cluster_name
  capacity_provider_name  = local.ecs_capacity_provider_name
  task_execution_role_arn = local.ecs_task_execution_role_arn

  image_url      = local.ecr_service2_repository_url
  image_tag      = local.service2_image_tag
  container_port = 8080
  cpu            = var.service2_cpu
  memory         = var.service2_memory
  desired_count  = 1

  task_role_policies = {
    sqs = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueUrl",
            "sqs:GetQueueAttributes"
          ]
          Resource = local.sqs_queue_arn
        }
      ]
    })
    s3 = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            local.s3_bucket_arn,
            "${local.s3_bucket_arn}/*"
          ]
        }
      ]
    })
  }

  environment_variables = {
    SERVICE_NAME   = "service2"
    SQS_QUEUE_URL  = local.sqs_queue_url
    S3_BUCKET_NAME = local.s3_bucket_name
    AWS_REGION     = local.aws_region
  }

  aws_region = local.aws_region

  common_tags = local.common_tags
}

# ============================================================================
# STORAGE (S3 & SQS)
# ============================================================================

module "storage" {
  source = "./storage"

  project_name            = local.project_name
  environment             = local.environment
  aws_account_id          = local.aws_account_id
  service1_task_role_arn  = module.service1.task_role_arn
  service2_task_role_arn  = module.service2.task_role_arn
  s3_vpc_endpoint_id      = local.s3_vpc_endpoint_id
  sqs_vpc_endpoint_id     = local.sqs_vpc_endpoint_id

  common_tags = local.common_tags
}

