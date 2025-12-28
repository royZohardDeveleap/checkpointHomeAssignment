output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "capacity_provider_name" {
  description = "ECS capacity provider name"
  value       = aws_ecs_capacity_provider.main.name
}

output "task_execution_role_arn" {
  description = "Task execution role ARN"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "task_execution_role_name" {
  description = "Task execution role name"
  value       = aws_iam_role.ecs_task_execution_role.name
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS instances"
  value       = aws_security_group.ecs_instances.id
}

output "ecs_ami_id" {
  description = "ECS-optimized AMI ID being used"
  value       = data.aws_ami.ecs_optimized.id
}

output "ecs_ami_name" {
  description = "ECS-optimized AMI name"
  value       = data.aws_ami.ecs_optimized.name
}

output "ecs_ami_details" {
  description = "Detailed information about the ECS-optimized AMI"
  value = {
    ami_id             = local.ecs_ami_data.image_id
    ami_name           = local.ecs_ami_data.image_name
    ami_version        = local.ecs_ami_data.image_version
    ecs_agent_version  = local.ecs_ami_data.ecs_agent_version
    docker_version     = local.ecs_ami_data.ecs_runtime_version
    os                 = local.ecs_ami_data.os
  }
}
