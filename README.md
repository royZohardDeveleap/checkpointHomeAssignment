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
           │                  │
           ▼                  ▼
    ┌────────────────────────────┐
    │      SQS Queue             │
    │  (Message Broker)          │
    └────────────────────────────┘
                     │
                     ▼
              ┌────────────┐
              │ S3 Bucket  │
              │  (Storage) │
              └────────────┘
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
│   ├── build-grafana.yaml      # Grafana build workflow
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
│   ├── setup-backend.sh      # Create Terraform state backend
│   └── delete-backend.sh     # Delete Terraform state backend
│
├── Taskfile.yml              # Task automation (similar to Makefile)
├── Steps                     # Quick reference guide
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
2. **AWS Profile** configured:
   ```bash
   aws configure --profile checkpoint
   # Enter your AWS credentials
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
# Install Task runner if you haven't already
brew install go-task/tap/go-task  # macOS
# or
sudo snap install task --classic  # Linux

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
- Application Load Balancer with target groups
- SQS queue
- S3 bucket for message storage
- 3 ECR repositories (service1, service2, grafana)
- CloudWatch log groups
- IAM roles (EC2 instance role + task execution role) and policies
- Security groups for ALB and ECS instances

### Step 3: Create Authentication Token

Create a secure authentication token in SSM Parameter Store:

```bash
cd tasks
./create-auth-token-param.sh
```

You'll be prompted to enter a token (or it will generate one). This token is used by Service1 for request authentication.

### Step 4: Build and Push Docker Images (CI Pipeline)

The CI pipeline automatically:
- Detects changed services
- Runs unit tests (on PRs)
- Builds Docker images
- Pushes to ECR
- Tags images with git SHA
- Triggers CD pipeline

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
- **Automated tagging** - Git SHA-based image tags
- **Repository dispatch** - Triggers CD pipeline automatically
- **Matrix builds** - Builds multiple services in parallel

### CD Pipeline Features

- **Dual triggers** - `repository_dispatch` (automated) + `workflow_dispatch` (manual)
- **Service selection** - Deploy specific services or all
- **Terraform-based** - Infrastructure as Code deployment
- **Health checks** - Waits for ECS service stability
- **Rollback ready** - Previous task definitions retained

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

**4. Pull Request (Tests Only)**
```bash
git checkout -b feature/new-feature
git push origin feature/new-feature
# Create PR - triggers tests only, no builds
```

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
  --profile checkpoint \
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
  --queue-url $(aws sqs get-queue-url --queue-name ha-roy-develeap-dev-queue --profile checkpoint --query 'QueueUrl' --output text) \
  --attribute-names ApproximateNumberOfMessages \
  --profile checkpoint

# List S3 objects
aws s3 ls s3://ha-roy-develeap-dev-storage/ --recursive --profile checkpoint
```

## Monitoring

### Grafana Dashboards

Access Grafana at: `http://<ALB-DNS>/grafana`

**Default credentials**: `admin` / `admin` (change on first login)

**Available Dashboards**:
- **System Overview** - ECS cluster metrics, task counts, resource utilization
- **Service Metrics** - Per-service CPU, memory, network stats
- **Queue Monitoring** - SQS message counts and processing rates

### CloudWatch Logs

View service logs:

```bash
# Stream Service1 logs
task logs:service1

# Stream Service2 logs
task logs:service2

# View logs in AWS Console
aws logs tail /ecs/ha-roy-develeap-dev/service1 --follow --profile checkpoint
```

### Service Status

```bash
# Check ECS service status
task status

# Get detailed service info
aws ecs describe-services \
  --cluster ha-roy-develeap-dev-cluster \
  --services ha-roy-develeap-dev-service1 ha-roy-develeap-dev-service2 \
  --profile checkpoint
```

### EC2 Instance Access

Since this uses EC2 launch type, you can connect to the container instances:

```bash
# List ECS container instances
aws ecs list-container-instances \
  --cluster ha-roy-develeap-dev-cluster \
  --profile checkpoint

# Get EC2 instance IDs
aws ecs describe-container-instances \
  --cluster ha-roy-develeap-dev-cluster \
  --container-instances <CONTAINER-INSTANCE-ARN> \
  --profile checkpoint \
  --query 'containerInstances[*].ec2InstanceId'

# Connect via SSM Session Manager (no SSH keys needed)
aws ssm start-session \
  --target <EC2-INSTANCE-ID> \
  --profile checkpoint

# Once connected, you can:
# - View running containers: docker ps
# - Check container logs: docker logs <container-id>
# - Inspect ECS agent: cat /etc/ecs/ecs.config
# - Monitor resources: top, htop
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
aws ecs list-clusters --profile checkpoint

# Verify S3 buckets are gone
aws s3 ls --profile checkpoint | grep ha-roy-develeap

# Verify ECR repositories are gone
aws ecr describe-repositories --profile checkpoint | grep ha-roy-develeap
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

- **Secure** - Encrypted at rest with KMS
- **Versioned** - Parameter history tracking
- **IAM integrated** - Fine-grained access control
- **No cost** - Standard parameters are free

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
- **Better instance types** - t3.small instead of t3.micro to avoid resource constraints
- **NAT Gateway** - Outbound internet access for private subnets (currently using IGW only)
- **VPC Endpoints** - ECR, S3, CloudWatch endpoints to reduce data transfer costs
- **Multi-region deployment** - Cross-region replication for disaster recovery

### Security
- **WAF** - Web Application Firewall for ALB
- **Secrets rotation** - Automated credential rotation
- **KMS encryption** - Customer-managed encryption keys
- **Network isolation** - Private subnets for services

### Monitoring
- **CloudWatch Dashboards** - Native AWS monitoring
- **CloudWatch Alarms** - Automated alerting
- **X-Ray tracing** - Distributed request tracing
- **Metrics enrichment** - Custom business metrics

### Application
- **Event-driven Service2** - SQS event source instead of polling
- **DLQ** - Dead Letter Queue for failed messages
- **Message batching** - Process multiple messages at once
- **Idempotency** - Prevent duplicate processing

### DevOps
- **Blue/Green deployment** - Zero-downtime deployments
- **Canary releases** - Gradual rollout strategy
- **Automated rollback** - Detect and revert failures
- **Environment parity** - Dev/Staging/Prod consistency

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
  --with-decryption \
  --profile checkpoint

# Recreate token if needed
cd tasks
./create-auth-token-param.sh
```

### Messages not processing

```bash
# Check SQS queue depth
aws sqs get-queue-attributes \
  --queue-url <QUEUE-URL> \
  --attribute-names All \
  --profile checkpoint

# Check Service2 logs
task logs:service2

# Verify S3 bucket permissions
aws s3 ls s3://ha-roy-develeap-dev-storage/ --profile checkpoint
```

## Contributing

This is a home assignment project. For questions or issues, please contact the maintainer.

## License

This project is created for evaluation purposes.
