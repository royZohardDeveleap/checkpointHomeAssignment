locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Service     = "service1"
    ManagedBy   = "Terraform"
    Workspace   = "service1"
  }
}
