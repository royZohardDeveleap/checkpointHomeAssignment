variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "service_name" {
  description = "Name of the service (e.g., service1, service2, grafana)"
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "capacity_provider_name" {
  description = "ECS capacity provider name"
  type        = string
}

variable "image_url" {
  description = "Docker image URL (ECR repository URL)"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
}

variable "cpu" {
  description = "Task CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "task_role_policies" {
  description = "Map of IAM policy names to policy JSON documents for the task role"
  type        = map(string)
  default     = {}
}

variable "task_execution_role_arn" {
  description = "ARN of the task execution role"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets for the container (from Secrets Manager or SSM)"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "expose" {
  description = "Whether to expose this service via ALB"
  type        = bool
  default     = false
}

variable "target_group_arn" {
  description = "ARN of the target group for ALB (required if expose is true)"
  type        = string
  default     = null
}

variable "health_check_command" {
  description = "Health check command for the container"
  type        = list(string)
  default     = null
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "aws_region" {
  description = "AWS region for CloudWatch logs"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
