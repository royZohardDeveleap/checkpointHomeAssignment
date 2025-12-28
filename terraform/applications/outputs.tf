# Applications Workspace Outputs

# =============================================================================
# SERVICE OUTPUTS
# =============================================================================

output "service1_id" {
  description = "Service 1 ECS service ID"
  value       = module.service1.service_id
}

output "service1_name" {
  description = "Service 1 ECS service name"
  value       = module.service1.service_name
}

output "service1_task_definition_arn" {
  description = "Service 1 task definition ARN"
  value       = module.service1.task_definition_arn
}

output "service1_task_role_arn" {
  description = "Service 1 task role ARN"
  value       = module.service1.task_role_arn
}

output "service2_id" {
  description = "Service 2 ECS service ID"
  value       = module.service2.service_id
}

output "service2_name" {
  description = "Service 2 ECS service name"
  value       = module.service2.service_name
}

output "service2_task_definition_arn" {
  description = "Service 2 task definition ARN"
  value       = module.service2.task_definition_arn
}

output "service2_task_role_arn" {
  description = "Service 2 task role ARN"
  value       = module.service2.task_role_arn
}

# =============================================================================
# STORAGE OUTPUTS
# =============================================================================

output "s3_bucket_id" {
  description = "S3 bucket ID"
  value       = module.storage.s3_bucket_id
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.storage.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.storage.s3_bucket_arn
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = module.storage.sqs_queue_url
}

output "sqs_queue_arn" {
  description = "SQS queue ARN"
  value       = module.storage.sqs_queue_arn
}

# =============================================================================
# DEPLOYMENT INFO
# =============================================================================

output "deployment_info" {
  description = "Application deployment information"
  value = {
    service1_image = "${local.ecr_service1_repository_url}:${local.service1_image_tag}"
    service2_image = "${local.ecr_service2_repository_url}:${local.service2_image_tag}"
    cluster_name   = local.ecs_cluster_name
  }
}
