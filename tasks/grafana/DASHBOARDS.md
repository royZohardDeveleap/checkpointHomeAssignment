# Grafana Dashboard Reference

This document describes the pre-configured dashboard and available metrics.

## Dashboard: System Overview

**File:** `dashboards/system-overview.json`
**UID:** `system-overview`
**Refresh Rate:** 30 seconds

A comprehensive single-page dashboard that provides complete visibility into the entire system.

---

## Dashboard Layout

### Row 1: Cluster Overview (Top)
- **Cluster CPU Utilization** - Average CPU across all services
- **Cluster Memory Utilization** - Average memory across all services
- **Running Tasks** - Total number of running tasks (with alert if 0)

### Row 2-3: Service Metrics
- **Service 1 CPU** - REST API service CPU usage
- **Service 1 Memory** - REST API service memory usage
- **Service 2 CPU** - SQS processor service CPU usage
- **Service 2 Memory** - SQS processor service memory usage

### Row 4: SQS Queue Metrics
- **Messages Visible** - Messages waiting to be processed
- **Messages In Flight** - Messages currently being processed
- **Oldest Message Age** - How long the oldest message has been waiting (with alert if > 5 minutes)

### Row 5: ALB Metrics
- **Request Count** - Number of HTTP requests to Service 1
- **Target Response Time** - API response latency

---

## CloudWatch Metrics Used

### ECS Metrics (AWS/ECS namespace)
- `CPUUtilization` - Percentage of CPU used (cluster and service level)
- `MemoryUtilization` - Percentage of memory used (cluster and service level)

### ECS Container Insights (ECS/ContainerInsights namespace)
- `RunningTaskCount` - Number of running tasks
- **Note:** Only available if Container Insights is enabled

### SQS Metrics (AWS/SQS namespace)
- `ApproximateNumberOfMessagesVisible` - Messages in queue
- `ApproximateNumberOfMessagesNotVisible` - Messages being processed
- `ApproximateAgeOfOldestMessage` - Age of oldest message in seconds

### ALB Metrics (AWS/ApplicationELB namespace)
- `RequestCount` - Total number of requests
- `TargetResponseTime` - Average response time in seconds

---

## Dashboard Variables

The dashboard uses template variables that match your resource names:

```
cluster_name: checkpoint-home-assignment-royzohar-dev-cluster
queue_name: checkpoint-home-assignment-royzohar-dev-queue
service1_name: checkpoint-home-assignment-royzohar-dev-service1
service2_name: checkpoint-home-assignment-royzohar-dev-service2
```

**Note:** If you change your project name or environment in Terraform, update these values in `system-overview.json`.

---

## Built-in Alerts

### SQS Message Age Alert
- **Condition:** Oldest message age > 300 seconds (5 minutes)
- **Action:** Notification that messages are stuck in queue
- **Purpose:** Detect when Service 2 is not processing messages

### Running Tasks Alert (Visual)
- **Condition:** Running tasks = 0
- **Visual:** Panel turns red
- **Purpose:** Indicate when all tasks have stopped

---

## Accessing the Dashboard

After Grafana is deployed:

1. Get the ALB URL:
   ```bash
   cd terraform/infrastructure
   terraform output alb_dns_name
   ```

2. Access Grafana at: `http://<alb-dns>/grafana`

3. Login with:
   - **Username:** `admin`
   - **Password:** `admin123` (change after first login)

4. Navigate to: **Dashboards → System Overview**

---

## Customizing the Dashboard

### Update Resource Names

Edit `dashboards/system-overview.json` and update the `templating.list` section:

```json
{
  "name": "cluster_name",
  "current": {
    "value": "your-new-cluster-name"
  }
}
```

### Add New Panels

1. Open the dashboard in Grafana UI
2. Click **Add Panel** → **Add a new panel**
3. Configure CloudWatch query:
   - Select datasource: **CloudWatch**
   - Choose namespace (AWS/ECS, AWS/SQS, etc.)
   - Select metric and dimensions
4. Save the dashboard
5. Export JSON: **Dashboard settings → JSON Model**
6. Replace `dashboards/system-overview.json`
7. Rebuild and redeploy Grafana

### Adjust Time Ranges

Use the time picker in the top-right corner:
- Last 5 minutes
- Last 15 minutes
- Last 1 hour
- Custom range

---

## Adding GitHub Actions Monitoring (Future)

To monitor CI/CD pipelines, add GitHub datasource:

1. **Install GitHub plugin** in `Dockerfile`:
   ```dockerfile
   RUN grafana-cli plugins install grafana-github-datasource
   ```

2. **Create datasource config** `provisioning/datasources/github.yml`:
   ```yaml
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

3. **Add to ECS task definition** environment variables:
   ```hcl
   environment = [
     { name = "GITHUB_TOKEN", value = var.github_token }
   ]
   ```

4. **Create CI/CD panels** tracking:
   - Build success/failure rates
   - Deployment frequency
   - Build duration trends
   - Failed pipeline alerts

---

## Importing Community Dashboards

You can import pre-built dashboards from Grafana.com:

### Recommended Dashboards:
- **ID 551** - AWS ECS Cluster Monitoring
- **ID 584** - AWS SQS Monitoring
- **ID 11099** - AWS CloudWatch Overview

**To import:**
1. Dashboards → Import
2. Enter dashboard ID
3. Select **CloudWatch** datasource
4. Click **Import**

---

## Troubleshooting

### No Data in Panels

**Check Container Insights:**
```bash
aws ecs describe-clusters --clusters <cluster-name> --include SETTINGS
```

If Container Insights is disabled, some metrics won't be available (RunningTaskCount, ServiceCount).

**Verify resources are running:**
```bash
aws ecs list-services --cluster <cluster-name>
aws sqs get-queue-attributes --queue-url <queue-url> --attribute-names All
```

**CloudWatch metric delay:** Metrics can take 1-5 minutes to appear.

### Permissions Errors

Check Grafana task role has CloudWatch permissions:
```bash
aws iam get-role-policy --role-name <grafana-task-role> --policy-name grafana-cloudwatch-policy
```

Check logs:
```bash
aws logs tail /ecs/checkpoint-home-assignment-royzohar-dev/grafana --follow
```

### Wrong Resource Names

Update variables in `system-overview.json` to match your actual resource names from Terraform outputs.

---

## Metrics Not Requiring Container Insights

These metrics work **without** Container Insights (free tier):

✅ ECS service CPU/Memory utilization
✅ All SQS metrics
✅ All ALB metrics
✅ CloudWatch Logs

These require Container Insights (paid):

❌ RunningTaskCount
❌ ServiceCount
❌ ContainerInstanceCount
❌ Task-level metrics

If Container Insights is disabled, the **Running Tasks** panel will show no data. You can remove this panel or replace it with a CloudWatch Logs Insights query.
