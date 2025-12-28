# Applications Workspace Variables
# Copy this file to terraform.tfvars and customize as needed

# =============================================================================
# PROJECT CONFIGURATION
# =============================================================================

project_name = "ha-roy-develeap"
environment  = "dev"

# =============================================================================
# SERVICE RESOURCE ALLOCATION
# =============================================================================

# Service 1 resources
service1_cpu    = 256   # CPU units (256 = 0.25 vCPU)
service1_memory = 512   # Memory in MB

# Service 2 resources
service2_cpu    = 256
service2_memory = 512
