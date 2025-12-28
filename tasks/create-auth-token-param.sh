#!/bin/bash

# Script to create auth token parameter in AWS SSM Parameter Store
# Parameter path: /ha-roy-develeap/dev/service1/auth-token
#
# Usage: ./create-auth-token-param.sh [--profile PROFILE_NAME]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PARAMETER_NAME="/ha-roy-develeap/dev/service1/auth-token"
AWS_REGION=us-east-1
AWS_PROFILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Usage: $0 [--profile PROFILE_NAME]"
            exit 1
            ;;
    esac
done

# Build AWS CLI profile option
PROFILE_OPTION=""
if [ -n "$AWS_PROFILE" ]; then
    PROFILE_OPTION="--profile ${AWS_PROFILE}"
fi

echo "=========================================="
echo "Create Auth Token SSM Parameter"
echo "=========================================="
echo ""
echo "Parameter Name: ${PARAMETER_NAME}"
echo "AWS Region: ${AWS_REGION}"
if [ -n "$AWS_PROFILE" ]; then
    echo "AWS Profile: ${AWS_PROFILE}"
fi
echo ""

# Prompt for auth token (hidden input)
echo -n "Enter auth token: "
read -s AUTH_TOKEN
echo ""

# Validate input
if [ -z "$AUTH_TOKEN" ]; then
    echo -e "${RED}Error: Auth token cannot be empty${NC}"
    exit 1
fi

# Display the token for confirmation
echo ""
echo "Token entered: ${AUTH_TOKEN}"
echo ""

# Confirm before creating
echo -e "${YELLOW}Ready to create parameter in AWS SSM Parameter Store${NC}"
echo -n "Continue? (y/n): "
read -r CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

# Check if parameter already exists
echo ""
echo "Checking if parameter already exists..."

if aws ssm get-parameter \
    --name "${PARAMETER_NAME}" \
    --region "${AWS_REGION}" \
    ${PROFILE_OPTION} \
    --query "Parameter.Name" \
    --output text >/dev/null 2>&1; then

    echo -e "${YELLOW}Parameter already exists. Updating...${NC}"

    aws ssm put-parameter \
        --name "${PARAMETER_NAME}" \
        --value "${AUTH_TOKEN}" \
        --type "SecureString" \
        --overwrite \
        --region "${AWS_REGION}" \
        ${PROFILE_OPTION}

    echo -e "${GREEN}✓ Parameter updated successfully!${NC}"
else
    echo "Parameter does not exist. Creating..."

    aws ssm put-parameter \
        --name "${PARAMETER_NAME}" \
        --value "${AUTH_TOKEN}" \
        --type "SecureString" \
        --description "Auth token for service1" \
        --region "${AWS_REGION}" \
        ${PROFILE_OPTION}

    echo -e "${GREEN}✓ Parameter created successfully!${NC}"
fi

echo ""
echo "=========================================="
echo "Parameter Details:"
echo "  Name: ${PARAMETER_NAME}"
echo "  Type: SecureString"
echo "  Region: ${AWS_REGION}"
if [ -n "$AWS_PROFILE" ]; then
    echo "  Profile: ${AWS_PROFILE}"
fi
echo "=========================================="
echo ""
echo "To verify, run:"
if [ -n "$AWS_PROFILE" ]; then
    echo "  aws ssm get-parameter --name \"${PARAMETER_NAME}\" --region ${AWS_REGION} --profile ${AWS_PROFILE} --with-decryption"
else
    echo "  aws ssm get-parameter --name \"${PARAMETER_NAME}\" --region ${AWS_REGION} --with-decryption"
fi
