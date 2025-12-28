# Project Configuration
variable "project_name" {
  description = "Project name (used for SSM parameter path)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Service Configuration
variable "service1_cpu" {
  description = "CPU units for Service 1"
  type        = number
  default     = 256
}

variable "service1_memory" {
  description = "Memory (MB) for Service 1"
  type        = number
  default     = 512
}

variable "service2_cpu" {
  description = "CPU units for Service 2"
  type        = number
  default     = 256
}

variable "service2_memory" {
  description = "Memory (MB) for Service 2"
  type        = number
  default     = 512
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
  default     = 345600  # 4 days
}
