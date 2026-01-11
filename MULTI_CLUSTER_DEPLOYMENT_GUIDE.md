# Multi-Cluster ECS Deployment - Complete Guide

> **Demo-Ready: Deploy Common Container to Multiple ECS Clusters**
> **Use Case**: Deploy notification-service to both Production and Analytics clusters

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Infrastructure Setup](#3-infrastructure-setup)
4. [Harness Configuration](#4-harness-configuration)
5. [Pipeline Implementation](#5-pipeline-implementation)
6. [Deployment Scripts](#6-deployment-scripts)
7. [Demo Walkthrough](#7-demo-walkthrough)
8. [Testing & Verification](#8-testing--verification)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Architecture Overview

### Scenario

**Cluster 1 (Production Cluster)**: us-east-1
- `frontend-service` (Port 3000)
- `backend-service` (Port 8080)
- `auth-service` (Port 8081)
- `payment-service` (Port 8082)
- `notification-service` (Port 8083) ← **COMMON**

**Cluster 2 (Analytics Cluster)**: us-west-2
- `analytics-service` (Port 9000)
- `reporting-service` (Port 9001)
- `notification-service` (Port 8083) ← **COMMON**

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS CLOUD                                │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Region: us-east-1 (Production)                          │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  ECS Cluster: prod-cluster                         │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌──────────────┐  ┌──────────────┐               │  │  │
│  │  │  │  frontend    │  │  backend     │               │  │  │
│  │  │  │  :3000       │  │  :8080       │               │  │  │
│  │  │  └──────────────┘  └──────────────┘               │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌──────────────┐  ┌──────────────┐               │  │  │
│  │  │  │  auth        │  │  payment     │               │  │  │
│  │  │  │  :8081       │  │  :8082       │               │  │  │
│  │  │  └──────────────┘  └──────────────┘               │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌─────────────────────────────────┐               │  │  │
│  │  │  │  notification-service           │ ◄─────────────┼──┼──┼─┐
│  │  │  │  :8083                          │               │  │  │ │
│  │  │  │  (COMMON - Deploy to Both)      │               │  │  │ │
│  │  │  └─────────────────────────────────┘               │  │  │ │
│  │  └─────────────────────────────────────────────────────┘  │  │ │
│  │                                                            │  │ │
│  │  ALB: prod-alb.example.com                                │  │ │
│  └────────────────────────────────────────────────────────────┘  │ │
│                                                                  │ │
│  ┌──────────────────────────────────────────────────────────┐  │ │
│  │  Region: us-west-2 (Analytics)                           │  │ │
│  │  ┌────────────────────────────────────────────────────┐  │  │ │
│  │  │  ECS Cluster: analytics-cluster                    │  │  │ │
│  │  │                                                     │  │  │ │
│  │  │  ┌──────────────┐  ┌──────────────┐               │  │  │ │
│  │  │  │  analytics   │  │  reporting   │               │  │  │ │
│  │  │  │  :9000       │  │  :9001       │               │  │  │ │
│  │  │  └──────────────┘  └──────────────┘               │  │  │ │
│  │  │                                                     │  │  │ │
│  │  │  ┌─────────────────────────────────┐               │  │  │ │
│  │  │  │  notification-service           │ ◄─────────────┼──┼──┼─┘
│  │  │  │  :8083                          │               │  │  │
│  │  │  │  (COMMON - Deploy to Both)      │               │  │  │
│  │  │  └─────────────────────────────────┘               │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                            │  │
│  │  ALB: analytics-alb.example.com                            │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ECR: us-east-1                                          │  │
│  │  • 123456789012.dkr.ecr.us-east-1.amazonaws.com          │  │
│  │    /notification-service:v1.2.3                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

                                ▲
                                │
                                │ Orchestration
                                │
                    ┌───────────┴───────────┐
                    │  HARNESS CD PLATFORM  │
                    │                       │
                    │  Pipeline:            │
                    │  • Deploy to Cluster 1│
                    │  • Verify Cluster 1   │
                    │  • Deploy to Cluster 2│
                    │  • Verify Cluster 2   │
                    └───────────────────────┘
```

### Deployment Flow

```
Developer Push → ECR Image Push → Harness Pipeline Trigger
                                          │
                                          ▼
                              ┌───────────────────────┐
                              │  Stage 1: Parallel    │
                              │  Pre-Deployment       │
                              │  Validation           │
                              └───────────┬───────────┘
                                          │
                    ┌─────────────────────┴─────────────────────┐
                    │                                           │
                    ▼                                           ▼
        ┌───────────────────────┐                 ┌───────────────────────┐
        │  Validate Cluster 1   │                 │  Validate Cluster 2   │
        │  (prod-cluster)       │                 │  (analytics-cluster)  │
        │  • Check cluster      │                 │  • Check cluster      │
        │  • Verify capacity    │                 │  • Verify capacity    │
        └───────────┬───────────┘                 └───────────┬───────────┘
                    │                                         │
                    └─────────────────────┬─────────────────────┘
                                          │
                                          ▼
                              ┌───────────────────────┐
                              │  Stage 2: Deploy to   │
                              │  Production Cluster   │
                              │  (us-east-1)          │
                              └───────────┬───────────┘
                                          │
                                          ▼
                              ┌───────────────────────┐
                              │  • Create new task    │
                              │  • Blue-Green deploy  │
                              │  • Health checks      │
                              │  • Traffic shift      │
                              └───────────┬───────────┘
                                          │
                                          ▼
                              ┌───────────────────────┐
                              │  Continuous           │
                              │  Verification         │
                              │  (5 minutes)          │
                              └───────────┬───────────┘
                                          │
                                 ┌────────┴────────┐
                                 │                 │
                            PASS │                 │ FAIL
                                 │                 │
                                 ▼                 ▼
                    ┌────────────────┐    ┌────────────────┐
                    │  Continue      │    │  Rollback      │
                    │                │    │  Stop Pipeline │
                    └────────┬───────┘    └────────────────┘
                             │
                             ▼
                  ┌───────────────────────┐
                  │  Stage 3: Deploy to   │
                  │  Analytics Cluster    │
                  │  (us-west-2)          │
                  └───────────┬───────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  • Create new task    │
                  │  • Blue-Green deploy  │
                  │  • Health checks      │
                  │  • Traffic shift      │
                  └───────────┬───────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  Continuous           │
                  │  Verification         │
                  │  (5 minutes)          │
                  └───────────┬───────────┘
                              │
                     ┌────────┴────────┐
                     │                 │
                PASS │                 │ FAIL
                     │                 │
                     ▼                 ▼
        ┌────────────────┐    ┌────────────────┐
        │  Success       │    │  Rollback      │
        │  Both Clusters │    │  Cluster 2     │
        │  Updated       │    │                │
        └────────────────┘    └────────────────┘

Total Deployment Time: ~20-25 minutes (both clusters)
Rollback Time: < 2 minutes per cluster
```

---

## 2. Prerequisites

### AWS Resources Required

#### ECS Clusters
```bash
# Production Cluster (us-east-1)
Cluster Name: prod-cluster
Region: us-east-1
Services: 5 (including notification-service)
Fargate Launch Type

# Analytics Cluster (us-west-2)
Cluster Name: analytics-cluster
Region: us-west-2
Services: 3 (including notification-service)
Fargate Launch Type
```

#### ECR Repository
```bash
Repository Name: notification-service
Region: us-east-1 (replicated to us-west-2)
URI: 123456789012.dkr.ecr.us-east-1.amazonaws.com/notification-service
```

#### IAM Roles
```bash
# Delegate Role (us-east-1)
Role Name: harness-delegate-prod-role
Permissions: ECS, ECR, ALB, CloudWatch

# Delegate Role (us-west-2)
Role Name: harness-delegate-analytics-role
Permissions: ECS, ECR, ALB, CloudWatch

# Task Execution Role
Role Name: notification-service-execution-role
Permissions: ECR pull, Secrets Manager, CloudWatch Logs

# Task Role
Role Name: notification-service-task-role
Permissions: Application-specific (SNS, SQS, DynamoDB)
```

#### Networking
```bash
# Production VPC (us-east-1)
VPC: 10.0.0.0/16
Private Subnets: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
Public Subnets: 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24
ALB: prod-alb

# Analytics VPC (us-west-2)
VPC: 10.1.0.0/16
Private Subnets: 10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24
Public Subnets: 10.1.11.0/24, 10.1.12.0/24, 10.1.13.0/24
ALB: analytics-alb
```

### Harness Prerequisites

```bash
# Delegates
- Delegate in us-east-1 (delegate-prod)
- Delegate in us-west-2 (delegate-analytics)

# Connectors
- AWS Connector (us-east-1): aws-prod-connector
- AWS Connector (us-west-2): aws-analytics-connector
- Docker Registry Connector: ecr-connector

# Secrets
- AWS Access Key (if not using IAM roles)
- Docker Registry Credentials
- Application Secrets (stored in AWS Secrets Manager)
```

---

## 3. Infrastructure Setup

### 3.1 Create ECR Repository

```bash
#!/bin/bash
# create-ecr-repo.sh

# Create ECR repository in us-east-1
aws ecr create-repository \
  --repository-name notification-service \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true \
  --tags Key=Environment,Value=production Key=Service,Value=notification

# Get repository URI
ECR_URI=$(aws ecr describe-repositories \
  --repository-names notification-service \
  --region us-east-1 \
  --query 'repositories[0].repositoryUri' \
  --output text)

echo "ECR Repository Created: $ECR_URI"

# Enable cross-region replication to us-west-2
aws ecr put-replication-configuration \
  --replication-configuration '{
    "rules": [{
      "destinations": [{
        "region": "us-west-2",
        "registryId": "123456789012"
      }]
    }]
  }' \
  --region us-east-1

echo "Cross-region replication enabled to us-west-2"
```

### 3.2 Create ECS Clusters

```bash
#!/bin/bash
# create-ecs-clusters.sh

# Create Production Cluster (us-east-1)
aws ecs create-cluster \
  --cluster-name prod-cluster \
  --region us-east-1 \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy \
    capacityProvider=FARGATE,weight=1,base=2 \
    capacityProvider=FARGATE_SPOT,weight=1 \
  --tags key=Environment,value=production

echo "Production cluster created in us-east-1"

# Create Analytics Cluster (us-west-2)
aws ecs create-cluster \
  --cluster-name analytics-cluster \
  --region us-west-2 \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy \
    capacityProvider=FARGATE,weight=1,base=1 \
    capacityProvider=FARGATE_SPOT,weight=1 \
  --tags key=Environment,value=analytics

echo "Analytics cluster created in us-west-2"
```

### 3.3 Create IAM Roles

```bash
#!/bin/bash
# create-iam-roles.sh

# Task Execution Role
cat > task-execution-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "ecs-tasks.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name notification-service-execution-role \
  --assume-role-policy-document file://task-execution-trust-policy.json

# Attach managed policy
aws iam attach-role-policy \
  --role-name notification-service-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Task Role
cat > task-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "ecs-tasks.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name notification-service-task-role \
  --assume-role-policy-document file://task-trust-policy.json

# Attach custom policy for application
cat > notification-task-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish",
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:notification/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name notification-service-task-role \
  --policy-name NotificationServicePolicy \
  --policy-document file://notification-task-policy.json

echo "IAM roles created successfully"
```

### 3.4 Create Task Definitions

```bash
#!/bin/bash
# create-task-definitions.sh

# Production Task Definition (us-east-1)
cat > notification-task-def-prod.json <<EOF
{
  "family": "notification-service-prod",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::123456789012:role/notification-service-execution-role",
  "taskRoleArn": "arn:aws:iam::123456789012:role/notification-service-task-role",
  "containerDefinitions": [
    {
      "name": "notification-service",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/notification-service:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8083,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "ENVIRONMENT",
          "value": "production"
        },
        {
          "name": "REGION",
          "value": "us-east-1"
        },
        {
          "name": "CLUSTER",
          "value": "prod-cluster"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:notification/db-url"
        },
        {
          "name": "API_KEY",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:notification/api-key"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/notification-service-prod",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8083/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition \
  --cli-input-json file://notification-task-def-prod.json \
  --region us-east-1

echo "Production task definition registered"

# Analytics Task Definition (us-west-2)
cat > notification-task-def-analytics.json <<EOF
{
  "family": "notification-service-analytics",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::123456789012:role/notification-service-execution-role",
  "taskRoleArn": "arn:aws:iam::123456789012:role/notification-service-task-role",
  "containerDefinitions": [
    {
      "name": "notification-service",
      "image": "123456789012.dkr.ecr.us-west-2.amazonaws.com/notification-service:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8083,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "ENVIRONMENT",
          "value": "analytics"
        },
        {
          "name": "REGION",
          "value": "us-west-2"
        },
        {
          "name": "CLUSTER",
          "value": "analytics-cluster"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:us-west-2:123456789012:secret:notification/db-url"
        },
        {
          "name": "API_KEY",
          "valueFrom": "arn:aws:secretsmanager:us-west-2:123456789012:secret:notification/api-key"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/notification-service-analytics",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8083/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition \
  --cli-input-json file://notification-task-def-analytics.json \
  --region us-west-2

echo "Analytics task definition registered"
```

### 3.5 Create ECS Services

```bash
#!/bin/bash
# create-ecs-services.sh

# Create Production Service (us-east-1)
aws ecs create-service \
  --cluster prod-cluster \
  --service-name notification-service \
  --task-definition notification-service-prod \
  --desired-count 3 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[subnet-prod1,subnet-prod2,subnet-prod3],
    securityGroups=[sg-prod-ecs],
    assignPublicIp=DISABLED
  }" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/notification-prod-tg/abc123,containerName=notification-service,containerPort=8083" \
  --deployment-controller type=ECS \
  --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100,deploymentCircuitBreaker={enable=true,rollback=true}" \
  --region us-east-1

echo "Production service created"

# Create Analytics Service (us-west-2)
aws ecs create-service \
  --cluster analytics-cluster \
  --service-name notification-service \
  --task-definition notification-service-analytics \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[subnet-analytics1,subnet-analytics2,subnet-analytics3],
    securityGroups=[sg-analytics-ecs],
    assignPublicIp=DISABLED
  }" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/notification-analytics-tg/def456,containerName=notification-service,containerPort=8083" \
  --deployment-controller type=ECS \
  --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100,deploymentCircuitBreaker={enable=true,rollback=true}" \
  --region us-west-2

echo "Analytics service created"
```

---

## 4. Harness Configuration

### 4.1 Install Harness Delegates

**Delegate for Production Cluster (us-east-1)**

```bash
#!/bin/bash
# install-delegate-prod.sh

# Create namespace
kubectl create namespace harness-delegate-ng

# Download delegate YAML from Harness UI
# Project Settings > Delegates > New Delegate > Kubernetes

# Apply delegate
kubectl apply -f harness-delegate-prod.yaml -n harness-delegate-ng

# Verify delegate
kubectl get pods -n harness-delegate-ng

# Expected output:
# NAME                                READY   STATUS    RESTARTS   AGE
# delegate-prod-xxxxx-xxxxx           1/1     Running   0          2m
```

**Delegate YAML Configuration** (`harness-delegate-prod.yaml`):

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: harness-delegate-ng

---
apiVersion: v1
kind: Secret
metadata:
  name: delegate-prod-account-token
  namespace: harness-delegate-ng
type: Opaque
data:
  DELEGATE_TOKEN: "<base64-encoded-token>"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    harness.io/name: delegate-prod
  name: delegate-prod
  namespace: harness-delegate-ng
spec:
  replicas: 1
  selector:
    matchLabels:
      harness.io/name: delegate-prod
  template:
    metadata:
      labels:
        harness.io/name: delegate-prod
    spec:
      serviceAccountName: delegate-prod
      containers:
      - image: harness/delegate:latest
        imagePullPolicy: Always
        name: delegate
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: "1"
            memory: "2048Mi"
          requests:
            cpu: "0.5"
            memory: "1024Mi"
        env:
        - name: JAVA_OPTS
          value: "-Xms512M -Xmx2048M"
        - name: ACCOUNT_ID
          value: "<your-account-id>"
        - name: DELEGATE_TOKEN
          valueFrom:
            secretKeyRef:
              name: delegate-prod-account-token
              key: DELEGATE_TOKEN
        - name: DELEGATE_TYPE
          value: "KUBERNETES"
        - name: DELEGATE_NAME
          value: "delegate-prod"
        - name: NEXT_GEN
          value: "true"
        - name: DELEGATE_TAGS
          value: "prod,us-east-1,ecs"
        - name: AWS_REGION
          value: "us-east-1"
      restartPolicy: Always

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: delegate-prod
  namespace: harness-delegate-ng

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: delegate-prod-cluster-admin
subjects:
- kind: ServiceAccount
  name: delegate-prod
  namespace: harness-delegate-ng
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

**Delegate for Analytics Cluster (us-west-2)**

Similar configuration with:
- `DELEGATE_NAME: "delegate-analytics"`
- `DELEGATE_TAGS: "analytics,us-west-2,ecs"`
- `AWS_REGION: "us-west-2"`

### 4.2 Create Connectors

**AWS Connector for Production (us-east-1)**

```yaml
# Via Harness UI: Project Settings > Connectors > + New Connector > AWS

connector:
  name: aws-prod-connector
  identifier: aws_prod_connector
  description: AWS connector for production cluster in us-east-1
  type: Aws
  spec:
    credential:
      type: InheritFromDelegate
      spec:
        delegateSelectors:
          - delegate-prod
    region: us-east-1
```

**AWS Connector for Analytics (us-west-2)**

```yaml
connector:
  name: aws-analytics-connector
  identifier: aws_analytics_connector
  description: AWS connector for analytics cluster in us-west-2
  type: Aws
  spec:
    credential:
      type: InheritFromDelegate
      spec:
        delegateSelectors:
          - delegate-analytics
    region: us-west-2
```

**Docker Registry Connector (ECR)**

```yaml
connector:
  name: ecr-connector
  identifier: ecr_connector
  description: ECR connector for notification-service
  type: DockerRegistry
  spec:
    dockerRegistryUrl: https://123456789012.dkr.ecr.us-east-1.amazonaws.com
    providerType: Ecr
    auth:
      type: InheritFromDelegate
      spec:
        delegateSelectors:
          - delegate-prod
```

### 4.3 Create Service

```yaml
# Service Definition: notification-service

service:
  name: notification-service
  identifier: notification_service
  serviceDefinition:
    type: ECS
    spec:
      manifests:
        - manifest:
            identifier: TaskDefinition
            type: EcsTaskDefinition
            spec:
              store:
                type: Inline
                spec:
                  content: |
                    {
                      "family": "notification-service",
                      "networkMode": "awsvpc",
                      "requiresCompatibilities": ["FARGATE"],
                      "cpu": "<+serviceVariables.cpu>",
                      "memory": "<+serviceVariables.memory>",
                      "executionRoleArn": "arn:aws:iam::123456789012:role/notification-service-execution-role",
                      "taskRoleArn": "arn:aws:iam::123456789012:role/notification-service-task-role",
                      "containerDefinitions": [
                        {
                          "name": "notification-service",
                          "image": "<+artifacts.primary.image>",
                          "essential": true,
                          "portMappings": [
                            {
                              "containerPort": 8083,
                              "protocol": "tcp"
                            }
                          ],
                          "environment": [
                            {
                              "name": "ENVIRONMENT",
                              "value": "<+env.name>"
                            },
                            {
                              "name": "REGION",
                              "value": "<+infra.region>"
                            },
                            {
                              "name": "CLUSTER",
                              "value": "<+infra.cluster>"
                            }
                          ],
                          "logConfiguration": {
                            "logDriver": "awslogs",
                            "options": {
                              "awslogs-group": "/ecs/notification-service",
                              "awslogs-region": "<+infra.region>",
                              "awslogs-stream-prefix": "ecs"
                            }
                          },
                          "healthCheck": {
                            "command": ["CMD-SHELL", "curl -f http://localhost:8083/health || exit 1"],
                            "interval": 30,
                            "timeout": 5,
                            "retries": 3,
                            "startPeriod": 60
                          }
                        }
                      ]
                    }
        - manifest:
            identifier: ServiceDefinition
            type: EcsServiceDefinition
            spec:
              store:
                type: Inline
                spec:
                  content: |
                    {
                      "serviceName": "notification-service",
                      "desiredCount": <+serviceVariables.desiredCount>,
                      "launchType": "FARGATE",
                      "deploymentConfiguration": {
                        "maximumPercent": 200,
                        "minimumHealthyPercent": 100,
                        "deploymentCircuitBreaker": {
                          "enable": true,
                          "rollback": true
                        }
                      }
                    }
      artifacts:
        primary:
          primaryArtifactRef: notification_image
          sources:
            - identifier: notification_image
              type: Ecr
              spec:
                connectorRef: ecr_connector
                imagePath: notification-service
                region: us-east-1
                tag: <+input>
      variables:
        - name: cpu
          type: String
          value: "512"
        - name: memory
          type: String
          value: "1024"
        - name: desiredCount
          type: String
          value: "3"
```

### 4.4 Create Environments

**Production Environment**

```yaml
environment:
  name: Production
  identifier: production
  type: Production
  tags:
    region: us-east-1
    cluster: prod-cluster
  variables:
    - name: region
      type: String
      value: us-east-1
    - name: cluster
      type: String
      value: prod-cluster
```

**Analytics Environment**

```yaml
environment:
  name: Analytics
  identifier: analytics
  type: Production
  tags:
    region: us-west-2
    cluster: analytics-cluster
  variables:
    - name: region
      type: String
      value: us-west-2
    - name: cluster
      type: String
      value: analytics-cluster
```

### 4.5 Create Infrastructure Definitions

**Production Infrastructure**

```yaml
infrastructureDefinition:
  name: prod-ecs-infra
  identifier: prod_ecs_infra
  type: ECS
  spec:
    connectorRef: aws_prod_connector
    region: us-east-1
    cluster: prod-cluster
  allowSimultaneousDeployments: false
```

**Analytics Infrastructure**

```yaml
infrastructureDefinition:
  name: analytics-ecs-infra
  identifier: analytics_ecs_infra
  type: ECS
  spec:
    connectorRef: aws_analytics_connector
    region: us-west-2
    cluster: analytics-cluster
  allowSimultaneousDeployments: false
```

---

## 5. Pipeline Implementation

### Complete Harness Pipeline YAML

```yaml
pipeline:
  name: Multi-Cluster Notification Service Deployment
  identifier: multi_cluster_notification_deploy
  projectIdentifier: default
  orgIdentifier: default
  tags:
    service: notification
    deployment: multi-cluster
  stages:
    # Stage 1: Parallel Validation
    - parallel:
        - stage:
            name: Validate Production Cluster
            identifier: validate_prod
            description: Validate production cluster readiness
            type: Custom
            spec:
              execution:
                steps:
                  - step:
                      type: ShellScript
                      name: Check Prod Cluster
                      identifier: check_prod_cluster
                      spec:
                        shell: Bash
                        onDelegate: true
                        source:
                          type: Inline
                          spec:
                            script: |-
                              #!/bin/bash
                              set -e

                              echo "Checking production cluster status..."

                              # Check cluster exists and is active
                              CLUSTER_STATUS=$(aws ecs describe-clusters \
                                --clusters prod-cluster \
                                --region us-east-1 \
                                --query 'clusters[0].status' \
                                --output text)

                              if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
                                echo "ERROR: Production cluster is not active"
                                exit 1
                              fi

                              echo "✓ Production cluster is active"

                              # Check current service status
                              RUNNING_COUNT=$(aws ecs describe-services \
                                --cluster prod-cluster \
                                --services notification-service \
                                --region us-east-1 \
                                --query 'services[0].runningCount' \
                                --output text)

                              DESIRED_COUNT=$(aws ecs describe-services \
                                --cluster prod-cluster \
                                --services notification-service \
                                --region us-east-1 \
                                --query 'services[0].desiredCount' \
                                --output text)

                              echo "Current running tasks: $RUNNING_COUNT"
                              echo "Desired tasks: $DESIRED_COUNT"

                              if [ "$RUNNING_COUNT" -lt 1 ]; then
                                echo "ERROR: No tasks running in production"
                                exit 1
                              fi

                              echo "✓ Service is healthy with $RUNNING_COUNT/$DESIRED_COUNT tasks"

                              # Check cluster capacity
                              CAPACITY_PROVIDERS=$(aws ecs describe-clusters \
                                --clusters prod-cluster \
                                --region us-east-1 \
                                --query 'clusters[0].capacityProviders' \
                                --output json)

                              echo "Capacity providers: $CAPACITY_PROVIDERS"

                              echo "✓ Production cluster validation complete"
                        environmentVariables: []
                        outputVariables: []
                        delegateSelectors:
                          - delegate-prod
                      timeout: 5m
                      failureStrategies: []

        - stage:
            name: Validate Analytics Cluster
            identifier: validate_analytics
            description: Validate analytics cluster readiness
            type: Custom
            spec:
              execution:
                steps:
                  - step:
                      type: ShellScript
                      name: Check Analytics Cluster
                      identifier: check_analytics_cluster
                      spec:
                        shell: Bash
                        onDelegate: true
                        source:
                          type: Inline
                          spec:
                            script: |-
                              #!/bin/bash
                              set -e

                              echo "Checking analytics cluster status..."

                              # Check cluster exists and is active
                              CLUSTER_STATUS=$(aws ecs describe-clusters \
                                --clusters analytics-cluster \
                                --region us-west-2 \
                                --query 'clusters[0].status' \
                                --output text)

                              if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
                                echo "ERROR: Analytics cluster is not active"
                                exit 1
                              fi

                              echo "✓ Analytics cluster is active"

                              # Check current service status
                              RUNNING_COUNT=$(aws ecs describe-services \
                                --cluster analytics-cluster \
                                --services notification-service \
                                --region us-west-2 \
                                --query 'services[0].runningCount' \
                                --output text)

                              DESIRED_COUNT=$(aws ecs describe-services \
                                --cluster analytics-cluster \
                                --services notification-service \
                                --region us-west-2 \
                                --query 'services[0].desiredCount' \
                                --output text)

                              echo "Current running tasks: $RUNNING_COUNT"
                              echo "Desired tasks: $DESIRED_COUNT"

                              if [ "$RUNNING_COUNT" -lt 1 ]; then
                                echo "ERROR: No tasks running in analytics"
                                exit 1
                              fi

                              echo "✓ Service is healthy with $RUNNING_COUNT/$DESIRED_COUNT tasks"

                              echo "✓ Analytics cluster validation complete"
                        environmentVariables: []
                        outputVariables: []
                        delegateSelectors:
                          - delegate-analytics
                      timeout: 5m
                      failureStrategies: []

    # Stage 2: Deploy to Production Cluster
    - stage:
        name: Deploy to Production
        identifier: deploy_production
        description: Deploy notification service to production cluster
        type: Deployment
        spec:
          deploymentType: ECS
          service:
            serviceRef: notification_service
            serviceInputs:
              serviceDefinition:
                type: ECS
                spec:
                  artifacts:
                    primary:
                      primaryArtifactRef: <+input>
                      sources: <+input>
                  variables:
                    - name: cpu
                      type: String
                      value: "512"
                    - name: memory
                      type: String
                      value: "1024"
                    - name: desiredCount
                      type: String
                      value: "3"
          environment:
            environmentRef: production
            deployToAll: false
            infrastructureDefinitions:
              - identifier: prod_ecs_infra
          execution:
            steps:
              - step:
                  type: ShellScript
                  name: Pre-Deployment Health Check
                  identifier: pre_deploy_health_check
                  spec:
                    shell: Bash
                    onDelegate: true
                    source:
                      type: Inline
                      spec:
                        script: |-
                          #!/bin/bash
                          set -e

                          echo "Running pre-deployment health checks..."

                          # Check ALB target group health
                          TG_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/notification-prod-tg/abc123"

                          HEALTHY_TARGETS=$(aws elbv2 describe-target-health \
                            --target-group-arn $TG_ARN \
                            --region us-east-1 \
                            --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
                            --output text)

                          echo "Healthy targets before deployment: $HEALTHY_TARGETS"

                          if [ "$HEALTHY_TARGETS" -lt 2 ]; then
                            echo "ERROR: Not enough healthy targets. Need at least 2."
                            exit 1
                          fi

                          echo "✓ Pre-deployment health check passed"
                    environmentVariables: []
                    outputVariables: []
                    delegateSelectors:
                      - delegate-prod
                  timeout: 5m

              - step:
                  type: EcsBlueGreenCreateService
                  name: Create Green Service
                  identifier: create_green_service
                  spec:
                    loadBalancer:
                      loadBalancerArn: arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/prod-alb/xyz789
                      prodListenerArn: arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/prod-alb/xyz789/abc123
                      prodListenerRuleArn: arn:aws:elasticloadbalancing:us-east-1:123456789012:listener-rule/app/prod-alb/xyz789/abc123/rule1
                      stageListenerArn: arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/prod-alb/xyz789/def456
                      stageListenerRuleArn: arn:aws:elasticloadbalancing:us-east-1:123456789012:listener-rule/app/prod-alb/xyz789/def456/rule2
                  timeout: 10m

              - step:
                  type: EcsBlueGreenSwapTargetGroups
                  name: Swap Target Groups
                  identifier: swap_target_groups
                  spec:
                    doNotDownsizeOldService: true
                  timeout: 10m

              - step:
                  type: ShellScript
                  name: Post-Deployment Verification
                  identifier: post_deploy_verification
                  spec:
                    shell: Bash
                    onDelegate: true
                    source:
                      type: Inline
                      spec:
                        script: |-
                          #!/bin/bash
                          set -e

                          echo "Running post-deployment verification..."

                          # Wait for tasks to be stable
                          sleep 30

                          # Check new service health
                          RUNNING_COUNT=$(aws ecs describe-services \
                            --cluster prod-cluster \
                            --services notification-service \
                            --region us-east-1 \
                            --query 'services[0].runningCount' \
                            --output text)

                          DESIRED_COUNT=$(aws ecs describe-services \
                            --cluster prod-cluster \
                            --services notification-service \
                            --region us-east-1 \
                            --query 'services[0].desiredCount' \
                            --output text)

                          echo "Running tasks: $RUNNING_COUNT"
                          echo "Desired tasks: $DESIRED_COUNT"

                          if [ "$RUNNING_COUNT" != "$DESIRED_COUNT" ]; then
                            echo "ERROR: Task count mismatch"
                            exit 1
                          fi

                          # Test health endpoint
                          ALB_DNS="prod-alb-123456789.us-east-1.elb.amazonaws.com"
                          HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/health)

                          if [ "$HEALTH_CHECK" != "200" ]; then
                            echo "ERROR: Health check failed with status $HEALTH_CHECK"
                            exit 1
                          fi

                          echo "✓ Post-deployment verification passed"
                    environmentVariables: []
                    outputVariables: []
                    delegateSelectors:
                      - delegate-prod
                  timeout: 5m

            rollbackSteps:
              - step:
                  type: EcsBlueGreenRollback
                  name: Rollback Production
                  identifier: rollback_production
                  spec: {}
                  timeout: 10m

        tags: {}
        failureStrategies:
          - onFailure:
              errors:
                - AllErrors
              action:
                type: StageRollback

    # Stage 3: Deploy to Analytics Cluster
    - stage:
        name: Deploy to Analytics
        identifier: deploy_analytics
        description: Deploy notification service to analytics cluster
        type: Deployment
        spec:
          deploymentType: ECS
          service:
            serviceRef: notification_service
            serviceInputs:
              serviceDefinition:
                type: ECS
                spec:
                  artifacts:
                    primary:
                      primaryArtifactRef: <+input>
                      sources: <+input>
                  variables:
                    - name: cpu
                      type: String
                      value: "256"
                    - name: memory
                      type: String
                      value: "512"
                    - name: desiredCount
                      type: String
                      value: "2"
          environment:
            environmentRef: analytics
            deployToAll: false
            infrastructureDefinitions:
              - identifier: analytics_ecs_infra
          execution:
            steps:
              - step:
                  type: ShellScript
                  name: Pre-Deployment Health Check
                  identifier: pre_deploy_health_check_analytics
                  spec:
                    shell: Bash
                    onDelegate: true
                    source:
                      type: Inline
                      spec:
                        script: |-
                          #!/bin/bash
                          set -e

                          echo "Running pre-deployment health checks for analytics..."

                          # Check ALB target group health
                          TG_ARN="arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/notification-analytics-tg/def456"

                          HEALTHY_TARGETS=$(aws elbv2 describe-target-health \
                            --target-group-arn $TG_ARN \
                            --region us-west-2 \
                            --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
                            --output text)

                          echo "Healthy targets before deployment: $HEALTHY_TARGETS"

                          if [ "$HEALTHY_TARGETS" -lt 1 ]; then
                            echo "ERROR: Not enough healthy targets."
                            exit 1
                          fi

                          echo "✓ Pre-deployment health check passed"
                    environmentVariables: []
                    outputVariables: []
                    delegateSelectors:
                      - delegate-analytics
                  timeout: 5m

              - step:
                  type: EcsBlueGreenCreateService
                  name: Create Green Service
                  identifier: create_green_service_analytics
                  spec:
                    loadBalancer:
                      loadBalancerArn: arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/analytics-alb/uvw123
                      prodListenerArn: arn:aws:elasticloadbalancing:us-west-2:123456789012:listener/app/analytics-alb/uvw123/ghi789
                      prodListenerRuleArn: arn:aws:elasticloadbalancing:us-west-2:123456789012:listener-rule/app/analytics-alb/uvw123/ghi789/rule1
                      stageListenerArn: arn:aws:elasticloadbalancing:us-west-2:123456789012:listener/app/analytics-alb/uvw123/jkl012
                      stageListenerRuleArn: arn:aws:elasticloadbalancing:us-west-2:123456789012:listener-rule/app/analytics-alb/uvw123/jkl012/rule2
                  timeout: 10m

              - step:
                  type: EcsBlueGreenSwapTargetGroups
                  name: Swap Target Groups
                  identifier: swap_target_groups_analytics
                  spec:
                    doNotDownsizeOldService: true
                  timeout: 10m

              - step:
                  type: ShellScript
                  name: Post-Deployment Verification
                  identifier: post_deploy_verification_analytics
                  spec:
                    shell: Bash
                    onDelegate: true
                    source:
                      type: Inline
                      spec:
                        script: |-
                          #!/bin/bash
                          set -e

                          echo "Running post-deployment verification for analytics..."

                          # Wait for tasks to be stable
                          sleep 30

                          # Check new service health
                          RUNNING_COUNT=$(aws ecs describe-services \
                            --cluster analytics-cluster \
                            --services notification-service \
                            --region us-west-2 \
                            --query 'services[0].runningCount' \
                            --output text)

                          DESIRED_COUNT=$(aws ecs describe-services \
                            --cluster analytics-cluster \
                            --services notification-service \
                            --region us-west-2 \
                            --query 'services[0].desiredCount' \
                            --output text)

                          echo "Running tasks: $RUNNING_COUNT"
                          echo "Desired tasks: $DESIRED_COUNT"

                          if [ "$RUNNING_COUNT" != "$DESIRED_COUNT" ]; then
                            echo "ERROR: Task count mismatch"
                            exit 1
                          fi

                          # Test health endpoint
                          ALB_DNS="analytics-alb-987654321.us-west-2.elb.amazonaws.com"
                          HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/health)

                          if [ "$HEALTH_CHECK" != "200" ]; then
                            echo "ERROR: Health check failed with status $HEALTH_CHECK"
                            exit 1
                          fi

                          echo "✓ Post-deployment verification passed"
                          echo "✓ Both clusters successfully deployed!"
                    environmentVariables: []
                    outputVariables: []
                    delegateSelectors:
                      - delegate-analytics
                  timeout: 5m

            rollbackSteps:
              - step:
                  type: EcsBlueGreenRollback
                  name: Rollback Analytics
                  identifier: rollback_analytics
                  spec: {}
                  timeout: 10m

        tags: {}
        failureStrategies:
          - onFailure:
              errors:
                - AllErrors
              action:
                type: StageRollback

    # Stage 4: Final Verification
    - stage:
        name: Final Verification
        identifier: final_verification
        description: Verify both clusters are healthy
        type: Custom
        spec:
          execution:
            steps:
              - parallel:
                  - step:
                      type: ShellScript
                      name: Verify Production
                      identifier: verify_production
                      spec:
                        shell: Bash
                        onDelegate: true
                        source:
                          type: Inline
                          spec:
                            script: |-
                              #!/bin/bash
                              set -e

                              echo "Final verification for production cluster..."

                              # Get current image
                              CURRENT_IMAGE=$(aws ecs describe-services \
                                --cluster prod-cluster \
                                --services notification-service \
                                --region us-east-1 \
                                --query 'services[0].taskDefinition' \
                                --output text)

                              IMAGE_TAG=$(aws ecs describe-task-definition \
                                --task-definition $CURRENT_IMAGE \
                                --region us-east-1 \
                                --query 'taskDefinition.containerDefinitions[0].image' \
                                --output text | cut -d':' -f2)

                              echo "Deployed image tag: $IMAGE_TAG"
                              echo "Expected image tag: <+artifacts.primary.tag>"

                              if [ "$IMAGE_TAG" != "<+artifacts.primary.tag>" ]; then
                                echo "ERROR: Image tag mismatch"
                                exit 1
                              fi

                              echo "✓ Production cluster verified"
                        environmentVariables: []
                        outputVariables: []
                        delegateSelectors:
                          - delegate-prod
                      timeout: 5m

                  - step:
                      type: ShellScript
                      name: Verify Analytics
                      identifier: verify_analytics
                      spec:
                        shell: Bash
                        onDelegate: true
                        source:
                          type: Inline
                          spec:
                            script: |-
                              #!/bin/bash
                              set -e

                              echo "Final verification for analytics cluster..."

                              # Get current image
                              CURRENT_IMAGE=$(aws ecs describe-services \
                                --cluster analytics-cluster \
                                --services notification-service \
                                --region us-west-2 \
                                --query 'services[0].taskDefinition' \
                                --output text)

                              IMAGE_TAG=$(aws ecs describe-task-definition \
                                --task-definition $CURRENT_IMAGE \
                                --region us-west-2 \
                                --query 'taskDefinition.containerDefinitions[0].image' \
                                --output text | cut -d':' -f2)

                              echo "Deployed image tag: $IMAGE_TAG"
                              echo "Expected image tag: <+artifacts.primary.tag>"

                              if [ "$IMAGE_TAG" != "<+artifacts.primary.tag>" ]; then
                                echo "ERROR: Image tag mismatch"
                                exit 1
                              fi

                              echo "✓ Analytics cluster verified"
                              echo ""
                              echo "═══════════════════════════════════════"
                              echo "✓ DEPLOYMENT SUCCESSFUL"
                              echo "✓ Both clusters updated to version $IMAGE_TAG"
                              echo "═══════════════════════════════════════"
                        environmentVariables: []
                        outputVariables: []
                        delegateSelectors:
                          - delegate-analytics
                      timeout: 5m
        tags: {}

  notificationRules:
    - name: Deployment Failed
      identifier: deployment_failed
      pipelineEvents:
        - type: PipelineFailed
      notificationMethod:
        type: Slack
        spec:
          userGroups: []
          webhookUrl: <+secrets.getValue("slack_webhook_url")>
      enabled: true

    - name: Deployment Success
      identifier: deployment_success
      pipelineEvents:
        - type: PipelineSuccess
      notificationMethod:
        type: Slack
        spec:
          userGroups: []
          webhookUrl: <+secrets.getValue("slack_webhook_url")>
      enabled: true
```

---

## 6. Deployment Scripts

### 6.1 Build and Push Script

```bash
#!/bin/bash
# build-and-push.sh
# Build Docker image and push to ECR

set -e

# Configuration
SERVICE_NAME="notification-service"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="123456789012"
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${SERVICE_NAME}"

# Get version from git or use timestamp
VERSION=${1:-$(git rev-parse --short HEAD)}
IMAGE_TAG="${VERSION}"

echo "Building ${SERVICE_NAME}:${IMAGE_TAG}..."

# Build Docker image
docker build -t ${SERVICE_NAME}:${IMAGE_TAG} .

# Tag for ECR
docker tag ${SERVICE_NAME}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
docker tag ${SERVICE_NAME}:${IMAGE_TAG} ${ECR_REPO}:latest

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REPO}

# Push to ECR
echo "Pushing to ECR..."
docker push ${ECR_REPO}:${IMAGE_TAG}
docker push ${ECR_REPO}:latest

echo "✓ Image pushed: ${ECR_REPO}:${IMAGE_TAG}"
echo "✓ Latest tag updated"

# Output image details for pipeline
echo "IMAGE_URI=${ECR_REPO}:${IMAGE_TAG}" >> $GITHUB_OUTPUT
```

### 6.2 Health Check Script

```bash
#!/bin/bash
# health-check.sh
# Comprehensive health check for notification service

set -e

CLUSTER=$1
REGION=$2
SERVICE_NAME="notification-service"

echo "Running health check for ${SERVICE_NAME} in ${CLUSTER} (${REGION})..."

# Check service status
SERVICE_STATUS=$(aws ecs describe-services \
  --cluster ${CLUSTER} \
  --services ${SERVICE_NAME} \
  --region ${REGION} \
  --query 'services[0].status' \
  --output text)

if [ "$SERVICE_STATUS" != "ACTIVE" ]; then
  echo "ERROR: Service status is $SERVICE_STATUS"
  exit 1
fi

echo "✓ Service status: ACTIVE"

# Check task count
RUNNING_COUNT=$(aws ecs describe-services \
  --cluster ${CLUSTER} \
  --services ${SERVICE_NAME} \
  --region ${REGION} \
  --query 'services[0].runningCount' \
  --output text)

DESIRED_COUNT=$(aws ecs describe-services \
  --cluster ${CLUSTER} \
  --services ${SERVICE_NAME} \
  --region ${REGION} \
  --query 'services[0].desiredCount' \
  --output text)

echo "Running tasks: ${RUNNING_COUNT}/${DESIRED_COUNT}"

if [ "$RUNNING_COUNT" != "$DESIRED_COUNT" ]; then
  echo "ERROR: Task count mismatch"
  exit 1
fi

echo "✓ All tasks running"

# Check task health
TASK_ARNS=$(aws ecs list-tasks \
  --cluster ${CLUSTER} \
  --service-name ${SERVICE_NAME} \
  --region ${REGION} \
  --query 'taskArns' \
  --output text)

for TASK_ARN in $TASK_ARNS; do
  TASK_HEALTH=$(aws ecs describe-tasks \
    --cluster ${CLUSTER} \
    --tasks ${TASK_ARN} \
    --region ${REGION} \
    --query 'tasks[0].healthStatus' \
    --output text)

  echo "Task $(basename $TASK_ARN): $TASK_HEALTH"

  if [ "$TASK_HEALTH" != "HEALTHY" ]; then
    echo "ERROR: Task is not healthy"
    exit 1
  fi
done

echo "✓ All tasks healthy"

# Check ALB target health
TG_ARN=$(aws ecs describe-services \
  --cluster ${CLUSTER} \
  --services ${SERVICE_NAME} \
  --region ${REGION} \
  --query 'services[0].loadBalancers[0].targetGroupArn' \
  --output text)

if [ "$TG_ARN" != "None" ]; then
  HEALTHY_TARGETS=$(aws elbv2 describe-target-health \
    --target-group-arn ${TG_ARN} \
    --region ${REGION} \
    --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
    --output text)

  echo "Healthy ALB targets: ${HEALTHY_TARGETS}"

  if [ "$HEALTHY_TARGETS" -lt 1 ]; then
    echo "ERROR: No healthy ALB targets"
    exit 1
  fi

  echo "✓ ALB targets healthy"
fi

echo "✓ Health check passed for ${CLUSTER}"
```

### 6.3 Rollback Script

```bash
#!/bin/bash
# rollback.sh
# Manual rollback to previous version

set -e

CLUSTER=$1
REGION=$2
SERVICE_NAME="notification-service"

echo "Rolling back ${SERVICE_NAME} in ${CLUSTER} (${REGION})..."

# Get current task definition
CURRENT_TASK_DEF=$(aws ecs describe-services \
  --cluster ${CLUSTER} \
  --services ${SERVICE_NAME} \
  --region ${REGION} \
  --query 'services[0].taskDefinition' \
  --output text)

echo "Current task definition: ${CURRENT_TASK_DEF}"

# Get current revision number
CURRENT_REVISION=$(echo ${CURRENT_TASK_DEF} | grep -o '[0-9]*$')
PREVIOUS_REVISION=$((CURRENT_REVISION - 1))

TASK_FAMILY=$(echo ${CURRENT_TASK_DEF} | sed 's/:[0-9]*$//')
PREVIOUS_TASK_DEF="${TASK_FAMILY}:${PREVIOUS_REVISION}"

echo "Rolling back to: ${PREVIOUS_TASK_DEF}"

# Check if previous revision exists
aws ecs describe-task-definition \
  --task-definition ${PREVIOUS_TASK_DEF} \
  --region ${REGION} > /dev/null 2>&1 || {
  echo "ERROR: Previous task definition not found"
  exit 1
}

# Update service to previous task definition
aws ecs update-service \
  --cluster ${CLUSTER} \
  --service ${SERVICE_NAME} \
  --task-definition ${PREVIOUS_TASK_DEF} \
  --region ${REGION} \
  --force-new-deployment

echo "Waiting for rollback to complete..."

# Wait for service to stabilize
aws ecs wait services-stable \
  --cluster ${CLUSTER} \
  --services ${SERVICE_NAME} \
  --region ${REGION}

echo "✓ Rollback complete: ${PREVIOUS_TASK_DEF}"

# Verify rollback
./health-check.sh ${CLUSTER} ${REGION}
```

### 6.4 Cleanup Old Task Definitions

```bash
#!/bin/bash
# cleanup-task-definitions.sh
# Remove old task definition revisions (keep last 5)

set -e

REGION=$1
TASK_FAMILY="notification-service-prod"
KEEP_COUNT=5

echo "Cleaning up old task definitions for ${TASK_FAMILY}..."

# Get all task definition ARNs
TASK_DEFS=$(aws ecs list-task-definitions \
  --family-prefix ${TASK_FAMILY} \
  --region ${REGION} \
  --query 'taskDefinitionArns' \
  --output text | tr '\t' '\n' | sort -V)

# Count total revisions
TOTAL_COUNT=$(echo "$TASK_DEFS" | wc -l | tr -d ' ')

echo "Found ${TOTAL_COUNT} task definition revisions"

if [ "$TOTAL_COUNT" -le "$KEEP_COUNT" ]; then
  echo "No cleanup needed (keeping last ${KEEP_COUNT})"
  exit 0
fi

# Calculate how many to delete
DELETE_COUNT=$((TOTAL_COUNT - KEEP_COUNT))

echo "Deleting ${DELETE_COUNT} old revisions..."

# Delete old revisions
echo "$TASK_DEFS" | head -n ${DELETE_COUNT} | while read TASK_DEF; do
  echo "Deregistering: ${TASK_DEF}"
  aws ecs deregister-task-definition \
    --task-definition ${TASK_DEF} \
    --region ${REGION} > /dev/null
done

echo "✓ Cleanup complete"
```

---

## 7. Demo Walkthrough

### Pre-Demo Setup Checklist

```bash
# 1. Verify AWS resources
./scripts/verify-infrastructure.sh

# 2. Check Harness delegates
kubectl get pods -n harness-delegate-ng

# 3. Verify ECR repository
aws ecr describe-repositories --repository-names notification-service --region us-east-1

# 4. Check current service status
./scripts/health-check.sh prod-cluster us-east-1
./scripts/health-check.sh analytics-cluster us-west-2
```

### Demo Script

**Step 1: Show Current State (2 minutes)**

```bash
# Show production cluster services
echo "=== Production Cluster (us-east-1) ==="
aws ecs list-services --cluster prod-cluster --region us-east-1

# Show current version in production
CURRENT_IMAGE=$(aws ecs describe-services \
  --cluster prod-cluster \
  --services notification-service \
  --region us-east-1 \
  --query 'services[0].taskDefinition' \
  --output text)

echo "Current production version:"
aws ecs describe-task-definition \
  --task-definition $CURRENT_IMAGE \
  --region us-east-1 \
  --query 'taskDefinition.containerDefinitions[0].image'

# Show analytics cluster
echo "=== Analytics Cluster (us-west-2) ==="
aws ecs list-services --cluster analytics-cluster --region us-west-2

# Show current version in analytics
CURRENT_IMAGE=$(aws ecs describe-services \
  --cluster analytics-cluster \
  --services notification-service \
  --region us-west-2 \
  --query 'services[0].taskDefinition' \
  --output text)

echo "Current analytics version:"
aws ecs describe-task-definition \
  --task-definition $CURRENT_IMAGE \
  --region us-west-2 \
  --query 'taskDefinition.containerDefinitions[0].image'
```

**Step 2: Build and Push New Version (3 minutes)**

```bash
# Build new version
cd notification-service/

# Show Dockerfile
cat Dockerfile

# Build and push
./build-and-push.sh v1.3.0

# Verify image in ECR
aws ecr describe-images \
  --repository-name notification-service \
  --region us-east-1 \
  --image-ids imageTag=v1.3.0
```

**Step 3: Trigger Harness Pipeline (1 minute)**

```bash
# Open Harness UI
# Navigate to Pipelines > Multi-Cluster Notification Service Deployment

# Or trigger via API
curl -X POST 'https://app.harness.io/gateway/pipeline/api/pipeline/execute/multi_cluster_notification_deploy' \
  -H 'x-api-key: <your-api-key>' \
  -H 'Content-Type: application/json' \
  -d '{
    "inputSetReferences": [],
    "runtimeInput": {
      "artifacts": {
        "primary": {
          "tag": "v1.3.0"
        }
      }
    }
  }'
```

**Step 4: Show Pipeline Execution (15-20 minutes)**

```bash
# Stage 1: Validation (parallel - 2 minutes)
# - Show both cluster validations running in parallel
# - Point out health checks passing

# Stage 2: Production Deployment (8-10 minutes)
# - Show pre-deployment checks
# - Blue-Green deployment creating green service
# - Traffic shift
# - Post-deployment verification

# Stage 3: Analytics Deployment (8-10 minutes)
# - Show analytics deployment starting after production success
# - Blue-Green deployment
# - Traffic shift
# - Final verification

# Stage 4: Final Verification (2 minutes)
# - Show both clusters verified in parallel
# - Success notification
```

**Step 5: Verify Deployment (3 minutes)**

```bash
# Verify production
echo "=== Verifying Production Cluster ==="
./scripts/health-check.sh prod-cluster us-east-1

# Check new version
aws ecs describe-services \
  --cluster prod-cluster \
  --services notification-service \
  --region us-east-1 \
  --query 'services[0].taskDefinition'

# Test health endpoint
curl -s http://prod-alb-123456789.us-east-1.elb.amazonaws.com/health | jq .

# Verify analytics
echo "=== Verifying Analytics Cluster ==="
./scripts/health-check.sh analytics-cluster us-west-2

# Check new version
aws ecs describe-services \
  --cluster analytics-cluster \
  --services notification-service \
  --region us-west-2 \
  --query 'services[0].taskDefinition'

# Test health endpoint
curl -s http://analytics-alb-987654321.us-west-2.elb.amazonaws.com/health | jq .
```

**Step 6: Demo Rollback (Optional - 5 minutes)**

```bash
# Simulate failure scenario
echo "Simulating deployment failure..."

# Trigger pipeline with bad image tag
# Show automatic rollback

# Or demonstrate manual rollback
./scripts/rollback.sh prod-cluster us-east-1
./scripts/rollback.sh analytics-cluster us-west-2

# Verify rollback
./scripts/health-check.sh prod-cluster us-east-1
./scripts/health-check.sh analytics-cluster us-west-2
```

### Demo Talking Points

1. **Multi-Cluster Architecture**
   - "We have notification-service deployed across two clusters"
   - "Production cluster serves customer-facing apps"
   - "Analytics cluster serves internal analytics workloads"
   - "Single source of truth: same container image, different configurations"

2. **Deployment Strategy**
   - "Using Blue-Green deployment for zero downtime"
   - "Each cluster deploys independently"
   - "If production fails, analytics deployment is skipped"
   - "Complete deployment takes ~20 minutes for both clusters"

3. **Safety & Validation**
   - "Pre-deployment validation ensures clusters are healthy"
   - "Health checks at every stage"
   - "Automatic rollback on failure"
   - "Post-deployment verification confirms success"

4. **Operational Benefits**
   - "Single pipeline handles both clusters"
   - "Consistent deployment process"
   - "Full audit trail and deployment history"
   - "Can deploy to one cluster or both"

---

## 8. Testing & Verification

### 8.1 Integration Tests

```python
#!/usr/bin/env python3
# test-multi-cluster-deployment.py
# Integration tests for multi-cluster deployment

import boto3
import requests
import time
import sys

def test_cluster_health(cluster_name, region, alb_dns):
    """Test ECS cluster and service health"""
    print(f"\n{'='*60}")
    print(f"Testing {cluster_name} in {region}")
    print(f"{'='*60}")

    ecs = boto3.client('ecs', region_name=region)

    # Test 1: Cluster exists and is active
    print("Test 1: Cluster status...")
    response = ecs.describe_clusters(clusters=[cluster_name])
    cluster = response['clusters'][0]
    assert cluster['status'] == 'ACTIVE', f"Cluster not active: {cluster['status']}"
    print("✓ Cluster is active")

    # Test 2: Service is running
    print("Test 2: Service status...")
    response = ecs.describe_services(
        cluster=cluster_name,
        services=['notification-service']
    )
    service = response['services'][0]
    assert service['status'] == 'ACTIVE', f"Service not active: {service['status']}"
    assert service['runningCount'] == service['desiredCount'], \
        f"Task count mismatch: {service['runningCount']}/{service['desiredCount']}"
    print(f"✓ Service is active with {service['runningCount']} tasks")

    # Test 3: Tasks are healthy
    print("Test 3: Task health...")
    response = ecs.list_tasks(
        cluster=cluster_name,
        serviceName='notification-service'
    )
    task_arns = response['taskArns']
    assert len(task_arns) > 0, "No tasks found"

    response = ecs.describe_tasks(cluster=cluster_name, tasks=task_arns)
    for task in response['tasks']:
        assert task['healthStatus'] == 'HEALTHY', \
            f"Task not healthy: {task['taskArn']}"
    print(f"✓ All {len(task_arns)} tasks are healthy")

    # Test 4: Health endpoint responds
    print("Test 4: Health endpoint...")
    health_url = f"http://{alb_dns}/health"
    response = requests.get(health_url, timeout=10)
    assert response.status_code == 200, \
        f"Health check failed: {response.status_code}"
    health_data = response.json()
    assert health_data['status'] == 'healthy', \
        f"Unhealthy status: {health_data}"
    print(f"✓ Health endpoint responding: {health_data}")

    # Test 5: Version endpoint
    print("Test 5: Version endpoint...")
    version_url = f"http://{alb_dns}/version"
    response = requests.get(version_url, timeout=10)
    assert response.status_code == 200, \
        f"Version check failed: {response.status_code}"
    version_data = response.json()
    print(f"✓ Running version: {version_data['version']}")

    print(f"\n✓ All tests passed for {cluster_name}")
    return True

def test_both_clusters_same_version(prod_alb, analytics_alb):
    """Verify both clusters are running the same version"""
    print(f"\n{'='*60}")
    print("Testing version consistency across clusters")
    print(f"{'='*60}")

    # Get production version
    prod_response = requests.get(f"http://{prod_alb}/version", timeout=10)
    prod_version = prod_response.json()['version']
    print(f"Production version: {prod_version}")

    # Get analytics version
    analytics_response = requests.get(f"http://{analytics_alb}/version", timeout=10)
    analytics_version = analytics_response.json()['version']
    print(f"Analytics version: {analytics_version}")

    # Compare
    assert prod_version == analytics_version, \
        f"Version mismatch: {prod_version} != {analytics_version}"

    print(f"✓ Both clusters running same version: {prod_version}")
    return True

def main():
    """Run all tests"""
    print("Starting multi-cluster deployment tests...")

    # Production cluster
    prod_alb = "prod-alb-123456789.us-east-1.elb.amazonaws.com"
    test_cluster_health('prod-cluster', 'us-east-1', prod_alb)

    # Analytics cluster
    analytics_alb = "analytics-alb-987654321.us-west-2.elb.amazonaws.com"
    test_cluster_health('analytics-cluster', 'us-west-2', analytics_alb)

    # Cross-cluster tests
    test_both_clusters_same_version(prod_alb, analytics_alb)

    print(f"\n{'='*60}")
    print("✓ ALL TESTS PASSED")
    print(f"{'='*60}")

    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"\n✗ TEST FAILED: {e}")
        sys.exit(1)
```

### 8.2 Load Testing

```bash
#!/bin/bash
# load-test.sh
# Simple load test for deployed service

ENDPOINT=$1
DURATION=${2:-60}  # seconds
CONCURRENCY=${3:-10}

echo "Running load test against ${ENDPOINT}"
echo "Duration: ${DURATION}s, Concurrency: ${CONCURRENCY}"

# Using Apache Bench
ab -t ${DURATION} -c ${CONCURRENCY} -k http://${ENDPOINT}/health

# Or using wrk
# wrk -t${CONCURRENCY} -c${CONCURRENCY} -d${DURATION}s http://${ENDPOINT}/health
```

---

## 9. Troubleshooting

### Common Issues and Solutions

#### Issue 1: Delegate Not Connecting

**Symptoms:**
- Pipeline execution stuck at "Waiting for delegate"
- Delegate shows as "DISCONNECTED" in Harness UI

**Solution:**
```bash
# Check delegate pods
kubectl get pods -n harness-delegate-ng

# Check delegate logs
kubectl logs -f delegate-prod-xxxxx -n harness-delegate-ng

# Common fixes:
# 1. Verify delegate token
kubectl get secret delegate-prod-account-token -n harness-delegate-ng -o yaml

# 2. Check network connectivity
kubectl exec -it delegate-prod-xxxxx -n harness-delegate-ng -- curl https://app.harness.io/health

# 3. Restart delegate
kubectl rollout restart deployment/delegate-prod -n harness-delegate-ng
```

#### Issue 2: Task Definition Registration Fails

**Symptoms:**
- Pipeline fails at "Create Green Service" step
- Error: "Unable to register task definition"

**Solution:**
```bash
# Check IAM role permissions
aws ecs register-task-definition --cli-input-json file://task-def.json --region us-east-1

# Verify execution role exists
aws iam get-role --role-name notification-service-execution-role

# Check task role exists
aws iam get-role --role-name notification-service-task-role

# Verify ECR image exists
aws ecr describe-images --repository-name notification-service --region us-east-1
```

#### Issue 3: Health Checks Failing

**Symptoms:**
- Tasks start but quickly stop
- "Unhealthy" status in ECS console

**Solution:**
```bash
# Check task logs
aws logs tail /ecs/notification-service-prod --follow

# Check container health command
aws ecs describe-task-definition \
  --task-definition notification-service-prod \
  --query 'taskDefinition.containerDefinitions[0].healthCheck'

# Test health endpoint manually
TASK_IP=$(aws ecs describe-tasks \
  --cluster prod-cluster \
  --tasks <task-arn> \
  --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' \
  --output text)

curl http://${TASK_IP}:8083/health
```

#### Issue 4: Traffic Not Shifting

**Symptoms:**
- Green service created but no traffic
- Old service still receiving 100% traffic

**Solution:**
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <tg-arn> \
  --region us-east-1

# Check listener rules
aws elbv2 describe-rules \
  --listener-arn <listener-arn> \
  --region us-east-1

# Manually update listener rule if needed
aws elbv2 modify-rule \
  --rule-arn <rule-arn> \
  --actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"<green-tg-arn>","Weight":100}
    ]
  }'
```

#### Issue 5: Cross-Region Replication Not Working

**Symptoms:**
- Production deploys successfully
- Analytics deployment fails with "Image not found"

**Solution:**
```bash
# Check replication configuration
aws ecr describe-registry --region us-east-1

# Enable replication
aws ecr put-replication-configuration \
  --replication-configuration '{
    "rules": [{
      "destinations": [{"region": "us-west-2", "registryId": "123456789012"}]
    }]
  }' \
  --region us-east-1

# Manually replicate image
aws ecr batch-get-image \
  --repository-name notification-service \
  --image-ids imageTag=v1.3.0 \
  --region us-east-1 \
  --query 'images[].imageManifest' \
  --output text | \
aws ecr put-image \
  --repository-name notification-service \
  --image-tag v1.3.0 \
  --image-manifest file:///dev/stdin \
  --region us-west-2
```

---

## 10. Quick Reference

### Environment Variables

```bash
# Production Cluster
export PROD_CLUSTER="prod-cluster"
export PROD_REGION="us-east-1"
export PROD_ALB="prod-alb-123456789.us-east-1.elb.amazonaws.com"

# Analytics Cluster
export ANALYTICS_CLUSTER="analytics-cluster"
export ANALYTICS_REGION="us-west-2"
export ANALYTICS_ALB="analytics-alb-987654321.us-west-2.elb.amazonaws.com"

# ECR
export ECR_REPO="123456789012.dkr.ecr.us-east-1.amazonaws.com/notification-service"
```

### Useful Commands

```bash
# Check cluster status
aws ecs describe-clusters --clusters ${PROD_CLUSTER} --region ${PROD_REGION}

# List services
aws ecs list-services --cluster ${PROD_CLUSTER} --region ${PROD_REGION}

# Get service details
aws ecs describe-services \
  --cluster ${PROD_CLUSTER} \
  --services notification-service \
  --region ${PROD_REGION}

# List tasks
aws ecs list-tasks \
  --cluster ${PROD_CLUSTER} \
  --service-name notification-service \
  --region ${PROD_REGION}

# Get task details
aws ecs describe-tasks \
  --cluster ${PROD_CLUSTER} \
  --tasks <task-arn> \
  --region ${PROD_REGION}

# View logs
aws logs tail /ecs/notification-service-prod --follow

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <tg-arn> \
  --region ${PROD_REGION}
```

---

## Summary

This guide provides:

✅ Complete architecture for multi-cluster deployment
✅ All AWS infrastructure setup scripts
✅ Full Harness pipeline configuration (copy-paste ready)
✅ Deployment, health check, and rollback scripts
✅ Step-by-step demo walkthrough
✅ Integration tests
✅ Comprehensive troubleshooting guide

**Deployment Stats:**
- **Total Time**: ~20-25 minutes (both clusters)
- **Rollback Time**: < 2 minutes per cluster
- **Validation**: Parallel across clusters
- **Zero Downtime**: Blue-Green strategy

**Demo Duration**: 30-40 minutes including:
- Setup verification: 2 min
- Build & push: 3 min
- Pipeline execution: 20-25 min
- Verification: 3 min
- Q&A buffer: 5-10 min

---

**Document Version**: 1.0
**Last Updated**: January 10, 2026
**Classification**: Customer-Sharable / Demo-Ready

**END OF GUIDE**
