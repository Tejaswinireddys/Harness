# Multi-Cluster Deployment Scripts

This directory contains all scripts needed for demonstrating and managing multi-cluster ECS deployments with Harness CD.

## 📋 Scripts Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| **demo.sh** | Interactive demo walkthrough | `./demo.sh` |
| **verify-infrastructure.sh** | Verify AWS resources ready | `./verify-infrastructure.sh` |
| **build-and-push.sh** | Build and push Docker image | `./build-and-push.sh <version>` |
| **health-check.sh** | Check ECS service health | `./health-check.sh <cluster> <region> [alb-dns]` |
| **rollback.sh** | Rollback to previous version | `./rollback.sh <cluster> <region> [revision]` |

## 🚀 Quick Start

### 1. Setup

Make all scripts executable:
```bash
chmod +x *.sh
```

Configure environment variables (optional):
```bash
export AWS_ACCOUNT_ID="123456789012"
export PROD_CLUSTER="prod-cluster"
export PROD_REGION="us-east-1"
export ANALYTICS_CLUSTER="analytics-cluster"
export ANALYTICS_REGION="us-west-2"
```

### 2. Verify Infrastructure

Run the verification script to check all AWS resources:
```bash
./verify-infrastructure.sh
```

This will check:
- AWS CLI configuration
- ECR repository
- ECS clusters (both regions)
- IAM roles
- Harness delegates
- Docker installation

### 3. Run the Demo

Execute the interactive demo script:
```bash
./demo.sh
```

The demo will guide you through:
1. Viewing current deployment state
2. Building and pushing a new version
3. Triggering Harness pipeline
4. Verifying deployment
5. (Optional) Rollback demonstration

## 📖 Detailed Script Documentation

### demo.sh

**Purpose**: Interactive demo walkthrough for multi-cluster deployment

**Usage**:
```bash
./demo.sh
```

**Features**:
- Step-by-step guided demo
- Shows current state
- Builds and pushes new version
- Monitors deployment
- Verifies both clusters
- Optional rollback demo

**Environment Variables**:
- `PROD_CLUSTER` - Production cluster name (default: prod-cluster)
- `PROD_REGION` - Production region (default: us-east-1)
- `ANALYTICS_CLUSTER` - Analytics cluster name (default: analytics-cluster)
- `ANALYTICS_REGION` - Analytics region (default: us-west-2)

---

### verify-infrastructure.sh

**Purpose**: Verify all AWS infrastructure is ready for deployment

**Usage**:
```bash
./verify-infrastructure.sh
```

**Checks**:
1. ✅ AWS CLI configuration and credentials
2. ✅ ECR repository exists and has images
3. ✅ Production ECS cluster and service
4. ✅ Analytics ECS cluster and service
5. ✅ IAM roles (execution and task roles)
6. ✅ Harness delegates (if kubectl available)
7. ✅ Docker daemon
8. ✅ Additional tools (jq, curl)

**Exit Codes**:
- `0` - All checks passed
- `1` - One or more critical checks failed

---

### build-and-push.sh

**Purpose**: Build Docker image and push to Amazon ECR

**Usage**:
```bash
./build-and-push.sh <version-tag>

# Examples:
./build-and-push.sh v1.0.0
./build-and-push.sh $(git rev-parse --short HEAD)
./build-and-push.sh latest
```

**Parameters**:
- `<version-tag>` - Version tag for the image (optional, defaults to git commit hash)

**Environment Variables**:
- `AWS_ACCOUNT_ID` - AWS account ID (default: 123456789012)
- `AWS_REGION` - AWS region for ECR (default: us-east-1)
- `SERVICE_NAME` - Service name (default: notification-service)

**What it does**:
1. Creates sample Dockerfile if not present
2. Builds Docker image
3. Tags for ECR (with version and latest)
4. Authenticates with ECR
5. Pushes both tags to ECR
6. Displays image URI and digest

**Requirements**:
- Docker installed and running
- AWS CLI configured
- ECR repository created

---

### health-check.sh

**Purpose**: Comprehensive health check for ECS service

**Usage**:
```bash
./health-check.sh <cluster-name> <region> [alb-dns]

# Examples:
./health-check.sh prod-cluster us-east-1
./health-check.sh prod-cluster us-east-1 prod-alb.example.com
./health-check.sh analytics-cluster us-west-2
```

**Parameters**:
- `<cluster-name>` - ECS cluster name
- `<region>` - AWS region
- `[alb-dns]` - (Optional) ALB DNS for HTTP health checks

**Checks Performed**:
1. ✅ Service status (ACTIVE)
2. ✅ Task count (running vs desired)
3. ✅ Individual task health
4. ✅ Current task definition and image
5. ✅ ALB target group health
6. ✅ HTTP health endpoint (if ALB provided)
7. ✅ Recent deployment events

**Exit Codes**:
- `0` - All health checks passed
- `1` - Critical health check failed

**Example Output**:
```
========================================
Health Check: notification-service
Cluster: prod-cluster (us-east-1)
========================================

Check 1: Service Status
✓ Service status: ACTIVE

Check 2: Task Count
Running tasks: 3/3
✓ Tasks running: 3

Check 3: Task Health
✓ Task abc12345: HEALTHY / RUNNING
✓ Task def67890: HEALTHY / RUNNING
✓ Task ghi12345: HEALTHY / RUNNING

✓ ALL HEALTH CHECKS PASSED
```

---

### rollback.sh

**Purpose**: Rollback ECS service to previous task definition

**Usage**:
```bash
./rollback.sh <cluster-name> <region> [revision-number]

# Examples:
./rollback.sh prod-cluster us-east-1              # Roll back to previous revision
./rollback.sh prod-cluster us-east-1 145          # Roll back to specific revision
./rollback.sh analytics-cluster us-west-2
```

**Parameters**:
- `<cluster-name>` - ECS cluster name
- `<region>` - AWS region
- `[revision-number]` - (Optional) Specific revision to rollback to

**What it does**:
1. Gets current task definition
2. Determines target revision (previous or specified)
3. Validates target revision exists
4. Prompts for confirmation
5. Updates service to target revision
6. Waits for deployment to stabilize (max 10 minutes)
7. Verifies rollback succeeded
8. Runs health check

**Safety Features**:
- Confirmation prompt before rollback
- Validates target revision exists
- Shows current and target images
- Automatic health check after rollback

**Example Output**:
```
========================================
Rollback: notification-service
Cluster: prod-cluster (us-east-1)
========================================

Step 1: Getting current deployment info...
Current task definition: notification-service-prod:150
Task family: notification-service-prod
Current revision: 150
Current image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/notification-service:v1.3.0

Rolling back to previous revision: 149

Step 2: Validating target revision...
✓ Target task definition exists
Target image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/notification-service:v1.2.9

ROLLBACK CONFIRMATION
Cluster: prod-cluster
Region: us-east-1
Service: notification-service

Current: notification-service-prod:150
  Image: .../:v1.3.0

Target:  notification-service-prod:149
  Image: .../:v1.2.9

Continue with rollback? (yes/no): yes

✓ ROLLBACK COMPLETE
```

---

## 🔧 Configuration

### Environment Variables

Set these before running scripts (optional):

```bash
# AWS Configuration
export AWS_ACCOUNT_ID="123456789012"
export AWS_REGION="us-east-1"

# Production Cluster
export PROD_CLUSTER="prod-cluster"
export PROD_REGION="us-east-1"
export PROD_ALB="prod-alb-123.us-east-1.elb.amazonaws.com"

# Analytics Cluster
export ANALYTICS_CLUSTER="analytics-cluster"
export ANALYTICS_REGION="us-west-2"
export ANALYTICS_ALB="analytics-alb-456.us-west-2.elb.amazonaws.com"

# Service
export SERVICE_NAME="notification-service"
export ECR_REPO_NAME="notification-service"
```

### AWS CLI Configuration

Ensure AWS CLI is configured with appropriate credentials:

```bash
# Configure AWS CLI
aws configure

# Or use AWS SSO
aws sso login --profile your-profile

# Verify credentials
aws sts get-caller-identity
```

## 📝 Common Workflows

### Complete Deployment Workflow

```bash
# 1. Verify infrastructure
./verify-infrastructure.sh

# 2. Build and push new version
./build-and-push.sh v1.3.0

# 3. Trigger Harness pipeline (via UI or API)
# Navigate to Harness UI and run pipeline with tag: v1.3.0

# 4. Monitor deployment in Harness UI (20-25 minutes)

# 5. Verify both clusters
./health-check.sh prod-cluster us-east-1
./health-check.sh analytics-cluster us-west-2
```

### Emergency Rollback Workflow

```bash
# 1. Check current status
./health-check.sh prod-cluster us-east-1

# 2. Rollback production
./rollback.sh prod-cluster us-east-1

# 3. Verify production rollback
./health-check.sh prod-cluster us-east-1

# 4. Rollback analytics
./rollback.sh analytics-cluster us-west-2

# 5. Verify analytics rollback
./health-check.sh analytics-cluster us-west-2
```

### Daily Health Check Workflow

```bash
# Quick health check for both clusters
./health-check.sh prod-cluster us-east-1 prod-alb.example.com
./health-check.sh analytics-cluster us-west-2 analytics-alb.example.com
```

## 🐛 Troubleshooting

### Script Permissions

If you get "Permission denied":
```bash
chmod +x *.sh
```

### AWS Credentials

If you get "Unable to locate credentials":
```bash
# Check AWS configuration
aws configure list

# Re-configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

### ECR Authentication

If Docker push fails:
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com
```

### Cluster Not Found

If cluster doesn't exist:
```bash
# Create cluster
aws ecs create-cluster --cluster-name prod-cluster --region us-east-1
```

### Service Not Responding

If health checks fail:
```bash
# Check service status
aws ecs describe-services \
  --cluster prod-cluster \
  --services notification-service \
  --region us-east-1

# Check task logs
aws logs tail /ecs/notification-service-prod --follow

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <your-tg-arn> \
  --region us-east-1
```

## 📚 Additional Resources

- [Main Documentation](../MULTI_CLUSTER_DEPLOYMENT_GUIDE.md) - Complete deployment guide
- [Harness Documentation](https://developer.harness.io/docs/continuous-delivery)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Docker Documentation](https://docs.docker.com/)

## 🤝 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the main deployment guide
3. Contact the DevOps team

## 📄 License

Internal use only - Company confidential

---

**Version**: 1.0
**Last Updated**: January 10, 2026
**Maintained by**: DevOps Team
