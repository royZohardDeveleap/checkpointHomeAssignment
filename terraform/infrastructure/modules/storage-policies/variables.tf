variable "sqs_queue_url" {
  description = "SQS queue URL"
  type        = string
}

variable "sqs_queue_arn" {
  description = "SQS queue ARN"
  type        = string
}

variable "service1_task_role_arn" {
  description = "ARN of Service 1 task role"
  type        = string
}

variable "service2_task_role_arn" {
  description = "ARN of Service 2 task role"
  type        = string
}

variable "sqs_vpc_endpoint_id" {
  description = "SQS VPC endpoint ID"
  type        = string
}
