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

data "aws_iam_role" "service2_task_role" {
  name = "${var.project_name}-${var.environment}-service2-task-role"
}

# ECR Repository
data "aws_ecr_repository" "service2" {
  name = "${var.project_name}/${var.environment}/service2"
}

# SQS Queue
data "aws_sqs_queue" "main" {
  name = "${var.project_name}-${var.environment}-queue"
}

# S3 Bucket
data "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-${var.environment}-messages-bucket"
}

# SSM Parameter - Image Tag
data "aws_ssm_parameter" "image_tag" {
  name = "/${var.project_name}/${var.environment}/service2/image-tag"
}