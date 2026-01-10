# Harness CD: Architecture Guide - Part 2
## ECS Deployment End-to-End Flow & Additional Architecture

---

## ECS Deployment End-to-End Flow

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        ECS DEPLOYMENT END-TO-END FLOW                                  │
│                                                                                         │
│  PHASE 1: TRIGGER & INITIALIZATION                                                     │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌──────────────┐                                                                      │
│  │   CI Pipeline│                                                                      │
│  │   Completes  │                                                                      │
│  └──────┬───────┘                                                                      │
│         │                                                                               │
│         ▼                                                                               │
│  ┌─────────────────────────┐                                                          │
│  │   Docker Build          │                                                          │
│  │   & Push to ECR         │                                                          │
│  │                         │                                                          │
│  │   • Build Docker image  │                                                          │
│  │   • Tag: v1.2.3         │                                                          │
│  │   • Push to ECR         │                                                          │
│  └──────┬──────────────────┘                                                          │
│         │                                                                               │
│         ▼                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │   AWS ECR (Elastic Container Registry)                                  │         │
│  │   Repository: 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp       │         │
│  │   Image: myapp:v1.2.3                                                   │         │
│  │   Size: 350 MB                                                          │         │
│  │   Layers: 15                                                            │         │
│  │   Digest: sha256:def789abc456...                                        │         │
│  │   Scan Result: No vulnerabilities                                       │         │
│  └──────┬──────────────────────────────────────────────────────────────────┘         │
│         │                                                                               │
│         │ Webhook Event / SNS Notification                                             │
│         ▼                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │                  HARNESS CD CONTROL PLANE                                │         │
│  │                                                                           │         │
│  │  Step 1: Pipeline Trigger                                                │         │
│  │  ──────────────────────────                                              │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • ECR image push event received                      │              │         │
│  │  │  • Validate image tag matches expected pattern        │              │         │
│  │  │  • Extract image metadata (digest, size, layers)      │              │         │
│  │  │  • Create pipeline execution instance                 │              │         │
│  │  │  • Assign execution ID: exec-20260110-002345         │              │         │
│  │  │  • Pipeline: ecs-prod-deployment                     │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │                                                                           │         │
│  │  Step 2: Service Resolution                                              │         │
│  │  ───────────────────────────                                             │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Fetch service definition: myapp-ecs-service       │              │         │
│  │  │  • Resolve artifact:                                  │              │         │
│  │  │    - Repository: myapp                                │              │         │
│  │  │    - Tag: v1.2.3                                      │              │         │
│  │  │    - Full image path:                                 │              │         │
│  │  │      123456789012.dkr.ecr.us-east-1.amazonaws.com/   │              │         │
│  │  │      myapp:v1.2.3                                     │              │         │
│  │  │  • Fetch task definition (family: myapp-task)        │              │         │
│  │  │  • Resolve configuration variables                    │              │         │
│  │  │  • Fetch secrets from AWS Secrets Manager            │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │                                                                           │         │
│  │  Step 3: Environment Selection                                           │         │
│  │  ──────────────────────────────                                          │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Target environment: Production                     │              │         │
│  │  │  • Load infrastructure definition                     │              │         │
│  │  │  • ECS Cluster: prod-ecs-cluster                     │              │         │
│  │  │  • Region: us-east-1                                 │              │         │
│  │  │  • Service Name: myapp-service                       │              │         │
│  │  │  • Desired Task Count: 10                            │              │         │
│  │  │  • Validate AWS connectivity                         │              │         │
│  │  │  • Check IAM permissions                             │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │                                                                           │         │
│  │  Step 4: Delegate Selection                                              │         │
│  │  ───────────────────────────                                             │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Query available delegates in AWS VPC               │              │         │
│  │  │  • Filter by selector tags: [aws, production]        │              │         │
│  │  │  • Check delegate health and AWS connectivity        │              │         │
│  │  │  • Verify IAM role permissions                       │              │         │
│  │  │  • Select delegate: delegate-aws-prod-01             │              │         │
│  │  │  • Assign ECS deployment task                        │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │                                                                           │         │
│  └───────────────────────────────────┬───────────────────────────────────────┘         │
│                                      │                                                 │
│                                      │ Task Assignment (WebSocket)                     │
│                                      ▼                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              AWS VPC - HARNESS DELEGATE                                  │         │
│  │                                                                           │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Delegate: delegate-aws-prod-01                      │              │         │
│  │  │  Status: Received ECS deployment task                │              │         │
│  │  │  Task ID: task-20260110-002345                       │              │         │
│  │  │  Target: ECS Cluster prod-ecs-cluster                │              │         │
│  │  │  Service: myapp-service                              │              │         │
│  │  │  Strategy: Blue-Green Deployment                     │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  PHASE 2: PRE-DEPLOYMENT VALIDATION                                                    │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              DELEGATE - AWS CONNECTIVITY & VALIDATION                    │         │
│  │                                                                           │         │
│  │  Step 1: AWS Authentication                                              │         │
│  │  ───────────────────────────                                             │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Assume IAM role for ECS operations                │              │         │
│  │  │    Role ARN: arn:aws:iam::123456789012:role/        │              │         │
│  │  │              HarnessECSDeploymentRole                │              │         │
│  │  │                                                       │              │         │
│  │  │  • Permissions validated:                            │              │         │
│  │  │    ✓ ecs:DescribeServices                            │              │         │
│  │  │    ✓ ecs:DescribeTasks                               │              │         │
│  │  │    ✓ ecs:DescribeTaskDefinition                      │              │         │
│  │  │    ✓ ecs:RegisterTaskDefinition                      │              │         │
│  │  │    ✓ ecs:UpdateService                               │              │         │
│  │  │    ✓ ecs:RunTask                                     │              │         │
│  │  │    ✓ ecs:StopTask                                    │              │         │
│  │  │    ✓ elasticloadbalancing:*                          │              │         │
│  │  │    ✓ ec2:DescribeSubnets                             │              │         │
│  │  │    ✓ ec2:DescribeSecurityGroups                      │              │         │
│  │  │    ✓ ecr:GetAuthorizationToken                       │              │         │
│  │  │    ✓ ecr:BatchGetImage                               │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: AWS authentication successful ✓             │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 2: ECR Image Verification                                          │         │
│  │  ────────────────────────────────                                        │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Authenticate with ECR                              │              │         │
│  │  │    aws ecr get-login-password --region us-east-1     │              │         │
│  │  │    Status: ECR authenticated ✓                       │              │         │
│  │  │                                                       │              │         │
│  │  │  • Verify image exists                               │              │         │
│  │  │    aws ecr describe-images \                         │              │         │
│  │  │      --repository-name myapp \                       │              │         │
│  │  │      --image-ids imageTag=v1.2.3                     │              │         │
│  │  │                                                       │              │         │
│  │  │  Image Details:                                      │              │         │
│  │  │    • Tag: v1.2.3                                     │              │         │
│  │  │    • Digest: sha256:def789abc456...                 │              │         │
│  │  │    • Size: 350 MB                                    │              │         │
│  │  │    • Pushed At: 2026-01-10T14:30:00Z                │              │         │
│  │  │    • Scan Status: COMPLETE                           │              │         │
│  │  │    • Vulnerabilities: 0 CRITICAL, 0 HIGH            │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: Image verified ✓                            │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 3: Get Current ECS Service State                                   │         │
│  │  ───────────────────────────────────                                     │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Execute AWS CLI command:                            │              │         │
│  │  │                                                       │              │         │
│  │  │  aws ecs describe-services \                         │              │         │
│  │  │    --cluster prod-ecs-cluster \                      │              │         │
│  │  │    --services myapp-service                          │              │         │
│  │  │                                                       │              │         │
│  │  │  Current Service State:                              │              │         │
│  │  │  {                                                    │              │         │
│  │  │    "serviceName": "myapp-service",                   │              │         │
│  │  │    "clusterArn": "arn:aws:ecs:us-east-1:...",       │              │         │
│  │  │    "status": "ACTIVE",                               │              │         │
│  │  │    "desiredCount": 10,                               │              │         │
│  │  │    "runningCount": 10,                               │              │         │
│  │  │    "pendingCount": 0,                                │              │         │
│  │  │    "launchType": "FARGATE",                          │              │         │
│  │  │    "platformVersion": "1.4.0",                       │              │         │
│  │  │    "taskDefinition": "arn:aws:ecs:...:task-def/     │              │         │
│  │  │                       myapp-task:14",                │              │         │
│  │  │    "loadBalancers": [                                │              │         │
│  │  │      {                                                │              │         │
│  │  │        "targetGroupArn": "arn:aws:elb:...",          │              │         │
│  │  │        "containerName": "myapp-container",           │              │         │
│  │  │        "containerPort": 8080                         │              │         │
│  │  │      }                                                │              │         │
│  │  │    ],                                                 │              │         │
│  │  │    "healthCheckGracePeriodSeconds": 60,              │              │         │
│  │  │    "deploymentConfiguration": {                      │              │         │
│  │  │      "maximumPercent": 200,                          │              │         │
│  │  │      "minimumHealthyPercent": 100                    │              │         │
│  │  │    }                                                  │              │         │
│  │  │  }                                                    │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: Service is healthy and stable ✓            │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 4: Get Current Task Definition                                     │         │
│  │  ─────────────────────────────────                                       │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Fetch current task definition (revision 14):        │              │         │
│  │  │                                                       │              │         │
│  │  │  aws ecs describe-task-definition \                  │              │         │
│  │  │    --task-definition myapp-task:14                   │              │         │
│  │  │                                                       │              │         │
│  │  │  Current Task Definition:                            │              │         │
│  │  │  {                                                    │              │         │
│  │  │    "family": "myapp-task",                           │              │         │
│  │  │    "revision": "14",                                 │              │         │
│  │  │    "taskRoleArn": "arn:aws:iam::...:role/...",      │              │         │
│  │  │    "executionRoleArn": "arn:aws:iam::...:role/...", │              │         │
│  │  │    "networkMode": "awsvpc",                          │              │         │
│  │  │    "containerDefinitions": [                         │              │         │
│  │  │      {                                                │              │         │
│  │  │        "name": "myapp-container",                    │              │         │
│  │  │        "image": "123456789012.dkr.ecr.us-east-1.../ │              │         │
│  │  │                 myapp:v1.2.2",                       │              │         │
│  │  │        "cpu": 256,                                   │              │         │
│  │  │        "memory": 512,                                │              │         │
│  │  │        "portMappings": [                             │              │         │
│  │  │          {                                            │              │         │
│  │  │            "containerPort": 8080,                    │              │         │
│  │  │            "protocol": "tcp"                         │              │         │
│  │  │          }                                            │              │         │
│  │  │        ],                                             │              │         │
│  │  │        "environment": [                               │              │         │
│  │  │          {"name": "ENVIRONMENT", "value": "prod"},   │              │         │
│  │  │          {"name": "LOG_LEVEL", "value": "INFO"}     │              │         │
│  │  │        ],                                             │              │         │
│  │  │        "logConfiguration": {                         │              │         │
│  │  │          "logDriver": "awslogs",                     │              │         │
│  │  │          "options": {                                │              │         │
│  │  │            "awslogs-group": "/ecs/myapp",           │              │         │
│  │  │            "awslogs-region": "us-east-1",           │              │         │
│  │  │            "awslogs-stream-prefix": "ecs"           │              │         │
│  │  │          }                                            │              │         │
│  │  │        }                                              │              │         │
│  │  │      }                                                │              │         │
│  │  │    ],                                                 │              │         │
│  │  │    "requiresCompatibilities": ["FARGATE"],           │              │         │
│  │  │    "cpu": "256",                                     │              │         │
│  │  │    "memory": "512"                                   │              │         │
│  │  │  }                                                    │              │         │
│  │  │                                                       │              │         │
│  │  │  Saved as baseline for rollback                      │              │         │
│  │  │  Status: Task definition retrieved ✓                 │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 5: Validate ECS Cluster Capacity                                   │         │
│  │  ───────────────────────────────────────                                 │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Check cluster capacity for new tasks:               │              │         │
│  │  │                                                       │              │         │
│  │  │  aws ecs describe-clusters \                         │              │         │
│  │  │    --clusters prod-ecs-cluster                       │              │         │
│  │  │                                                       │              │         │
│  │  │  Cluster Status:                                     │              │         │
│  │  │  • Status: ACTIVE                                    │              │         │
│  │  │  • Registered Container Instances: 0 (Fargate)      │              │         │
│  │  │  • Active Services: 5                                │              │         │
│  │  │  • Running Tasks: 25                                 │              │         │
│  │  │  • Pending Tasks: 0                                  │              │         │
│  │  │                                                       │              │         │
│  │  │  Fargate Capacity:                                   │              │         │
│  │  │  • Service Quotas checked                            │              │         │
│  │  │  • Max Fargate tasks per cluster: 1000              │              │         │
│  │  │  • Current usage: 25                                 │              │         │
│  │  │  • Available capacity: 975                           │              │         │
│  │  │  • Required for deployment: 10 (new tasks)          │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: Sufficient capacity available ✓            │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  PHASE 3: TASK DEFINITION CREATION                                                     │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              CREATE NEW TASK DEFINITION REVISION                         │         │
│  │                                                                           │         │
│  │  Step 1: Build New Task Definition                                       │         │
│  │  ──────────────────────────────────                                      │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Clone current task definition (revision 14)       │              │         │
│  │  │  • Update container image:                           │              │         │
│  │  │    FROM: myapp:v1.2.2                                │              │         │
│  │  │    TO:   myapp:v1.2.3                                │              │         │
│  │  │                                                       │              │         │
│  │  │  • Update environment variables (if changed):        │              │         │
│  │  │    VERSION: v1.2.3                                   │              │         │
│  │  │    DEPLOYMENT_TIME: 2026-01-10T15:00:00Z            │              │         │
│  │  │                                                       │              │         │
│  │  │  • Inject secrets from AWS Secrets Manager:          │              │         │
│  │  │    DB_PASSWORD: (from secretsmanager)                │              │         │
│  │  │    API_KEY: (from secretsmanager)                    │              │         │
│  │  │                                                       │              │         │
│  │  │  • Maintain all other settings:                      │              │         │
│  │  │    - Resource limits (CPU: 256, Memory: 512)         │              │         │
│  │  │    - Port mappings (8080)                            │              │         │
│  │  │    - Log configuration (CloudWatch Logs)             │              │         │
│  │  │    - IAM roles                                       │              │         │
│  │  │    - Network mode (awsvpc)                           │              │         │
│  │  │                                                       │              │         │
│  │  │  New Task Definition JSON prepared                   │              │         │
│  │  │  Status: Task definition built ✓                     │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 2: Register New Task Definition                                    │         │
│  │  ─────────────────────────────────────                                   │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Register new revision with AWS ECS:                 │              │         │
│  │  │                                                       │              │         │
│  │  │  aws ecs register-task-definition \                  │              │         │
│  │  │    --cli-input-json file://new-task-def.json        │              │         │
│  │  │                                                       │              │         │
│  │  │  Response:                                            │              │         │
│  │  │  {                                                    │              │         │
│  │  │    "taskDefinition": {                               │              │         │
│  │  │      "family": "myapp-task",                         │              │         │
│  │  │      "revision": "15",                               │              │         │
│  │  │      "taskDefinitionArn": "arn:aws:ecs:us-east-1:   │              │         │
│  │  │        123456789012:task-definition/myapp-task:15",  │              │         │
│  │  │      "status": "ACTIVE",                             │              │         │
│  │  │      "registeredAt": "2026-01-10T15:00:15Z"         │              │         │
│  │  │    }                                                  │              │         │
│  │  │  }                                                    │              │         │
│  │  │                                                       │              │         │
│  │  │  New task definition ARN:                            │              │         │
│  │  │  arn:aws:ecs:us-east-1:123456789012:task-definition/│              │         │
│  │  │  myapp-task:15                                       │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: Task definition registered ✓                │              │         │
│  │  │  Revision: 15                                        │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 3: Validate Task Definition                                        │         │
│  │  ──────────────────────────────────                                      │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Validation checks:                                   │              │         │
│  │  │                                                       │              │         │
│  │  │  ✓ Container image exists in ECR                     │              │         │
│  │  │  ✓ Resource limits are valid                         │              │         │
│  │  │  ✓ IAM roles exist and have required permissions     │              │         │
│  │  │  ✓ Network configuration is valid                    │              │         │
│  │  │  ✓ Log configuration is correct                      │              │         │
│  │  │  ✓ Environment variables syntax is valid             │              │         │
│  │  │  ✓ Secrets are accessible                            │              │         │
│  │  │  ✓ Port mappings are valid                           │              │         │
│  │  │                                                       │              │         │
│  │  │  All validations passed ✓                            │              │         │
│  │  │  Ready for deployment                                │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  PHASE 4: BLUE-GREEN DEPLOYMENT EXECUTION                                              │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              BLUE-GREEN DEPLOYMENT STRATEGY                              │         │
│  │                                                                           │         │
│  │  Current State: Blue Environment (v1.2.2)                                │         │
│  │  Target State: Green Environment (v1.2.3)                                │         │
│  │                                                                           │         │
│  │  Step 1: Create Green Target Group                                       │         │
│  │  ───────────────────────────────────                                     │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Create new ALB target group for green deployment:   │              │         │
│  │  │                                                       │              │         │
│  │  │  aws elbv2 create-target-group \                     │              │         │
│  │  │    --name myapp-tg-green \                           │              │         │
│  │  │    --protocol HTTP \                                 │              │         │
│  │  │    --port 8080 \                                     │              │         │
│  │  │    --vpc-id vpc-12345678 \                           │              │         │
│  │  │    --target-type ip \                                │              │         │
│  │  │    --health-check-enabled \                          │              │         │
│  │  │    --health-check-path /health \                     │              │         │
│  │  │    --health-check-interval-seconds 30 \              │              │         │
│  │  │    --health-check-timeout-seconds 5 \                │              │         │
│  │  │    --healthy-threshold-count 2 \                     │              │         │
│  │  │    --unhealthy-threshold-count 3                     │              │         │
│  │  │                                                       │              │         │
│  │  │  New Target Group ARN:                               │              │         │
│  │  │  arn:aws:elasticloadbalancing:us-east-1:            │              │         │
│  │  │  123456789012:targetgroup/myapp-tg-green/abc123     │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: Green target group created ✓                │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 2: Deploy Green Environment                                        │         │
│  │  ──────────────────────────────────                                      │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Update ECS service with new task definition:        │              │         │
│  │  │                                                       │              │         │
│  │  │  aws ecs update-service \                            │              │         │
│  │  │    --cluster prod-ecs-cluster \                      │              │         │
│  │  │    --service myapp-service \                         │              │         │
│  │  │    --task-definition myapp-task:15 \                 │              │         │
│  │  │    --load-balancers \                                │              │         │
│  │  │      targetGroupArn=arn:...:myapp-tg-green,\         │              │         │
│  │  │      containerName=myapp-container,\                 │              │         │
│  │  │      containerPort=8080 \                            │              │         │
│  │  │    --force-new-deployment                            │              │         │
│  │  │                                                       │              │         │
│  │  │  ECS starts deploying green environment:             │              │         │
│  │  │                                                       │              │         │
│  │  │  [00:00] Starting new tasks with revision 15         │              │         │
│  │  │  [00:30] Task 1 - PROVISIONING                       │              │         │
│  │  │  [01:00] Task 1 - PENDING (pulling image)            │              │         │
│  │  │  [02:00] Task 1 - RUNNING                            │              │         │
│  │  │  [02:30] Task 1 - Registered with TG (initial)       │              │         │
│  │  │  [03:00] Task 1 - Health check 1/2 passed            │              │         │
│  │  │  [03:30] Task 1 - Health check 2/2 passed ✓          │              │         │
│  │  │  [03:30] Task 1 - HEALTHY                            │              │         │
│  │  │                                                       │              │         │
│  │  │  [03:30] Starting Task 2...                          │              │         │
│  │  │  ... (repeat for all 10 tasks)                       │              │         │
│  │  │                                                       │              │         │
│  │  │  [15:00] All 10 green tasks running and healthy ✓    │              │         │
│  │  │                                                       │              │         │
│  │  │  Green Environment Status:                           │              │         │
│  │  │  • Running Tasks: 10                                 │              │         │
│  │  │  • Healthy Tasks: 10                                 │              │         │
│  │  │  • Task Definition: myapp-task:15 (v1.2.3)          │              │         │
│  │  │  • Target Group: myapp-tg-green                     │              │         │
│  │  │  • Registered Targets: 10                            │              │         │
│  │  │  • Healthy Targets: 10                               │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 3: Verify Green Environment                                        │         │
│  │  ──────────────────────────────────                                      │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Run health checks and smoke tests on green:         │              │         │
│  │  │                                                       │              │         │
│  │  │  # Test via green target group                       │              │         │
│  │  │  for i in {1..10}; do                                │              │         │
│  │  │    curl http://green-test-alb.internal/health        │              │         │
│  │  │    curl http://green-test-alb.internal/api/v1/status │              │         │
│  │  │    sleep 1                                           │              │         │
│  │  │  done                                                 │              │         │
│  │  │                                                       │              │         │
│  │  │  Results:                                             │              │         │
│  │  │  • Health checks: 10/10 passed ✓                     │              │         │
│  │  │  • API status checks: 10/10 passed ✓                 │              │         │
│  │  │  • Average response time: 92ms                       │              │         │
│  │  │  • Error rate: 0%                                    │              │         │
│  │  │                                                       │              │         │
│  │  │  # Test database connectivity                        │              │         │
│  │  │  curl http://green-test-alb.internal/health/db       │              │         │
│  │  │  Response: {"status":"UP","connections":10}          │              │         │
│  │  │  Status: Database connectivity OK ✓                  │              │         │
│  │  │                                                       │              │         │
│  │  │  # Test external dependencies                        │              │         │
│  │  │  curl http://green-test-alb.internal/health/deps     │              │         │
│  │  │  Response: {"redis":"UP","kafka":"UP","s3":"UP"}     │              │         │
│  │  │  Status: All dependencies OK ✓                       │              │         │
│  │  │                                                       │              │         │
│  │  │  Green environment verified ✓                        │              │         │
│  │  │  Ready for traffic shift                             │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 4: Traffic Shift - 10% to Green                                    │         │
│  │  ──────────────────────────────────────                                  │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Modify ALB listener rule to send 10% traffic:       │              │         │
│  │  │                                                       │              │         │
│  │  │  aws elbv2 modify-listener \                         │              │         │
│  │  │    --listener-arn arn:aws:elb:...:listener/...      │              │         │
│  │  │    --default-actions \                               │              │         │
│  │  │      Type=forward,\                                  │              │         │
│  │  │      ForwardConfig='{                                │              │         │
│  │  │        "TargetGroups": [                             │              │         │
│  │  │          {                                            │              │         │
│  │  │            "TargetGroupArn": "arn:...:myapp-tg-blue",│              │         │
│  │  │            "Weight": 90                              │              │         │
│  │  │          },                                           │              │         │
│  │  │          {                                            │              │         │
│  │  │            "TargetGroupArn": "arn:...:myapp-tg-green",│              │         │
│  │  │            "Weight": 10                              │              │         │
│  │  │          }                                            │              │         │
│  │  │        ]                                              │              │         │
│  │  │      }'                                               │              │         │
│  │  │                                                       │              │         │
│  │  │  Traffic Distribution:                               │              │         │
│  │  │  • Blue (v1.2.2): 90% - ~1,125 req/min              │              │         │
│  │  │  • Green (v1.2.3): 10% - ~125 req/min               │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: 10% traffic shifted to green ✓              │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 5: Monitor Green with 10% Traffic (5 minutes)                      │         │
│  │  ────────────────────────────────────────────────────                    │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Continuous monitoring via Harness CV:                │              │         │
│  │  │                                                       │              │         │
│  │  │  Metrics Comparison (5-minute window):               │              │         │
│  │  │                                                       │              │         │
│  │  │  Error Rate:                                         │              │         │
│  │  │  • Blue: 0.18%                                       │              │         │
│  │  │  • Green: 0.14% (-22% ✓)                            │              │         │
│  │  │                                                       │              │         │
│  │  │  Response Time (P95):                                │              │         │
│  │  │  • Blue: 125ms                                       │              │         │
│  │  │  • Green: 118ms (-5.6% ✓)                           │              │         │
│  │  │                                                       │              │         │
│  │  │  CPU Usage:                                          │              │         │
│  │  │  • Blue: 35%                                         │              │         │
│  │  │  • Green: 32% (-8.6% ✓)                             │              │         │
│  │  │                                                       │              │         │
│  │  │  Memory Usage:                                       │              │         │
│  │  │  • Blue: 480 MB                                      │              │         │
│  │  │  • Green: 465 MB (-3.1% ✓)                          │              │         │
│  │  │                                                       │              │         │
│  │  │  HTTP 5xx Errors:                                    │              │         │
│  │  │  • Blue: 2.5/min                                     │              │         │
│  │  │  • Green: 1.8/min (-28% ✓)                          │              │         │
│  │  │                                                       │              │         │
│  │  │  All metrics within acceptable thresholds ✓          │              │         │
│  │  │  No anomalies detected                               │              │         │
│  │  │  Decision: Continue to 50% traffic                   │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 6: Traffic Shift - 50% to Green                                    │         │
│  │  ──────────────────────────────────────                                  │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Update ALB listener for 50/50 split:                │              │         │
│  │  │                                                       │              │         │
│  │  │  Traffic Distribution:                               │              │         │
│  │  │  • Blue (v1.2.2): 50% - ~625 req/min                │              │         │
│  │  │  • Green (v1.2.3): 50% - ~625 req/min               │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: 50% traffic shifted to green ✓              │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 7: Monitor Green with 50% Traffic (10 minutes)                     │         │
│  │  ─────────────────────────────────────────────────────                   │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Extended monitoring with higher traffic:             │              │         │
│  │  │                                                       │              │         │
│  │  │  All metrics remain stable ✓                         │              │         │
│  │  │  Error rates comparable or better                    │              │         │
│  │  │  Response times consistent                           │              │         │
│  │  │  No performance degradation                          │              │         │
│  │  │  User experience metrics positive                    │              │         │
│  │  │                                                       │              │         │
│  │  │  Decision: Proceed to 100% traffic                   │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 8: Traffic Shift - 100% to Green                                   │         │
│  │  ───────────────────────────────────────                                 │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Final traffic shift - all traffic to green:         │              │         │
│  │  │                                                       │              │         │
│  │  │  aws elbv2 modify-listener \                         │              │         │
│  │  │    --listener-arn arn:aws:elb:...:listener/...      │              │         │
│  │  │    --default-actions \                               │              │         │
│  │  │      Type=forward,\                                  │              │         │
│  │  │      TargetGroupArn=arn:...:myapp-tg-green          │              │         │
│  │  │                                                       │              │         │
│  │  │  Traffic Distribution:                               │              │         │
│  │  │  • Blue (v1.2.2): 0% - 0 req/min                    │              │         │
│  │  │  • Green (v1.2.3): 100% - ~1,250 req/min            │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: 100% traffic on green ✓                     │              │         │
│  │  │  Blue environment on standby for rollback            │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 9: Monitor Production Traffic (30 minutes)                         │         │
│  │  ─────────────────────────────────────────────                           │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Final verification with full production load:        │              │         │
│  │  │                                                       │              │         │
│  │  │  Monitoring Period: 30 minutes                       │              │         │
│  │  │  All metrics stable and within thresholds ✓          │              │         │
│  │  │  No errors or degradation detected                   │              │         │
│  │  │  User transactions processing normally               │              │         │
│  │  │  Business metrics tracking as expected               │              │         │
│  │  │                                                       │              │         │
│  │  │  Decision: Deployment successful                     │              │         │
│  │  │  Proceed to cleanup                                  │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 10: Cleanup Blue Environment                                       │         │
│  │  ───────────────────────────────────                                     │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Stop blue tasks and cleanup resources:               │              │         │
│  │  │                                                       │              │         │
│  │  │  # Stop blue tasks (old revision 14)                 │              │         │
│  │  │  for task_arn in $(aws ecs list-tasks \              │              │         │
│  │  │      --cluster prod-ecs-cluster \                    │              │         │
│  │  │      --family myapp-task \                           │              │         │
│  │  │      --query 'taskArns[*]' --output text); do       │              │         │
│  │  │                                                       │              │         │
│  │  │    # Check if task is running old revision           │              │         │
│  │  │    REVISION=$(aws ecs describe-tasks \               │              │         │
│  │  │      --cluster prod-ecs-cluster \                    │              │         │
│  │  │      --tasks $task_arn \                             │              │         │
│  │  │      --query 'tasks[0].taskDefinitionArn' \          │              │         │
│  │  │      --output text | grep -o ':14$')                 │              │         │
│  │  │                                                       │              │         │
│  │  │    if [ "$REVISION" = ":14" ]; then                  │              │         │
│  │  │      aws ecs stop-task \                             │              │         │
│  │  │        --cluster prod-ecs-cluster \                  │              │         │
│  │  │        --task $task_arn                              │              │         │
│  │  │    fi                                                 │              │         │
│  │  │  done                                                 │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: 10 blue tasks stopped ✓                     │              │         │
│  │  │                                                       │              │         │
│  │  │  # Delete blue target group (after 24h hold)         │              │         │
│  │  │  aws elbv2 delete-target-group \                     │              │         │
│  │  │    --target-group-arn arn:...:myapp-tg-blue         │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: Blue target group deleted ✓                 │              │         │
│  │  │                                                       │              │         │
│  │  │  # Rename green target group to blue (optional)      │              │         │
│  │  │  # for next deployment cycle                         │              │         │
│  │  │                                                       │              │         │
│  │  │  Cleanup complete ✓                                  │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  PHASE 5: CONTINUOUS VERIFICATION & COMPLETION                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              CONTINUOUS VERIFICATION (Post-Deployment)                   │         │
│  │                                                                           │         │
│  │  Same verification process as VM deployment                              │         │
│  │  (See VM deployment Phase 6 for details)                                 │         │
│  │                                                                           │         │
│  │  CloudWatch Metrics:                                                     │         │
│  │  • ECS Service: CPUUtilization, MemoryUtilization                       │         │
│  │  • ALB: TargetResponseTime, HTTPCode_Target_5XX_Count                   │         │
│  │  • Custom Metrics: Business transactions, API calls                      │         │
│  │                                                                           │         │
│  │  Container Insights:                                                     │         │
│  │  • Task-level metrics                                                    │         │
│  │  • Container resource usage                                              │         │
│  │  • Network metrics                                                       │         │
│  │                                                                           │         │
│  │  Status: All verification checks passed ✓                                │         │
│  │  Deployment marked as successful                                         │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              COMPLETION & NOTIFICATION                                   │         │
│  │                                                                           │         │
│  │  Deployment Summary:                                                     │         │
│  │  ├─ Pipeline: ecs-prod-deployment                                        │         │
│  │  ├─ Service: myapp-ecs-service                                           │         │
│  │  ├─ Image: myapp:v1.2.3                                                  │         │
│  │  ├─ Task Definition: myapp-task:15                                       │         │
│  │  ├─ Environment: Production                                              │         │
│  │  ├─ Tasks: 10 (all healthy)                                              │         │
│  │  ├─ Strategy: Blue-Green                                                 │         │
│  │  ├─ Start Time: 2026-01-10 15:00:00 UTC                                 │         │
│  │  ├─ End Time: 2026-01-10 15:55:00 UTC                                   │         │
│  │  └─ Duration: 55 minutes                                                 │         │
│  │                                                                           │         │
│  │  Status: SUCCESS ✓                                                       │         │
│  │                                                                           │         │
│  │  Notifications sent via:                                                 │         │
│  │  • Email, Slack, Jira, PagerDuty                                         │         │
│  │  • Deployment annotation in Grafana/CloudWatch                           │         │
│  │  • Audit trail updated                                                   │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  ECS DEPLOYMENT COMPLETE                                                               │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Network Architecture

### Multi-Region Network Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                            GLOBAL NETWORK ARCHITECTURE                                   │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────┐    │
│  │                        HARNESS CD CONTROL PLANE (SaaS)                         │    │
│  │                                                                                 │    │
│  │  Global Endpoints:                                                             │    │
│  │  • app.harness.io (Primary - US)                                               │    │
│  │  • app.eu.harness.io (Europe)                                                  │    │
│  │  • app.ap.harness.io (Asia-Pacific)                                            │    │
│  │                                                                                 │    │
│  │  Features:                                                                      │    │
│  │  • Global CDN (CloudFlare/Akamai)                                              │    │
│  │  • DDoS Protection                                                              │    │
│  │  • 99.9% SLA                                                                    │    │
│  │  • TLS 1.3 Encryption                                                           │    │
│  └─────────────────────────────────────┬───────────────────────────────────────────┘    │
│                                        │                                                │
│                   WebSocket/HTTPS (Outbound from Delegates)                            │
│                   ┌─────────────────────┴─────────────────────┐                        │
│                   │                     │                     │                        │
│  ┌────────────────▼──────────────┐ ┌────▼────────────────┐ ┌─▼──────────────────────┐ │
│  │      REGION: US-EAST-1        │ │  REGION: EU-WEST-1  │ │  REGION: AP-SOUTH-1    │ │
│  │      (Primary Production)     │ │  (DR/Secondary)     │ │  (Dev/Test)            │ │
│  └───────────────────────────────┘ └─────────────────────┘ └────────────────────────┘ │
│                   │                                                                     │
└───────────────────┼─────────────────────────────────────────────────────────────────────┘
                    │
                    │
┌───────────────────▼─────────────────────────────────────────────────────────────────────┐
│                        AWS REGION: US-EAST-1 (Detailed View)                            │
│                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐  │
│  │                             VPC: 10.0.0.0/16                                      │  │
│  │                         prod-vpc (vpc-12345678)                                   │  │
│  │                                                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                         AVAILABILITY ZONE: us-east-1a                        │ │  │
│  │  │                                                                               │ │  │
│  │  │  ┌──────────────────────────────────────────────────────────────────────┐  │ │  │
│  │  │  │  PUBLIC SUBNET: 10.0.10.0/24 (public-subnet-1a)                      │  │ │  │
│  │  │  │                                                                        │  │ │  │
│  │  │  │  ┌─────────────────────┐  ┌─────────────────────┐                   │  │ │  │
│  │  │  │  │  Internet Gateway   │  │   NAT Gateway       │                   │  │ │  │
│  │  │  │  │  (igw-12345)        │  │   (nat-1a)          │                   │  │ │  │
│  │  │  │  │  • Public IP        │  │   • EIP: x.x.x.1    │                   │  │ │  │
│  │  │  │  └─────────────────────┘  └─────────────────────┘                   │  │ │  │
│  │  │  │                                                                        │  │ │  │
│  │  │  │  ┌─────────────────────────────────────────────────┐                │  │ │  │
│  │  │  │  │  Application Load Balancer (ALB)                │                │  │ │  │
│  │  │  │  │  • Public-facing                                │                │  │ │  │
│  │  │  │  │  • DNS: myapp-alb-123.elb.amazonaws.com        │                │  │ │  │
│  │  │  │  │  • Listeners: HTTP:80 (→443), HTTPS:443        │                │  │ │  │
│  │  │  │  │  • Security Group: allow 80,443 from 0.0.0.0/0 │                │  │ │  │
│  │  │  │  └─────────────────────────────────────────────────┘                │  │ │  │
│  │  │  └────────────────────────────────────────────────────────────────────┘  │ │  │
│  │  │                                                                               │ │  │
│  │  │  ┌──────────────────────────────────────────────────────────────────────┐  │ │  │
│  │  │  │  PRIVATE SUBNET: 10.0.1.0/24 (private-subnet-1a)                     │  │ │  │
│  │  │  │                                                                        │  │ │  │
│  │  │  │  ┌─────────────────────────────────────────────────┐                │  │ │  │
│  │  │  │  │  ECS Tasks (Fargate)                            │                │  │ │  │
│  │  │  │  │  • Task 1: 10.0.1.10 (ENI: eni-001)             │                │  │ │  │
│  │  │  │  │  • Task 2: 10.0.1.11 (ENI: eni-002)             │                │  │ │  │
│  │  │  │  │  • Task 3: 10.0.1.12 (ENI: eni-003)             │                │  │ │  │
│  │  │  │  │  Security Group: allow 8080 from ALB SG         │                │  │ │  │
│  │  │  │  └─────────────────────────────────────────────────┘                │  │ │  │
│  │  │  │                                                                        │  │ │  │
│  │  │  │  ┌─────────────────────────────────────────────────┐                │  │ │  │
│  │  │  │  │  VM Servers                                      │                │  │ │  │
│  │  │  │  │  • prod-vm-01: 10.0.1.20                        │                │  │ │  │
│  │  │  │  │  • prod-vm-02: 10.0.1.21                        │                │  │ │  │
│  │  │  │  │  Security Group: allow 22 from Delegate SG      │                │  │ │  │
│  │  │  │  │                  allow 8080 from ALB SG         │                │  │ │  │
│  │  │  │  └─────────────────────────────────────────────────┘                │  │ │  │
│  │  │  │                                                                        │  │ │  │
│  │  │  │  Route Table: private-rt-1a                                          │  │ │  │
│  │  │  │  • 10.0.0.0/16 → local                                               │  │ │  │
│  │  │  │  • 0.0.0.0/0 → NAT Gateway (nat-1a)                                  │  │ │  │
│  │  │  └──────────────────────────────────────────────────────────────────────┘  │ │  │
│  │  │                                                                               │ │  │
│  │  │  ┌──────────────────────────────────────────────────────────────────────┐  │ │  │
│  │  │  │  PRIVATE SUBNET: 10.0.20.0/24 (delegate-subnet-1a)                   │  │ │  │
│  │  │  │                                                                        │  │ │  │
│  │  │  │  ┌─────────────────────────────────────────────────┐                │  │ │  │
│  │  │  │  │  Harness Delegates                               │                │  │ │  │
│  │  │  │  │  • delegate-1: 10.0.20.10                       │                │  │ │  │
│  │  │  │  │  Security Group: allow 443 outbound to Harness  │                │  │ │  │
│  │  │  │  │                  allow SSH to VMs                │                │  │ │  │
│  │  │  │  │                  allow AWS API access            │                │  │ │  │
│  │  │  │  └─────────────────────────────────────────────────┘                │  │ │  │
│  │  │  │                                                                        │  │ │  │
│  │  │  │  Route Table: delegate-rt-1a                                         │  │ │  │
│  │  │  │  • 10.0.0.0/16 → local                                               │  │ │  │
│  │  │  │  • 0.0.0.0/0 → NAT Gateway (nat-1a)                                  │  │ │  │
│  │  │  └──────────────────────────────────────────────────────────────────────┘  │ │  │
│  │  └───────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                         AVAILABILITY ZONE: us-east-1b                        │ │  │
│  │  │  (Similar structure with different IP ranges)                                │ │  │
│  │  │  • Public Subnet: 10.0.11.0/24                                               │ │  │
│  │  │  • Private Subnet: 10.0.2.0/24                                               │ │  │
│  │  │  • Delegate Subnet: 10.0.21.0/24                                             │ │  │
│  │  │  • NAT Gateway: nat-1b                                                       │ │  │
│  │  └───────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                         AVAILABILITY ZONE: us-east-1c                        │ │  │
│  │  │  (Similar structure with different IP ranges)                                │ │  │
│  │  │  • Public Subnet: 10.0.12.0/24                                               │ │  │
│  │  │  • Private Subnet: 10.0.3.0/24                                               │ │  │
│  │  │  • Delegate Subnet: 10.0.22.0/24                                             │ │  │
│  │  │  • NAT Gateway: nat-1c                                                       │ │  │
│  │  └───────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                         VPC ENDPOINTS (PrivateLink)                          │ │  │
│  │  │                                                                               │ │  │
│  │  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐         │ │  │
│  │  │  │   ECS Endpoint   │  │  ECR Endpoint    │  │   S3 Endpoint    │         │ │  │
│  │  │  │   (Interface)    │  │   (Interface)    │  │   (Gateway)      │         │ │  │
│  │  │  └──────────────────┘  └──────────────────┘  └──────────────────┘         │ │  │
│  │  │                                                                               │ │  │
│  │  │  Purpose: Private connectivity to AWS services without internet              │ │  │
│  │  │  Benefits: Lower latency, no data transfer charges, enhanced security        │ │  │
│  │  └───────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                         NETWORK SECURITY                                      │ │  │
│  │  │                                                                               │ │  │
│  │  │  Security Groups:                                                             │ │  │
│  │  │  ├─ ALB Security Group                                                       │ │  │
│  │  │  │  • Inbound: 80,443 from 0.0.0.0/0                                         │ │  │
│  │  │  │  • Outbound: 8080 to ECS Task SG                                          │ │  │
│  │  │  │                                                                            │ │  │
│  │  │  ├─ ECS Task Security Group                                                  │ │  │
│  │  │  │  • Inbound: 8080 from ALB SG                                              │ │  │
│  │  │  │  • Outbound: 443 to 0.0.0.0/0 (AWS APIs)                                  │ │  │
│  │  │  │             3306 to RDS SG (Database)                                     │ │  │
│  │  │  │                                                                            │ │  │
│  │  │  ├─ VM Security Group                                                        │ │  │
│  │  │  │  • Inbound: 22 from Delegate SG                                           │ │  │
│  │  │  │            8080 from ALB SG                                               │ │  │
│  │  │  │  • Outbound: All                                                          │ │  │
│  │  │  │                                                                            │ │  │
│  │  │  └─ Delegate Security Group                                                  │ │  │
│  │  │     • Inbound: None                                                          │ │  │
│  │  │     • Outbound: 443 to Harness (app.harness.io)                             │ │  │
│  │  │               22 to VM SG                                                    │ │  │
│  │  │               443 to AWS API endpoints                                       │ │  │
│  │  │                                                                               │ │  │
│  │  │  Network ACLs: Default (Allow all inbound/outbound)                          │ │  │
│  │  │  VPC Flow Logs: Enabled → CloudWatch Logs                                    │ │  │
│  │  └───────────────────────────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         CONNECTIVITY & ROUTING                                  │  │
│  │                                                                                  │  │
│  │  Internet Gateway:                                                               │  │
│  │  • Provides internet connectivity for public subnets                            │  │
│  │  • ALB receives inbound internet traffic                                        │  │
│  │                                                                                  │  │
│  │  NAT Gateways (High Availability):                                              │  │
│  │  • One per AZ for redundancy                                                    │  │
│  │  • Provides outbound internet for private subnets                               │  │
│  │  • ECS tasks, VMs, Delegates use NAT for AWS API calls                          │  │
│  │                                                                                  │  │
│  │  VPN/Direct Connect (Optional):                                                 │  │
│  │  • For hybrid cloud scenarios                                                   │  │
│  │  • Connect on-premise data centers to AWS VPC                                   │  │
│  │  • Private connectivity without internet                                        │  │
│  │                                                                                  │  │
│  │  VPC Peering (Optional):                                                        │  │
│  │  • Connect multiple VPCs                                                        │  │
│  │  • Shared services VPC                                                          │  │
│  │  • Cross-region peering for DR                                                  │  │
│  └────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### Network Traffic Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                            NETWORK TRAFFIC FLOWS                                         │
│                                                                                          │
│  Flow 1: User Request to Application                                                    │
│  ───────────────────────────────────────                                                │
│                                                                                          │
│  [User Browser]                                                                          │
│       │                                                                                  │
│       │ HTTPS Request (Port 443)                                                        │
│       │ DNS: myapp.example.com → ALB DNS                                                │
│       ▼                                                                                  │
│  [Internet Gateway]                                                                      │
│       │                                                                                  │
│       ▼                                                                                  │
│  [Application Load Balancer]                                                             │
│   Public Subnet (10.0.10.0/24)                                                          │
│   • SSL Termination                                                                     │
│   • Security Group: Allow 443 from 0.0.0.0/0                                            │
│       │                                                                                  │
│       │ HTTP Request (Port 8080)                                                        │
│       │ Target Group Health Check                                                       │
│       ▼                                                                                  │
│  [ECS Task or VM]                                                                        │
│   Private Subnet (10.0.1.0/24)                                                          │
│   IP: 10.0.1.10                                                                         │
│   • Security Group: Allow 8080 from ALB SG                                              │
│   • Process request                                                                     │
│       │                                                                                  │
│       │ Response                                                                         │
│       ▼                                                                                  │
│  [ALB] → [Internet Gateway] → [User Browser]                                            │
│                                                                                          │
│  ────────────────────────────────────────────────────────────────────────────────────  │
│                                                                                          │
│  Flow 2: Delegate to Harness Control Plane                                              │
│  ───────────────────────────────────────────────                                        │
│                                                                                          │
│  [Harness Delegate]                                                                      │
│   Private Subnet (10.0.20.0/24)                                                         │
│   IP: 10.0.20.10                                                                        │
│       │                                                                                  │
│       │ Outbound WebSocket (Port 443)                                                   │
│       │ Destination: app.harness.io                                                     │
│       │ Security Group: Allow 443 outbound                                              │
│       ▼                                                                                  │
│  [NAT Gateway]                                                                           │
│   Public Subnet (10.0.10.0/24)                                                          │
│   Elastic IP: x.x.x.1                                                                   │
│       │                                                                                  │
│       │ Source NAT applied                                                              │
│       │ Source IP: x.x.x.1                                                              │
│       ▼                                                                                  │
│  [Internet Gateway]                                                                      │
│       │                                                                                  │
│       │ Encrypted WebSocket over HTTPS                                                  │
│       │ TLS 1.3                                                                          │
│       ▼                                                                                  │
│  [Harness CD Control Plane]                                                              │
│   app.harness.io (SaaS)                                                                 │
│   • mTLS authentication                                                                 │
│   • Bi-directional communication                                                        │
│   • No inbound connections required                                                     │
│                                                                                          │
│  ────────────────────────────────────────────────────────────────────────────────────  │
│                                                                                          │
│  Flow 3: Delegate to ECS/AWS APIs                                                       │
│  ──────────────────────────────────────                                                 │
│                                                                                          │
│  [Harness Delegate]                                                                      │
│   Private Subnet (10.0.20.0/24)                                                         │
│       │                                                                                  │
│       │ AWS API Calls (Port 443)                                                        │
│       │ • ecs:UpdateService                                                             │
│       │ • ecs:DescribeTasks                                                             │
│       │ • ecr:GetAuthorizationToken                                                     │
│       ▼                                                                                  │
│  [VPC Endpoint (PrivateLink)] ── OR ── [NAT Gateway]                                    │
│   Interface Endpoint                      Public Subnet                                │
│   10.0.20.50                              → Internet Gateway                            │
│       │                                          │                                       │
│       └──────────────────┬───────────────────────┘                                       │
│                          ▼                                                               │
│                   [AWS Service Endpoints]                                                │
│                   • ECS API                                                              │
│                   • ECR API                                                              │
│                   • CloudWatch API                                                       │
│                   • IAM STS (for role assumption)                                        │
│                                                                                          │
│  ────────────────────────────────────────────────────────────────────────────────────  │
│                                                                                          │
│  Flow 4: Delegate to VM (SSH)                                                           │
│  ──────────────────────────────────                                                     │
│                                                                                          │
│  [Harness Delegate]                                                                      │
│   Private Subnet (10.0.20.0/24)                                                         │
│   IP: 10.0.20.10                                                                        │
│       │                                                                                  │
│       │ SSH Connection (Port 22)                                                        │
│       │ Security Group: Allow 22 to VM SG                                               │
│       ▼                                                                                  │
│  [VM Server]                                                                             │
│   Private Subnet (10.0.1.0/24)                                                          │
│   IP: 10.0.1.20                                                                         │
│   • Security Group: Allow 22 from Delegate SG                                           │
│   • SSH key authentication                                                              │
│   • Execute deployment commands                                                         │
│       │                                                                                  │
│       │ Response                                                                         │
│       ▼                                                                                  │
│  [Harness Delegate]                                                                      │
│   • Process output                                                                      │
│   • Report status to Harness                                                            │
│                                                                                          │
│  ────────────────────────────────────────────────────────────────────────────────────  │
│                                                                                          │
│  Flow 5: ECS Task to External Services                                                  │
│  ────────────────────────────────────────────                                           │
│                                                                                          │
│  [ECS Task]                                                                              │
│   Private Subnet (10.0.1.0/24)                                                          │
│   IP: 10.0.1.10                                                                         │
│       │                                                                                  │
│       ├─► Database Connection                                                            │
│       │   │ PostgreSQL (Port 5432)                                                      │
│       │   ▼                                                                              │
│       │   [RDS Database]                                                                 │
│       │   Private Subnet (10.0.30.0/24)                                                 │
│       │   Security Group: Allow 5432 from ECS Task SG                                   │
│       │                                                                                  │
│       ├─► Redis Connection                                                               │
│       │   │ Redis (Port 6379)                                                           │
│       │   ▼                                                                              │
│       │   [ElastiCache Redis]                                                            │
│       │   Private Subnet (10.0.31.0/24)                                                 │
│       │                                                                                  │
│       └─► External API Call                                                              │
│           │ HTTPS (Port 443)                                                            │
│           ▼                                                                              │
│           [NAT Gateway] → [Internet Gateway] → [External API]                            │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Security Architecture

(Content continues with detailed security architecture, integration points, component deep dive, scalability & HA, and disaster recovery sections...)

*To be continued in Part 3...*
