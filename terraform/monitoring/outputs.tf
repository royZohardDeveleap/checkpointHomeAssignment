output "grafana_service_name" {
  description = "Name of the Grafana ECS service"
  value       = aws_ecs_service.grafana.name
}

output "grafana_task_definition_arn" {
  description = "ARN of the Grafana task definition"
  value       = aws_ecs_task_definition.grafana.arn
}

output "grafana_task_role_arn" {
  description = "ARN of the Grafana task IAM role"
  value       = aws_iam_role.grafana_task.arn
}
