# Storage Policies module - S3 and SQS resource policies
# Created separately to avoid circular dependencies with IAM roles

# ============================================================================
# S3 BUCKET POLICY
# ============================================================================

# S3 Bucket Policy - AWS recommended VPC endpoint policy
# Allows account root access and restricts access to VPC endpoint only
# Reference: https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies-vpc-endpoint.html
resource "aws_s3_bucket_policy" "main" {
  bucket = var.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Access-to-specific-VPCE-only"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:SourceVpce" = var.s3_vpc_endpoint_id
          }
        }
      }
    ]
  })
}

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
