output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.main.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.main.arn
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.main.url
}

output "sqs_queue_arn" {
  description = "SQS queue ARN"
  value       = aws_sqs_queue.main.arn
}

output "sqs_queue_name" {
  description = "SQS queue name"
  value       = aws_sqs_queue.main.name
}
