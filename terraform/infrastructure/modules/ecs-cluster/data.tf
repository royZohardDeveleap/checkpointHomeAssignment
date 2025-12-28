# Get latest ECS-optimized AMI from AWS SSM Parameter Store
# This is the recommended approach as AWS maintains these parameters
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

# Parse the JSON to extract the AMI ID
locals {
  ecs_ami_data = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)
}

# For backward compatibility with existing code that references data.aws_ami.ecs_optimized.id
# We create a data source that looks up the specific AMI
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "image-id"
    values = [local.ecs_ami_data.image_id]
  }
}
