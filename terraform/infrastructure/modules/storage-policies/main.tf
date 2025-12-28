# Storage Policies module - SQS resource policies
# Created separately to avoid circular dependencies with IAM roles

# ============================================================================
# SQS QUEUE POLICY
# ============================================================================

# SQS Queue Policy - Allow Service 1 to send, Service 2 to receive
resource "aws_sqs_queue_policy" "main" {
  queue_url = var.sqs_queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowService1SendMessage"
        Effect = "Allow"
        Principal = {
          AWS = var.service1_task_role_arn
        }
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arn
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = var.sqs_vpc_endpoint_id
          }
        }
      },
      {
        Sid    = "AllowService2ReceiveMessage"
        Effect = "Allow"
        Principal = {
          AWS = var.service2_task_role_arn
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arn
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = var.sqs_vpc_endpoint_id
          }
        }
      }
    ]
  })
}
