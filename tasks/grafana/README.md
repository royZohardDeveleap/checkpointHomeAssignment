# Grafana Monitoring Setup

This directory contains a custom Grafana Docker image configured for monitoring your ECS cluster, SQS queues, and services using CloudWatch as a datasource.

## Features

- **Pre-configured CloudWatch datasource** - Uses IAM role authentication (no credentials needed)
- **Pre-built dashboards** for:
  - ECS Cluster Overview (CPU, Memory, Task counts)
  - SQS Queue Monitoring (Message counts, age, throughput)
  - ECS Services (Service-level metrics, ALB metrics)
- **Ready for GitHub Insights** - Can easily add additional datasources later
- **Auto-provisioning** - Dashboards and datasources are automatically configured on startup

## Directory Structure

```
grafana/
├── Dockerfile                          # Custom Grafana image
├── provisioning/
│   ├── datasources/
│   │   └── cloudwatch.yml             # CloudWatch datasource config
│   └── dashboards/
│       └── default.yml                # Dashboard provisioning config
└── dashboards/
    ├── ecs-cluster-overview.json      # ECS cluster metrics
    ├── ecs-services.json              # Service-level metrics
    └── sqs-monitoring.json            # SQS queue metrics
```

## Building the Docker Image

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform infrastructure deployed
3. ECR repository created (done by Terraform)

### Build and Push

```bash
# Navigate to the grafana directory
cd grafana

# Get your AWS account ID and region from Terraform outputs
AWS_ACCOUNT_ID=$(cd ../terraform && terraform output -raw aws_account_id)
AWS_REGION="us-east-1"
ECR_REPO=$(cd ../terraform && terraform output -raw ecr_grafana_repository_url)

# Authenticate Docker to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build the image
docker build -t grafana-cloudwatch .

# Tag the image
docker tag grafana-cloudwatch:latest $ECR_REPO:latest

# Push to ECR
docker push $ECR_REPO:latest
```

## Accessing Grafana

After the ECS service is deployed:

```bash
# Get the Grafana URL from Terraform outputs
cd terraform
terraform output grafana_url
```

**Default credentials:**
- Username: `admin`
- Password: `admin` (you should change this after first login)

## Pre-configured Dashboards

### 1. ECS Cluster Overview
- **Location:** Dashboards → ECS Cluster Overview
- **Metrics:**
  - Cluster CPU Utilization
  - Cluster Memory Utilization
  - Running Tasks Count
  - Service Count
  - Container Instance Count

### 2. SQS Queue Monitoring
- **Location:** Dashboards → SQS Queue Monitoring
- **Metrics:**
  - Messages Visible (in queue)
  - Messages In Flight (being processed)
  - Messages Sent/Received/Deleted
  - Oldest Message Age

### 3. ECS Services Monitoring
- **Location:** Dashboards → ECS Services Monitoring
- **Metrics:**
  - Service 1 & 2 CPU/Memory Utilization
  - ALB Target Response Time
  - ALB Request Count

## Customizing Dashboards

The dashboards use template variables that are pre-configured with your resource names:

- `cluster_name`: `devops-practice-dev-cluster`
- `queue_name`: `devops-practice-dev-queue`
- `service1_name`: `devops-practice-dev-service1`
- `service2_name`: `devops-practice-dev-service2`

If you change your project name or environment in Terraform variables, update these values in the dashboard JSON files before building the image.

## Adding GitHub Insights Datasource (Future)

To add GitHub as a datasource later:

1. Install the GitHub datasource plugin by adding to `Dockerfile`:
   ```dockerfile
   RUN grafana-cli plugins install grafana-github-datasource
   ```

2. Create a new provisioning file:
   ```yaml
   # provisioning/datasources/github.yml
   apiVersion: 1
   datasources:
     - name: GitHub
       type: grafana-github-datasource
       access: proxy
       jsonData:
         githubUrl: https://api.github.com
       secureJsonData:
         accessToken: ${GITHUB_TOKEN}
   ```

3. Pass the GitHub token as an environment variable in the ECS task definition

## IAM Permissions

The Grafana task role has the following CloudWatch permissions:

- **CloudWatch Metrics:** Read access to all metrics
- **CloudWatch Logs:** Query and read log groups
- **EC2/Tags:** Describe resources for dimension filtering

These permissions are configured in `terraform/grafana.tf`

## Troubleshooting

### Dashboards not showing data

1. Check that Container Insights is enabled on your ECS cluster
2. Verify the cluster/service names match in the dashboard variables
3. Ensure the Grafana task role has CloudWatch read permissions
4. Check CloudWatch Logs for Grafana container errors:
   ```bash
   aws logs tail /ecs/devops-practice-dev/grafana --follow
   ```

### Cannot access Grafana UI

1. Check the ALB listener rule is configured for `/grafana*`
2. Verify the ECS service is running:
   ```bash
   aws ecs describe-services --cluster devops-practice-dev-cluster \
     --services devops-practice-dev-grafana
   ```
3. Check target group health:
   ```bash
   aws elbv2 describe-target-health --target-group-arn <grafana-tg-arn>
   ```

## Updating Dashboards

To update dashboards after deployment:

1. Edit the JSON files in `dashboards/`
2. Rebuild and push the Docker image
3. Force a new deployment in ECS:
   ```bash
   aws ecs update-service --cluster devops-practice-dev-cluster \
     --service devops-practice-dev-grafana --force-new-deployment
   ```

## Cost Considerations

- **Container Insights:** ~$5-15/month for metrics and logs
- **CloudWatch API calls:** Grafana queries CloudWatch, minimal cost (~$1-5/month)
- **ECS task:** Uses existing t2.micro instance (no additional cost)
- **Total estimated:** ~$6-20/month additional for monitoring

## Security Notes

- Default admin password is `admin` - **change this immediately after first login**
- Grafana is exposed via HTTP through the ALB - consider adding HTTPS
- The ALB is public - consider restricting access via security groups or WAF
- Consider using AWS Secrets Manager for the admin password instead of hardcoding
