variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS instances"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for ECS instances"
  type        = string
  default     = "t2.micro"
}

variable "desired_capacity" {
  description = "Desired number of ECS instances"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of ECS instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of ECS instances"
  type        = number
  default     = 4
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
