# Service 1 Workspace
# Manages only Service 1 ECS task definition and service
# Reads infrastructure outputs via remote state

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
    key            = "service1/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-roy-develeap"
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================================
# REMOTE STATE - Infrastructure
# ============================================================================

data "terraform_remote_state" "infrastructure" {
  backend = "s3"

  config = {
    bucket = "ha-roy-develeap-dev-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"
  }
}

# ============================================================================
# SSM PARAMETER - IMAGE TAG
# ============================================================================

data "aws_ssm_parameter" "image_tag" {
  name = "/${var.project_name}/${var.environment}/service1/image-tag"
}

# ============================================================================
# ECS TASK DEFINITION
# ============================================================================

resource "aws_ecs_task_definition" "service1" {
  family                   = "${var.project_name}-${var.environment}-service1"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = data.terraform_remote_state.infrastructure.outputs.ecs_task_execution_role_arn
  task_role_arn            = data.terraform_remote_state.infrastructure.outputs.service1_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "service1"
      image     = "${data.terraform_remote_state.infrastructure.outputs.ecr_service1_repository_url}:${data.aws_ssm_parameter.image_tag.value}"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SERVICE_NAME"
          value = "service1"
        },
        {
          name  = "SQS_QUEUE_URL"
          value = data.terraform_remote_state.infrastructure.outputs.sqs_queue_url
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-${var.environment}/service1"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "service1"
          "awslogs-create-group"  = "true"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}

# ============================================================================
# ECS SERVICE
# ============================================================================

resource "aws_ecs_service" "service1" {
  name            = "${var.project_name}-${var.environment}-service1"
  cluster         = data.terraform_remote_state.infrastructure.outputs.ecs_cluster_id
  task_definition = aws_ecs_task_definition.service1.arn
  desired_count   = var.desired_count

  load_balancer {
    target_group_arn = data.terraform_remote_state.infrastructure.outputs.service1_target_group_arn
    container_name   = "service1"
    container_port   = 8080
  }

  capacity_provider_strategy {
    capacity_provider = data.terraform_remote_state.infrastructure.outputs.ecs_capacity_provider_name
    weight            = 100
    base              = 1
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  tags = local.common_tags
}
