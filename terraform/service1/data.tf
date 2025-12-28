# ============================================================================
# DATA SOURCES - Infrastructure Resources
# ============================================================================

# ECS Cluster
data "aws_ecs_cluster" "main" {
  cluster_name = "${var.project_name}-${var.environment}-cluster"
}

# IAM Roles
data "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"
}

data "aws_iam_role" "service1_task_role" {
  name = "${var.project_name}-${var.environment}-service1-task-role"
}

# ECR Repository
data "aws_ecr_repository" "service1" {
  name = "${var.project_name}/${var.environment}/service1"
}

# SQS Queue
data "aws_sqs_queue" "main" {
  name = "${var.project_name}-${var.environment}-queue"
}

# Target Group
data "aws_lb_target_group" "service1" {
  name = "${var.project_name}-${var.environment}-svc1-tg"
}

# SSM Parameter - Image Tag
data "aws_ssm_parameter" "image_tag" {
  name = "/${var.project_name}/${var.environment}/service1/image-tag"
}
