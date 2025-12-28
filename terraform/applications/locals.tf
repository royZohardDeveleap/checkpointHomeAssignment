# Local values from AWS data sources
locals {
  # AWS account and region
  aws_region                   = data.aws_region.current.name
  aws_account_id               = data.aws_caller_identity.current.account_id
  project_name                 = var.project_name
  environment                  = var.environment

  # Networking
  vpc_id                       = data.aws_vpc.main.id
  private_subnet_ids           = data.aws_subnets.private.ids
  s3_vpc_endpoint_id           = data.aws_vpc_endpoint.s3.id
  sqs_vpc_endpoint_id          = data.aws_vpc_endpoint.sqs.id

  # ECS Cluster
  ecs_cluster_id               = data.aws_ecs_cluster.main.id
  ecs_cluster_name             = data.aws_ecs_cluster.main.cluster_name
  ecs_capacity_provider_name   = data.aws_ecs_capacity_provider.main.name
  ecs_task_execution_role_arn  = data.aws_iam_role.ecs_task_execution.arn

  # ECR Repositories
  ecr_service1_repository_url  = data.aws_ecr_repository.service1.repository_url
  ecr_service2_repository_url  = data.aws_ecr_repository.service2.repository_url

  # Storage (from storage module)
  sqs_queue_url                = module.storage.sqs_queue_url
  sqs_queue_arn                = module.storage.sqs_queue_arn
  s3_bucket_name               = module.storage.s3_bucket_name
  s3_bucket_arn                = module.storage.s3_bucket_arn

  # ALB
  service1_target_group_arn    = data.aws_lb_target_group.service1.arn

  #Service Image tags
  service1_image_tag = data.aws_ssm_parameter.service1_image_tag.value
  service2_image_tag = data.aws_ssm_parameter.service2_image_tag.value

  # Common tags
  common_tags = {
    Environment = local.environment
    Project     = local.project_name
    ManagedBy   = "terraform"
    Workspace   = "applications"
    CreatedDate = timestamp()
  }
}
