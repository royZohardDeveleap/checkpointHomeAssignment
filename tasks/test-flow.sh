#!/bin/bash

# Script to test the complete flow of the application
# Service1 receives request -> validates token -> publishes to SQS -> Service2 processes and uploads to S3

set -e

# Configuration
PROFILE="checkpoint"
REGION="us-east-1"
PROJECT="ha-roy-develeap"
ENV="dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "${BLUE}$1${NC}"
    echo "----------------------------------------------------------------"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

echo "================================================================"
echo "Testing Complete Application Flow"
echo "================================================================"
echo ""

# 1. Get ALB DNS
print_header "1. Getting ALB Endpoint"
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "LoadBalancers[?LoadBalancerName=='${PROJECT}-${ENV}-alb'].DNSName" \
    --output text 2>/dev/null)

if [ -z "$ALB_DNS" ]; then
    print_error "Could not find ALB"
    exit 1
fi

echo "ALB URL: http://$ALB_DNS"
print_success "ALB found"
echo ""

# 2. Get current SQS message count (before sending)
print_header "2. Checking SQS Queue Status (Before)"
QUEUE_URL=$(aws sqs get-queue-url \
    --queue-name "${PROJECT}-${ENV}-queue" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'QueueUrl' \
    --output text 2>/dev/null)

if [ -z "$QUEUE_URL" ]; then
    print_error "Could not find SQS queue"
    exit 1
fi

MESSAGES_BEFORE=$(aws sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names ApproximateNumberOfMessages \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'Attributes.ApproximateNumberOfMessages' \
    --output text 2>/dev/null)

echo "Queue URL: $QUEUE_URL"
echo "Messages in queue (before): $MESSAGES_BEFORE"
echo ""

# 3. Send test request to Service1
print_header "3. Sending Test Request to Service1"

# Create payload with valid token and data
TIMESTAMP=$(date +%s)
PAYLOAD=$(cat <<'EOF_TEMPLATE'
{
  "data": {
    "email_subject": "Happy new year!",
    "email_sender": "John Doe",
    "email_timestream": "TIMESTAMP_PLACEHOLDER",
    "email_content": "Just want to say... Happy new year!!!"
  },
  "token": "$DJISA<$#45ex3RtYr"
}
EOF_TEMPLATE
)
# Replace timestamp placeholder
PAYLOAD="${PAYLOAD//TIMESTAMP_PLACEHOLDER/$TIMESTAMP}"

echo "Payload:"
echo "$PAYLOAD" | jq .
echo ""

echo "Sending POST request to http://$ALB_DNS/process"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "http://$ALB_DNS/process")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)

echo "HTTP Status Code: $HTTP_CODE"
echo "Response Body: $BODY"
echo ""

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "202" ]; then
    print_success "Request accepted by Service1"
else
    print_error "Request failed with status $HTTP_CODE"
fi
echo ""

# 4. Wait a moment for message to be published
echo "Waiting 5 seconds for message to be published to SQS..."
sleep 5
echo ""

# 5. Check SQS queue (after sending)
print_header "4. Checking SQS Queue Status (After)"
MESSAGES_AFTER=$(aws sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
    --region "$REGION" \
    --profile "$PROFILE" \
    --output json | jq -r '.Attributes | "Available: \(.ApproximateNumberOfMessages), In-Flight: \(.ApproximateNumberOfMessagesNotVisible)"')

echo "Messages in queue (after): $MESSAGES_AFTER"

if [ "$MESSAGES_AFTER" != "$MESSAGES_BEFORE" ]; then
    print_success "Message appears to have been published to SQS"
else
    echo "No change in queue - this could mean:"
    echo "  - Message was already processed by Service2"
    echo "  - Token validation failed"
    echo "  - Data validation failed"
fi
echo ""

# 6. Check S3 bucket for new objects
print_header "5. Checking S3 Bucket for Processed Messages"
BUCKET_NAME="${PROJECT}-${ENV}-messages-bucket"

echo "Listing recent objects in s3://$BUCKET_NAME/emails/"
RECENT_OBJECTS=$(aws s3api list-objects-v2 \
    --bucket "$BUCKET_NAME" \
    --prefix "emails/" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'sort_by(Contents, &LastModified)[-5:].{Key:Key,Size:Size,LastModified:LastModified}' \
    --output table 2>/dev/null || echo "ERROR")

if [ "$RECENT_OBJECTS" = "ERROR" ]; then
    print_error "Could not list S3 objects - bucket might not exist"
else
    echo "$RECENT_OBJECTS"
    echo ""
    echo "To check if your message was processed, wait 1-2 minutes"
    echo "and look for a new file with timestamp close to: $TIMESTAMP"
fi
echo ""

# 7. Show CloudWatch Logs command
print_header "6. Monitoring (CloudWatch Logs)"
echo "To monitor Service1 logs:"
echo "  aws logs tail /ecs/${PROJECT}-${ENV}/service1 --follow --region $REGION --profile $PROFILE"
echo ""
echo "To monitor Service2 logs:"
echo "  aws logs tail /ecs/${PROJECT}-${ENV}/service2 --follow --region $REGION --profile $PROFILE"
echo ""

# Summary
print_header "Summary"
echo "Flow Test Complete!"
echo ""
echo "Expected Flow:"
echo "  1. ✓ ALB receives request at http://$ALB_DNS/process"
echo "  2. ✓ Service1 validates token and data fields"
echo "  3. ✓ Service1 publishes message to SQS: $QUEUE_URL"
echo "  4. ? Service2 polls SQS and retrieves message"
echo "  5. ? Service2 uploads to S3: s3://$BUCKET_NAME/emails/"
echo ""
echo "To verify Service2 processing:"
echo "  1. Wait 1-2 minutes for Service2 to poll"
echo "  2. Run: aws s3 ls s3://$BUCKET_NAME/emails/ --recursive --profile $PROFILE | tail -5"
echo "  3. Check CloudWatch Logs for Service2"
echo ""
echo "================================================================"
