output "service1_task_role_arn" {
  description = "ARN of Service 1 task role"
  value       = aws_iam_role.service1_task_role.arn
}

output "service1_task_role_name" {
  description = "Name of Service 1 task role"
  value       = aws_iam_role.service1_task_role.name
}

output "service2_task_role_arn" {
  description = "ARN of Service 2 task role"
  value       = aws_iam_role.service2_task_role.arn
}

output "service2_task_role_name" {
  description = "Name of Service 2 task role"
  value       = aws_iam_role.service2_task_role.name
}
