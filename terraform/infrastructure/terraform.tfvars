# Infrastructure Workspace Variables
# Copy this file to terraform.tfvars and customize as needed

# =============================================================================
# PROJECT CONFIGURATION
# =============================================================================

project_name = "ha-roy-develeap"
environment  = "dev"
aws_region   = "us-east-1"

# =============================================================================
# NETWORKING
# =============================================================================

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# =============================================================================
# FEATURE FLAGS
# =============================================================================

# Enable VPC endpoints (recommended to save ~$65/month vs NAT Gateway)
enable_vpc_endpoints = true

# =============================================================================
# ECS CLUSTER CONFIGURATION
# =============================================================================

ecs_instance_type    = "t3.micro" 
ecs_desired_capacity = 3
ecs_min_size         = 2
ecs_max_size         = 4
