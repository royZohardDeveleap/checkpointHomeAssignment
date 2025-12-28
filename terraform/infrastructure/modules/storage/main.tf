# Storage module - S3 and SQS base resources only
# Note: S3 bucket policy and encryption config are blocked by organization SCP
# Access control is handled via IAM role policies only

# ============================================================================
# S3 BUCKET
# ============================================================================

resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-${var.environment}-messages-bucket"

  tags = var.common_tags
}

# Enable encryption (security best practice)
# resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
#   bucket = aws_s3_bucket.main.id

#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# ============================================================================
# SQS QUEUE
# ============================================================================

resource "aws_sqs_queue" "main" {
  name = "${var.project_name}-${var.environment}-queue"

  tags = var.common_tags
}
