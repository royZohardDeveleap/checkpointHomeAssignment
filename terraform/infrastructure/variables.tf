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

