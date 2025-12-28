output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.service2.arn
}

output "task_definition_family" {
  description = "Family of the task definition"
  value       = aws_ecs_task_definition.service2.family
}

output "task_definition_revision" {
  description = "Revision of the task definition"
  value       = aws_ecs_task_definition.service2.revision
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.service2.name
}

output "service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.service2.id
}

output "image_tag" {
  description = "Current image tag deployed"
  value       = data.aws_ssm_parameter.image_tag.value
}
