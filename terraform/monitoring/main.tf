# Monitoring Workspace
# Manages only Grafana ECS task definition and service
# Reads infrastructure outputs via data sources

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
    key            = "monitoring/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-roy-develeap"
  }
}

provider "aws" {
  region = var.aws_region
}


# ============================================================================
# IAM ROLE FOR GRAFANA TASK
# ============================================================================

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

  tags = local.common_tags
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
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListDashboards",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents",
          "logs:GetLogGroupFields",
          "logs:GetLogRecord",
          "logs:GetQueryResults",
          "logs:StartQuery",
          "logs:StopQuery",
          "ec2:DescribeRegions",
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# CLOUDWATCH LOG GROUP
# ============================================================================

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/${var.project_name}-${var.environment}-grafana"
  retention_in_days = 7

  tags = local.common_tags
}

# ============================================================================
# ECS TASK DEFINITION
# ============================================================================

resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.project_name}-${var.environment}-grafana"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.grafana_task.arn

  container_definitions = jsonencode([{
    name      = "grafana"
    image     = "${data.aws_ecr_repository.grafana.repository_url}:${data.aws_ssm_parameter.image_tag.value}"
    essential = true

    portMappings = [{
      containerPort = 3000
      hostPort      = 0
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "GF_SECURITY_ADMIN_PASSWORD"
        value = data.aws_ssm_parameter.admin_password.value
      },
      {
        name  = "GF_SERVER_ROOT_URL"
        value = "http://%(domain)s/grafana"
      },
      {
        name  = "GF_SERVER_SERVE_FROM_SUB_PATH"
        value = "true"
      },
      {
        name  = "IMAGE_TAG"
        value = data.aws_ssm_parameter.image_tag.value
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "grafana"
        "awslogs-create-group"  = "true"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = local.common_tags
}

# ============================================================================
# ECS SERVICE
# ============================================================================

resource "aws_ecs_service" "grafana" {
  name            = "${var.project_name}-${var.environment}-grafana"
  cluster         = data.aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = var.desired_count

  load_balancer {
    target_group_arn = data.aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  capacity_provider_strategy {
    capacity_provider = "${var.project_name}-${var.environment}-capacity-provider"
    weight            = 100
    base              = 1
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  tags = local.common_tags
}
