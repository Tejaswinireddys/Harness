# Harness AWS ECS Deployments - Technical Deep Dive

## Table of Contents
1. [Overview](#overview)
2. [ECS Architecture with Harness](#ecs-architecture-with-harness)
3. [Harness ECS Components](#harness-ecs-components)
4. [Deployment Strategies](#deployment-strategies)
5. [Service Configuration](#service-configuration)
6. [Container Management](#container-management)
7. [Auto Scaling and Load Balancing](#auto-scaling-and-load-balancing)
8. [Monitoring and Observability](#monitoring-and-observability)
9. [Security Implementation](#security-implementation)
10. [Networking and Service Discovery](#networking-and-service-discovery)
11. [Best Practices](#best-practices)
12. [Troubleshooting Guide](#troubleshooting-guide)

## Overview

This document provides a comprehensive technical deep-dive into AWS ECS (Elastic Container Service) deployments using Harness, covering container orchestration, service management, and operational considerations for containerized applications in AWS.

### Key Benefits of Harness for ECS Deployments
- **Native ECS Integration**: First-class support for ECS services and task definitions
- **Blue-Green Deployments**: Zero-downtime deployments with automatic traffic shifting
- **Canary Releases**: Progressive traffic routing with automated rollback
- **Auto Scaling**: Intelligent scaling based on application metrics
- **Service Mesh Support**: Integration with AWS App Mesh for advanced traffic management

## ECS Architecture with Harness

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Harness Control Plane                    │
├─────────────────────┬───────────────────┬───────────────────┤
│   Pipeline Engine   │   GitOps Engine   │  Policy Engine    │
└─────────────────────┴───────────────────┴───────────────────┘
                              │
                              │
┌─────────────────────────────▼─────────────────────────────────┐
│                      Harness Delegate                        │
│              (Running in ECS/EC2/Fargate)                    │
└─────────────────────────────┬─────────────────────────────────┘
                              │
                              │
┌─────────────────────────────▼─────────────────────────────────┐
│                      AWS ECS Infrastructure                   │
├─────────────────────┬───────────────────┬───────────────────┤
│    ECS Clusters     │     Services      │   Task Definitions │
├─────────────────────┼───────────────────┼───────────────────┤
│   - EC2 Launch      │  - Service        │  - Container      │
│     Type            │    Discovery      │    Specs          │
│   - Fargate         │  - Load Balancer  │  - Resource       │
│     Launch Type     │    Integration    │    Requirements   │
│   - Capacity        │  - Auto Scaling   │  - IAM Roles      │
│     Providers       │                   │                   │
└─────────────────────┴───────────────────┴───────────────────┘
```

### Component Breakdown

#### 1. ECS Cluster
- **Compute Resources**: EC2 instances or AWS Fargate
- **Capacity Providers**: Auto Scaling Groups for EC2, Fargate/Fargate Spot
- **Networking**: VPC, subnets, security groups
- **Service Discovery**: AWS Cloud Map integration

#### 2. ECS Services
- **Service Definition**: Desired count, task definition, networking
- **Load Balancer Integration**: ALB/NLB target group management
- **Service Auto Scaling**: Target tracking and step scaling
- **Rolling Updates**: Deployment configuration and health checks

#### 3. Task Definitions
- **Container Specifications**: Image URI, resource requirements
- **Task Role**: IAM permissions for application
- **Task Execution Role**: IAM permissions for ECS agent
- **Logging**: CloudWatch Logs integration

## Harness ECS Components

### 1. ECS Service Configuration

```yaml
# ECS Service Definition in Harness
apiVersion: v1
kind: Service
metadata:
  name: web-app-ecs
  identifier: web_app_ecs
spec:
  serviceDefinition:
    type: ECS
    spec:
      artifacts:
        primary:
          spec:
            connectorRef: ecr_connector
            imagePath: "123456789012.dkr.ecr.us-east-1.amazonaws.com/web-app"
            tag: <+input>
          type: DockerRegistry
      manifests:
        - manifest:
            identifier: ecs_task_definition
            type: EcsTaskDefinition
            spec:
              store:
                type: Harness
                spec:
                  files:
                    - /task-definition.json
        - manifest:
            identifier: ecs_service_definition
            type: EcsServiceDefinition
            spec:
              store:
                type: Harness
                spec:
                  files:
                    - /service-definition.json
      variables:
        - name: cpu_units
          type: String
          value: "512"
        - name: memory_units
          type: String
          value: "1024"
        - name: desired_count
          type: Number
          value: 3
```

### 2. Task Definition Template

```json
{
  "family": "web-app-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "<+serviceVariables.cpu_units>",
  "memory": "<+serviceVariables.memory_units>",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "web-app-container",
      "image": "<+artifacts.primary.image>",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/web-app",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "environment": [
        {
          "name": "APP_ENV",
          "value": "<+env.name>"
        },
        {
          "name": "APP_PORT",
          "value": "8080"
        }
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-password"
        }
      ],
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8080/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "ulimits": [
        {
          "name": "nofile",
          "softLimit": 65536,
          "hardLimit": 65536
        }
      ],
      "stopTimeout": 30
    },
    {
      "name": "datadog-agent",
      "image": "datadog/agent:latest",
      "portMappings": [
        {
          "containerPort": 8125,
          "protocol": "udp"
        }
      ],
      "essential": false,
      "environment": [
        {
          "name": "DD_API_KEY",
          "value": "<+secrets.getValue('datadog_api_key')>"
        },
        {
          "name": "DD_SITE",
          "value": "datadoghq.com"
        },
        {
          "name": "ECS_FARGATE",
          "value": "true"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/datadog-agent",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### 3. Service Definition Template

```json
{
  "serviceName": "web-app-service",
  "cluster": "production-cluster",
  "taskDefinition": "web-app-task",
  "desiredCount": <+serviceVariables.desired_count>,
  "launchType": "FARGATE",
  "platformVersion": "LATEST",
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": [
        "subnet-12345678",
        "subnet-87654321"
      ],
      "securityGroups": [
        "sg-12345678"
      ],
      "assignPublicIp": "DISABLED"
    }
  },
  "loadBalancers": [
    {
      "targetGroupArn": "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-app-tg/1234567890123456",
      "containerName": "web-app-container",
      "containerPort": 8080
    }
  ],
  "serviceRegistries": [
    {
      "registryArn": "arn:aws:servicediscovery:us-east-1:123456789012:service/srv-12345678",
      "containerName": "web-app-container",
      "containerPort": 8080
    }
  ],
  "deploymentConfiguration": {
    "maximumPercent": 200,
    "minimumHealthyPercent": 50,
    "deploymentCircuitBreaker": {
      "enable": true,
      "rollback": true
    }
  },
  "serviceTags": [
    {
      "key": "Environment",
      "value": "<+env.name>"
    },
    {
      "key": "Application",
      "value": "web-app"
    },
    {
      "key": "ManagedBy",
      "value": "Harness"
    }
  ]
}
```

### 4. ECS Environment Configuration

```yaml
# ECS Environment Definition
apiVersion: v1
kind: Environment
metadata:
  name: production-ecs-env
  identifier: prod_ecs_env
spec:
  type: Production
  tags:
    environment: production
    platform: ecs
  variables:
    - name: cluster_name
      type: String
      value: "production-cluster"
    - name: vpc_id
      type: String
      value: "vpc-12345678"
    - name: private_subnet_ids
      type: String
      value: "subnet-12345678,subnet-87654321"
  infrastructureDefinitions:
    - name: ecs-fargate-infrastructure
      identifier: ecs_fargate_infra
      spec:
        cloudProviderType: Aws
        deploymentType: ECS
        spec:
          cloudProviderRef: aws_connector
          cluster: <+env.variables.cluster_name>
          region: us-east-1
          launchType: FARGATE
```

## Deployment Strategies

### 1. Blue-Green Deployment

```yaml
# Blue-Green ECS Deployment Pipeline
apiVersion: v1
kind: Pipeline
metadata:
  name: ecs-blue-green-deployment
spec:
  stages:
    - stage:
        name: Blue Green Deploy
        identifier: blue_green_deploy
        type: Deployment
        spec:
          deploymentType: ECS
          service:
            serviceRef: web_app_ecs
          environment:
            environmentRef: prod_ecs_env
            infrastructureDefinitions:
              - identifier: ecs_fargate_infra
          execution:
            steps:
              - step:
                  type: EcsBlueGreenCreateService
                  name: Create Blue Green Service
                  identifier: create_bg_service
                  spec:
                    loadBalancer: "web-app-alb"
                    prodListener: "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web-app-alb/1234567890123456/1234567890123456"
                    prodListenerRuleArn: "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener-rule/app/web-app-alb/1234567890123456/1234567890123456/1234567890123456"
                    stageListener: "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web-app-alb/1234567890123456/1234567890123456"
                    stageListenerRuleArn: "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener-rule/app/web-app-alb/1234567890123456/1234567890123456/1234567890123456"
              
              - step:
                  type: EcsBlueGreenSwapTargetGroups
                  name: Swap Target Groups
                  identifier: swap_target_groups
                  spec:
                    downsizeOldService: true
                  timeout: 10m
                  
              - step:
                  type: Http
                  name: Health Check
                  identifier: health_check
                  spec:
                    url: "https://web-app-alb-123456789.us-east-1.elb.amazonaws.com/health"
                    method: GET
                    headers:
                      - key: "User-Agent"
                        value: "Harness-Health-Check"
                    assertion: <+httpResponseCode> == 200 && <+httpResponseBody>.contains("healthy")
                    timeout: 30s
          rollbackSteps:
            - step:
                type: EcsBlueGreenRollback
                name: Rollback Blue Green Deployment
                identifier: rollback_bg_deployment
                timeout: 10m
```

### 2. Canary Deployment

```yaml
# Canary ECS Deployment Pipeline
apiVersion: v1
kind: Pipeline
metadata:
  name: ecs-canary-deployment
spec:
  stages:
    - stage:
        name: Canary Deploy
        identifier: canary_deploy
        type: Deployment
        spec:
          deploymentType: ECS
          service:
            serviceRef: web_app_ecs
          environment:
            environmentRef: prod_ecs_env
            infrastructureDefinitions:
              - identifier: ecs_fargate_infra
          execution:
            steps:
              - step:
                  type: EcsCanaryDeploy
                  name: Canary Deploy
                  identifier: canary_deploy_step
                  spec:
                    instances:
                      type: Count
                      spec:
                        count: 1
                  timeout: 10m
              
              - step:
                  type: EcsCanaryDelete
                  name: Canary Delete
                  identifier: canary_delete
                  timeout: 10m
              
              - step:
                  type: EcsRollingDeploy
                  name: Primary Deploy
                  identifier: primary_deploy
                  timeout: 10m
          rollbackSteps:
            - step:
                type: EcsRollingRollback
                name: Rollback Rolling Deployment
                identifier: rollback_deployment
                timeout: 10m

  # Advanced Canary with Traffic Shifting
  - stage:
      name: Advanced Canary Deploy
      identifier: advanced_canary_deploy
      type: Deployment
      spec:
        deploymentType: ECS
        execution:
          steps:
            - stepGroup:
                name: Canary Phase 1
                identifier: canary_phase_1
                steps:
                  - step:
                      type: EcsCanaryDeploy
                      name: Deploy 10%
                      identifier: deploy_10_percent
                      spec:
                        instances:
                          type: Percentage
                          spec:
                            percentage: 10
                  
                  - step:
                      type: ApprovalStep
                      name: Manual Approval - 10%
                      identifier: approval_10_percent
                      spec:
                        message: "Canary deployment at 10%. Approve to continue?"
                        timeout: 1h
            
            - stepGroup:
                name: Canary Phase 2
                identifier: canary_phase_2
                steps:
                  - step:
                      type: EcsCanaryDeploy
                      name: Deploy 50%
                      identifier: deploy_50_percent
                      spec:
                        instances:
                          type: Percentage
                          spec:
                            percentage: 50
                  
                  - step:
                      type: Verify
                      name: Performance Verification
                      identifier: performance_verify
                      spec:
                        type: Prometheus
                        spec:
                          connectorRef: prometheus_connector
                          query: "rate(http_requests_total[5m])"
                          threshold: 1000
            
            - step:
                type: EcsCanaryDelete
                name: Canary Delete
                identifier: canary_delete_final
                timeout: 10m
            
            - step:
                type: EcsRollingDeploy
                name: Primary Deploy
                identifier: primary_deploy_final
                timeout: 10m
```

### 3. Rolling Deployment

```yaml
# Rolling ECS Deployment
rolling_deployment:
  type: EcsRollingDeploy
  name: Rolling Deploy
  identifier: rolling_deploy
  spec:
    # Optional: Override service definition for this deployment
    ecsServiceDefinitionOverrides:
      spec:
        desiredCount: <+pipeline.variables.target_instances>
        deploymentConfiguration:
          maximumPercent: 200
          minimumHealthyPercent: 50
          deploymentCircuitBreaker:
            enable: true
            rollback: true
    
    # Optional: Override task definition for this deployment
    ecsTaskDefinitionOverrides:
      spec:
        containerDefinitions:
          - name: web-app-container
            environment:
              - name: DEPLOYMENT_VERSION
                value: <+pipeline.sequenceId>
              - name: BUILD_NUMBER
                value: <+pipeline.variables.build_number>
  timeout: 10m

# Advanced Rolling with Health Checks
advanced_rolling:
  type: EcsRollingDeploy
  name: Advanced Rolling Deploy
  identifier: advanced_rolling_deploy
  spec:
    ecsServiceDefinitionOverrides:
      spec:
        healthCheckGracePeriodSeconds: 300
        deploymentConfiguration:
          maximumPercent: 150
          minimumHealthyPercent: 75
    
    # Post-deployment verification
    postDeploymentSteps:
      - step:
          type: ShellScript
          name: Service Discovery Check
          identifier: service_discovery_check
          spec:
            shell: Bash
            onDelegate: true
            source:
              type: Inline
              spec:
                script: |
                  #!/bin/bash
                  
                  # Check service registration in AWS Cloud Map
                  SERVICE_ID="srv-12345678"
                  NAMESPACE_ID="ns-12345678"
                  
                  # Wait for service to be registered
                  for i in {1..30}; do
                    INSTANCES=$(aws servicediscovery list-instances \
                      --service-id $SERVICE_ID \
                      --query 'Instances[?contains(Attributes.AWS_INSTANCE_IPV4, `10.0.`)]' \
                      --output json)
                    
                    INSTANCE_COUNT=$(echo $INSTANCES | jq '. | length')
                    
                    if [ "$INSTANCE_COUNT" -ge "<+serviceVariables.desired_count>" ]; then
                      echo "All instances registered in service discovery"
                      exit 0
                    fi
                    
                    echo "Waiting for service discovery registration... ($i/30)"
                    sleep 10
                  done
                  
                  echo "Service discovery registration timeout"
                  exit 1
  timeout: 15m
```

## Service Configuration

### 1. Auto Scaling Configuration

```yaml
# ECS Service Auto Scaling
auto_scaling:
  service_name: "web-app-service"
  cluster_name: "production-cluster"
  
  # Target Tracking Scaling Policies
  target_tracking_policies:
    - policy_name: "cpu-target-tracking"
      target_value: 70.0
      metric_type: "ECSServiceAverageCPUUtilization"
      scale_out_cooldown: 300
      scale_in_cooldown: 300
      disable_scale_in: false
    
    - policy_name: "memory-target-tracking"
      target_value: 80.0
      metric_type: "ECSServiceAverageMemoryUtilization"
      scale_out_cooldown: 300
      scale_in_cooldown: 300
      disable_scale_in: false
    
    - policy_name: "alb-request-count-tracking"
      target_value: 1000.0
      metric_type: "ALBRequestCountPerTarget"
      resource_label: "app/web-app-alb/1234567890123456/targetgroup/web-app-tg/1234567890123456"
      scale_out_cooldown: 300
      scale_in_cooldown: 300

  # Step Scaling Policies
  step_scaling_policies:
    - policy_name: "scale-out-on-high-cpu"
      adjustment_type: "ChangeInCapacity"
      metric_aggregation_type: "Average"
      cooldown: 300
      step_adjustments:
        - metric_interval_lower_bound: 0
          metric_interval_upper_bound: 20
          scaling_adjustment: 1
        - metric_interval_lower_bound: 20
          scaling_adjustment: 2
      
      # CloudWatch Alarm
      alarm_name: "high-cpu-alarm"
      alarm_description: "Scale out on high CPU"
      metric_name: "CPUUtilization"
      namespace: "AWS/ECS"
      statistic: "Average"
      dimensions:
        ServiceName: "web-app-service"
        ClusterName: "production-cluster"
      period: 300
      evaluation_periods: 2
      threshold: 80.0
      comparison_operator: "GreaterThanThreshold"
    
    - policy_name: "scale-in-on-low-cpu"
      adjustment_type: "ChangeInCapacity"
      metric_aggregation_type: "Average"
      cooldown: 300
      step_adjustments:
        - metric_interval_upper_bound: 0
          scaling_adjustment: -1
      
      # CloudWatch Alarm
      alarm_name: "low-cpu-alarm"
      alarm_description: "Scale in on low CPU"
      metric_name: "CPUUtilization"
      namespace: "AWS/ECS"
      statistic: "Average"
      dimensions:
        ServiceName: "web-app-service"
        ClusterName: "production-cluster"
      period: 300
      evaluation_periods: 3
      threshold: 30.0
      comparison_operator: "LessThanThreshold"

  # Scaling Configuration
  scaling_configuration:
    min_capacity: 2
    max_capacity: 20
    scale_out_cooldown: 300
    scale_in_cooldown: 300
```

### 2. Load Balancer Integration

```yaml
# Application Load Balancer Configuration for ECS
load_balancer:
  alb_configuration:
    name: "web-app-alb"
    scheme: "internet-facing"
    type: "application"
    ip_address_type: "ipv4"
    
    subnets:
      - "subnet-12345678"  # Public subnet AZ-1
      - "subnet-87654321"  # Public subnet AZ-2
    
    security_groups:
      - "sg-alb-12345678"
    
    tags:
      Environment: "production"
      Application: "web-app"
      ManagedBy: "Harness"
    
    # Listeners
    listeners:
      - port: 80
        protocol: "HTTP"
        default_actions:
          - type: "redirect"
            redirect:
              protocol: "HTTPS"
              port: "443"
              status_code: "HTTP_301"
      
      - port: 443
        protocol: "HTTPS"
        ssl_policy: "ELBSecurityPolicy-TLS-1-2-2017-01"
        certificate_arn: "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
        default_actions:
          - type: "forward"
            target_group_arn: "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-app-tg/1234567890123456"
    
    # Target Groups
    target_groups:
      - name: "web-app-tg"
        port: 8080
        protocol: "HTTP"
        vpc_id: "vpc-12345678"
        target_type: "ip"
        
        health_check:
          enabled: true
          healthy_threshold_count: 2
          unhealthy_threshold_count: 2
          timeout: 5
          interval: 30
          path: "/health"
          port: "traffic-port"
          protocol: "HTTP"
          matcher: "200"
        
        attributes:
          deregistration_delay.timeout_seconds: 30
          load_balancing.algorithm.type: "round_robin"
          stickiness.enabled: false
          slow_start.duration_seconds: 30
        
        tags:
          Environment: "production"
          Application: "web-app"

# Network Load Balancer Configuration (Alternative)
nlb_configuration:
  name: "web-app-nlb"
  scheme: "internet-facing"
  type: "network"
  ip_address_type: "ipv4"
  
  subnets:
    - "subnet-12345678"
    - "subnet-87654321"
  
  listeners:
    - port: 80
      protocol: "TCP"
      default_actions:
        - type: "forward"
          target_group_arn: "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-app-nlb-tg/1234567890123456"
  
  target_groups:
    - name: "web-app-nlb-tg"
      port: 8080
      protocol: "TCP"
      vpc_id: "vpc-12345678"
      target_type: "ip"
      
      health_check:
        enabled: true
        healthy_threshold_count: 3
        unhealthy_threshold_count: 3
        timeout: 10
        interval: 30
        port: "traffic-port"
        protocol: "TCP"
```

## Container Management

### 1. Container Image Management

```yaml
# Container Registry Integration
container_registry:
  ecr_configuration:
    registry_url: "123456789012.dkr.ecr.us-east-1.amazonaws.com"
    repositories:
      - name: "web-app"
        image_tag_mutability: "MUTABLE"
        image_scanning_configuration:
          scan_on_push: true
        
        lifecycle_policy: |
          {
            "rules": [
              {
                "rulePriority": 1,
                "description": "Keep last 10 production images",
                "selection": {
                  "tagStatus": "tagged",
                  "tagPrefixList": ["prod"],
                  "countType": "imageCountMoreThan",
                  "countNumber": 10
                },
                "action": {
                  "type": "expire"
                }
              },
              {
                "rulePriority": 2,
                "description": "Keep last 5 development images",
                "selection": {
                  "tagStatus": "tagged",
                  "tagPrefixList": ["dev"],
                  "countType": "imageCountMoreThan",
                  "countNumber": 5
                },
                "action": {
                  "type": "expire"
                }
              },
              {
                "rulePriority": 3,
                "description": "Delete untagged images older than 1 day",
                "selection": {
                  "tagStatus": "untagged",
                  "countType": "sinceImagePushed",
                  "countUnit": "days",
                  "countNumber": 1
                },
                "action": {
                  "type": "expire"
                }
              }
            ]
          }

# Image Building Pipeline
image_build_pipeline:
  stages:
    - stage:
        name: Build and Push Image
        identifier: build_push_image
        type: CI
        spec:
          cloneCodebase: true
          platform:
            os: Linux
            arch: Amd64
          runtime:
            type: Cloud
            spec: {}
          execution:
            steps:
              - step:
                  type: RestoreCacheS3
                  name: Restore Cache
                  identifier: restore_cache
                  spec:
                    connectorRef: aws_connector
                    region: us-east-1
                    bucket: harness-cache-bucket
                    key: "docker-{{ checksum 'Dockerfile' }}"
                    archiveFormat: Tar
              
              - step:
                  type: Run
                  name: Build Application
                  identifier: build_app
                  spec:
                    connectorRef: docker_hub_connector
                    image: openjdk:11-jdk-slim
                    shell: Bash
                    command: |
                      # Install Maven
                      apt-get update && apt-get install -y maven
                      
                      # Build application
                      mvn clean package -DskipTests
                      
                      # Copy artifact for Docker build
                      cp target/app.jar .
              
              - step:
                  type: BuildAndPushDockerRegistry
                  name: Build and Push Image
                  identifier: build_push_docker
                  spec:
                    connectorRef: ecr_connector
                    repo: "123456789012.dkr.ecr.us-east-1.amazonaws.com/web-app"
                    tags:
                      - "latest"
                      - "<+pipeline.sequenceId>"
                      - "prod-<+pipeline.sequenceId>"
                    dockerfile: Dockerfile
                    context: .
                    buildArgs:
                      BUILD_DATE: "<+pipeline.startTs>"
                      VERSION: "<+pipeline.sequenceId>"
              
              - step:
                  type: SaveCacheS3
                  name: Save Cache
                  identifier: save_cache
                  spec:
                    connectorRef: aws_connector
                    region: us-east-1
                    bucket: harness-cache-bucket
                    key: "docker-{{ checksum 'Dockerfile' }}"
                    sourcePaths:
                      - "/var/lib/docker"
                    archiveFormat: Tar
```

### 2. Multi-Architecture Builds

```dockerfile
# Multi-stage Dockerfile for optimized container images
FROM openjdk:11-jdk-slim as build

# Install build dependencies
RUN apt-get update && \
    apt-get install -y maven && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy pom.xml first for better caching
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests && \
    mkdir -p target/dependency && \
    (cd target/dependency; jar -xf ../*.jar)

# Production image
FROM openjdk:11-jre-slim

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y curl dumb-init && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy application artifacts from build stage
ARG DEPENDENCY=/app/target/dependency
COPY --from=build ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=build ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=build ${DEPENDENCY}/BOOT-INF/classes /app

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Build arguments
ARG BUILD_DATE
ARG VERSION
LABEL build_date=${BUILD_DATE}
LABEL version=${VERSION}

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose port
EXPOSE 8080

# Use dumb-init as PID 1
ENTRYPOINT ["dumb-init", "--"]

# Run application
CMD ["java", "-cp", "app:app/lib/*", "com.example.Application"]
```

## Auto Scaling and Load Balancing

### 1. Advanced Auto Scaling

```yaml
# Custom Metrics Auto Scaling
custom_metrics_scaling:
  cloudwatch_metrics:
    - metric_name: "active_connections"
      namespace: "Custom/WebApp"
      dimensions:
        ServiceName: "web-app-service"
        ClusterName: "production-cluster"
      statistic: "Average"
      unit: "Count"
    
    - metric_name: "queue_depth"
      namespace: "Custom/WebApp"
      dimensions:
        QueueName: "processing-queue"
      statistic: "Average"
      unit: "Count"

  scaling_policies:
    - policy_name: "scale-on-active-connections"
      policy_type: "TargetTrackingScaling"
      target_tracking_configuration:
        target_value: 100.0
        customized_metric_specification:
          metric_name: "active_connections"
          namespace: "Custom/WebApp"
          statistic: "Average"
          dimensions:
            - name: "ServiceName"
              value: "web-app-service"
        scale_out_cooldown: 300
        scale_in_cooldown: 600
    
    - policy_name: "scale-on-queue-depth"
      policy_type: "StepScaling"
      step_scaling_configuration:
        adjustment_type: "ChangeInCapacity"
        cooldown: 300
        step_adjustments:
          - metric_interval_lower_bound: 0
            metric_interval_upper_bound: 50
            scaling_adjustment: 1
          - metric_interval_lower_bound: 50
            metric_interval_upper_bound: 100
            scaling_adjustment: 2
          - metric_interval_lower_bound: 100
            scaling_adjustment: 3

# Scheduled Scaling
scheduled_scaling:
  schedules:
    - name: "scale-up-business-hours"
      description: "Scale up during business hours"
      schedule: "cron(0 8 ? * MON-FRI *)"  # 8 AM weekdays
      timezone: "America/New_York"
      scalable_target_action:
        min_capacity: 5
        max_capacity: 20
    
    - name: "scale-down-off-hours"
      description: "Scale down during off hours"
      schedule: "cron(0 20 ? * MON-FRI *)"  # 8 PM weekdays
      timezone: "America/New_York"
      scalable_target_action:
        min_capacity: 2
        max_capacity: 10
    
    - name: "weekend-scaling"
      description: "Minimal scaling on weekends"
      schedule: "cron(0 0 ? * SAT *)"  # Saturday midnight
      timezone: "America/New_York"
      scalable_target_action:
        min_capacity: 1
        max_capacity: 5
```

### 2. Advanced Load Balancing

```yaml
# Application Load Balancer with Advanced Routing
alb_advanced_routing:
  listeners:
    - port: 443
      protocol: "HTTPS"
      rules:
        # API versioning routing
        - priority: 100
          conditions:
            - field: "path-pattern"
              values: ["/api/v1/*"]
          actions:
            - type: "forward"
              target_group_arn: "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-app-v1-tg/1234567890123456"
        
        - priority: 200
          conditions:
            - field: "path-pattern"
              values: ["/api/v2/*"]
          actions:
            - type: "forward"
              target_group_arn: "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-app-v2-tg/1234567890123456"
        
        # Header-based routing
        - priority: 300
          conditions:
            - field: "http-header"
              http_header_config:
                http_header_name: "User-Agent"
                values: ["MobileApp/*"]
          actions:
            - type: "forward"
              target_group_arn: "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mobile-api-tg/1234567890123456"
        
        # Geographic routing
        - priority: 400
          conditions:
            - field: "source-ip"
              values: ["192.0.2.0/24", "203.0.113.0/24"]  # Specific IP ranges
          actions:
            - type: "forward"
              target_group_arn: "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/regional-tg/1234567890123456"
        
        # Weighted routing for A/B testing
        - priority: 500
          conditions:
            - field: "query-string"
              query_string_config:
                values:
                  - key: "experiment"
                    value: "new-feature"
          actions:
            - type: "forward"
              forward_config:
                target_groups:
                  - target_group_arn: "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-app-tg/1234567890123456"
                    weight: 80
                  - target_group_arn: "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/experiment-tg/1234567890123456"
                    weight: 20
        
        # Default rule
        - priority: 1000
          conditions: []
          actions:
            - type: "forward"
              target_group_arn: "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-app-tg/1234567890123456"

# WAF Integration
waf_configuration:
  web_acl:
    name: "web-app-waf"
    scope: "REGIONAL"
    default_action: "ALLOW"
    rules:
      - name: "RateLimitRule"
        priority: 1
        statement:
          rate_based_statement:
            limit: 2000
            aggregate_key_type: "IP"
        action: "BLOCK"
        visibility_config:
          sampled_requests_enabled: true
          cloud_watch_metrics_enabled: true
          metric_name: "RateLimitRule"
      
      - name: "SQLInjectionRule"
        priority: 2
        statement:
          managed_rule_group_statement:
            vendor_name: "AWS"
            name: "AWSManagedRulesSQLiRuleSet"
        override_action: "NONE"
        visibility_config:
          sampled_requests_enabled: true
          cloud_watch_metrics_enabled: true
          metric_name: "SQLInjectionRule"
      
      - name: "XSSRule"
        priority: 3
        statement:
          managed_rule_group_statement:
            vendor_name: "AWS"
            name: "AWSManagedRulesKnownBadInputsRuleSet"
        override_action: "NONE"
        visibility_config:
          sampled_requests_enabled: true
          cloud_watch_metrics_enabled: true
          metric_name: "XSSRule"
```

## Monitoring and Observability

### 1. Container Insights and Monitoring

```yaml
# CloudWatch Container Insights
container_insights:
  cluster_name: "production-cluster"
  
  # Enable Container Insights
  enable_container_insights: true
  
  # Custom Log Groups
  log_groups:
    - name: "/ecs/web-app"
      retention_in_days: 30
      kms_key_id: "alias/cloudwatch-logs"
    
    - name: "/ecs/datadog-agent"
      retention_in_days: 7

  # Custom Metrics
  custom_metrics:
    - metric_name: "TaskCount"
      namespace: "ECS/ContainerInsights"
      dimensions:
        ClusterName: "production-cluster"
        ServiceName: "web-app-service"
      unit: "Count"
    
    - metric_name: "ServiceCPUUtilization"
      namespace: "ECS/ContainerInsights"
      dimensions:
        ClusterName: "production-cluster"
        ServiceName: "web-app-service"
      unit: "Percent"

# Prometheus Integration
prometheus_config:
  scrape_configs:
    - job_name: "ecs-service-discovery"
      ec2_sd_configs:
        - region: "us-east-1"
          port: 8080
          filters:
            - name: "tag:aws:ecs:cluster-name"
              values: ["production-cluster"]
            - name: "tag:aws:ecs:service-name"
              values: ["web-app-service"]
      
      relabel_configs:
        - source_labels: ["__meta_ec2_tag_aws_ecs_task_family"]
          target_label: "task_family"
        - source_labels: ["__meta_ec2_tag_aws_ecs_task_revision"]
          target_label: "task_revision"
        - source_labels: ["__meta_ec2_tag_aws_ecs_cluster_name"]
          target_label: "cluster"
        - source_labels: ["__meta_ec2_tag_aws_ecs_service_name"]
          target_label: "service"

# X-Ray Tracing
xray_tracing:
  daemon_container:
    name: "xray-daemon"
    image: "amazon/aws-xray-daemon:latest"
    port_mappings:
      - container_port: 2000
        protocol: "udp"
    environment:
      - name: "AWS_REGION"
        value: "us-east-1"
    log_configuration:
      log_driver: "awslogs"
      options:
        awslogs-group: "/ecs/xray-daemon"
        awslogs-region: "us-east-1"
        awslogs-stream-prefix: "ecs"

  # Application instrumentation
  application_config:
    environment:
      - name: "_X_AMZN_TRACE_ID"
        value: "Root=1-5e1b4151-5ac6c58d3a24a43e5a1a93c1"
      - name: "AWS_XRAY_TRACING_NAME"
        value: "web-app"
      - name: "AWS_XRAY_DEBUG_MODE"
        value: "true"
```

### 2. Application Performance Monitoring

```yaml
# APM Integration with Datadog
datadog_apm:
  agent_configuration:
    container_definition:
      name: "datadog-agent"
      image: "datadog/agent:latest"
      port_mappings:
        - container_port: 8125
          protocol: "udp"  # StatsD
        - container_port: 8126
          protocol: "tcp"  # APM
      environment:
        - name: "DD_API_KEY"
          value: "<+secrets.getValue('datadog_api_key')>"
        - name: "DD_SITE"
          value: "datadoghq.com"
        - name: "DD_APM_ENABLED"
          value: "true"
        - name: "DD_APM_NON_LOCAL_TRAFFIC"
          value: "true"
        - name: "ECS_FARGATE"
          value: "true"
        - name: "DD_DOGSTATSD_NON_LOCAL_TRAFFIC"
          value: "true"

  application_instrumentation:
    java_agent:
      download_url: "https://dtdg.co/latest-java-tracer"
      jvm_args:
        - "-javaagent:/opt/dd-java-agent.jar"
        - "-Ddd.service=web-app"
        - "-Ddd.env=production"
        - "-Ddd.version=<+pipeline.sequenceId>"
        - "-Ddd.agent.host=localhost"
        - "-Ddd.agent.port=8126"

# Custom Application Metrics
application_metrics:
  micrometer_config:
    management:
      endpoints:
        web:
          exposure:
            include: "health,info,metrics,prometheus"
      metrics:
        export:
          prometheus:
            enabled: true
          datadog:
            enabled: true
            api-key: "<+secrets.getValue('datadog_api_key')>"
            step: "30s"
        tags:
          application: "web-app"
          environment: "production"
          version: "<+pipeline.sequenceId>"

  custom_metrics:
    - name: "business_transactions_total"
      type: "counter"
      description: "Total number of business transactions"
      tags: ["transaction_type", "status"]
    
    - name: "order_processing_duration_seconds"
      type: "timer"
      description: "Time taken to process orders"
      tags: ["order_type", "customer_segment"]
    
    - name: "active_user_sessions"
      type: "gauge"
      description: "Number of active user sessions"
      tags: ["user_type", "region"]
```

## Security Implementation

### 1. IAM Roles and Policies

```json
{
  "TaskExecutionRole": {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  },
  "TaskExecutionRolePolicy": {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Resource": [
          "arn:aws:secretsmanager:us-east-1:123456789012:secret:web-app/*"
        ]
      }
    ]
  },
  "TaskRole": {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  },
  "TaskRolePolicy": {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        "Resource": [
          "arn:aws:s3:::web-app-assets/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        "Resource": [
          "arn:aws:dynamodb:us-east-1:123456789012:table/web-app-*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage"
        ],
        "Resource": [
          "arn:aws:sqs:us-east-1:123456789012:web-app-queue"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        "Resource": "*"
      }
    ]
  }
}
```

### 2. Network Security

```yaml
# VPC Security Groups
security_groups:
  alb_security_group:
    name: "web-app-alb-sg"
    description: "Security group for Application Load Balancer"
    ingress_rules:
      - from_port: 80
        to_port: 80
        protocol: "tcp"
        cidr_blocks: ["0.0.0.0/0"]
        description: "HTTP from internet"
      
      - from_port: 443
        to_port: 443
        protocol: "tcp"
        cidr_blocks: ["0.0.0.0/0"]
        description: "HTTPS from internet"
    
    egress_rules:
      - from_port: 0
        to_port: 65535
        protocol: "tcp"
        security_groups: ["${aws_security_group.ecs_service.id}"]
        description: "To ECS service"

  ecs_service_security_group:
    name: "web-app-ecs-sg"
    description: "Security group for ECS service"
    ingress_rules:
      - from_port: 8080
        to_port: 8080
        protocol: "tcp"
        security_groups: ["${aws_security_group.alb.id}"]
        description: "From ALB"
      
      - from_port: 8125
        to_port: 8125
        protocol: "udp"
        security_groups: ["${aws_security_group.ecs_service.id}"]
        description: "StatsD from same service"
      
      - from_port: 8126
        to_port: 8126
        protocol: "tcp"
        security_groups: ["${aws_security_group.ecs_service.id}"]
        description: "APM from same service"
    
    egress_rules:
      - from_port: 443
        to_port: 443
        protocol: "tcp"
        cidr_blocks: ["0.0.0.0/0"]
        description: "HTTPS to internet"
      
      - from_port: 3306
        to_port: 3306
        protocol: "tcp"
        security_groups: ["${aws_security_group.rds.id}"]
        description: "To RDS MySQL"
      
      - from_port: 6379
        to_port: 6379
        protocol: "tcp"
        security_groups: ["${aws_security_group.redis.id}"]
        description: "To ElastiCache Redis"

# Network ACLs
network_acls:
  private_nacl:
    subnet_ids: ["subnet-12345678", "subnet-87654321"]
    ingress_rules:
      - rule_number: 100
        protocol: "tcp"
        from_port: 80
        to_port: 80
        cidr_block: "10.0.0.0/16"
        action: "allow"
      
      - rule_number: 110
        protocol: "tcp"
        from_port: 443
        to_port: 443
        cidr_block: "10.0.0.0/16"
        action: "allow"
      
      - rule_number: 120
        protocol: "tcp"
        from_port: 8080
        to_port: 8080
        cidr_block: "10.0.1.0/24"  # ALB subnet
        action: "allow"
    
    egress_rules:
      - rule_number: 100
        protocol: "tcp"
        from_port: 443
        to_port: 443
        cidr_block: "0.0.0.0/0"
        action: "allow"
```

### 3. Secrets Management

```yaml
# AWS Secrets Manager Integration
secrets_management:
  secrets:
    - name: "web-app/database"
      description: "Database credentials for web application"
      secret_string: |
        {
          "username": "app_user",
          "password": "<randomly_generated_password>",
          "host": "db.example.com",
          "port": 3306,
          "database": "webapp_prod"
        }
      kms_key_id: "alias/web-app-secrets"
      
    - name: "web-app/api-keys"
      description: "External API keys"
      secret_string: |
        {
          "stripe_api_key": "<stripe_secret_key>",
          "sendgrid_api_key": "<sendgrid_key>",
          "datadog_api_key": "<datadog_key>"
        }
      kms_key_id: "alias/web-app-secrets"

  # Secret rotation
  rotation_configuration:
    - secret_name: "web-app/database"
      rotation_lambda_arn: "arn:aws:lambda:us-east-1:123456789012:function:db-rotation-function"
      rotation_rules:
        automatically_after_days: 30

# Task Definition Secret Integration
task_definition_secrets:
  containerDefinitions:
    - name: "web-app-container"
      secrets:
        - name: "DB_USERNAME"
          valueFrom: "arn:aws:secretsmanager:us-east-1:123456789012:secret:web-app/database:username::"
        - name: "DB_PASSWORD"
          valueFrom: "arn:aws:secretsmanager:us-east-1:123456789012:secret:web-app/database:password::"
        - name: "STRIPE_API_KEY"
          valueFrom: "arn:aws:secretsmanager:us-east-1:123456789012:secret:web-app/api-keys:stripe_api_key::"

# Harness Secret Management Integration
harness_secrets:
  secret_managers:
    - name: "AWS Secrets Manager"
      identifier: "aws_secrets_manager"
      type: "AwsSecretsManager"
      spec:
        region: "us-east-1"
        connectorRef: "aws_connector"
        
  secrets:
    - name: "database_credentials"
      identifier: "db_creds"
      type: "SecretText"
      spec:
        secretManagerIdentifier: "aws_secrets_manager"
        valueType: "Reference"
        value: "web-app/database"
```

## Networking and Service Discovery

### 1. Service Mesh with AWS App Mesh

```yaml
# AWS App Mesh Configuration
app_mesh:
  mesh_name: "web-app-mesh"
  
  virtual_services:
    - name: "web-app"
      spec:
        provider:
          virtual_router:
            virtual_router_name: "web-app-router"
  
  virtual_routers:
    - name: "web-app-router"
      spec:
        listeners:
          - port_mapping:
              port: 8080
              protocol: "http"
        routes:
          - name: "web-app-route"
            spec:
              http_route:
                match:
                  prefix: "/"
                action:
                  weighted_targets:
                    - virtual_node: "web-app-v1"
                      weight: 80
                    - virtual_node: "web-app-v2"
                      weight: 20
  
  virtual_nodes:
    - name: "web-app-v1"
      spec:
        listeners:
          - port_mapping:
              port: 8080
              protocol: "http"
            health_check:
              protocol: "http"
              path: "/health"
              healthy_threshold: 2
              unhealthy_threshold: 3
              timeout_millis: 2000
              interval_millis: 5000
        service_discovery:
          aws_cloud_map:
            namespace_name: "web-app.local"
            service_name: "web-app-v1"
        logging:
          access_log:
            file:
              path: "/dev/stdout"
    
    - name: "web-app-v2"
      spec:
        listeners:
          - port_mapping:
              port: 8080
              protocol: "http"
        service_discovery:
          aws_cloud_map:
            namespace_name: "web-app.local"
            service_name: "web-app-v2"

# Envoy Proxy Sidecar
envoy_sidecar:
  container_definition:
    name: "envoy"
    image: "840364872350.dkr.ecr.us-east-1.amazonaws.com/aws-appmesh-envoy:v1.22.2.0-prod"
    essential: true
    environment:
      - name: "APPMESH_VIRTUAL_NODE_NAME"
        value: "mesh/web-app-mesh/virtualNode/web-app-v1"
      - name: "APPMESH_PREVIEW"
        value: "1"
      - name: "ENVOY_LOG_LEVEL"
        value: "info"
    health_check:
      command:
        - "CMD-SHELL"
        - "curl -s http://localhost:9901/server_info | grep state | grep -q LIVE"
      interval: 30
      timeout: 5
      retries: 3
      start_period: 10
    user: "1337"
    ulimits:
      - name: "nofile"
        soft_limit: 15000
        hard_limit: 15000
```

### 2. Service Discovery with AWS Cloud Map

```yaml
# Cloud Map Service Discovery
service_discovery:
  namespace:
    name: "web-app.local"
    type: "DNS_PRIVATE"
    vpc_id: "vpc-12345678"
    description: "Service discovery for web application"
    
  services:
    - name: "web-app"
      description: "Web application service"
      dns_config:
        namespace_id: "${aws_service_discovery_private_dns_namespace.web_app.id}"
        routing_policy: "MULTIVALUE"
        dns_records:
          - ttl: 60
            type: "A"
          - ttl: 60
            type: "SRV"
      
      health_check_custom_config:
        failure_threshold: 1
      
      tags:
        Environment: "production"
        Application: "web-app"

# ECS Service Integration with Service Discovery
ecs_service_discovery:
  service_registries:
    - registry_arn: "${aws_service_discovery_service.web_app.arn}"
      container_name: "web-app-container"
      container_port: 8080
      port: 8080

# DNS Resolution Configuration
dns_configuration:
  # Custom DNS for ECS tasks
  task_definition:
    family: "web-app-task"
    network_mode: "awsvpc"
    dns_servers: ["169.254.169.253"]  # Amazon DNS
    dns_search_domains: ["web-app.local"]
    
  # Route 53 Private Hosted Zone
  private_hosted_zone:
    name: "internal.example.com"
    vpc:
      vpc_id: "vpc-12345678"
    
    records:
      - name: "api.internal.example.com"
        type: "CNAME"
        ttl: 300
        records: ["web-app.web-app.local"]
      
      - name: "health.internal.example.com"
        type: "CNAME"
        ttl: 300
        records: ["web-app.web-app.local"]
```

## Best Practices

### 1. Container Security Best Practices

```yaml
container_security:
  image_security:
    base_images:
      - "Use minimal base images (alpine, distroless)"
      - "Regularly update base images for security patches"
      - "Scan images for vulnerabilities before deployment"
    
    dockerfile_practices:
      - "Use specific image tags, not 'latest'"
      - "Run containers as non-root user"
      - "Use multi-stage builds to reduce attack surface"
      - "Copy only necessary files"
      - "Set appropriate file permissions"
    
    runtime_security:
      - "Enable read-only root filesystem when possible"
      - "Use security profiles (AppArmor/SELinux)"
      - "Limit container capabilities"
      - "Configure resource limits"

  secrets_management:
    - "Never embed secrets in container images"
    - "Use AWS Secrets Manager or Parameter Store"
    - "Rotate secrets regularly"
    - "Use IAM roles for service authentication"
    - "Enable encryption in transit and at rest"

  network_security:
    - "Use private subnets for ECS tasks"
    - "Configure security groups with minimal access"
    - "Enable VPC Flow Logs"
    - "Use AWS PrivateLink for AWS service access"
    - "Implement network segmentation"

# Security Scanning Pipeline
security_scanning:
  stages:
    - stage:
        name: Security Scan
        identifier: security_scan
        type: Security
        spec:
          execution:
            steps:
              - step:
                  type: AquaTrivy
                  name: Container Image Scan
                  identifier: container_scan
                  spec:
                    mode: orchestratedScan
                    config: default
                    target:
                      type: container
                      detection: auto
                    advanced:
                      log:
                        level: info
                    resources:
                      limits:
                        memory: 2Gi
                        cpu: 1000m
                  
              - step:
                  type: Grype
                  name: Vulnerability Assessment
                  identifier: vuln_assessment
                  spec:
                    mode: orchestratedScan
                    config: default
                    target:
                      type: container
                      detection: auto
                    advanced:
                      args:
                        cli: "-o json"
                  
              - step:
                  type: OWASP
                  name: OWASP Dependency Check
                  identifier: owasp_scan
                  spec:
                    mode: orchestratedScan
                    config: default
                    target:
                      type: repository
                      detection: auto
                    advanced:
                      log:
                        level: info
```

### 2. Performance Optimization

```yaml
performance_optimization:
  container_optimization:
    resource_allocation:
      cpu_optimization:
        - "Use appropriate CPU allocation based on workload"
        - "Enable CPU burst for burstable workloads"
        - "Monitor CPU utilization and adjust"
      
      memory_optimization:
        - "Set memory limits to prevent OOM kills"
        - "Use memory-optimized instances for memory-intensive workloads"
        - "Configure JVM heap size appropriately"
      
      network_optimization:
        - "Use placement groups for high-throughput applications"
        - "Enable enhanced networking"
        - "Optimize container networking mode"

  application_optimization:
    jvm_tuning:
      heap_settings:
        initial_heap: "512m"
        max_heap: "1024m"
        new_ratio: 3
        gc_algorithm: "G1GC"
      
      gc_settings:
        g1_heap_region_size: "16m"
        g1_max_gc_pause_millis: 200
        concurrent_gc_threads: 4
        parallel_gc_threads: 8
    
    connection_pooling:
      database_pool:
        initial_size: 5
        max_size: 20
        min_idle: 5
        max_idle: 10
        validation_query: "SELECT 1"
        test_on_borrow: true
      
      http_client_pool:
        max_connections: 200
        max_connections_per_route: 50
        connection_timeout: 5000
        socket_timeout: 30000

# Performance Monitoring
performance_monitoring:
  metrics_collection:
    system_metrics:
      - "cpu.usage_percent"
      - "memory.usage_percent"
      - "disk.io_read_bytes"
      - "disk.io_write_bytes"
      - "network.bytes_sent"
      - "network.bytes_recv"
    
    application_metrics:
      - "http_requests_total"
      - "http_request_duration_seconds"
      - "jvm_memory_used_bytes"
      - "jvm_gc_pause_seconds"
      - "database_connections_active"
    
    business_metrics:
      - "user_registrations_total"
      - "orders_processed_total"
      - "revenue_generated_total"

  alerting_rules:
    - alert_name: "HighCPUUsage"
      expression: "cpu_usage_percent > 80"
      duration: "5m"
      labels:
        severity: "warning"
      annotations:
        summary: "High CPU usage detected"
    
    - alert_name: "HighMemoryUsage"
      expression: "memory_usage_percent > 85"
      duration: "3m"
      labels:
        severity: "critical"
      annotations:
        summary: "High memory usage detected"
```

## Troubleshooting Guide

### 1. Common ECS Deployment Issues

```yaml
troubleshooting_guide:
  deployment_failures:
    task_placement_failures:
      symptoms:
        - "Tasks fail to start"
        - "Service shows PENDING tasks"
        - "Events show placement failures"
      
      causes:
        - "Insufficient CPU/memory resources"
        - "No available container instances"
        - "Security group restrictions"
        - "Subnet configuration issues"
      
      solutions:
        - "Check cluster capacity and scale if needed"
        - "Verify task resource requirements"
        - "Review security group rules"
        - "Ensure subnets have available IP addresses"
      
      diagnostic_commands:
        - "aws ecs describe-services --cluster production-cluster --services web-app-service"
        - "aws ecs describe-tasks --cluster production-cluster --tasks TASK_ARN"
        - "aws ec2 describe-instances --filters 'Name=tag:aws:ecs:cluster-name,Values=production-cluster'"

    container_health_check_failures:
      symptoms:
        - "Tasks fail health checks"
        - "Service shows unhealthy tasks"
        - "Load balancer returns 503 errors"
      
      causes:
        - "Application startup time too slow"
        - "Health check endpoint not responding"
        - "Port configuration mismatch"
        - "Application dependencies not ready"
      
      solutions:
        - "Increase health check grace period"
        - "Verify health check endpoint"
        - "Check port mappings in task definition"
        - "Add dependency checks in application"
      
      diagnostic_commands:
        - "aws elbv2 describe-target-health --target-group-arn TARGET_GROUP_ARN"
        - "docker exec -it CONTAINER_ID curl localhost:8080/health"
        - "aws logs get-log-events --log-group-name /ecs/web-app"

    image_pull_failures:
      symptoms:
        - "Tasks stuck in PENDING state"
        - "Error: 'CannotPullContainerError'"
        - "Authentication failures in logs"
      
      causes:
        - "ECR authentication issues"
        - "Image doesn't exist or wrong tag"
        - "Network connectivity problems"
        - "IAM permissions insufficient"
      
      solutions:
        - "Verify ECR repository and image tag"
        - "Check task execution role permissions"
        - "Test ECR connectivity from container instances"
        - "Verify VPC endpoints for ECR"
      
      diagnostic_commands:
        - "aws ecr describe-repositories --repository-names web-app"
        - "aws ecr describe-images --repository-name web-app"
        - "aws sts get-caller-identity"
        - "docker pull 123456789012.dkr.ecr.us-east-1.amazonaws.com/web-app:latest"

  performance_issues:
    high_cpu_usage:
      symptoms:
        - "CPU utilization consistently above 80%"
        - "Application response times increase"
        - "Auto scaling triggers frequently"
      
      investigation:
        - "Check CloudWatch CPU metrics"
        - "Review application logs for errors"
        - "Analyze thread dumps and GC logs"
        - "Monitor database query performance"
      
      solutions:
        - "Increase CPU allocation in task definition"
        - "Optimize application code and queries"
        - "Enable auto scaling if not configured"
        - "Consider using larger instance types"
      
      diagnostic_commands:
        - "aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization"
        - "docker exec -it CONTAINER_ID top"
        - "docker exec -it CONTAINER_ID jstack PID"

    memory_leaks:
      symptoms:
        - "Memory usage continuously increases"
        - "Tasks killed with OOMKilled status"
        - "Application becomes unresponsive"
      
      investigation:
        - "Monitor memory metrics over time"
        - "Generate heap dumps for analysis"
        - "Review GC logs and patterns"
        - "Check for memory-intensive operations"
      
      solutions:
        - "Increase memory allocation"
        - "Optimize application memory usage"
        - "Implement memory monitoring alerts"
        - "Use memory profiling tools"
      
      diagnostic_commands:
        - "docker exec -it CONTAINER_ID jmap -histo PID"
        - "docker exec -it CONTAINER_ID jstat -gc PID"
        - "aws logs filter-log-events --log-group-name /ecs/web-app --filter-pattern 'OutOfMemory'"

  networking_issues:
    connectivity_problems:
      symptoms:
        - "Cannot reach application endpoints"
        - "Load balancer health checks fail"
        - "Inter-service communication fails"
      
      investigation:
        - "Check security group rules"
        - "Verify VPC routing tables"
        - "Test network connectivity"
        - "Review DNS resolution"
      
      solutions:
        - "Update security group rules"
        - "Fix VPC routing configuration"
        - "Verify load balancer target group health"
        - "Check service discovery configuration"
      
      diagnostic_commands:
        - "aws ec2 describe-security-groups --filters 'Name=group-name,Values=web-app-ecs-sg'"
        - "nslookup web-app.web-app.local"
        - "telnet ALB_DNS_NAME 80"
        - "curl -v http://TASK_IP:8080/health"

# Automated Troubleshooting Scripts
troubleshooting_scripts:
  health_check_script: |
    #!/bin/bash
    
    CLUSTER_NAME="production-cluster"
    SERVICE_NAME="web-app-service"
    
    echo "=== ECS Service Health Check ==="
    
    # Get service status
    echo "Checking service status..."
    aws ecs describe-services \
      --cluster $CLUSTER_NAME \
      --services $SERVICE_NAME \
      --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
      --output table
    
    # Get task status
    echo "Checking task status..."
    TASK_ARNS=$(aws ecs list-tasks \
      --cluster $CLUSTER_NAME \
      --service-name $SERVICE_NAME \
      --query 'taskArns[]' \
      --output text)
    
    if [ -n "$TASK_ARNS" ]; then
      aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $TASK_ARNS \
        --query 'tasks[].{TaskArn:taskArn,LastStatus:lastStatus,HealthStatus:healthStatus,CPU:cpu,Memory:memory}' \
        --output table
    fi
    
    # Check load balancer target health
    echo "Checking load balancer target health..."
    TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-app-tg/1234567890123456"
    aws elbv2 describe-target-health \
      --target-group-arn $TARGET_GROUP_ARN \
      --query 'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State,Reason:TargetHealth.Reason}' \
      --output table

  log_analysis_script: |
    #!/bin/bash
    
    LOG_GROUP="/ecs/web-app"
    START_TIME=$(date -d '1 hour ago' +%s)000
    END_TIME=$(date +%s)000
    
    echo "=== Log Analysis for Web App ==="
    
    # Check for errors
    echo "Searching for errors..."
    aws logs filter-log-events \
      --log-group-name $LOG_GROUP \
      --start-time $START_TIME \
      --end-time $END_TIME \
      --filter-pattern "ERROR" \
      --query 'events[].message' \
      --output text | head -10
    
    # Check for exceptions
    echo "Searching for exceptions..."
    aws logs filter-log-events \
      --log-group-name $LOG_GROUP \
      --start-time $START_TIME \
      --end-time $END_TIME \
      --filter-pattern "Exception" \
      --query 'events[].message' \
      --output text | head -10
    
    # Check for health check failures
    echo "Searching for health check failures..."
    aws logs filter-log-events \
      --log-group-name $LOG_GROUP \
      --start-time $START_TIME \
      --end-time $END_TIME \
      --filter-pattern "health" \
      --query 'events[].message' \
      --output text | head -10
```

## Conclusion

This comprehensive technical deep-dive covers all aspects of AWS ECS deployments with Harness, from basic service configuration to advanced security and monitoring practices. The combination of Harness's deployment automation with ECS's container orchestration provides a robust platform for modern application delivery.

Key implementation points:
- Use infrastructure as code for consistent environments
- Implement proper security controls and IAM policies
- Configure comprehensive monitoring and alerting
- Follow container security best practices
- Plan for scalability and performance optimization
- Implement proper networking and service discovery

For additional resources and support, refer to the [AWS ECS documentation](https://docs.aws.amazon.com/ecs/) and [Harness ECS integration guide](https://docs.harness.io/article/ot8lqf7l3f-ecs-deployment).