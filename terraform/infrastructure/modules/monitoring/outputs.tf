output "service_name" {
  description = "Grafana ECS service name"
  value       = aws_ecs_service.grafana.name
}

output "service_id" {
  description = "Grafana ECS service ID"
  value       = aws_ecs_service.grafana.id
}

output "task_role_arn" {
  description = "Grafana task role ARN"
  value       = aws_iam_role.grafana_task.arn
}

output "log_group_name" {
  description = "CloudWatch log group name for Grafana"
  value       = aws_cloudwatch_log_group.grafana.name
}
