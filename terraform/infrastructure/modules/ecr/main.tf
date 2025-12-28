# ECR Repositories for container images

# ECR Repository for Service 1
resource "aws_ecr_repository" "service1" {
  name                 = "${var.project_name}-${var.environment}-service1"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-service1"
    }
  )
}

# # ECR Lifecycle Policy for Service 1
# resource "aws_ecr_lifecycle_policy" "service1" {
#   repository = aws_ecr_repository.service1.name

#   policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1
#         description  = "Keep last 5 images"
#         selection = {
#           tagStatus     = "any"
#           countType     = "imageCountMoreThan"
#           countNumber   = 5
#         }
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
# }

# ECR Repository for Service 2
resource "aws_ecr_repository" "service2" {
  name                 = "${var.project_name}-${var.environment}-service2"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-service2"
    }
  )
}

# # ECR Lifecycle Policy for Service 2
# resource "aws_ecr_lifecycle_policy" "service2" {
#   repository = aws_ecr_repository.service2.name

#   policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1
#         description  = "Keep last 5 images"
#         selection = {
#           tagStatus     = "any"
#           countType     = "imageCountMoreThan"
#           countNumber   = 5
#         }
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
# }

# ECR Repository for Grafana (conditional)
resource "aws_ecr_repository" "grafana" {
  count = var.enable_grafana ? 1 : 0

  name                 = "${var.project_name}-${var.environment}-grafana"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-grafana"
    }
  )
}

# # ECR Lifecycle Policy for Grafana
# resource "aws_ecr_lifecycle_policy" "grafana" {
#   count = var.enable_grafana ? 1 : 0

#   repository = aws_ecr_repository.grafana[0].name

#   policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1
#         description  = "Keep last 5 images"
#         selection = {
#           tagStatus     = "any"
#           countType     = "imageCountMoreThan"
#           countNumber   = 5
#         }
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
# }
