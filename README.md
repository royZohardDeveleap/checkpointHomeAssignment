# Home Assignment - Microservices Infrastructure on AWS ECS

A production-ready microservices architecture deployed on AWS ECS Fargate with automated CI/CD pipelines, monitoring, and observability using Grafana.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Components](#components)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup Guide](#detailed-setup-guide)
- [CI/CD Pipeline](#cicd-pipeline)
- [Testing](#testing)
- [Monitoring](#monitoring)
- [Cleanup](#cleanup)
- [Available Commands](#available-commands)
- [Architecture Decisions](#architecture-decisions)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet Gateway                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                   ┌──────────────────────┐
                   │ Public Subnets (2 AZs)│
                   └──────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                   Application Load Balancer                      │
│              /service1/* → Service1 Target Group                 │
│              /grafana/*  → Grafana Target Group                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                   ┌──────────────────────┐
                   │ Private Subnets (2 AZs)│
                   └──────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│               ECS Cluster (EC2 Launch Type)                      │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │        Auto Scaling Group (t3.micro instances)          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │    │
│  │  │  EC2 Instance│  │  EC2 Instance│  │  EC2 Instance│ │    │
│  │  │  ┌─────────┐ │  │  ┌─────────┐ │  │  ┌─────────┐ │ │    │
│  │  │  │Service1 │ │  │  │Service2 │ │  │  │ Grafana │ │ │    │
│  │  │  │Container│ │  │  │Container│ │  │  │Container│ │ │    │
│  │  │  └─────────┘ │  │  └─────────┘ │  │  └─────────┘ │ │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │    │
│  │       Capacity Provider: Managed Scaling               │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
           │                  │                    │
           ▼                  ▼                    ▼
    ┌────────────┐    ┌────────────┐      ┌──────────────┐
    │VPC Endpoint│    │VPC Endpoint│      │VPC Endpoint  │
    │  (SQS)     │    │   (S3)     │      │(SSM/Logs/ECR)│
    └────────────┘    └────────────┘      └──────────────┘
           │                  │
           ▼                  ▼
    ┌────────────┐      ┌────────────┐
    │ SQS Queue  │      │ S3 Bucket  │
    │ (Messages) │      │ (Storage)  │
    └────────────┘      └────────────┘
```

### Service Flow

1. **Service1** - REST API that receives HTTP POST requests with email data
   - Validates authentication token from SSM Parameter Store
   - Validates payload structure
   - Sends messages to SQS queue
   - Returns success/error responses

2. **Service2** - Background worker that processes messages
   - Polls SQS queue for new messages
   - Processes messages and uploads to S3
   - Deletes processed messages from queue
   - Handles errors and retries

3. **Grafana** - Monitoring and visualization
   - Pre-configured dashboards for system metrics
   - ECS task monitoring
   - Resource utilization tracking

## Project Structure

```
.
├── .github/workflows/          # GitHub Actions CI/CD pipelines
│   ├── ci-pipeline.yaml        # Continuous Integration pipeline
│   ├── cd-pipeline.yaml        # Continuous Deployment pipeline
│   ├── build-service.yaml      # Service build workflow
│   ├── build-deploy-grafana.yaml  # Grafana build and deployment workflow
│   ├── test-service.yaml       # Service testing workflow
│   └── deploy-service.yaml     # Service deployment workflow
│
├── tasks/                      # Application services
│   ├── service1/              # REST API service
│   │   ├── app.py             # Flask application
│   │   ├── Dockerfile         # Container image definition
│   │   ├── requirements.txt   # Python dependencies
│   │   └── test_app.py        # Unit tests
│   │
│   ├── service2/              # Background worker service
│   │   ├── app.py             # Worker application
│   │   ├── Dockerfile         # Container image definition
│   │   ├── requirements.txt   # Python dependencies
│   │   └── test_app.py        # Unit tests
│   │
│   ├── grafana/               # Monitoring service
│   │   ├── Dockerfile         # Grafana container
│   │   ├── dashboards/        # Pre-configured dashboards
│   │   ├── provisioning/      # Grafana configuration
│   │   └── README.md          # Grafana documentation
│   │
│   ├── create-auth-token-param.sh  # Create SSM auth token
│   ├── cleanup-storage.sh          # Empty ECR/S3 resources
│   ├── ssm-connect.sh              # Interactive SSM session to EC2 instances
│   └── test-flow.sh                # End-to-end testing script
│
├── terraform/                  # Infrastructure as Code
│   ├── infrastructure/        # Core infrastructure
│   │   ├── main.tf           # VPC, ECS, ALB, SQS, S3
│   │   ├── modules/          # Reusable Terraform modules
│   │   └── variables.tf      # Configuration variables
│   │
│   ├── service1/             # Service1 ECS deployment
│   ├── service2/             # Service2 ECS deployment
│   ├── monitoring/           # Grafana ECS deployment (separate workspace)
│   ├── setup-backend.sh      # Create Terraform state backend
│   └── delete-backend.sh     # Delete Terraform state backend
│
├── Taskfile.yml              # Task automation (similar to Makefile)
└── README.md                 # This file
```

## Components

### Infrastructure (Terraform)

- **VPC** - Multi-AZ networking with public and private subnets
- **ECS Cluster** - EC2-based container orchestration with Auto Scaling
- **EC2 Auto Scaling Group** - Self-managed container instances (t3.micro)
- **ECS Capacity Provider** - Managed scaling for container instances
- **Application Load Balancer** - HTTP routing and health checks
- **SQS Queue** - Message queue for async communication
- **S3 Bucket** - Object storage for processed messages
- **ECR Repositories** - Docker image registry
- **CloudWatch Logs** - Centralized logging
- **IAM Roles** - Least-privilege access control (instance role + task execution role)
- **SSM Parameter Store** - Secure configuration management
- **Launch Template** - EC2 instance configuration with ECS-optimized AMI

### Services

#### Service1 (REST API)
- **Framework**: Flask (Python)
- **Port**: 5000
- **Endpoints**:
  - `POST /` - Receive email data
  - `GET /health` - Health check
- **Features**:
  - Token-based authentication via SSM
  - Payload validation
  - SQS message publishing
  - Comprehensive error handling

#### Service2 (Worker)
- **Framework**: Python
- **Type**: Long-running background process
- **Features**:
  - SQS message polling (10-second interval)
  - S3 object upload
  - Message deletion after processing
  - Graceful error handling

#### Grafana (Monitoring)
- **Version**: Latest
- **Port**: 3000
- **Features**:
  - CloudWatch data source integration
  - Pre-configured dashboards
  - ECS metrics visualization
  - System overview dashboard

## Prerequisites

### Required Tools

- **AWS CLI** (v2.x) - [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Terraform** (v1.9.0+) - [Install Guide](https://developer.hashicorp.com/terraform/install)
- **Docker** (v20.x+) - [Install Guide](https://docs.docker.com/get-docker/)
- **Task** (v3.x) - [Install Guide](https://taskfile.dev/installation/)
- **GitHub CLI** (optional) - [Install Guide](https://cli.github.com/)
- **jq** - JSON processor (`sudo apt install jq` or `brew install jq`)

### AWS Setup

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials:
   ```bash
   aws configure
   # Enter your AWS credentials, region (us-east-1), and output format
   ```
3. **Required IAM Permissions**:
   - VPC, EC2, ECS management
   - S3, SQS, ECR operations
   - CloudWatch Logs access
   - SSM Parameter Store access
   - IAM role creation

### GitHub Setup (for CI/CD)

1. Fork or clone this repository
2. Add GitHub Secrets (Settings → Secrets and variables → Actions):
   - `AWS_ACCESS_KEY_ID` - Your AWS access key
   - `AWS_SECRET_ACCESS_KEY` - Your AWS secret key

## Quick Start

The fastest way to get started:

```bash
# Optional: Configure AWS profile in Taskfile.yml if using named profiles
# Edit the AWS_PROFILE variable in Taskfile.yml (default: checkpoint)
# Or remove --profile flags from Taskfile.yml if using default AWS credentials

# Complete setup (all steps automated)
task setup

# View endpoints
task info

# Check service status
task status

# View logs
task logs:service1
task logs:service2
```

This will:
1. Create Terraform backend
2. Deploy infrastructure (VPC, ECS, ALB, SQS, S3)
3. Create authentication token in SSM
4. Prompt you to trigger CI/CD workflows

## Detailed Setup Guide

### Step 1: Backend Setup

Create S3 bucket and DynamoDB table for Terraform state:

```bash
cd terraform
./setup-backend.sh
```

This creates:
- S3 bucket: `ha-roy-develeap-terraform-state`
- DynamoDB table: `ha-roy-develeap-terraform-locks`

### Step 2: Deploy Infrastructure

Deploy core AWS resources:

```bash
cd terraform/infrastructure
terraform init
terraform plan
terraform apply
```

Resources created:
- VPC with 2 public and 2 private subnets across AZs
- ECS Cluster (EC2 Launch Type)
- Auto Scaling Group with ECS-optimized EC2 instances
- ECS Capacity Provider with managed scaling
- Launch Template for EC2 instances
- Application Load Balancer with target groups (including Grafana target group)
- SQS queue
- S3 bucket for message storage
- 3 ECR repositories (service1, service2, grafana)
- CloudWatch log groups
- IAM roles (EC2 instance role + task execution role) and policies
- Security groups for ALB and ECS instances

**Note**: Grafana monitoring service is deployed separately in Step 4a using its own Terraform workspace.

### Step 3: Create Authentication Token

Create a secure authentication token in SSM Parameter Store:

```bash
cd tasks
./create-auth-token-param.sh
```

You'll be prompted to enter a token (or it will generate one). This token is used by Service1 for request authentication.

### Step 4: Build and Push Docker Images (CI Pipeline)

#### 4a. Build and Deploy Grafana (Optional - for monitoring)

Build Grafana image and deploy the monitoring service:

```bash
# Build and deploy Grafana with custom admin password
gh workflow run build-deploy-grafana.yaml -f admin_password=<YOUR-SECURE-PASSWORD>

# Or use existing password from SSM (if already set)
gh workflow run build-deploy-grafana.yaml
```

This workflow:
1. Stores/updates admin password in SSM Parameter Store (if provided)
2. Builds Grafana Docker image with pre-configured dashboards
3. Pushes image to ECR
4. Stores image tag in SSM Parameter Store
5. Deploys Grafana ECS service using Terraform (terraform/monitoring workspace)
6. Waits for service to become healthy

**Note**: Grafana has its own Terraform workspace ([terraform/monitoring/](terraform/monitoring/)) separate from core infrastructure. This allows independent monitoring updates without touching infrastructure.

#### 4b. Build Application Services

The CI pipeline automatically:
- Detects changed services
- Runs unit tests (on PRs)
- Builds Docker images
- Pushes to ECR
- Tags images with semantic version (e.g., `service1-v1.2.3`)
- Creates git tags
- Stores image tags in SSM Parameter Store
- Triggers CD pipeline via repository_dispatch

**Trigger CI manually:**
```bash
gh workflow run ci-pipeline.yaml -f services=all -f trigger_cd=true
```

**Or push to main branch:**
```bash
git add .
git commit -m "Deploy services"
git push origin main
```

### Step 5: Deploy Services (CD Pipeline)

The CD pipeline automatically:
- Receives trigger from CI (repository_dispatch)
- Deploys selected services to ECS
- Updates task definitions
- Waits for services to stabilize

**Trigger CD manually:**
```bash
gh workflow run cd-pipeline.yaml -f services=all
```

### Step 6: Verify Deployment

```bash
# Get ALB endpoint
task info

# Check service health
curl http://<ALB-DNS>/service1/health

# Test Service1 endpoint
curl -X POST http://<ALB-DNS>/service1/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <YOUR-TOKEN>" \
  -d '{
    "email_timestream": "2024-01-15T10:30:00Z",
    "email_subject": "Test Email",
    "email_content": "This is a test message"
  }'

# Access Grafana
open http://<ALB-DNS>/grafana
# Default credentials: admin / admin
```

## CI/CD Pipeline

### Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      CI Pipeline                             │
│  (Triggered on: push to main, PR, manual)                   │
└─────────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
  ┌──────────┐    ┌──────────┐    ┌──────────┐
  │ Detect   │    │  Test    │    │  Build   │
  │ Changes  │───▶│ Services │───▶│ & Push   │
  └──────────┘    └──────────┘    └──────────┘
                                        │
                                        ▼
                         ┌──────────────────────────┐
                         │ Repository Dispatch Event │
                         │   event: trigger-cd       │
                         └──────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────┐
│                      CD Pipeline                             │
│  (Triggered by: repository_dispatch, manual)                │
└─────────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
  ┌──────────┐    ┌──────────┐    ┌──────────┐
  │ Determine│    │  Deploy  │    │ Verify   │
  │ Services │───▶│ to ECS   │───▶│ Stable   │
  └──────────┘    └──────────┘    └──────────┘
```

### CI Pipeline Features

- **Path-based detection** - Only builds changed services
- **Parallel testing** - Tests run concurrently
- **Semantic versioning** - Auto-incremented versions based on commit messages
  - **Format**: `service1-v1.2.3`, `service2-v2.0.1` (per-service independent versioning)
  - **MAJOR bump**: Commit message contains `BREAKING CHANGE` or `major:`
  - **MINOR bump**: Commit message contains `feat:`, `feature:`, or `minor:`
  - **PATCH bump**: Default for bug fixes, chores, and other changes
- **Git tagging** - Auto-creates annotated tags for each build
- **SSM integration** - Stores image tags in Parameter Store for deployment
- **Repository dispatch** - Triggers CD pipeline automatically
- **Matrix builds** - Builds multiple services in parallel

### CD Pipeline Features

- **Dual triggers** - `repository_dispatch` (automated) + `workflow_dispatch` (manual)
- **Service selection** - Deploy specific services or all
- **Terraform-based** - Infrastructure as Code deployment
- **SSM-based versioning** - Reads image tags from Parameter Store
- **Health checks** - Waits for ECS service stability
- **Rollback ready** - Previous task definitions retained

### How Image Versioning Works

The system uses SSM Parameter Store as the source of truth for image tags:

**CI Pipeline (Build):**
1. Builds Docker image with semantic version tag (e.g., `1.2.3`)
2. Pushes image to ECR: `<account>.dkr.ecr.us-east-1.amazonaws.com/ha-roy-develeap/dev/service1:1.2.3`
3. Stores tag in SSM: `/ha-roy-develeap/dev/service1/image-tag` = `1.2.3`

**CD Pipeline (Deploy):**
1. Terraform reads image tag from SSM Parameter Store
2. Creates/updates ECS task definition with the image URI
3. Updates ECS service with new task definition
4. ECS pulls the correct image version from ECR

This decouples build from deployment - you can:
- Deploy any previously built version by updating SSM parameter
- Roll back by changing SSM parameter to previous version
- Deploy same version across multiple environments

**SSM Parameters:**
```
/ha-roy-develeap/dev/service1/image-tag      # Service1 version
/ha-roy-develeap/dev/service2/image-tag      # Service2 version
/ha-roy-develeap/dev/grafana/image-tag       # Grafana version
/ha-roy-develeap/dev/service1/auth-token     # Service1 auth token
/ha-roy-develeap/dev/grafana/admin-password  # Grafana admin password
```

### Triggering Methods

**1. Automatic (Push to Main)**
```bash
git push origin main
# CI detects changes → builds → triggers CD → deploys
```

**2. Manual CI with CD Trigger**
```bash
gh workflow run ci-pipeline.yaml \
  -f services=service1,service2 \
  -f run_tests=true \
  -f trigger_cd=true
```

**3. Manual CD Only**
```bash
gh workflow run cd-pipeline.yaml \
  -f services=service1 \
  -f environment=dev
```

**4. Manual Rollback (Change SSM Parameter)**
```bash
# View current version
aws ssm get-parameter \
  --name /ha-roy-develeap/dev/service1/image-tag \
  --query 'Parameter.Value' \
  --output text

# Rollback to previous version
aws ssm put-parameter \
  --name /ha-roy-develeap/dev/service1/image-tag \
  --value "1.2.2" \
  --overwrite

# Trigger deployment with rollback version
gh workflow run cd-pipeline.yaml -f services=service1
```

**5. Pull Request (Tests Only)**
```bash
git checkout -b feature/new-feature
git push origin feature/new-feature
# Create PR - triggers tests only, no builds
```

### Semantic Versioning

The CI pipeline automatically versions your services using **Semantic Versioning 2.0.0**:

**Version Format**: `<service>-v<MAJOR>.<MINOR>.<PATCH>`

Examples:
- `service1-v1.0.0` - Initial release
- `service1-v1.1.0` - Added new feature
- `service1-v1.1.1` - Bug fix
- `service2-v2.0.0` - Breaking change

**Version Bumping Rules**:

The version is automatically calculated based on commit messages since the last tag:

1. **MAJOR version** (breaking changes):
   ```bash
   git commit -m "BREAKING CHANGE: redesign API endpoints"
   git commit -m "major: remove deprecated authentication"
   ```

2. **MINOR version** (new features, backwards compatible):
   ```bash
   git commit -m "feat: add email validation"
   git commit -m "feature: support batch processing"
   git commit -m "minor: add new dashboard widget"
   ```

3. **PATCH version** (bug fixes, default):
   ```bash
   git commit -m "fix: resolve memory leak in worker"
   git commit -m "chore: update dependencies"
   git commit -m "docs: improve README"
   ```

**How It Works**:

1. CI pipeline examines commit messages since last tag
2. Determines highest priority bump (MAJOR > MINOR > PATCH)
3. Increments version automatically
4. Creates git tag: `service1-v1.2.3`
5. Stores version in SSM Parameter Store
6. CD pipeline reads version from SSM and deploys

**Per-Service Versioning**:

Each service has independent version numbers:
- `service1-v2.3.5`
- `service2-v1.0.2`
- `grafana-v3.1.0`

This allows services to evolve independently without coordinating version numbers.

## Testing

### Unit Tests

Run tests for individual services:

```bash
# Test Service1
task test:service1

# Test Service2
task test:service2

# Test all services
task test:all
```

### End-to-End Flow Test

Test the complete message flow:

```bash
task test:flow
```

This script:
1. Sends a test message to Service1
2. Waits for Service2 to process it
3. Verifies the message appears in S3
4. Reports success/failure

### Manual Testing

```bash
# Get auth token from SSM
TOKEN=$(aws ssm get-parameter \
  --name /ha-roy-develeap/dev/service1/auth-token \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)

# Get ALB DNS
ALB_DNS=$(task info | grep "Service1:" | awk '{print $2}' | sed 's|http://||' | sed 's|/service1/||')

# Send test request
curl -X POST http://${ALB_DNS}/service1/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "email_timestream": "2024-12-29T10:30:00Z",
    "email_subject": "Production Test",
    "email_content": "Testing the service pipeline"
  }'

# Check SQS queue
aws sqs get-queue-attributes \
  --queue-url $(aws sqs get-queue-url --queue-name ha-roy-develeap-dev-queue --query 'QueueUrl' --output text) \
  --attribute-names ApproximateNumberOfMessages

# List S3 objects
aws s3 ls s3://ha-roy-develeap-dev-storage/ --recursive
```

## Monitoring

### Grafana Dashboards

Access Grafana at: `http://<ALB-DNS>/grafana`

**Initial Setup**:

Grafana has a separate build and deployment workflow for security (password management) and independent lifecycle:

```bash
# Build and deploy Grafana with admin password
gh workflow run build-deploy-grafana.yaml -f admin_password=<YOUR-SECURE-PASSWORD>

# Build with custom image tag
gh workflow run build-deploy-grafana.yaml \
  -f admin_password=<YOUR-SECURE-PASSWORD> \
  -f image_tag=v1.0.0

# Or build with existing password (if already set in SSM) and auto-generated tag (git SHA)
gh workflow run build-deploy-grafana.yaml
```

The workflow:
1. Stores/updates admin password in SSM Parameter Store (if provided)
2. Builds Grafana Docker image with pre-configured dashboards
3. Tags image (custom tag or git commit SHA)
4. Pushes to ECR
5. Stores image tag in SSM Parameter Store
6. Deploys Grafana ECS service using Terraform (terraform/monitoring workspace)
7. Waits for service to become healthy

**Default credentials**: `admin` / `<password-from-SSM>`

**Available Dashboards**:
- **System Overview** - ECS cluster metrics, task counts, resource utilization
- **Service Metrics** - Per-service CPU, memory, network stats
- **Queue Monitoring** - SQS message counts and processing rates

See [tasks/grafana/README.md](tasks/grafana/README.md) for dashboard details.

### CloudWatch Logs

View service logs:

```bash
# Stream Service1 logs
task logs:service1

# Stream Service2 logs
task logs:service2

# View logs in AWS Console
aws logs tail /ecs/ha-roy-develeap-dev/service1 --follow
```

### Service Status

```bash
# Check ECS service status
task status

# Get detailed service info
aws ecs describe-services \
  --cluster ha-roy-develeap-dev-cluster \
  --services ha-roy-develeap-dev-service1 ha-roy-develeap-dev-service2
```

### EC2 Instance Access

Since this uses EC2 launch type, you can connect to the container instances for debugging.

**Method 1: Interactive SSM Connect Script (Recommended)**

```bash
cd tasks
./ssm-connect.sh

# Optional arguments:
# --cluster CLUSTER_NAME    # Default: ha-roy-develeap-dev-cluster
# --instance INSTANCE_ID    # Skip interactive selection
# --profile PROFILE_NAME    # AWS profile to use
```

This script will:
1. List all ECS container instances with their status
2. Show running task counts and ECS agent health
3. Verify SSM Agent is online
4. Start an interactive SSM session
5. Provide helpful commands for debugging

**Method 2: Manual AWS CLI**

```bash
# List ECS container instances
aws ecs list-container-instances \
  --cluster ha-roy-develeap-dev-cluster

# Get EC2 instance IDs
aws ecs describe-container-instances \
  --cluster ha-roy-develeap-dev-cluster \
  --container-instances <CONTAINER-INSTANCE-ARN> \
  --query 'containerInstances[*].ec2InstanceId'

# Connect via SSM Session Manager (no SSH keys needed)
aws ssm start-session \
  --target <EC2-INSTANCE-ID>
```

**Useful Commands Once Connected:**

```bash
# View running containers
docker ps

# Check container logs
docker logs <container-id>

# Follow container logs in real-time
docker logs -f <container-id>

# Inspect ECS agent config
sudo cat /etc/ecs/ecs.config

# Check ECS agent status
sudo systemctl status ecs

# View ECS agent logs
sudo cat /var/log/ecs/ecs-agent.log

# Monitor system resources
top
htop
df -h

# Restart ECS agent if needed
sudo systemctl restart ecs
```

## Cleanup

### Quick Cleanup (Recommended)

Complete teardown of all resources:

```bash
task destroy
```

This runs all cleanup steps in the correct order.

### Manual Cleanup (Step by Step)

If you prefer manual control:

#### Step 1: Empty Storage Resources

**IMPORTANT**: Must be done first to avoid deletion errors

```bash
cd tasks
./cleanup-storage.sh
```

This empties:
- All ECR repositories (service1, service2, grafana)
- S3 bucket contents

#### Step 2: Destroy Services

```bash
# Destroy Service2 first (depends on Service1 queue)
cd terraform/service2
terraform destroy

# Then destroy Service1
cd ../service1
terraform destroy
```

#### Step 3: Destroy Infrastructure

```bash
cd terraform/infrastructure
terraform destroy
```

This removes:
- ECS cluster and services
- Application Load Balancer
- SQS queue
- S3 bucket
- VPC and networking
- IAM roles
- CloudWatch logs
- SSM parameters

#### Step 4: Delete Terraform Backend

**WARNING**: This is the final step - state will be lost

```bash
cd terraform
./delete-backend.sh
```

### Cleanup Verification

```bash
# Verify ECS resources are gone
aws ecs list-clusters

# Verify S3 buckets are gone
aws s3 ls | grep ha-roy-develeap

# Verify ECR repositories are gone
aws ecr describe-repositories | grep ha-roy-develeap
```

## Available Commands

Full list of Task commands:

### Setup & Deployment
```bash
task setup                  # Complete project setup
task setup:backend          # Create Terraform backend only
task setup:infrastructure   # Deploy infrastructure only
task setup:auth-token       # Create auth token only
```

### Building
```bash
task build:service1         # Build Service1 Docker image
task build:service2         # Build Service2 Docker image
```

### Testing
```bash
task test:service1          # Run Service1 tests
task test:service2          # Run Service2 tests
task test:all               # Run all unit tests
task test:flow              # Run E2E flow test
```

### Deployment
```bash
task deploy:force SERVICE=service1   # Force redeploy service1
task deploy:force SERVICE=service2   # Force redeploy service2
task deploy:force SERVICE=grafana    # Force redeploy grafana
```

### Monitoring
```bash
task info                   # Show endpoints and project info
task status                 # Show ECS service status
task logs:service1          # Tail Service1 logs
task logs:service2          # Tail Service2 logs
```

### Cleanup
```bash
task destroy                # Complete teardown
task destroy:storage        # Empty ECR/S3 only
task destroy:services       # Destroy ECS services only
task destroy:infrastructure # Destroy infrastructure only
task destroy:backend        # Delete Terraform backend
```

### Utilities
```bash
task fmt                    # Format Terraform code
task validate               # Validate Terraform configs
task --list                 # Show all available tasks

# Utility scripts (in tasks/ directory)
./tasks/ssm-connect.sh      # Interactive SSM session to EC2 instances
./tasks/test-flow.sh        # End-to-end integration test
./tasks/create-auth-token-param.sh  # Create/update auth token in SSM
./tasks/cleanup-storage.sh  # Empty ECR and S3 before teardown
```

## Architecture Decisions

### Why ECS with EC2 Launch Type?

- **Cost control** - More cost-effective than Fargate for long-running services
- **Instance control** - Direct access to underlying EC2 instances via SSM
- **Capacity Provider** - ECS-managed scaling of EC2 instances
- **Resource efficiency** - Multiple containers per instance for better utilization
- **Flexibility** - Ability to SSH/SSM into instances for debugging
- **ECS-optimized AMI** - Pre-configured Amazon Linux with Docker and ECS agent

### Why Application Load Balancer?

- **Path-based routing** - `/service1/*`, `/grafana/*`
- **Health checks** - Automatic unhealthy target removal
- **SSL/TLS termination** - Centralized certificate management
- **High availability** - Multi-AZ deployment

### Why SQS for Message Queue?

- **Fully managed** - No infrastructure to manage
- **Reliable** - Message durability and delivery guarantees
- **Scalable** - Handles any message volume
- **Decoupling** - Services operate independently

### Why SSM Parameter Store?

- **Secure** - Encrypted at rest with KMS (SecureString for passwords)
- **Versioned** - Parameter history tracking
- **IAM integrated** - Fine-grained access control
- **No cost** - Standard parameters are free
- **Decoupled deployments** - Separates image building from deployment
  - Build once, deploy many times
  - Easy rollbacks by changing parameter value
  - Deploy different versions to different environments
  - Terraform reads current version dynamically
- **Single source of truth** - All deployment configs in one place

### Why Repository Dispatch?

- **Event-driven** - Flexible triggering mechanism
- **Decoupled** - CI and CD pipelines are independent
- **Payload flexibility** - Rich metadata passing
- **Cross-repository** - Can trigger workflows in other repos

### CI/CD Design Decisions

1. **Path-based change detection** - Only build/deploy changed services
2. **Matrix builds** - Parallel execution for speed
3. **Repository dispatch over workflow_dispatch** - More flexible for automation
4. **Separate CI/CD pipelines** - Independent testing and deployment
5. **Terraform for deployment** - Infrastructure as Code consistency

## Future Enhancements

Items that would improve this solution:

### Infrastructure
- **Better instance types** - t3.small instead of t2.micro to prevent resource constraints from blocking new task versions
- **Multi-region deployment** - Cross-region replication for disaster recovery
- **Auto Scaling policies** - Scale based on CPU/memory metrics instead of just capacity

### Security
- **WAF** - Web Application Firewall for ALB
- **HTTPS for ALB** - Configure SSL/TLS certificate via ACM, enforce HTTPS redirect, add to Route53 public hosted zone as alias record or add as CNAME record to domain purchased from 3rd party domain provider
- **Network ACLs** - Additional network layer security

### Monitoring
- **Custom business metrics** - Application-level KPIs (messages processed, processing time, error rates, queue depth trends) emitted to CloudWatch for operational insights
- **CI/CD pipeline monitoring** - Build success rates, deployment frequency, lead time for changes, MTTR

### Application
- **Event-driven Service2 (Option 1: Lambda)** - Replace with Lambda function using SQS event source mapping (auto-scales, auto-deletes, built-in retry/DLQ)
- **Event-driven Service2 (Option 2: EventBridge Pipes + ECS RunTask)** - Remove Service2 ECS service and polling loop; EventBridge Pipe is triggered by mesage entering the SQS queue and and target is an an Service2 ECS task with message as input via containerOverrides environment variables or it reads message from the queue 
- **Event-driven Service2 (Option 3: EventBridge Pipes + ECS RunTask)** - Expose a API endpoint for Service2 via VPC latice  refactor the source code to run a app that has an API webnook insteaed of the polling loop; EventBridge Pipe is triggeed by a message entering the SQS queue and the target is an API destination of the VPC lattice service with with a resoucee gateway depeloyed into the vpc to give the Eventbridge pipe access to it. The pipe sends a webhook to read messages from the queue 
- **DLQ with redrive** - Dead Letter Queue for failed messages with redrive policy to move messages back to source queue after fixing issues
- **SQS batch actions** - Use ReceiveMessageBatch, DeleteMessageBatch, and ChangeMessageVisibilityBatch for better throughput in current polling implementation
- **Visibility timeout tuning** - Adjust message visibility timeout based on processing time to prevent duplicate processing
- **Message delay configuration** - Use delay queues or per-message delay for retry backoff strategies
- **Idempotency** - Prevent duplicate processing using message deduplication ID (FIFO queues) or application-level idempotency keys

### DevOps
- **Environment promotion** - Expand pipelines to promote builds between environments (dev → staging → prod)
- **Zero-downtime deployment strategy** - Blue/Green deployment and Canary releases
- **Automated rollback** - Detect and revert failures (requires custom business metrics)
- **Environment parity** - Use same IaC modules and Docker images across dev/staging/prod with environment-specific scaling via Terraform variables (e.g., dev: 1 instance, prod: 10 instances)

## Troubleshooting

### Services not starting

```bash
# Check ECS service events
aws ecs describe-services \
  --cluster ha-roy-develeap-dev-cluster \
  --services ha-roy-develeap-dev-service1 \
  --profile checkpoint

# Check task definition
aws ecs describe-task-definition \
  --task-definition ha-roy-develeap-dev-service1 \
  --profile checkpoint

# Check CloudWatch logs
task logs:service1
```

### Authentication failures

```bash
# Verify token exists in SSM
aws ssm get-parameter \
  --name /ha-roy-develeap/dev/service1/auth-token \
  --with-decryption

# Recreate token if needed
cd tasks
./create-auth-token-param.sh
```

### Messages not processing

```bash
# Check SQS queue depth
aws sqs get-queue-attributes \
  --queue-url <QUEUE-URL> \
  --attribute-names All

# Check Service2 logs
task logs:service2

# Verify S3 bucket permissions
aws s3 ls s3://ha-roy-develeap-dev-storage/
```

### Wrong version deployed

```bash
# Check current image tag in SSM
aws ssm get-parameter \
  --name /ha-roy-develeap/dev/service1/image-tag \
  --query 'Parameter.Value' \
  --output text

# Check running task definition
aws ecs describe-services \
  --cluster ha-roy-develeap-dev-cluster \
  --services ha-roy-develeap-dev-service1 \
  --query 'services[0].taskDefinition'

# View task definition details
aws ecs describe-task-definition \
  --task-definition <TASK-DEF-ARN> \
  --query 'taskDefinition.containerDefinitions[0].image'

# List available git tags
git tag -l "service1-v*"

# Update SSM to desired version and redeploy
aws ssm put-parameter \
  --name /ha-roy-develeap/dev/service1/image-tag \
  --value "1.2.3" \
  --overwrite

gh workflow run cd-pipeline.yaml -f services=service1
```

## Contributing

This is a home assignment project. For questions or issues, please contact the maintainer.

## License

This project is created for evaluation purposes.
