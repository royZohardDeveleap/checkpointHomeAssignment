#!/bin/bash

# Cleanup Parameters Script
# Deletes SSM parameters created by the application
# Run this before destroying infrastructure to clean up SSM parameters

set -e

# Configuration
PROJECT="${PROJECT:-ha-roy-develeap}"
ENV="${ENV:-dev}"
REGION="${REGION:-us-east-1}"
AWS_PROFILE="${AWS_PROFILE:-checkpoint}"

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

echo -e "${GREEN}=== SSM Parameters Cleanup Script ===${NC}"
echo "Project: ${PROJECT}"
echo "Environment: ${ENV}"
echo "Region: ${REGION}"
echo "AWS Profile: ${AWS_PROFILE}"
echo ""

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
echo -e "${YELLOW}Starting SSM parameters cleanup...${NC}"
echo ""

# Cleanup SSM Parameters
echo -e "${GREEN}=== Cleaning SSM Parameters ===${NC}"
cleanup_ssm_parameter "${SSM_SERVICE1_AUTH}"
cleanup_ssm_parameter "${SSM_SERVICE1_TAG}"
cleanup_ssm_parameter "${SSM_SERVICE2_TAG}"
cleanup_ssm_parameter "${SSM_GRAFANA_PASSWORD}"
cleanup_ssm_parameter "${SSM_GRAFANA_TAG}"
echo ""

echo -e "${GREEN}=== Parameters Cleanup Complete ===${NC}"
echo ""
echo -e "${YELLOW}Summary - SSM parameters deleted:${NC}"
echo "  - ${SSM_SERVICE1_AUTH}"
echo "  - ${SSM_SERVICE1_TAG}"
echo "  - ${SSM_SERVICE2_TAG}"
echo "  - ${SSM_GRAFANA_PASSWORD}"
echo "  - ${SSM_GRAFANA_TAG}"
echo ""
