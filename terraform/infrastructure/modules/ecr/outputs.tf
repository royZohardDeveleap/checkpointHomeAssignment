# ECR Outputs
output "ecr_service1_repository_url" {
  description = "ECR repository URL for Service 1"
  value       = aws_ecr_repository.service1.repository_url
}

output "ecr_service2_repository_url" {
  description = "ECR repository URL for Service 2"
  value       = aws_ecr_repository.service2.repository_url
}

output "ecr_grafana_repository_url" {
  description = "ECR repository URL for Grafana"
  value       = var.enable_grafana ? aws_ecr_repository.grafana[0].repository_url : null
}
