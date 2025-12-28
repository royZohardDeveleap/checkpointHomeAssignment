# ============================================================================
# AWS DATA SOURCES
# ============================================================================

# Current AWS region and account
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# VPC - lookup by tags
data "aws_vpc" "main" {
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Subnets - lookup by VPC and tags
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Type = "private"
  }
}

# VPC Endpoints
data "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
}

data "aws_vpc_endpoint" "sqs" {
  vpc_id       = data.aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.sqs"
}

# ECS Cluster - lookup by name
data "aws_ecs_cluster" "main" {
  cluster_name = "${var.project_name}-${var.environment}-cluster"
}

# Capacity Provider - lookup by ARN pattern
data "aws_ecs_capacity_provider" "main" {
  name = "${var.project_name}-${var.environment}-cp"
}

# IAM Role - ECS task execution role
data "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"
}

# ECR Repositories - lookup by name
data "aws_ecr_repository" "service1" {
  name = "${var.project_name}/${var.environment}/service1"
}

data "aws_ecr_repository" "service2" {
  name = "${var.project_name}/${var.environment}/service2"
}

# ALB Target Group - lookup by tags
data "aws_lb_target_group" "service1" {
  tags = {
    Name        = "${var.project_name}-${var.environment}-service1-tg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# SSM PARAMETER STORE - IMAGE TAGS
# Read Docker image tags from SSM Parameter Store
# These are set by the CI/CD pipeline after building images

data "aws_ssm_parameter" "service1_image_tag" {
  name = "/${var.project_name}/${var.environment}/service1/image-tag"
}

data "aws_ssm_parameter" "service2_image_tag" {
  name = "/${var.project_name}/${var.environment}/service2/image-tag"
}

