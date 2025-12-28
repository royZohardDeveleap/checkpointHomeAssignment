#!/bin/bash

# Script to connect to ECS container instances via AWS Systems Manager Session Manager
# This allows shell access to private instances without SSH keys or bastion hosts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-ha-roy-develeap-dev-cluster}"
AWS_REGION=us-east-1
AWS_PROFILE="checkpoint"
INSTANCE_ID=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --instance)
            INSTANCE_ID="$2"
            shift 2
            ;;
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Usage: $0 [--cluster CLUSTER] [--instance INSTANCE_ID] [--profile PROFILE]"
            exit 1
            ;;
    esac
done

# Build AWS CLI profile option
PROFILE_OPTION=""
if [ -n "$AWS_PROFILE" ]; then
    PROFILE_OPTION="--profile ${AWS_PROFILE}"
fi

echo -e "${BLUE}=========================================="
echo "AWS Systems Manager - Session Manager"
echo "=========================================="
echo ""
echo "Cluster: ${CLUSTER_NAME}"
echo "Region: ${AWS_REGION}"
if [ -n "$AWS_PROFILE" ]; then
    echo "Profile: ${AWS_PROFILE}"
fi
echo -e "==========================================${NC}"
echo ""

# ============================================================================
# 1. LIST CONTAINER INSTANCES
# ============================================================================

if [ -z "$INSTANCE_ID" ]; then
    echo -e "${YELLOW}[1] Finding ECS container instances...${NC}"
    echo ""

    # Get container instances from ECS
    INSTANCE_ARNS=$(aws ecs list-container-instances \
        --cluster "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        ${PROFILE_OPTION} \
        --query 'containerInstanceArns[]' \
        --output text)

    if [ -z "$INSTANCE_ARNS" ]; then
        echo -e "${RED}✗ No container instances found in cluster${NC}"
        exit 1
    fi

    # Get EC2 instance IDs
    INSTANCE_DETAILS=$(aws ecs describe-container-instances \
        --cluster "${CLUSTER_NAME}" \
        --container-instances $INSTANCE_ARNS \
        --region "${AWS_REGION}" \
        ${PROFILE_OPTION})

    # Display instances with their status
    echo "Available instances:"
    echo ""

    INSTANCE_COUNT=0
    declare -a EC2_INSTANCES
    declare -a AGENT_STATUS

    while IFS= read -r line; do
        EC2_ID=$(echo "$line" | jq -r '.ec2InstanceId')
        AGENT_CONNECTED=$(echo "$line" | jq -r '.agentConnected')
        RUNNING_TASKS=$(echo "$line" | jq -r '.runningTasksCount')
        STATUS=$(echo "$line" | jq -r '.status')

        EC2_INSTANCES+=("$EC2_ID")
        AGENT_STATUS+=("$AGENT_CONNECTED")

        INSTANCE_COUNT=$((INSTANCE_COUNT + 1))

        # Color code based on agent status
        if [ "$AGENT_CONNECTED" == "true" ]; then
            STATUS_COLOR="${GREEN}"
            AGENT_TEXT="✓ Connected"
        else
            STATUS_COLOR="${RED}"
            AGENT_TEXT="✗ Disconnected"
        fi

        echo -e "  ${INSTANCE_COUNT}. ${STATUS_COLOR}${EC2_ID}${NC}"
        echo "     Status: ${STATUS}"
        echo "     Agent: ${STATUS_COLOR}${AGENT_TEXT}${NC}"
        echo "     Running Tasks: ${RUNNING_TASKS}"
        echo ""
    done < <(echo "$INSTANCE_DETAILS" | jq -c '.containerInstances[]')

    # Prompt user to select instance
    echo -n "Select instance number (1-${INSTANCE_COUNT}): "
    read SELECTION

    # Validate selection
    if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt "$INSTANCE_COUNT" ]; then
        echo -e "${RED}Error: Invalid selection${NC}"
        exit 1
    fi

    INSTANCE_ID="${EC2_INSTANCES[$((SELECTION - 1))]}"
fi

# ============================================================================
# 2. VERIFY SSM AGENT STATUS
# ============================================================================

echo ""
echo -e "${YELLOW}[2] Checking SSM Agent status for ${INSTANCE_ID}...${NC}"

SSM_STATUS=$(aws ssm describe-instance-information \
    --region "${AWS_REGION}" \
    ${PROFILE_OPTION} \
    --filters "Key=InstanceIds,Values=${INSTANCE_ID}" \
    --query 'InstanceInformationList[0].PingStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SSM_STATUS" == "Online" ]; then
    echo -e "${GREEN}✓ SSM Agent is online and ready${NC}"
elif [ "$SSM_STATUS" == "NOT_FOUND" ]; then
    echo -e "${RED}✗ Instance not registered with SSM${NC}"
    echo ""
    echo "Possible causes:"
    echo "  1. SSM Agent not installed (should be on ECS-optimized AMI)"
    echo "  2. IAM instance role missing AmazonSSMManagedInstanceCore policy"
    echo "  3. VPC endpoints for SSM not configured (ssm, ssmmessages, ec2messages)"
    echo "  4. Instance just launched (wait 2-3 minutes)"
    echo ""
    exit 1
else
    echo -e "${YELLOW}⚠ SSM Agent status: ${SSM_STATUS}${NC}"
    echo "  Instance may not be ready for Session Manager"
    echo ""
fi

# ============================================================================
# 3. START SESSION MANAGER SESSION
# ============================================================================

echo ""
echo -e "${YELLOW}[3] Starting Session Manager session...${NC}"
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  You are now connected to EC2 instance: ${INSTANCE_ID}  ║${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}║  Useful commands:                                              ║${NC}"
echo -e "${BLUE}║    - Check ECS agent status:                                   ║${NC}"
echo -e "${BLUE}║      sudo systemctl status ecs                                 ║${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}║    - View ECS agent logs:                                      ║${NC}"
echo -e "${BLUE}║      sudo cat /var/log/ecs/ecs-agent.log                       ║${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}║    - Check ECS config:                                         ║${NC}"
echo -e "${BLUE}║      sudo cat /etc/ecs/ecs.config                              ║${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}║    - List running containers:                                  ║${NC}"
echo -e "${BLUE}║      docker ps                                                 ║${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}║    - Restart ECS agent:                                        ║${NC}"
echo -e "${BLUE}║      sudo systemctl restart ecs                                ║${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}║  Type 'exit' to close the session                             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Start the session
aws ssm start-session \
    --target "${INSTANCE_ID}" \
    --region "${AWS_REGION}" \
    ${PROFILE_OPTION}
