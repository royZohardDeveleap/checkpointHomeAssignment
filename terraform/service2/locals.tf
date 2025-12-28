locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Service     = "service2"
    ManagedBy   = "Terraform"
    Workspace   = "service2"
  }
}
