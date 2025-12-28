# IAM Role for ECS Task
resource "aws_iam_role" "task_role" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${var.service_name}-task-role"
    }
  )
}

# Attach custom policies to task role
resource "aws_iam_role_policy" "task_policy" {
  for_each = var.task_role_policies

  name   = "${var.project_name}-${var.environment}-${var.service_name}-${each.key}-policy"
  role   = aws_iam_role.task_role.id
  policy = each.value
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project_name}-${var.environment}-${var.service_name}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = "${var.image_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      environment = [
        for key, value in var.environment_variables : {
          name  = key
          value = value
        }
      ]

      secrets = var.secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-${var.environment}/${var.service_name}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.service_name
          "awslogs-create-group"  = "true"
        }
      }

      healthCheck = var.health_check_command != null ? {
        command     = var.health_check_command
        interval    = var.health_check_interval
        timeout     = 5
        retries     = 3
        startPeriod = 60
      } : null
    }
  ])

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${var.service_name}-task"
    }
  )
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-${var.environment}-${var.service_name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count

  dynamic "load_balancer" {
    for_each = var.expose ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 100
    base              = 1
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  depends_on = [var.task_execution_role_arn]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${var.service_name}-service"
    }
  )
}
