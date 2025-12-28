output "sqs_queue_policy_id" {
  description = "SQS queue policy ID"
  value       = aws_sqs_queue_policy.main.id
}
