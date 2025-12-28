variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "service1_task_role_arn" {
  description = "Task role ARN for Service 1"
  type        = string
}

variable "service2_task_role_arn" {
  description = "Task role ARN for Service 2"
  type        = string
}

variable "s3_vpc_endpoint_id" {
  description = "S3 VPC endpoint ID"
  type        = string
}

variable "sqs_vpc_endpoint_id" {
  description = "SQS VPC endpoint ID"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
