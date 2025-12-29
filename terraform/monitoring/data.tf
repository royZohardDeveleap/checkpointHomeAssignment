# ============================================================================
# DATA SOURCES - Infrastructure Resources
# ============================================================================

# ECS Cluster
data "aws_ecs_cluster" "main" {
  cluster_name = "${var.project_name}-${var.environment}-cluster"
}

# IAM Role - Task Execution Role
data "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"
}

# ECR Repository
data "aws_ecr_repository" "grafana" {
  name = "${var.project_name}/${var.environment}/grafana"
}

# Target Group
data "aws_lb_target_group" "grafana" {
  name = "${var.project_name}-${var.environment}-grafana-tg"
}

# SSM Parameter - Image Tag
data "aws_ssm_parameter" "image_tag" {
  name = "/${var.project_name}/${var.environment}/grafana/image-tag"
}

# SSM Parameter - Admin Password
data "aws_ssm_parameter" "admin_password" {
  name            = "/${var.project_name}/${var.environment}/grafana/admin-password"
  with_decryption = true
}
