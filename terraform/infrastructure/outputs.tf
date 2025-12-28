# Infrastructure Workspace Outputs
# These outputs are consumed by the applications workspace via remote state

# =============================================================================
# NETWORKING OUTPUTS
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = module.alb.alb_security_group_id
}

output "s3_vpc_endpoint_id" {
  description = "S3 VPC endpoint ID"
  value       = module.networking.s3_vpc_endpoint_id
}

output "sqs_vpc_endpoint_id" {
  description = "SQS VPC endpoint ID"
  value       = module.networking.sqs_vpc_endpoint_id
}

# =============================================================================
# ECS CLUSTER OUTPUTS
# =============================================================================

output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs_cluster.cluster_arn
}

output "ecs_capacity_provider_name" {
  description = "ECS capacity provider name"
  value       = module.ecs_cluster.capacity_provider_name
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = module.ecs_cluster.task_execution_role_arn
}

output "ecs_ami_id" {
  description = "ECS-optimized AMI ID being used"
  value       = module.ecs_cluster.ecs_ami_id
}

output "ecs_ami_name" {
  description = "ECS-optimized AMI name"
  value       = module.ecs_cluster.ecs_ami_name
}

# =============================================================================
# ECR OUTPUTS (from ECR module)
# =============================================================================

output "ecr_service1_repository_url" {
  description = "ECR repository URL for Service 1"
  value       = module.ecr.service1_repository_url
}

output "ecr_service2_repository_url" {
  description = "ECR repository URL for Service 2"
  value       = module.ecr.service2_repository_url
}

output "ecr_grafana_repository_url" {
  description = "ECR repository URL for Grafana"
  value       = var.enable_monitoring ? module.ecr.grafana_repository_url : null
}

# =============================================================================
# ALB OUTPUTS
# =============================================================================

output "alb_id" {
  description = "ALB ID"
  value       = module.alb.alb_id
}

output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "service1_target_group_arn" {
  description = "Service 1 target group ARN"
  value       = module.alb.service1_target_group_arn
}

output "grafana_target_group_arn" {
  description = "Grafana target group ARN"
  value       = module.alb.grafana_target_group_arn
}

# =============================================================================
# MONITORING (GRAFANA) OUTPUTS
# =============================================================================

output "grafana_service_name" {
  description = "Grafana ECS service name"
  value       = var.enable_monitoring ? module.monitoring[0].service_name : null
}

output "grafana_service_id" {
  description = "Grafana ECS service ID"
  value       = var.enable_monitoring ? module.monitoring[0].service_id : null
}

output "grafana_log_group_name" {
  description = "Grafana CloudWatch log group name"
  value       = var.enable_monitoring ? module.monitoring[0].log_group_name : null
}

# =============================================================================
# GENERAL OUTPUTS
# =============================================================================

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
