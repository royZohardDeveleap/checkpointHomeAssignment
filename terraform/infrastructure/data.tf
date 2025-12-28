# Data source for AWS account ID
data "aws_caller_identity" "current" {}

# Data source for available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
