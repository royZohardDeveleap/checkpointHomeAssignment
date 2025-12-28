# IAM Roles for ECS Tasks
# Creates task roles with necessary permissions for each service

# ============================================================================
# SERVICE 1 TASK ROLE
# ============================================================================

resource "aws_iam_role" "service1_task_role" {
  name = "${var.project_name}-${var.environment}-service1-task-role"

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
      Name = "${var.project_name}-${var.environment}-service1-task-role"
    }
  )
}

# SQS Send permissions for Service 1
resource "aws_iam_role_policy" "service1_sqs" {
  name = "${var.project_name}-${var.environment}-service1-sqs-policy"
  role = aws_iam_role.service1_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# SSM Parameter Store read permissions for Service 1
resource "aws_iam_role_policy" "service1_ssm" {
  name = "${var.project_name}-${var.environment}-service1-ssm-policy"
  role = aws_iam_role.service1_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/${var.environment}/*"
      }
    ]
  })
}

# ============================================================================
# SERVICE 2 TASK ROLE
# ============================================================================

resource "aws_iam_role" "service2_task_role" {
  name = "${var.project_name}-${var.environment}-service2-task-role"

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
      Name = "${var.project_name}-${var.environment}-service2-task-role"
    }
  )
}

# SQS Receive permissions for Service 2
resource "aws_iam_role_policy" "service2_sqs" {
  name = "${var.project_name}-${var.environment}-service2-sqs-policy"
  role = aws_iam_role.service2_task_role.id

  policy = jsonencode({
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
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# S3 permissions for Service 2
resource "aws_iam_role_policy" "service2_s3" {
  name = "${var.project_name}-${var.environment}-service2-s3-policy"
  role = aws_iam_role.service2_task_role.id

  policy = jsonencode({
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
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}
