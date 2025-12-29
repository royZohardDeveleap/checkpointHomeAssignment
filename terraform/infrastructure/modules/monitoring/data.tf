# Data sources for Grafana monitoring module

# ============================================================================
# SSM PARAMETERS - Fetch Grafana configuration
# ============================================================================

data "aws_ssm_parameter" "grafana_admin_password" {
  name            = "/${var.project_name}/${var.environment}/grafana/admin-password"
  with_decryption = true
}

data "aws_ssm_parameter" "grafana_image_tag" {
  name = "/${var.project_name}/${var.environment}/grafana/image-tag"
}
