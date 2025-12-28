#!/bin/bash

# Terraform Backend Deletion Script
# Deletes S3 bucket and DynamoDB table used for Terraform remote state
# WARNING: This will delete all Terraform state files!

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

print_header "Terraform Backend Deletion"

print_warning "This will DELETE the following resources:"
print_warning "  S3 Bucket:       $BUCKET_NAME (and ALL contents)"
print_warning "  DynamoDB Table:  $DYNAMODB_TABLE"
echo ""
print_error "⚠️  WARNING: This will destroy all Terraform state files!"
print_error "⚠️  You will lose track of all infrastructure managed by Terraform!"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_info "Deletion cancelled."
    exit 0
fi

echo ""
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
# DELETE S3 BUCKET
# ============================================================================

print_header "Deleting S3 Bucket"

# Check if bucket exists
if aws s3 ls "s3://${BUCKET_NAME}" --profile "$AWS_PROFILE" &> /dev/null; then
    print_info "Found S3 bucket: $BUCKET_NAME"

    # Check if bucket has objects
    OBJECT_COUNT=$(aws s3 ls "s3://${BUCKET_NAME}" --profile "$AWS_PROFILE" --recursive --summarize 2>&1 | grep "Total Objects:" | awk '{print $3}')

    if [ -n "$OBJECT_COUNT" ] && [ "$OBJECT_COUNT" -gt 0 ]; then
        print_warning "Bucket contains $OBJECT_COUNT object(s)"
        print_info "Deleting all objects and versions..."

        # Delete all object versions (including delete markers)
        aws s3api list-object-versions \
            --bucket "$BUCKET_NAME" \
            \
            --profile "$AWS_PROFILE" \
            --output json \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
            | jq -r '.Objects[]? | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' \
            | xargs -I {} -P 10 aws s3api delete-object --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" {} || true

        # Delete all delete markers
        aws s3api list-object-versions \
            --bucket "$BUCKET_NAME" \
            \
            --profile "$AWS_PROFILE" \
            --output json \
            --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
            | jq -r '.Objects[]? | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' \
            | xargs -I {} -P 10 aws s3api delete-object --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" {} || true

        print_info "✓ All objects deleted"
    else
        print_info "Bucket is empty"
    fi

    # Delete the bucket
    print_info "Deleting bucket..."
    aws s3api delete-bucket \
        --bucket "$BUCKET_NAME" \
        --profile "$AWS_PROFILE"

    print_info "✓ S3 bucket deleted: $BUCKET_NAME"
else
    print_warning "S3 bucket does not exist: $BUCKET_NAME"
fi

# ============================================================================
# DELETE DYNAMODB TABLE
# ============================================================================

print_header "Deleting DynamoDB Table"

# Check if table exists
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --profile "$AWS_PROFILE" &> /dev/null; then
    print_info "Found DynamoDB table: $DYNAMODB_TABLE"

    # Delete the table
    print_info "Deleting table..."
    aws dynamodb delete-table \
        --table-name "$DYNAMODB_TABLE" \
        --profile "$AWS_PROFILE" &> /dev/null

    print_info "Waiting for table to be deleted..."
    aws dynamodb wait table-not-exists \
        --table-name "$DYNAMODB_TABLE" \
        --profile "$AWS_PROFILE"

    print_info "✓ DynamoDB table deleted: $DYNAMODB_TABLE"
else
    print_warning "DynamoDB table does not exist: $DYNAMODB_TABLE"
fi

# ============================================================================
# SUMMARY
# ============================================================================

print_header "Deletion Complete!"

cat <<EOF
Resources deleted:
- S3 Bucket: s3://${BUCKET_NAME}
- DynamoDB Table: ${DYNAMODB_TABLE}

Important:
- All Terraform state files have been deleted
- Infrastructure is no longer tracked by Terraform
- You can still manually delete resources via AWS Console or CLI

Next steps:
1. If you want to recreate the backend, run: ./setup-backend.sh
2. To clean up AWS resources, manually delete them or use Terraform destroy before deleting the backend
3. Check for any orphaned resources in AWS Console

EOF

print_info "Done!"
