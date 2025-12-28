#!/bin/bash

# Terraform Backend Setup Script
# Creates S3 bucket and DynamoDB table for Terraform remote state
# This bucket will be shared by both infrastructure and applications workspaces

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

# Default values
AWS_REGION=us-east-1
AWS_PROFILE=checkpoint
PROJECT_NAME=ha-roy-develeap
ENVIRONMENT=dev

# Derived names
BUCKET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-terraform-state"
DYNAMODB_TABLE="terraform-state-lock-roy-develeap"

# ============================================================================
# COLORS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# FUNCTIONS
# ============================================================================

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "============================================================================"
    echo "$1"
    echo "============================================================================"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

print_header "Terraform Backend Setup"

print_info "Configuration:"
print_info "  AWS Profile:     $AWS_PROFILE"
print_info "  Project Name:    $PROJECT_NAME"
print_info "  Environment:     $ENVIRONMENT"
print_info "  S3 Bucket:       $BUCKET_NAME"
print_info "  DynamoDB Table:  $DYNAMODB_TABLE"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
print_info "Checking AWS credentials..."
if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
    print_error "AWS credentials not configured for profile '$AWS_PROFILE'. Please run 'aws configure --profile $AWS_PROFILE' first."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
print_info "Using AWS Account: $ACCOUNT_ID"
echo ""

# ============================================================================
# CREATE S3 BUCKET
# ============================================================================

print_header "Creating S3 Bucket"

if aws s3 ls "s3://${BUCKET_NAME}" --profile "$AWS_PROFILE" 2>&1 | grep -q 'NoSuchBucket'; then
    print_info "Creating S3 bucket: $BUCKET_NAME"

    aws s3api create-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE"

    print_info "✓ S3 bucket created"
else
    print_warning "S3 bucket already exists: $BUCKET_NAME"
fi

# Enable versioning
print_info "Enabling versioning..."
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled --profile "$AWS_PROFILE"
print_info "✓ Versioning enabled"

# Enable encryption
print_info "Enabling server-side encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }' \
    \
    --profile "$AWS_PROFILE"
print_info "✓ Encryption enabled"


# ============================================================================
# CREATE DYNAMODB TABLE
# ============================================================================

print_header "Creating DynamoDB Table"

# Check if table exists
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --profile "$AWS_PROFILE" 2>&1 | grep -q 'ResourceNotFoundException'; then
    print_info "Creating DynamoDB table: $DYNAMODB_TABLE"

    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        \
        --profile "$AWS_PROFILE" \
        --tags Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENVIRONMENT" Key=ManagedBy,Value=script

    print_info "Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --profile "$AWS_PROFILE"

    print_info "✓ DynamoDB table created"
else
    print_warning "DynamoDB table already exists: $DYNAMODB_TABLE"
fi

# ============================================================================
# SUMMARY
# ============================================================================

print_header "Setup Complete!"

cat <<EOF
Backend configuration is ready. Update your Terraform files:

infrastructure/main.tf:
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "infrastructure/terraform.tfstate"
    region         = "$AWS_REGION"
    encrypt        = true
    dynamodb_table = "$DYNAMODB_TABLE"
  }

applications/main.tf:
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "applications/terraform.tfstate"
    region         = "$AWS_REGION"
    encrypt        = true
    dynamodb_table = "$DYNAMODB_TABLE"
  }

Next steps:
1. Update backend configuration in infrastructure/main.tf
2. Run: cd infrastructure && terraform init -migrate-state
3. Update backend configuration in applications/main.tf
4. Run: cd applications && terraform init -migrate-state

Resources created:
- S3 Bucket: s3://${BUCKET_NAME}
- DynamoDB Table: ${DYNAMODB_TABLE}

EOF

print_info "Done!"
