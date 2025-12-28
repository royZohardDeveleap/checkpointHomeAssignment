output "s3_bucket_policy_id" {
  description = "S3 bucket policy ID"
  value       = aws_s3_bucket_policy.main.id
}

output "sqs_queue_policy_id" {
  description = "SQS queue policy ID"
  value       = aws_sqs_queue_policy.main.id
}
