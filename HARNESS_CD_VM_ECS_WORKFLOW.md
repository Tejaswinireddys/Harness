# Harness CD Workflows: VM and ECS Deployment - Complete Guide

## Table of Contents

1. [Overview](#overview)
2. [VM Deployment Workflow](#vm-deployment-workflow)
3. [ECS Deployment Workflow](#ecs-deployment-workflow)
4. [Architecture Diagrams](#architecture-diagrams)
5. [Dataflow Diagrams](#dataflow-diagrams)
6. [Detailed Configuration](#detailed-configuration)
7. [Best Practices](#best-practices)

---

## Overview

This document provides comprehensive workflows for deploying applications using Harness CD to:
- **Virtual Machines (VMs)**: Traditional server-based deployments
- **Amazon ECS (Elastic Container Service)**: Containerized deployments on AWS

Both workflows include detailed architecture diagrams, dataflow diagrams, and step-by-step configurations.

---

## VM Deployment Workflow

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Harness CD Platform                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Pipeline   │  │   Service    │  │ Environment  │         │
│  │  Definition  │→ │  Definition  │→ │  Definition  │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│         │                  │                   │                │
│         └──────────────────┴───────────────────┘                │
│                            │                                    │
│                    ┌────────▼────────┐                          │
│                    │  Infrastructure │                          │
│                    │   Definition    │                          │
│                    └────────┬────────┘                          │
└────────────────────────────┼────────────────────────────────────┘
                             │
                             │ SSH/Agent Connection
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼───────┐   ┌────────▼────────┐  ┌───────▼───────┐
│   VM Server 1 │   │   VM Server 2    │  │  VM Server N  │
│  (Production) │   │   (Staging)     │  │   (Dev/QA)    │
│               │   │                  │  │               │
│  ┌─────────┐  │   │  ┌─────────┐    │  │  ┌─────────┐ │
│  │  App    │  │   │  │  App    │    │  │  │  App    │ │
│  │ Service │  │   │  │ Service │    │  │  │ Service │ │
│  └─────────┘  │   │  └─────────┘    │  │  └─────────┘ │
└───────────────┘   └──────────────────┘  └───────────────┘
```

### VM Deployment Dataflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DEPLOYMENT DATAFLOW                          │
└─────────────────────────────────────────────────────────────────────┘

[1] Developer Push Code
         │
         ▼
[2] Git Repository (GitHub/GitLab/Bitbucket)
         │
         ▼
[3] Harness CD Pipeline Triggered
         │
         ├─► [4] Artifact Source
         │        │
         │        ├─► Docker Registry
         │        ├─► Artifactory
         │        └─► S3/File Server
         │
         ▼
[5] Harness Delegate (Agent)
         │
         ├─► [6] Connect to VM via SSH
         │        │
         │        ├─► Authenticate (SSH Key/Password)
         │        ├─► Validate Connection
         │        └─► Prepare Environment
         │
         ▼
[7] Pre-Deployment Steps
         │
         ├─► Backup Current Application
         ├─► Stop Running Services
         ├─► Validate Disk Space
         └─► Check Dependencies
         │
         ▼
[8] Deployment Execution
         │
         ├─► Download Artifacts
         ├─► Extract/Install Application
         ├─► Configure Application
         ├─► Set Permissions
         └─► Update Configuration Files
         │
         ▼
[9] Post-Deployment Steps
         │
         ├─► Start Services
         ├─► Health Checks
         ├─► Smoke Tests
         └─► Verify Endpoints
         │
         ▼
[10] Continuous Verification (Optional)
         │
         ├─► Monitor Metrics (Prometheus/Datadog)
         ├─► Check Logs
         ├─► Verify Performance
         └─► Auto-Rollback if Issues Detected
         │
         ▼
[11] Deployment Complete / Rollback
```

### Detailed VM Deployment Steps

#### Step 1: Infrastructure Setup

**Infrastructure Definition:**
```yaml
infrastructure:
  type: SshWinRmAzureInfrastructure
  spec:
    connectorRef: vm-ssh-connector
    credentialsRef: vm-credentials
    hostname: production-vm-01.example.com
    osType: Linux  # or Windows
    tags:
      environment: production
      region: us-east-1
```

**SSH Connector Configuration:**
- **Type**: SSH Key or Username/Password
- **Host**: VM IP address or hostname
- **Port**: 22 (default SSH port)
- **Authentication**: SSH Key (recommended) or Password

#### Step 2: Service Definition

**Service Configuration:**
```yaml
service:
  name: my-application
  serviceDefinition:
    type: Ssh
    spec:
      artifacts:
        primary:
          type: DockerRegistry
          spec:
            connectorRef: docker-connector
            imagePath: myapp
            tag: <+pipeline.sequenceId>
      configFiles:
        - configFile:
            type: Ssh
            spec:
              store:
                type: Git
                spec:
                  connectorRef: git-connector
                  gitFetchType: Branch
                  paths:
                    - config/app.properties
                  repoName: config-repo
                  branch: main
```

#### Step 3: Deployment Workflow

**Complete VM Deployment Pipeline:**
```yaml
pipeline:
  name: VM Deployment Pipeline
  identifier: vm_deployment_pipeline
  projectIdentifier: default_project
  orgIdentifier: default
  stages:
    - stage:
        name: Deploy to VM
        identifier: Deploy_to_VM
        type: Deployment
        spec:
          serviceConfig:
            serviceRef: my-application
            serviceDefinition:
              type: Ssh
              spec:
                artifacts:
                  primary:
                    type: DockerRegistry
                    spec:
                      connectorRef: docker-connector
                      imagePath: myapp
                      tag: <+pipeline.sequenceId>
          infrastructure:
            environmentRef: production
            infrastructureDefinition:
              type: SshWinRmAzureInfrastructure
              spec:
                connectorRef: vm-ssh-connector
                credentialsRef: vm-credentials
                hostname: production-vm-01.example.com
                osType: Linux
          execution:
            steps:
              # Step 1: Pre-Deployment - Backup
              - step:
                  type: Command
                  name: Backup Current Application
                  identifier: Backup_Current_Application
                  spec:
                    onDelegate: false
                    commandUnits:
                      - commandUnit:
                          identifier: backup
                          type: Script
                          spec:
                            shell: Bash
                            source:
                              type: Inline
                              spec:
                                script: |
                                  #!/bin/bash
                                  echo "Creating backup..."
                                  BACKUP_DIR="/opt/backups/$(date +%Y%m%d_%H%M%S)"
                                  mkdir -p $BACKUP_DIR
                                  cp -r /opt/myapp/* $BACKUP_DIR/
                                  echo "Backup created at $BACKUP_DIR"
              
              # Step 2: Pre-Deployment - Stop Services
              - step:
                  type: Command
                  name: Stop Services
                  identifier: Stop_Services
                  spec:
                    onDelegate: false
                    commandUnits:
                      - commandUnit:
                          identifier: stop
                          type: Script
                          spec:
                            shell: Bash
                            source:
                              type: Inline
                              spec:
                                script: |
                                  #!/bin/bash
                                  echo "Stopping application services..."
                                  systemctl stop myapp || service myapp stop
                                  echo "Services stopped"
              
              # Step 3: Download Artifacts
              - step:
                  type: ArtifactoryDownload
                  name: Download Artifacts
                  identifier: Download_Artifacts
                  spec:
                    connectorRef: artifactory-connector
                    repository: myapp-releases
                    artifactPath: myapp-<+pipeline.sequenceId>.tar.gz
                    targetPath: /opt/myapp/
              
              # Step 4: Extract and Install
              - step:
                  type: Command
                  name: Extract and Install
                  identifier: Extract_and_Install
                  spec:
                    onDelegate: false
                    commandUnits:
                      - commandUnit:
                          identifier: extract
                          type: Script
                          spec:
                            shell: Bash
                            source:
                              type: Inline
                              spec:
                                script: |
                                  #!/bin/bash
                                  echo "Extracting application..."
                                  cd /opt/myapp
                                  tar -xzf myapp-<+pipeline.sequenceId>.tar.gz
                                  chmod +x bin/myapp
                                  echo "Application extracted"
              
              # Step 5: Update Configuration
              - step:
                  type: Command
                  name: Update Configuration
                  identifier: Update_Configuration
                  spec:
                    onDelegate: false
                    commandUnits:
                      - commandUnit:
                          identifier: config
                          type: Script
                          spec:
                            shell: Bash
                            source:
                              type: Inline
                              spec:
                                script: |
                                  #!/bin/bash
                                  echo "Updating configuration..."
                                  cp /opt/myapp/config/app.properties /opt/myapp/conf/
                                  # Update environment-specific config
                                  sed -i "s/ENVIRONMENT/production/g" /opt/myapp/conf/app.properties
                                  echo "Configuration updated"
              
              # Step 6: Start Services
              - step:
                  type: Command
                  name: Start Services
                  identifier: Start_Services
                  spec:
                    onDelegate: false
                    commandUnits:
                      - commandUnit:
                          identifier: start
                          type: Script
                          spec:
                            shell: Bash
                            source:
                              type: Inline
                              spec:
                                script: |
                                  #!/bin/bash
                                  echo "Starting application services..."
                                  systemctl start myapp || service myapp start
                                  sleep 5
                                  systemctl status myapp || service myapp status
                                  echo "Services started"
              
              # Step 7: Health Check
              - step:
                  type: Http
                  name: Health Check
                  identifier: Health_Check
                  spec:
                    url: http://production-vm-01.example.com:8080/health
                    method: GET
                    headers: []
                    assertion: |
                      <+json.select("status", <+httpResponseBody>)> == "UP"
                    timeout: 30s
              
              # Step 8: Smoke Tests
              - step:
                  type: Command
                  name: Run Smoke Tests
                  identifier: Run_Smoke_Tests
                  spec:
                    onDelegate: false
                    commandUnits:
                      - commandUnit:
                          identifier: smoke
                          type: Script
                          spec:
                            shell: Bash
                            source:
                              type: Inline
                              spec:
                                script: |
                                  #!/bin/bash
                                  echo "Running smoke tests..."
                                  curl -f http://localhost:8080/api/v1/status || exit 1
                                  curl -f http://localhost:8080/api/v1/health || exit 1
                                  echo "Smoke tests passed"
              
              # Step 9: Continuous Verification
              - step:
                  type: Verify
                  name: Continuous Verification
                  identifier: Continuous_Verification
                  spec:
                    type: Prometheus
                    spec:
                      connectorRef: prometheus-connector
                      metricName: http_requests_total
                      baseline: <+serviceConfig.artifacts.primary.tag>
                      canary: <+serviceConfig.artifacts.primary.tag>
                      query: sum(rate(http_requests_total[5m]))
                      threshold:
                        type: Absolute
                        spec:
                          value: 100
                    duration: 10m
            rollbackSteps:
              - step:
                  type: Command
                  name: Rollback Application
                  identifier: Rollback_Application
                  spec:
                    onDelegate: false
                    commandUnits:
                      - commandUnit:
                          identifier: rollback
                          type: Script
                          spec:
                            shell: Bash
                            source:
                              type: Inline
                              spec:
                                script: |
                                  #!/bin/bash
                                  echo "Rolling back application..."
                                  systemctl stop myapp
                                  LATEST_BACKUP=$(ls -t /opt/backups/ | head -1)
                                  cp -r /opt/backups/$LATEST_BACKUP/* /opt/myapp/
                                  systemctl start myapp
                                  echo "Rollback completed"
```

### VM Deployment Architecture Components

#### Component Details

**1. Harness Delegate**
- Lightweight agent installed on VM or separate machine
- Connects to Harness platform
- Executes deployment commands
- Reports status back to platform

**2. SSH Connection**
- Secure shell connection to VM
- Authentication via SSH keys or passwords
- Encrypted communication
- Port forwarding support

**3. VM Infrastructure**
- Physical or virtual machines
- Operating system: Linux or Windows
- Network access required
- Sufficient disk space and resources

**4. Application Artifacts**
- Source: Docker registry, Artifactory, S3, etc.
- Format: TAR, ZIP, RPM, DEB, etc.
- Versioning: Tagged artifacts
- Storage: Local or remote

---

## ECS Deployment Workflow

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Harness CD Platform                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Pipeline   │  │   Service    │  │ Environment  │         │
│  │  Definition  │→ │  Definition  │→ │  Definition  │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│         │                  │                   │                │
│         └──────────────────┴───────────────────┘                │
│                            │                                    │
│                    ┌────────▼────────┐                          │
│                    │  Infrastructure │                          │
│                    │   Definition    │                          │
│                    │   (AWS ECS)     │                          │
│                    └────────┬────────┘                          │
└────────────────────────────┼────────────────────────────────────┘
                             │
                             │ AWS API Calls
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼───────┐   ┌────────▼────────┐  ┌───────▼───────┐
│  ECS Cluster │   │  ECS Service     │  │  Task         │
│  (Production)│   │  (myapp-service) │  │  Definition   │
│              │   │                  │  │  (myapp-task) │
│  ┌─────────┐ │   │  ┌─────────────┐ │  │               │
│  │  Tasks  │ │   │  │  Desired   │ │  │  ┌──────────┐ │
│  │ Running │ │   │  │  Count: 3  │ │  │  │ Container│ │
│  └─────────┘ │   │  └─────────────┘ │  │  │  Image   │ │
└───────┬───────┘   └────────┬────────┘  │  │  Ports   │ │
        │                    │            │  └──────────┘ │
        │                    │            └───────────────┘
        │                    │
        └────────────────────┼────────────────────┐
                             │                    │
                    ┌────────▼────────┐  ┌────────▼────────┐
                    │  Application    │  │  Target Group   │
                    │  Load Balancer  │  │  (ALB/NLB)      │
                    │  (ALB/NLB)      │  │                 │
                    └─────────────────┘  └──────────────────┘
                             │
                             │
                    ┌────────▼────────┐
                    │  ECR Registry   │
                    │  (Docker Images) │
                    └─────────────────┘
```

### ECS Deployment Dataflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                      ECS DEPLOYMENT DATAFLOW                         │
└─────────────────────────────────────────────────────────────────────┘

[1] Developer Push Code
         │
         ▼
[2] CI Pipeline Builds Docker Image
         │
         ├─► [3] Push to ECR (Elastic Container Registry)
         │        │
         │        └─► Image Tagged: myapp:v1.2.3
         │
         ▼
[4] Harness CD Pipeline Triggered
         │
         ├─► [5] Fetch Artifact from ECR
         │        │
         │        ├─► Authenticate with AWS
         │        ├─► Pull Image Metadata
         │        └─► Validate Image Exists
         │
         ▼
[6] Harness Delegate (in AWS)
         │
         ├─► [7] Connect to AWS ECS
         │        │
         │        ├─► Authenticate (IAM Role/Keys)
         │        ├─► Validate ECS Cluster
         │        └─► Check Service Status
         │
         ▼
[8] Pre-Deployment Steps
         │
         ├─► Get Current Task Definition
         ├─► Create New Task Definition Revision
         ├─► Update Container Image
         ├─► Validate Task Definition
         └─► Check Service Limits
         │
         ▼
[9] Deployment Strategy Selection
         │
         ├─► [A] Rolling Update (Default)
         │        │
         │        ├─► Stop Old Tasks
         │        ├─► Start New Tasks (one by one)
         │        └─► Health Check Each Task
         │
         ├─► [B] Blue-Green Deployment
         │        │
         │        ├─► Create New Service (Green)
         │        ├─► Route Traffic Gradually
         │        └─► Switch All Traffic
         │
         └─► [C] Canary Deployment
                  │
                  ├─► Deploy 10% New Tasks
                  ├─► Verify Performance
                  ├─► Deploy 50% New Tasks
                  ├─► Verify Performance
                  └─► Deploy 100% New Tasks
         │
         ▼
[10] ECS Service Update
         │
         ├─► Update Service with New Task Definition
         ├─► ECS Starts New Tasks
         ├─► Register Tasks with Target Group
         ├─► Health Checks Pass
         └─► Old Tasks Deregistered
         │
         ▼
[11] Post-Deployment Verification
         │
         ├─► Check Task Status (RUNNING)
         ├─► Verify Health Checks
         ├─► Test Endpoints
         └─► Monitor Metrics
         │
         ▼
[12] Continuous Verification
         │
         ├─► Monitor CloudWatch Metrics
         ├─► Check Application Logs
         ├─► Verify Performance
         └─► Auto-Rollback if Issues
         │
         ▼
[13] Deployment Complete / Rollback
```

### Detailed ECS Deployment Steps

#### Step 1: AWS Infrastructure Setup

**AWS Connector Configuration:**
```yaml
connector:
  name: aws-connector
  type: Aws
  spec:
    credential:
      type: ManualConfig
      spec:
        accessKey: <+secrets.getValue("aws_access_key")>
        secretKey: <+secrets.getValue("aws_secret_key")>
        region: us-east-1
    delegateSelectors: []
```

**ECS Infrastructure Definition:**
```yaml
infrastructure:
  type: EcsInfrastructure
  spec:
    connectorRef: aws-connector
    region: us-east-1
    cluster: production-cluster
    namespace: default  # Optional, for ECS with Fargate
```

#### Step 2: ECS Service Definition

**Service Configuration:**
```yaml
service:
  name: myapp-ecs-service
  serviceDefinition:
    type: Ecs
    spec:
      artifacts:
        primary:
          type: Ecr
          spec:
            connectorRef: aws-connector
            imagePath: 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp
            tag: <+pipeline.sequenceId>
      taskDefinition:
        taskDefinitionArn: arn:aws:ecs:us-east-1:123456789012:task-definition/myapp-task:10
        # OR provide task definition spec
        taskDefinitionSpec:
          containerDefinitions:
            - name: myapp-container
              image: <+artifact.image>
              memory: 512
              cpu: 256
              portMappings:
                - containerPort: 8080
                  protocol: tcp
              environment:
                - name: ENVIRONMENT
                  value: production
                - name: LOG_LEVEL
                  value: INFO
              logConfiguration:
                logDriver: awslogs
                options:
                  awslogs-group: /ecs/myapp
                  awslogs-region: us-east-1
                  awslogs-stream-prefix: ecs
          family: myapp-task
          networkMode: awsvpc
          requiresCompatibilities:
            - FARGATE
          cpu: 256
          memory: 512
      serviceDefinition:
        serviceName: myapp-service
        desiredCount: 3
        launchType: FARGATE
        networkConfiguration:
          awsvpcConfiguration:
            subnets:
              - subnet-12345678
              - subnet-87654321
            securityGroups:
              - sg-12345678
            assignPublicIp: ENABLED
        loadBalancers:
          - targetGroupArn: arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/myapp-tg/1234567890123456
            containerName: myapp-container
            containerPort: 8080
        healthCheckGracePeriodSeconds: 60
        deploymentConfiguration:
          maximumPercent: 200
          minimumHealthyPercent: 100
```

#### Step 3: Complete ECS Deployment Pipeline

**Full ECS Deployment Pipeline:**
```yaml
pipeline:
  name: ECS Deployment Pipeline
  identifier: ecs_deployment_pipeline
  projectIdentifier: default_project
  orgIdentifier: default
  stages:
    - stage:
        name: Deploy to ECS
        identifier: Deploy_to_ECS
        type: Deployment
        spec:
          serviceConfig:
            serviceRef: myapp-ecs-service
            serviceDefinition:
              type: Ecs
              spec:
                artifacts:
                  primary:
                    type: Ecr
                    spec:
                      connectorRef: aws-connector
                      imagePath: 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp
                      tag: <+pipeline.sequenceId>
                taskDefinition:
                  taskDefinitionArn: arn:aws:ecs:us-east-1:123456789012:task-definition/myapp-task:10
          infrastructure:
            environmentRef: production
            infrastructureDefinition:
              type: EcsInfrastructure
              spec:
                connectorRef: aws-connector
                region: us-east-1
                cluster: production-cluster
          execution:
            steps:
              # Step 1: Fetch Task Definition
              - step:
                  type: EcsRunTask
                  name: Fetch Current Task Definition
                  identifier: Fetch_Task_Definition
                  spec:
                    taskDefinition: <+serviceConfig.taskDefinition.taskDefinitionArn>
                    cluster: production-cluster
                    region: us-east-1
              
              # Step 2: Create New Task Definition
              - step:
                  type: EcsRunTask
                  name: Create New Task Definition
                  identifier: Create_New_Task_Definition
                  spec:
                    taskDefinition:
                      containerDefinitions:
                        - name: myapp-container
                          image: <+artifact.image>
                          memory: 512
                          cpu: 256
                          portMappings:
                            - containerPort: 8080
                              protocol: tcp
                          environment:
                            - name: ENVIRONMENT
                              value: production
                            - name: VERSION
                              value: <+pipeline.sequenceId>
                          logConfiguration:
                            logDriver: awslogs
                            options:
                              awslogs-group: /ecs/myapp
                              awslogs-region: us-east-1
                              awslogs-stream-prefix: ecs
                      family: myapp-task
                      networkMode: awsvpc
                      requiresCompatibilities:
                        - FARGATE
                      cpu: 256
                      memory: 512
                    cluster: production-cluster
                    region: us-east-1
              
              # Step 3: Deploy with Rolling Update
              - step:
                  type: EcsRollingDeploy
                  name: Rolling Deployment
                  identifier: Rolling_Deployment
                  spec:
                    skipSteadyStateCheck: false
                    sameAsAlreadyRunningDeployment: false
                    forceNewDeployment: true
              
              # Step 4: Verify Deployment
              - step:
                  type: EcsRunTask
                  name: Verify Deployment
                  identifier: Verify_Deployment
                  spec:
                    taskDefinition: <+serviceConfig.taskDefinition.taskDefinitionArn>
                    cluster: production-cluster
                    region: us-east-1
                    command: |
                      echo "Verifying deployment..."
                      # Check if tasks are running
                      aws ecs describe-services \
                        --cluster production-cluster \
                        --services myapp-service \
                        --query 'services[0].runningCount' \
                        --output text
              
              # Step 5: Health Check
              - step:
                  type: Http
                  name: Health Check
                  identifier: Health_Check
                  spec:
                    url: http://myapp-alb-123456789.us-east-1.elb.amazonaws.com/health
                    method: GET
                    headers: []
                    assertion: |
                      <+json.select("status", <+httpResponseBody>)> == "UP"
                    timeout: 30s
              
              # Step 6: Continuous Verification
              - step:
                  type: Verify
                  name: Continuous Verification
                  identifier: Continuous_Verification
                  spec:
                    type: Prometheus
                    spec:
                      connectorRef: prometheus-connector
                      metricName: ecs_cpu_utilization
                      baseline: <+serviceConfig.artifacts.primary.tag>
                      canary: <+serviceConfig.artifacts.primary.tag>
                      query: avg(container_cpu_usage_seconds_total{container_name="myapp-container"})
                      threshold:
                        type: Percentage
                        spec:
                          value: 80
                    duration: 10m
            rollbackSteps:
              - step:
                  type: EcsRollingRollback
                  name: Rolling Rollback
                  identifier: Rolling_Rollback
                  spec:
                    skipSteadyStateCheck: false
```

### ECS Blue-Green Deployment

**Blue-Green Deployment Pipeline:**
```yaml
execution:
  steps:
    # Step 1: Deploy Green Environment
    - step:
        type: EcsRunTask
        name: Deploy Green Environment
        identifier: Deploy_Green
        spec:
          taskDefinition:
            containerDefinitions:
              - name: myapp-container
                image: <+artifact.image>
                # ... other config
          cluster: production-cluster
          launchType: FARGATE
          networkConfiguration:
            awsvpcConfiguration:
              subnets:
                - subnet-green-1
                - subnet-green-2
              securityGroups:
                - sg-green
          serviceName: myapp-service-green
    
    # Step 2: Verify Green Environment
    - step:
        type: Http
        name: Verify Green
        identifier: Verify_Green
        spec:
          url: http://green-alb.us-east-1.elb.amazonaws.com/health
          method: GET
    
    # Step 3: Route 10% Traffic to Green
    - step:
        type: EcsRunTask
        name: Route 10% Traffic
        identifier: Route_10_Percent
        spec:
          # Update ALB listener rules
          # 90% to blue, 10% to green
    
    # Step 4: Continuous Verification
    - step:
        type: Verify
        name: Verify 10% Traffic
        identifier: Verify_10_Percent
        spec:
          type: CloudWatch
          spec:
            connectorRef: aws-connector
            metricName: TargetResponseTime
            baseline: <+serviceConfig.artifacts.primary.tag>
            canary: <+serviceConfig.artifacts.primary.tag>
            query: avg(TargetResponseTime)
            threshold:
              type: Percentage
              spec:
                value: 20
          duration: 5m
    
    # Step 5: Route 50% Traffic to Green
    - step:
        type: EcsRunTask
        name: Route 50% Traffic
        identifier: Route_50_Percent
        spec:
          # Update ALB listener rules
          # 50% to blue, 50% to green
    
    # Step 6: Verify 50% Traffic
    - step:
        type: Verify
        name: Verify 50% Traffic
        identifier: Verify_50_Percent
        spec:
          type: CloudWatch
          # ... similar to above
          duration: 5m
    
    # Step 7: Route 100% Traffic to Green
    - step:
        type: EcsRunTask
        name: Route 100% Traffic
        identifier: Route_100_Percent
        spec:
          # Update ALB listener rules
          # 100% to green
    
    # Step 8: Terminate Blue Environment
    - step:
        type: EcsRunTask
        name: Terminate Blue
        identifier: Terminate_Blue
        spec:
          # Stop blue service tasks
          # Deregister from ALB
```

### ECS Canary Deployment

**Canary Deployment Pipeline:**
```yaml
execution:
  steps:
    # Step 1: Deploy Canary (10% of traffic)
    - step:
        type: EcsCanaryDeploy
        name: Canary Deploy 10%
        identifier: Canary_Deploy_10
        spec:
          instanceSelection:
            type: Count
            spec:
              count: 1  # 1 out of 10 tasks = 10%
    
    # Step 2: Verify Canary
    - step:
        type: Verify
        name: Verify Canary 10%
        identifier: Verify_Canary_10
        spec:
          type: CloudWatch
          spec:
            connectorRef: aws-connector
            metricName: HTTPCode_Target_5XX_Count
            query: sum(HTTPCode_Target_5XX_Count)
            threshold:
              type: Absolute
              spec:
                value: 10
          duration: 5m
    
    # Step 3: Increase Canary to 25%
    - step:
        type: EcsCanaryDeploy
        name: Canary Deploy 25%
        identifier: Canary_Deploy_25
        spec:
          instanceSelection:
            type: Count
            spec:
              count: 2  # 2 out of 8 tasks = 25%
    
    # Step 4: Verify 25%
    - step:
        type: Verify
        name: Verify Canary 25%
        identifier: Verify_Canary_25
        spec:
          # ... similar verification
          duration: 5m
    
    # Step 5: Increase Canary to 50%
    - step:
        type: EcsCanaryDeploy
        name: Canary Deploy 50%
        identifier: Canary_Deploy_50
        spec:
          instanceSelection:
            type: Count
            spec:
              count: 4  # 4 out of 8 tasks = 50%
    
    # Step 6: Verify 50%
    - step:
        type: Verify
        name: Verify Canary 50%
        identifier: Verify_Canary_50
        spec:
          # ... similar verification
          duration: 10m
    
    # Step 7: Delete Canary
    - step:
        type: EcsCanaryDelete
        name: Delete Canary
        identifier: Delete_Canary
        spec:
          skipDryRun: false
    
    # Step 8: Full Rolling Deployment
    - step:
        type: EcsRollingDeploy
        name: Full Deployment
        identifier: Full_Deployment
        spec:
          skipSteadyStateCheck: false
```

### ECS Architecture Components

#### Component Details

**1. ECS Cluster**
- Logical grouping of EC2 instances or Fargate capacity
- Manages container orchestration
- Handles task scheduling and placement

**2. ECS Service**
- Maintains desired number of tasks
- Handles load balancing
- Manages deployments and rollbacks
- Integrates with ALB/NLB

**3. Task Definition**
- Blueprint for containers
- Defines CPU, memory, networking
- Container images and configurations
- Environment variables and secrets

**4. Tasks**
- Running instances of task definitions
- Can run on EC2 or Fargate
- Networked via VPC
- Monitored via CloudWatch

**5. Application Load Balancer (ALB)**
- Routes traffic to ECS tasks
- Health checks
- SSL/TLS termination
- Path-based routing

**6. Elastic Container Registry (ECR)**
- Docker image repository
- Integrated with ECS
- Image scanning
- Lifecycle policies

---

## Architecture Diagrams

### Complete VM Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          HARNESS CD PLATFORM                            │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                         Pipeline Stage                           │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │  │
│  │  │  Build   │→ │   Test   │→ │  Deploy  │→ │  Verify  │     │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                              │                                          │
│                    ┌─────────▼─────────┐                                │
│                    │  Harness Delegate │                                │
│                    │   (Agent/Worker) │                                │
│                    └─────────┬─────────┘                                │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │
                               │ SSH Connection
                               │ (Port 22)
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼────────┐    ┌────────▼────────┐   ┌───────▼────────┐
│  VM Server 1   │    │  VM Server 2     │   │  VM Server N │
│  (Production)  │    │  (Staging)       │   │  (Development) │
│                │    │                  │   │                │
│  ┌──────────┐ │    │  ┌──────────┐   │   │  ┌──────────┐ │
│  │  OS:     │ │    │  │  OS:     │   │   │  │  OS:     │ │
│  │  Linux   │ │    │  │  Linux   │   │   │  │  Linux   │ │
│  └──────────┘ │    │  └──────────┘   │   │  └──────────┘ │
│                │    │                  │   │                │
│  ┌──────────┐ │    │  ┌──────────┐   │   │  ┌──────────┐ │
│  │  App     │ │    │  │  App     │   │   │  │  App     │ │
│  │ Service  │ │    │  │ Service  │   │   │  │ Service  │ │
│  │ Port:    │ │    │  │ Port:    │   │   │  │ Port:    │ │
│  │ 8080     │ │    │  │ 8080     │   │   │  │ 8080     │ │
│  └──────────┘ │    │  └──────────┘   │   │  └──────────┘ │
│                │    │                  │   │                │
│  ┌──────────┐ │    │  ┌──────────┐   │   │  ┌──────────┐ │
│  │  Config  │ │    │  │  Config  │   │   │  │  Config  │ │
│  │  Files   │ │    │  │  Files   │   │   │  │  Files   │ │
│  └──────────┘ │    │  └──────────┘   │   │  └──────────┘ │
│                │    │                  │   │                │
│  ┌──────────┐ │    │  ┌──────────┐   │   │  ┌──────────┐ │
│  │  Logs    │ │    │  │  Logs    │   │   │  │  Logs      │ │
│  │  /var/log│ │    │  │  /var/log│   │   │  │  /var/log  │ │
│  └──────────┘ │    │  └──────────┘   │   │  └──────────┘ │
└────────────────┘    └─────────────────┘   └────────────────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                    ┌───────────▼───────────┐
                    │   Artifact Repository  │
                    │  (Docker/Artifactory)  │
                    └────────────────────────┘
```

### Complete ECS Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          HARNESS CD PLATFORM                            │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                         Pipeline Stage                           │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │  │
│  │  │  Build   │→ │   Test   │→ │  Deploy  │→ │  Verify  │     │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                              │                                          │
│                    ┌─────────▼─────────┐                                │
│                    │  Harness Delegate │                                │
│                    │   (in AWS VPC)    │                                │
│                    └─────────┬─────────┘                                │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │
                               │ AWS API Calls
                               │ (ECS, EC2, ALB, CloudWatch)
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼────────┐    ┌────────▼────────┐   ┌───────▼────────┐
│  ECS Cluster  │    │  ECS Service     │   │  Task          │
│  (Production) │    │  (myapp-service) │   │  Definition    │
│               │    │                  │   │  (myapp-task)  │
│  ┌──────────┐ │    │  ┌────────────┐ │   │                │
│  │  Fargate  │ │    │  │  Desired   │ │   │  ┌──────────┐  │
│  │  Capacity│ │    │  │  Count: 3  │ │   │  │ Container │  │
│  └──────────┘ │    │  └────────────┘ │   │  │  Image    │  │
│               │    │                  │   │  │  Port:   │  │
│  ┌──────────┐ │    │  ┌────────────┐ │   │  │  8080     │  │
│  │  Tasks   │ │    │  │  Running   │ │   │  └──────────┘  │
│  │  Running │ │    │  │  Tasks: 3  │ │   │                │
│  └──────────┘ │    │  └────────────┘ │   │  ┌──────────┐  │
└───────┬───────┘    └────────┬─────────┘   │  │  CPU: 256 │  │
        │                     │             │  │  Memory:  │  │
        │                     │             │  │  512 MB   │  │
        │                     │             │  └──────────┘  │
        │                     │             └───────────────┘
        │                     │
        └─────────────────────┼─────────────────────┐
                              │                     │
                    ┌─────────▼─────────┐  ┌────────▼────────┐
                    │  Application      │  │  Target Group   │
                    │  Load Balancer    │  │  (ALB/NLB)      │
                    │  (ALB)            │  │                 │
                    │                   │  │  ┌──────────┐ │
                    │  ┌─────────────┐ │  │  │  Health    │ │
                    │  │  Listener    │ │  │  │  Checks    │ │
                    │  │  Port: 80/443│ │  │  └──────────┘ │
                    │  └─────────────┘ │  │                 │
                    └──────────────────┘  └─────────────────┘
                              │
                              │
                    ┌─────────▼─────────┐
                    │  ECR Registry     │
                    │  (Docker Images)  │
                    │                   │
                    │  ┌──────────────┐ │
                    │  │  myapp:v1.2.3 │ │
                    │  │  myapp:latest │ │
                    │  └──────────────┘ │
                    └───────────────────┘
```

---

## Dataflow Diagrams

### VM Deployment Dataflow (Detailed)

```
┌──────────────────────────────────────────────────────────────────────┐
│                    VM DEPLOYMENT DATAFLOW                           │
└──────────────────────────────────────────────────────────────────────┘

[TRIGGER]
    │
    ├─► Git Push Event
    ├─► Manual Trigger
    └─► Scheduled Trigger
    │
    ▼
[PIPELINE INITIATION]
    │
    ├─► Validate Pipeline Configuration
    ├─► Check Permissions
    └─► Initialize Execution Context
    │
    ▼
[ARTIFACT FETCH]
    │
    ├─► Connect to Artifact Source
    │   ├─► Docker Registry
    │   ├─► Artifactory
    │   └─► S3/File Server
    │
    ├─► Authenticate
    ├─► Fetch Artifact Metadata
    ├─► Download Artifact
    └─► Validate Artifact
    │
    ▼
[DELEGATE SELECTION]
    │
    ├─► Select Available Delegate
    ├─► Check Delegate Health
    └─► Assign Deployment Task
    │
    ▼
[SSH CONNECTION]
    │
    ├─► Establish SSH Connection
    │   ├─► Host: VM IP/Hostname
    │   ├─► Port: 22 (default)
    │   └─► Authentication: SSH Key/Password
    │
    ├─► Validate Connection
    ├─► Check SSH Access
    └─► Prepare Session
    │
    ▼
[PRE-DEPLOYMENT]
    │
    ├─► Backup Current Application
    │   ├─► Create Backup Directory
    │   ├─► Copy Application Files
    │   └─► Archive Backup
    │
    ├─► Stop Services
    │   ├─► systemctl stop myapp
    │   └─► Verify Service Stopped
    │
    ├─► Validate Environment
    │   ├─► Check Disk Space
    │   ├─► Check Memory
    │   └─► Check Dependencies
    │
    └─► Prepare Deployment Directory
    │
    ▼
[DEPLOYMENT EXECUTION]
    │
    ├─► Transfer Artifacts
    │   ├─► SCP/SFTP Transfer
    │   └─► Verify Transfer Complete
    │
    ├─► Extract/Install
    │   ├─► Extract Archive (tar, zip)
    │   ├─► Install Packages (rpm, deb)
    │   └─► Set Permissions
    │
    ├─► Update Configuration
    │   ├─► Copy Config Files
    │   ├─► Replace Variables
    │   └─► Validate Configuration
    │
    └─► Update System Services
        ├─► Update systemd service files
        └─► Reload systemd daemon
    │
    ▼
[POST-DEPLOYMENT]
    │
    ├─► Start Services
    │   ├─► systemctl start myapp
    │   └─► Verify Service Started
    │
    ├─► Health Checks
    │   ├─► Check Process Status
    │   ├─► Check Port Listening
    │   └─► HTTP Health Endpoint
    │
    ├─► Smoke Tests
    │   ├─► Test API Endpoints
    │   ├─► Verify Functionality
    │   └─► Check Logs for Errors
    │
    └─► Update Deployment Status
    │
    ▼
[CONTINUOUS VERIFICATION]
    │
    ├─► Monitor Metrics
    │   ├─► Prometheus Metrics
    │   ├─► Datadog Metrics
    │   └─► Custom Metrics
    │
    ├─► Analyze Performance
    │   ├─► Response Times
    │   ├─► Error Rates
    │   └─► Resource Usage
    │
    ├─► Detect Anomalies
    │   ├─► AI/ML Analysis
    │   └─► Threshold Checks
    │
    └─► Auto-Rollback Decision
        ├─► Issues Detected → Rollback
        └─► No Issues → Complete
    │
    ▼
[COMPLETION]
    │
    ├─► Success
    │   ├─► Update Deployment Status
    │   ├─► Send Notifications
    │   └─► Update Metrics
    │
    └─► Rollback (if needed)
        ├─► Stop New Services
        ├─► Restore Backup
        ├─► Start Old Services
        └─► Notify Team
```

### ECS Deployment Dataflow (Detailed)

```
┌──────────────────────────────────────────────────────────────────────┐
│                    ECS DEPLOYMENT DATAFLOW                           │
└──────────────────────────────────────────────────────────────────────┘

[TRIGGER]
    │
    ├─► CI Pipeline Completion
    ├─► Manual Trigger
    └─► Scheduled Trigger
    │
    ▼
[PIPELINE INITIATION]
    │
    ├─► Validate Pipeline Configuration
    ├─► Check AWS Permissions
    └─► Initialize Execution Context
    │
    ▼
[ECR ARTIFACT FETCH]
    │
    ├─► Connect to ECR
    │   ├─► Region: us-east-1
    │   ├─► Registry: 123456789012.dkr.ecr.us-east-1.amazonaws.com
    │   └─► Repository: myapp
    │
    ├─► Authenticate with AWS
    │   ├─► Get ECR Login Token
    │   └─► Authenticate Docker
    │
    ├─► Fetch Image Metadata
    │   ├─► Image Tag: v1.2.3
    │   ├─► Image Digest
    │   └─► Image Size
    │
    └─► Validate Image Exists
    │
    ▼
[DELEGATE SELECTION]
    │
    ├─► Select Delegate in AWS VPC
    ├─► Check Delegate Health
    └─► Assign Deployment Task
    │
    ▼
[AWS CONNECTION]
    │
    ├─► Authenticate with AWS
    │   ├─► IAM Role (preferred)
    │   ├─► Access Key/Secret Key
    │   └─► Validate Permissions
    │
    ├─► Connect to ECS API
    ├─► Connect to EC2 API (if EC2 launch type)
    └─► Connect to ALB API
    │
    ▼
[PRE-DEPLOYMENT]
    │
    ├─► Get Current Task Definition
    │   ├─► Fetch Latest Revision
    │   ├─► Parse Task Definition JSON
    │   └─► Extract Current Image
    │
    ├─► Get Current Service Status
    │   ├─► Running Task Count
    │   ├─► Desired Task Count
    │   └─► Service Health
    │
    ├─► Validate ECS Cluster
    │   ├─► Cluster Exists
    │   ├─► Cluster Status
    │   └─► Available Capacity
    │
    └─► Check Service Limits
        ├─► Service Quotas
        └─► Task Limits
    │
    ▼
[TASK DEFINITION CREATION]
    │
    ├─► Create New Task Definition Revision
    │   ├─► Copy Current Task Definition
    │   ├─► Update Container Image
    │   │   └─► New Image: <+artifact.image>
    │   ├─► Update Environment Variables
    │   ├─► Update Resource Limits (if needed)
    │   └─► Validate Task Definition
    │
    ├─► Register Task Definition
    │   ├─► Call ECS RegisterTaskDefinition API
    │   ├─► Get New Revision Number
    │   └─► Store Task Definition ARN
    │
    └─► Validate Registration
    │
    ▼
[DEPLOYMENT STRATEGY]
    │
    ├─► [ROLLING UPDATE]
    │   │
    │   ├─► Update Service
    │   │   ├─► Update Task Definition
    │   │   ├─► Set Desired Count
    │   │   └─► Configure Deployment
    │   │
    │   ├─► ECS Starts New Tasks
    │   │   ├─► Schedule Tasks on Fargate/EC2
    │   │   ├─► Pull Image from ECR
    │   │   ├─► Start Containers
    │   │   └─► Register with Target Group
    │   │
    │   ├─► Health Checks
    │   │   ├─► Container Health Check
    │   │   ├─► ALB Health Check
    │   │   └─► Wait for Healthy Status
    │   │
    │   ├─► Stop Old Tasks
    │   │   ├─► Deregister from ALB
    │   │   ├─► Drain Connections
    │   │   └─► Stop Containers
    │   │
    │   └─► Repeat for Each Task
    │
    ├─► [BLUE-GREEN]
    │   │
    │   ├─► Create Green Service
    │   │   ├─► New Service with New Task Definition
    │   │   ├─► Separate Target Group
    │   │   └─► Start Green Tasks
    │   │
    │   ├─► Verify Green Environment
    │   │   ├─► Health Checks
    │   │   └─► Smoke Tests
    │   │
    │   ├─► Route Traffic Gradually
    │   │   ├─► 10% to Green
    │   │   ├─► 50% to Green
    │   │   └─► 100% to Green
    │   │
    │   ├─► Monitor Green Environment
    │   │   ├─► Metrics Analysis
    │   │   └─► Error Rate Monitoring
    │   │
    │   └─► Terminate Blue Service
    │
    └─► [CANARY]
        │
        ├─► Deploy Canary Tasks
        │   ├─► 10% of Desired Count
        │   └─► New Task Definition
        │
        ├─► Verify Canary
        │   ├─► Health Checks
        │   └─► Performance Metrics
        │
        ├─► Increase Canary
        │   ├─► 25% → 50% → 100%
        │   └─► Verify at Each Stage
        │
        └─► Complete Deployment
    │
    ▼
[SERVICE UPDATE]
    │
    ├─► Update ECS Service
    │   ├─► Call UpdateService API
    │   ├─► Set New Task Definition
    │   ├─► Configure Deployment Settings
    │   │   ├─► Maximum Percent: 200%
    │   │   └─► Minimum Healthy Percent: 100%
    │   └─► Force New Deployment
    │
    ├─► Monitor Deployment Progress
    │   ├─► Track Task Status
    │   ├─► Monitor Service Events
    │   └─► Check Deployment Status
    │
    └─► Wait for Steady State
        ├─► All Tasks Running
        ├─► All Tasks Healthy
        └─► Deployment Complete
    │
    ▼
[POST-DEPLOYMENT VERIFICATION]
    │
    ├─► Check Task Status
    │   ├─► Running Count = Desired Count
    │   ├─► All Tasks in RUNNING State
    │   └─► No Failed Tasks
    │
    ├─► Health Checks
    │   ├─► Container Health Checks Passing
    │   ├─► ALB Target Health: Healthy
    │   └─► Application Health Endpoint
    │
    ├─► Endpoint Testing
    │   ├─► Test API Endpoints
    │   ├─► Verify Functionality
    │   └─► Check Response Times
    │
    └─► Log Verification
        ├─► Check CloudWatch Logs
        ├─► Verify No Errors
        └─► Monitor Application Logs
    │
    ▼
[CONTINUOUS VERIFICATION]
    │
    ├─► Monitor CloudWatch Metrics
    │   ├─► CPU Utilization
    │   ├─► Memory Utilization
    │   ├─► Request Count
    │   ├─► Error Rate
    │   └─► Response Time
    │
    ├─► Monitor Application Metrics
    │   ├─► Prometheus Metrics
    │   ├─► Datadog Metrics
    │   └─► Custom Metrics
    │
    ├─► AI/ML Analysis
    │   ├─► Baseline Comparison
    │   ├─► Anomaly Detection
    │   └─► Performance Analysis
    │
    ├─► Threshold Checks
    │   ├─► Error Rate < Threshold
    │   ├─► Response Time < Threshold
    │   └─► Resource Usage < Threshold
    │
    └─► Auto-Rollback Decision
        ├─► Issues Detected → Trigger Rollback
        └─► No Issues → Complete Deployment
    │
    ▼
[ROLLBACK (if needed)]
    │
    ├─► Detect Rollback Trigger
    │   ├─► High Error Rate
    │   ├─► Performance Degradation
    │   └─► Health Check Failures
    │
    ├─► Get Previous Task Definition
    │   ├─► Fetch Previous Revision
    │   └─► Get Task Definition ARN
    │
    ├─► Update Service
    │   ├─► Set Previous Task Definition
    │   └─► Force New Deployment
    │
    ├─► ECS Rolls Back
    │   ├─► Start Old Tasks
    │   ├─► Stop New Tasks
    │   └─► Restore Previous State
    │
    └─► Verify Rollback
        ├─► Service Health Restored
        └─► Notify Team
    │
    ▼
[COMPLETION]
    │
    ├─► Success
    │   ├─► Update Deployment Status
    │   ├─► Send Notifications (Slack, Email)
    │   ├─► Update Deployment History
    │   └─► Record Metrics
    │
    └─► Failure/Rollback
        ├─► Log Failure Reason
        ├─► Send Alerts
        └─► Update Status
```

---

## Detailed Configuration

### VM Deployment Configuration Details

#### SSH Connector Setup

```yaml
connector:
  name: vm-ssh-connector
  type: Ssh
  spec:
    host: production-vm-01.example.com
    port: 22
    type: Key
    spec:
      credentialType: KeyReference
      auth:
        type: Ssh
        spec:
          credentialType: KeyReference
          sshKeyRef: vm-ssh-key
```

#### Service Configuration for VM

```yaml
service:
  name: myapp-vm-service
  serviceDefinition:
    type: Ssh
    spec:
      artifacts:
        primary:
          type: DockerRegistry
          spec:
            connectorRef: docker-connector
            imagePath: myapp
            tag: <+pipeline.sequenceId>
      configFiles:
        - configFile:
            type: Ssh
            spec:
              store:
                type: Git
                spec:
                  connectorRef: git-connector
                  gitFetchType: Branch
                  paths:
                    - config/app.properties
                    - config/log4j.xml
                  repoName: config-repo
                  branch: main
      variables:
        - name: ENVIRONMENT
          value: production
        - name: LOG_LEVEL
          value: INFO
```

### ECS Deployment Configuration Details

#### AWS Connector Setup

```yaml
connector:
  name: aws-connector
  type: Aws
  spec:
    credential:
      type: ManualConfig
      spec:
        accessKey: <+secrets.getValue("aws_access_key")>
        secretKey: <+secrets.getValue("aws_secret_key")>
        region: us-east-1
    delegateSelectors: []
    executeOnDelegate: false
```

#### ECS Service Configuration

```yaml
service:
  name: myapp-ecs-service
  serviceDefinition:
    type: Ecs
    spec:
      artifacts:
        primary:
          type: Ecr
          spec:
            connectorRef: aws-connector
            imagePath: 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp
            tag: <+pipeline.sequenceId>
            region: us-east-1
      taskDefinition:
        taskDefinitionArn: arn:aws:ecs:us-east-1:123456789012:task-definition/myapp-task:10
      serviceDefinition:
        serviceName: myapp-service
        desiredCount: 3
        launchType: FARGATE
        platformVersion: LATEST
        networkConfiguration:
          awsvpcConfiguration:
            subnets:
              - subnet-12345678
              - subnet-87654321
            securityGroups:
              - sg-12345678
            assignPublicIp: ENABLED
        loadBalancers:
          - targetGroupArn: arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/myapp-tg/1234567890123456
            containerName: myapp-container
            containerPort: 8080
        healthCheckGracePeriodSeconds: 60
        deploymentConfiguration:
          maximumPercent: 200
          minimumHealthyPercent: 100
          deploymentCircuitBreaker:
            enable: true
            rollback: true
```

---

## Best Practices

### VM Deployment Best Practices

1. **SSH Security**
   - Use SSH keys instead of passwords
   - Rotate SSH keys regularly
   - Use bastion hosts for production
   - Implement SSH key management

2. **Backup Strategy**
   - Always backup before deployment
   - Keep multiple backup versions
   - Test restore procedures
   - Store backups off-server

3. **Health Checks**
   - Implement comprehensive health checks
   - Check both process and HTTP endpoints
   - Set appropriate timeouts
   - Retry failed health checks

4. **Rollback Plan**
   - Test rollback procedures
   - Keep previous versions available
   - Document rollback steps
   - Automate rollback when possible

5. **Monitoring**
   - Monitor application metrics
   - Set up alerts for failures
   - Log all deployment activities
   - Track deployment history

### ECS Deployment Best Practices

1. **Task Definition Management**
   - Version control task definitions
   - Use parameterized task definitions
   - Test task definitions before production
   - Keep previous revisions available

2. **Deployment Strategies**
   - Use Blue-Green for zero-downtime
   - Use Canary for gradual rollouts
   - Set appropriate health check grace periods
   - Configure deployment circuit breakers

3. **Resource Management**
   - Right-size CPU and memory
   - Use Fargate Spot for cost savings
   - Monitor resource utilization
   - Scale based on demand

4. **Load Balancer Configuration**
   - Use Application Load Balancer (ALB)
   - Configure health checks properly
   - Set up SSL/TLS termination
   - Use path-based routing

5. **Monitoring and Logging**
   - Enable CloudWatch logging
   - Monitor ECS service metrics
   - Set up CloudWatch alarms
   - Use Container Insights

---

## Conclusion

This document provides comprehensive workflows for deploying applications to both VMs and ECS using Harness CD. The detailed architecture diagrams, dataflow diagrams, and configuration examples should help you implement robust deployment pipelines for your applications.

For additional resources, refer to:
- [Harness CD Documentation](https://developer.harness.io/docs/continuous-delivery)
- [VM Deployment Guide](https://developer.harness.io/docs/continuous-delivery/deploy-srv-diff-platforms/ssh-how-tos)
- [ECS Deployment Guide](https://developer.harness.io/docs/continuous-delivery/deploy-srv-diff-platforms/aws-ecs-deployments)

---

*Last Updated: 2024*
