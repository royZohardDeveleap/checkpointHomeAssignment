variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "sqs_queue_arn" {
  description = "SQS queue ARN for permissions"
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for permissions"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
