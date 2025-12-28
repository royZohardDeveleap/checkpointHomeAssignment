#!/bin/bash

set -e

echo "🔨 Building and pushing Grafana image to ECR..."

# Get AWS account ID and ECR repository URL from Terraform
cd ../terraform
AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id)
ECR_REPO=$(terraform output -raw ecr_grafana_repository_url)
AWS_REGION="us-east-1"
cd ../grafana

echo "📋 Configuration:"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  AWS Region: $AWS_REGION"
echo "  ECR Repository: $ECR_REPO"

# Authenticate Docker to ECR
echo "🔑 Authenticating to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build the image
echo "🐳 Building Docker image..."
docker build -t grafana-cloudwatch .

# Tag the image
echo "🏷️  Tagging image..."
docker tag grafana-cloudwatch:latest $ECR_REPO:latest

# Push to ECR
echo "⬆️  Pushing to ECR..."
docker push $ECR_REPO:latest

echo "✅ Successfully pushed Grafana image to ECR!"
echo ""
echo "Next steps:"
echo "  1. Deploy/update the ECS service:"
echo "     cd ../terraform && terraform apply"
echo ""
echo "  2. Access Grafana at:"
echo "     $(cd ../terraform && terraform output -raw grafana_url)"
echo ""
echo "  3. Login with:"
echo "     Username: admin"
echo "     Password: admin"
