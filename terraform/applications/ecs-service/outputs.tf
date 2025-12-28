output "service_id" {
  description = "ECS service ID"
  value       = aws_ecs_service.main.id
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "task_definition_arn" {
  description = "Task definition ARN"
  value       = aws_ecs_task_definition.main.arn
}

output "task_role_arn" {
  description = "Task role ARN"
  value       = aws_iam_role.task_role.arn
}

output "task_role_name" {
  description = "Task role name"
  value       = aws_iam_role.task_role.name
}
