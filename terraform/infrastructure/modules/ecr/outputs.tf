# ECR Outputs
output "service1_repository_url" {
  description = "ECR repository URL for Service 1"
  value       = aws_ecr_repository.service1.repository_url
}

output "service2_repository_url" {
  description = "ECR repository URL for Service 2"
  value       = aws_ecr_repository.service2.repository_url
}

output "grafana_repository_url" {
  description = "ECR repository URL for Grafana"
  value       = aws_ecr_repository.grafana.repository_url
}
