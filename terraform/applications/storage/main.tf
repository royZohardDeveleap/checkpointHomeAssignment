# Storage module - S3 and SQS with resource policies
# Simple configuration with essential security best practices

# ============================================================================
# S3 BUCKET
# ============================================================================

resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-${var.environment}-bucket"

  tags = var.common_tags
}

# Note: Public access block is managed by organization-level SCPs
# Removed aws_s3_bucket_public_access_block resource due to SCP restrictions

# Enable encryption (security best practice)
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ============================================================================
# SQS QUEUE
# ============================================================================

resource "aws_sqs_queue" "main" {
  name = "${var.project_name}-${var.environment}-queue"

  tags = var.common_tags
}

# ============================================================================
# RESOURCE POLICIES
# ============================================================================

# S3 Bucket Policy - Restrict access to Service 2 task role via VPC endpoint
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowService2TaskRole"
        Effect = "Allow"
        Principal = {
          AWS = var.service2_task_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = var.s3_vpc_endpoint_id
          }
        }
      },
      {
        Sid    = "AllowAccountRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
      },
      {
        Sid       = "DenyAccessNotFromVPCEndpoint"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:SourceVpce" = var.s3_vpc_endpoint_id
          }
          Bool = {
            "aws:PrincipalIsAWSService" = "false"
          }
        }
      }
    ]
  })
}

# SQS Queue Policy - Allow Service 1 to send, Service 2 to receive
resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.url

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
        Resource = aws_sqs_queue.main.arn
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
        Resource = aws_sqs_queue.main.arn
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = var.sqs_vpc_endpoint_id
          }
        }
      },
      {
        Sid    = "AllowAccountRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action = "sqs:*"
        Resource = aws_sqs_queue.main.arn
      }
    ]
  })
}
