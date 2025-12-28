# Grafana monitoring service - Simple configuration

# IAM Role for Grafana Task
resource "aws_iam_role" "grafana_task" {
  name = "${var.project_name}-${var.environment}-grafana-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

# CloudWatch read permissions for Grafana
resource "aws_iam_role_policy" "grafana_cloudwatch" {
  name = "grafana-cloudwatch-policy"
  role = aws_iam_role.grafana_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/${var.project_name}-${var.environment}-grafana"
  retention_in_days = 7

  tags = var.common_tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.project_name}-${var.environment}-grafana"
  network_mode             = "bridge"
  requires_compatibilities = []
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = aws_iam_role.grafana_task.arn

  container_definitions = jsonencode([{
    name      = "grafana"
    image     = "${var.grafana_repository_url}:${var.grafana_image_tag}"
    cpu       = 256
    memory    = 512
    essential = true

    portMappings = [{
      containerPort = 3000
      hostPort      = 0
      protocol      = "tcp"
    }]

    environment = [{
      name  = "GF_SECURITY_ADMIN_PASSWORD"
      value = var.admin_password
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "grafana"
      }
    }
  }])

  tags = var.common_tags
}

# ECS Service
resource "aws_ecs_service" "grafana" {
  name            = "${var.project_name}-${var.environment}-grafana"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 100
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "grafana"
    container_port   = 3000
  }

  tags = var.common_tags

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }
}
