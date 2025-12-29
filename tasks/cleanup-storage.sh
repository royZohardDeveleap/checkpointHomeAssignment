#!/bin/bash

# Cleanup Storage Script
# Empties ECR repositories and S3 bucket created by Terraform infrastructure
# This allows Terraform to destroy these resources cleanly

set -e

# Configuration
PROJECT="${PROJECT:-ha-roy-develeap}"
ENV="${ENV:-dev}"
REGION="${REGION:-us-east-1}"
AWS_PROFILE="${AWS_PROFILE:-checkpoint}"

# Derived names
ECR_REPO_SERVICE1="${PROJECT}/${ENV}/service1"
ECR_REPO_SERVICE2="${PROJECT}/${ENV}/service2"
ECR_REPO_GRAFANA="${PROJECT}/${ENV}/grafana"
S3_BUCKET="${PROJECT}-${ENV}-messages-bucket"

# SSM Parameter paths
SSM_SERVICE1_AUTH="/${PROJECT}/${ENV}/service1/auth-token"
SSM_SERVICE1_TAG="/${PROJECT}/${ENV}/service1/image-tag"
SSM_SERVICE2_TAG="/${PROJECT}/${ENV}/service2/image-tag"
SSM_GRAFANA_PASSWORD="/${PROJECT}/${ENV}/grafana/admin-password"
SSM_GRAFANA_TAG="/${PROJECT}/${ENV}/grafana/image-tag"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Storage Cleanup Script ===${NC}"
echo "Project: ${PROJECT}"
echo "Environment: ${ENV}"
echo "Region: ${REGION}"
echo "AWS Profile: ${AWS_PROFILE}"
echo ""

# Function to delete all ECR images
cleanup_ecr_repo() {
    local repo_name=$1
    echo -e "${YELLOW}Cleaning up ECR repository: ${repo_name}${NC}"

    # Check if repository exists
    if ! aws ecr describe-repositories \
        --repository-names "${repo_name}" \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        >/dev/null 2>&1; then
        echo -e "${YELLOW}Repository ${repo_name} does not exist, skipping${NC}"
        return 0
    fi

    # Get all image IDs
    local image_ids=$(aws ecr list-images \
        --repository-name "${repo_name}" \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'imageIds[*]' \
        --output json)

    if [ "${image_ids}" == "[]" ] || [ -z "${image_ids}" ]; then
        echo -e "${GREEN}No images found in ${repo_name}${NC}"
        return 0
    fi

    # Delete all images
    echo "Deleting images from ${repo_name}..."
    aws ecr batch-delete-image \
        --repository-name "${repo_name}" \
        --image-ids "${image_ids}" \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'imageIds[*].imageDigest' \
        --output text

    local image_count=$(echo "${image_ids}" | jq 'length')
    echo -e "${GREEN}Deleted ${image_count} images from ${repo_name}${NC}"
}

# Function to empty S3 bucket
cleanup_s3_bucket() {
    local bucket_name=$1
    echo -e "${YELLOW}Cleaning up S3 bucket: ${bucket_name}${NC}"

    # Check if bucket exists
    if ! aws s3 ls "s3://${bucket_name}" \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        >/dev/null 2>&1; then
        echo -e "${YELLOW}Bucket ${bucket_name} does not exist, skipping${NC}"
        return 0
    fi

    # Count objects
    local object_count=$(aws s3 ls "s3://${bucket_name}" \
        --recursive \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        | wc -l)

    if [ "${object_count}" -eq 0 ]; then
        echo -e "${GREEN}Bucket ${bucket_name} is already empty${NC}"
        return 0
    fi

    echo "Found ${object_count} objects in bucket"
    echo "Deleting all objects and versions..."

    # Delete all objects and versions
    aws s3api list-object-versions \
        --bucket "${bucket_name}" \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        --output json \
        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
        | jq -r '.Objects[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' \
        | xargs -I {} -P 10 aws s3api delete-object \
            --bucket "${bucket_name}" \
            --region "${REGION}" \
            --profile "${AWS_PROFILE}" {} \
        2>/dev/null || true

    # Delete all delete markers
    aws s3api list-object-versions \
        --bucket "${bucket_name}" \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        --output json \
        --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
        | jq -r '.Objects[]? | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' \
        | xargs -I {} -P 10 aws s3api delete-object \
            --bucket "${bucket_name}" \
            --region "${REGION}" \
            --profile "${AWS_PROFILE}" {} \
        2>/dev/null || true

    # Alternative: Force delete all (simpler but less parallel)
    # aws s3 rm "s3://${bucket_name}" --recursive --region "${REGION}" --profile "${AWS_PROFILE}"

    echo -e "${GREEN}Deleted all objects from ${bucket_name}${NC}"
}

# Function to delete SSM parameter
cleanup_ssm_parameter() {
    local param_name=$1
    echo -e "${YELLOW}Deleting SSM parameter: ${param_name}${NC}"

    # Check if parameter exists and delete it
    if aws ssm get-parameter \
        --name "${param_name}" \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        >/dev/null 2>&1; then

        aws ssm delete-parameter \
            --name "${param_name}" \
            --region "${REGION}" \
            --profile "${AWS_PROFILE}"

        echo -e "${GREEN}Deleted parameter ${param_name}${NC}"
    else
        echo -e "${YELLOW}Parameter ${param_name} does not exist, skipping${NC}"
    fi
}

# Main execution
echo -e "${YELLOW}Starting cleanup...${NC}"
echo ""

# Cleanup ECR repositories
echo -e "${GREEN}=== Cleaning ECR Repositories ===${NC}"
cleanup_ecr_repo "${ECR_REPO_SERVICE1}"
cleanup_ecr_repo "${ECR_REPO_SERVICE2}"
cleanup_ecr_repo "${ECR_REPO_GRAFANA}"
echo ""

# Cleanup S3 bucket
echo -e "${GREEN}=== Cleaning S3 Bucket ===${NC}"
cleanup_s3_bucket "${S3_BUCKET}"
echo ""

# Cleanup SSM Parameters
echo -e "${GREEN}=== Cleaning SSM Parameters ===${NC}"
cleanup_ssm_parameter "${SSM_SERVICE1_AUTH}"
cleanup_ssm_parameter "${SSM_SERVICE1_TAG}"
cleanup_ssm_parameter "${SSM_SERVICE2_TAG}"
cleanup_ssm_parameter "${SSM_GRAFANA_PASSWORD}"
cleanup_ssm_parameter "${SSM_GRAFANA_TAG}"
echo ""

echo -e "${GREEN}=== Cleanup Complete ===${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "✓ ECR repository ${ECR_REPO_SERVICE1} emptied"
echo "✓ ECR repository ${ECR_REPO_SERVICE2} emptied"
echo "✓ ECR repository ${ECR_REPO_GRAFANA} emptied"
echo "✓ S3 bucket ${S3_BUCKET} emptied"
echo "✓ SSM parameters deleted:"
echo "  - ${SSM_SERVICE1_AUTH}"
echo "  - ${SSM_SERVICE1_TAG}"
echo "  - ${SSM_SERVICE2_TAG}"
echo "  - ${SSM_GRAFANA_PASSWORD}"
echo "  - ${SSM_GRAFANA_TAG}"
echo ""
echo -e "${GREEN}You can now safely run 'terraform destroy'${NC}"
