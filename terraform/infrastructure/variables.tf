variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devops-practice"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "ecs_instance_type" {
  description = "EC2 instance type for ECS cluster (free tier eligible)"
  type        = string
  default     = "t2.micro"
}

variable "ecs_desired_capacity" {
  description = "Desired number of EC2 instances in ECS cluster"
  type        = number
  default     = 1
}

variable "ecs_max_size" {
  description = "Maximum number of EC2 instances in ECS cluster"
  type        = number
  default     = 2
}

variable "ecs_min_size" {
  description = "Minimum number of EC2 instances in ECS cluster"
  type        = number
  default     = 1
}

# Feature Flags
variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable Grafana monitoring service"
  type        = bool
  default     = false
}

# Storage Configuration
variable "sqs_visibility_timeout" {
  description = "SQS visibility timeout in seconds"
  type        = number
  default     = 30
}

variable "sqs_message_retention" {
  description = "SQS message retention period in seconds"
  type        = number
  default     = 345600
}

# Grafana Configuration
variable "grafana_image_tag" {
  description = "Grafana Docker image tag"
  type        = string
  default     = "latest"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin123"  # Change this in production!
}
