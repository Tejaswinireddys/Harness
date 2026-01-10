# Harness VM Deployments - Technical Deep Dive

## Table of Contents
1. [Overview](#overview)
2. [VM Deployment Architecture](#vm-deployment-architecture)
3. [Harness Components for VM Deployments](#harness-components-for-vm-deployments)
4. [Deployment Strategies](#deployment-strategies)
5. [Infrastructure Provisioning](#infrastructure-provisioning)
6. [Configuration Management](#configuration-management)
7. [Monitoring and Observability](#monitoring-and-observability)
8. [Security Implementation](#security-implementation)
9. [Best Practices](#best-practices)
10. [Troubleshooting Guide](#troubleshooting-guide)

## Overview

This document provides a comprehensive technical deep-dive into VM deployments using Harness, covering architecture patterns, implementation strategies, and operational considerations for deploying applications to virtual machines across various cloud providers and on-premises environments.

### Key Benefits of Harness for VM Deployments
- **Multi-cloud Support**: Deploy to AWS EC2, Azure VMs, GCP Compute Engine, and on-premises
- **Automated Scaling**: Auto-scaling based on metrics and demand
- **Zero-downtime Deployments**: Blue-green and canary deployment strategies
- **Infrastructure as Code**: Terraform and CloudFormation integration
- **Compliance**: Built-in governance and audit trails

## VM Deployment Architecture

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
│                      Harness Delegates                       │
├─────────────────────┬───────────────────┬───────────────────┤
│    AWS Delegate     │  Azure Delegate   │   GCP Delegate    │
└─────────────────────┴───────────────────┴───────────────────┘
                              │
                              │
┌─────────────────────────────▼─────────────────────────────────┐
│                    Target VM Infrastructure                   │
├─────────────────────┬───────────────────┬───────────────────┤
│     AWS EC2         │    Azure VMs      │  GCP Compute      │
│  - Auto Scaling     │  - Scale Sets     │  - Instance       │
│  - Load Balancer    │  - Load Balancer  │    Groups         │
│  - Security Groups  │  - NSGs           │  - Load Balancer  │
└─────────────────────┴───────────────────┴───────────────────┘
```

### Component Breakdown

#### 1. Harness Control Plane
- **Pipeline Orchestration**: Manages deployment workflows
- **Policy Enforcement**: Governance and compliance controls
- **Artifact Management**: Stores and versions deployment artifacts
- **Secret Management**: Secure credential storage and rotation

#### 2. Harness Delegates
- **Execution Agents**: Run deployment tasks in target environments
- **Security Boundary**: No inbound connections to control plane
- **Multi-environment**: Can manage multiple cloud accounts/regions
- **Auto-upgrade**: Self-updating with zero downtime

#### 3. Target Infrastructure
- **Virtual Machines**: EC2, Azure VMs, GCP Compute instances
- **Load Balancers**: Application and network load balancers
- **Auto Scaling**: Horizontal pod autoscaling based on metrics
- **Networking**: VPCs, subnets, security groups, firewalls

## Harness Components for VM Deployments

### 1. Services

```yaml
# Example VM Service Definition
apiVersion: v1
kind: Service
metadata:
  name: web-app-vm
  identifier: web_app_vm
spec:
  serviceDefinition:
    type: SSH
    spec:
      artifacts:
        primary:
          spec:
            connectorRef: artifactory_connector
            artifactPath: /apps/web-app/
            tag: <+input>
          type: Artifactory
      variables:
        - name: app_port
          type: String
          value: "8080"
        - name: max_memory
          type: String
          value: "2048m"
```

### 2. Environments

```yaml
# Example Environment Configuration
apiVersion: v1
kind: Environment
metadata:
  name: production-vm-env
  identifier: prod_vm_env
spec:
  type: Production
  tags:
    environment: production
    deployment_type: vm
  variables:
    - name: instance_type
      type: String
      value: "m5.large"
    - name: min_instances
      type: Number
      value: 2
    - name: max_instances
      type: Number
      value: 10
  infrastructureDefinitions:
    - name: aws-prod-infrastructure
      identifier: aws_prod_infra
      spec:
        cloudProviderType: Aws
        deploymentType: Ssh
        spec:
          cloudProviderRef: aws_connector
          region: us-east-1
          tags:
            Environment: production
            Team: platform
```

### 3. Infrastructure Definitions

```yaml
# AWS EC2 Infrastructure
apiVersion: v1
kind: Infrastructure
metadata:
  name: aws-ec2-infrastructure
spec:
  environmentRef: prod_vm_env
  deploymentType: Ssh
  type: DirectConnection
  spec:
    connectorRef: aws_connector
    region: us-east-1
    hostConnectionType: PublicIP
    hostFilter:
      type: AwsInstanceFilter
      spec:
        regions:
          - us-east-1
        tags:
          Environment: production
          Application: web-app
```

### 4. Pipelines

```yaml
# VM Deployment Pipeline
apiVersion: v1
kind: Pipeline
metadata:
  name: vm-deployment-pipeline
  identifier: vm_deployment_pipeline
spec:
  stages:
    - stage:
        name: Deploy to VMs
        identifier: deploy_vms
        type: Deployment
        spec:
          deploymentType: Ssh
          service:
            serviceRef: web_app_vm
          environment:
            environmentRef: prod_vm_env
            infrastructureDefinitions:
              - identifier: aws_prod_infra
          execution:
            steps:
              - step:
                  type: Command
                  name: Stop Application
                  identifier: stop_app
                  spec:
                    onDelegate: false
                    environmentVariables: []
                    outputVariables: []
                    commandUnits:
                      - identifier: stop_service
                        name: Stop Service
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                sudo systemctl stop web-app
                                sleep 10
              
              - step:
                  type: Command
                  name: Deploy Artifact
                  identifier: deploy_artifact
                  spec:
                    onDelegate: false
                    environmentVariables: []
                    outputVariables: []
                    commandUnits:
                      - identifier: download_artifact
                        name: Download Artifact
                        type: Copy
                        spec:
                          sourceType: Artifact
                          destinationPath: /opt/app/
              
              - step:
                  type: Command
                  name: Configure Application
                  identifier: configure_app
                  spec:
                    onDelegate: false
                    environmentVariables:
                      - name: APP_PORT
                        value: <+serviceVariables.app_port>
                      - name: MAX_MEMORY
                        value: <+serviceVariables.max_memory>
                    commandUnits:
                      - identifier: update_config
                        name: Update Configuration
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                # Update application configuration
                                cat > /opt/app/config.properties << EOF
                                server.port=${APP_PORT}
                                spring.jvm.memory=${MAX_MEMORY}
                                environment=<+env.name>
                                EOF
                                
                                # Set permissions
                                sudo chown app:app /opt/app/config.properties
                                sudo chmod 640 /opt/app/config.properties
              
              - step:
                  type: Command
                  name: Start Application
                  identifier: start_app
                  spec:
                    onDelegate: false
                    commandUnits:
                      - identifier: start_service
                        name: Start Service
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                sudo systemctl start web-app
                                sleep 30
                                
                                # Health check
                                curl -f http://localhost:${APP_PORT}/health || exit 1
```

## Deployment Strategies

### 1. Rolling Deployment

```yaml
# Rolling Deployment Strategy
rolloutDeployment:
  phases:
    - phase:
        name: Phase 1
        deploymentType: SSH
        computeProviderType: AWS
        infraDefinitionId: aws_prod_infra
        serviceId: web_app_vm
        instanceCount: "25%"
        instanceUnitType: PERCENTAGE
    - phase:
        name: Phase 2
        deploymentType: SSH
        computeProviderType: AWS
        infraDefinitionId: aws_prod_infra
        serviceId: web_app_vm
        instanceCount: "50%"
        instanceUnitType: PERCENTAGE
    - phase:
        name: Phase 3
        deploymentType: SSH
        computeProviderType: AWS
        infraDefinitionId: aws_prod_infra
        serviceId: web_app_vm
        instanceCount: "100%"
        instanceUnitType: PERCENTAGE
```

### 2. Blue-Green Deployment

```yaml
# Blue-Green Deployment with Load Balancer Switch
blueGreenDeployment:
  productionSlots: 1
  stagingSlots: 1
  steps:
    - stepType: AWS_AMI_SWITCH_ROUTES
      name: Switch Load Balancer
      properties:
        useAppAutoScaling: true
        autoScalingGroupName: <+infra.autoScaling.autoScalingGroupName>
        classicLoadBalancers:
          - web-app-clb
        targetGroupArns:
          - arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-app-tg/1234567890123456
```

### 3. Canary Deployment

```yaml
# Canary Deployment Strategy
canaryDeployment:
  phases:
    - phase:
        name: Canary Phase
        deploymentType: SSH
        computeProviderType: AWS
        infraDefinitionId: aws_prod_infra
        serviceId: web_app_vm
        instanceCount: "10%"
        instanceUnitType: PERCENTAGE
        steps:
          - type: VERIFICATION
            name: Performance Verification
            properties:
              analysisType: Prometheus
              comparisonStrategy: COMPARE_WITH_CURRENT
              timeDuration: "10"
    - phase:
        name: Primary Phase
        deploymentType: SSH
        computeProviderType: AWS
        infraDefinitionId: aws_prod_infra
        serviceId: web_app_vm
        instanceCount: "100%"
        instanceUnitType: PERCENTAGE
```

## Infrastructure Provisioning

### 1. Terraform Integration

```hcl
# terraform/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web_app" {
  name                = "${var.app_name}-asg"
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.web_app.arn]
  health_check_type   = "ELB"
  
  min_size         = var.min_instances
  max_size         = var.max_instances
  desired_capacity = var.desired_instances
  
  launch_template {
    id      = aws_launch_template.web_app.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "${var.app_name}-instance"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Launch Template
resource "aws_launch_template" "web_app" {
  name_prefix   = "${var.app_name}-template"
  image_id      = var.ami_id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.web_app.id]
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_name = var.app_name
  }))
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.app_name}-instance"
      Environment = var.environment
      ManagedBy   = "Harness"
    }
  }
}

# Load Balancer
resource "aws_lb" "web_app" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  
  enable_deletion_protection = false
  
  tags = {
    Name        = "${var.app_name}-alb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "web_app" {
  name     = "${var.app_name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  
  tags = {
    Name        = "${var.app_name}-tg"
    Environment = var.environment
  }
}

# Security Group for Application
resource "aws_security_group" "web_app" {
  name        = "${var.app_name}-sg"
  description = "Security group for web application instances"
  vpc_id      = var.vpc_id
  
  ingress {
    description = "HTTP from ALB"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "${var.app_name}-sg"
    Environment = var.environment
  }
}
```

### 2. Harness Terraform Pipeline

```yaml
# Terraform Provisioning Pipeline
apiVersion: v1
kind: Pipeline
metadata:
  name: infrastructure-provisioning
spec:
  stages:
    - stage:
        name: Terraform Plan
        identifier: terraform_plan
        type: Custom
        spec:
          execution:
            steps:
              - step:
                  type: TerraformPlan
                  name: Plan Infrastructure
                  identifier: plan_infra
                  spec:
                    configuration:
                      command: Apply
                      workspace: production
                      configFiles:
                        store:
                          type: Git
                          spec:
                            gitFetchType: Branch
                            repoName: infrastructure-repo
                            branch: main
                            folderPath: terraform/
                      secretManagerRef: vault_connector
                      varFiles:
                        - varFile:
                            type: Inline
                            spec:
                              content: |
                                app_name = "web-app"
                                environment = "production"
                                aws_region = "us-east-1"
                                instance_type = "m5.large"
                                min_instances = 2
                                max_instances = 10
                                desired_instances = 3
    
    - stage:
        name: Terraform Apply
        identifier: terraform_apply
        type: Custom
        spec:
          execution:
            steps:
              - step:
                  type: TerraformApply
                  name: Apply Infrastructure
                  identifier: apply_infra
                  spec:
                    configuration:
                      type: InheritFromPlan
                    provisionerIdentifier: plan_infra
```

## Configuration Management

### 1. Ansible Integration

```yaml
# ansible/playbook.yml
---
- name: Configure Web Application
  hosts: all
  become: yes
  vars:
    app_name: "{{ harness_app_name }}"
    app_port: "{{ harness_app_port }}"
    environment: "{{ harness_environment }}"
  
  tasks:
    - name: Install required packages
      package:
        name:
          - openjdk-11-jre
          - nginx
          - htop
          - curl
        state: present
    
    - name: Create application user
      user:
        name: "{{ app_name }}"
        system: yes
        shell: /bin/false
        home: "/opt/{{ app_name }}"
        create_home: yes
    
    - name: Create application directories
      file:
        path: "{{ item }}"
        state: directory
        owner: "{{ app_name }}"
        group: "{{ app_name }}"
        mode: '0755'
      loop:
        - "/opt/{{ app_name }}/bin"
        - "/opt/{{ app_name }}/config"
        - "/opt/{{ app_name }}/logs"
        - "/var/log/{{ app_name }}"
    
    - name: Configure application service
      template:
        src: app.service.j2
        dest: "/etc/systemd/system/{{ app_name }}.service"
        backup: yes
      notify: reload systemd
    
    - name: Configure nginx proxy
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/sites-available/{{ app_name }}
      notify: restart nginx
    
    - name: Enable nginx site
      file:
        src: "/etc/nginx/sites-available/{{ app_name }}"
        dest: "/etc/nginx/sites-enabled/{{ app_name }}"
        state: link
      notify: restart nginx
    
    - name: Configure log rotation
      template:
        src: logrotate.j2
        dest: "/etc/logrotate.d/{{ app_name }}"
  
  handlers:
    - name: reload systemd
      systemd:
        daemon_reload: yes
    
    - name: restart nginx
      service:
        name: nginx
        state: restarted
```

### 2. Harness Configuration Pipeline

```yaml
# Configuration Management Pipeline
apiVersion: v1
kind: Pipeline
metadata:
  name: vm-configuration-pipeline
spec:
  stages:
    - stage:
        name: Configure VMs
        identifier: configure_vms
        type: Deployment
        spec:
          deploymentType: Ssh
          service:
            serviceRef: web_app_vm
          environment:
            environmentRef: prod_vm_env
          execution:
            steps:
              - step:
                  type: Command
                  name: Run Ansible Configuration
                  identifier: run_ansible
                  spec:
                    onDelegate: true
                    environmentVariables:
                      - name: HARNESS_APP_NAME
                        value: <+service.name>
                      - name: HARNESS_APP_PORT
                        value: <+serviceVariables.app_port>
                      - name: HARNESS_ENVIRONMENT
                        value: <+env.name>
                    commandUnits:
                      - identifier: ansible_setup
                        name: Setup Ansible
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                # Install Ansible if not present
                                which ansible-playbook || {
                                  pip3 install ansible
                                }
                                
                                # Download playbook from Git
                                git clone <+pipeline.variables.ansible_repo> /tmp/ansible
                                cd /tmp/ansible
                      
                      - identifier: run_playbook
                        name: Run Playbook
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                cd /tmp/ansible
                                
                                # Create inventory from Harness instances
                                cat > inventory.ini << EOF
                                [web_servers]
                                <+instance.hostName>
                                EOF
                                
                                # Run Ansible playbook
                                ansible-playbook \
                                  -i inventory.ini \
                                  -e "harness_app_name=${HARNESS_APP_NAME}" \
                                  -e "harness_app_port=${HARNESS_APP_PORT}" \
                                  -e "harness_environment=${HARNESS_ENVIRONMENT}" \
                                  playbook.yml
```

## Monitoring and Observability

### 1. Application Monitoring

```yaml
# Monitoring Configuration
monitoring:
  prometheus:
    enabled: true
    endpoint: "/metrics"
    port: 9090
    scrape_configs:
      - job_name: "web-app"
        static_configs:
          - targets: ["<+instance.hostName>:<+serviceVariables.app_port>"]
        metrics_path: "/actuator/prometheus"
        scrape_interval: 30s
  
  grafana:
    dashboards:
      - name: "VM Application Dashboard"
        panels:
          - title: "Request Rate"
            type: "graph"
            metrics:
              - "rate(http_requests_total[5m])"
          - title: "Response Time"
            type: "graph"
            metrics:
              - "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
          - title: "Error Rate"
            type: "graph"
            metrics:
              - "rate(http_requests_total{status=~'5..'}[5m])"
          - title: "CPU Usage"
            type: "graph"
            metrics:
              - "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode='idle'}[5m])) * 100)"
          - title: "Memory Usage"
            type: "graph"
            metrics:
              - "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"
```

### 2. Health Checks and Verification

```yaml
# Health Check Step
healthCheck:
  type: Command
  name: Application Health Check
  identifier: health_check
  spec:
    onDelegate: false
    commandUnits:
      - identifier: service_health
        name: Check Service Health
        type: Script
        spec:
          shell: Bash
          source:
            type: Inline
            spec:
              script: |
                #!/bin/bash
                
                APP_PORT=<+serviceVariables.app_port>
                HEALTH_ENDPOINT="http://localhost:${APP_PORT}/health"
                MAX_RETRIES=30
                RETRY_INTERVAL=10
                
                echo "Checking application health at ${HEALTH_ENDPOINT}"
                
                for i in $(seq 1 $MAX_RETRIES); do
                  echo "Health check attempt $i/$MAX_RETRIES"
                  
                  if curl -f -s "${HEALTH_ENDPOINT}" > /dev/null; then
                    echo "Health check passed"
                    
                    # Additional checks
                    RESPONSE=$(curl -s "${HEALTH_ENDPOINT}")
                    echo "Health response: ${RESPONSE}"
                    
                    # Check if response contains expected status
                    if echo "${RESPONSE}" | grep -q '"status":"UP"'; then
                      echo "Application is healthy"
                      exit 0
                    else
                      echo "Application status is not UP"
                      exit 1
                    fi
                  else
                    echo "Health check failed, retrying in ${RETRY_INTERVAL} seconds..."
                    sleep $RETRY_INTERVAL
                  fi
                done
                
                echo "Health check failed after $MAX_RETRIES attempts"
                exit 1
```

## Security Implementation

### 1. Secret Management

```yaml
# Secret Configuration
secrets:
  - name: database_password
    identifier: db_password
    type: SecretText
    spec:
      secretManagerIdentifier: vault_connector
      valueType: Inline
      value: <vault_path>
  
  - name: api_key
    identifier: api_key
    type: SecretText
    spec:
      secretManagerIdentifier: aws_secrets_manager
      valueType: Reference
      value: "arn:aws:secretsmanager:us-east-1:123456789012:secret:api-key"

# Usage in Pipeline
environmentVariables:
  - name: DB_PASSWORD
    value: <+secrets.getValue("db_password")>
  - name: API_KEY
    value: <+secrets.getValue("api_key")>
```

### 2. RBAC and Governance

```yaml
# Role-Based Access Control
rbac:
  userGroups:
    - name: "DevOps Team"
      permissions:
        - pipeline:execute
        - pipeline:view
        - environment:view
        - service:view
    
    - name: "Developers"
      permissions:
        - pipeline:view
        - environment:view:non-production
        - service:view
    
    - name: "Platform Admin"
      permissions:
        - pipeline:*
        - environment:*
        - service:*
        - connector:*

# Policy as Code
policies:
  - name: "Production Deployment Policy"
    type: "Pipeline"
    rules:
      - name: "Require Approval for Production"
        condition: "environment.type == 'Production'"
        action: "require_approval"
        approvers:
          - "Platform Admin"
      
      - name: "Security Scan Required"
        condition: "stage.type == 'Deployment'"
        action: "require_step"
        requiredStep: "security_scan"
```

### 3. Network Security

```bash
#!/bin/bash
# Network Security Configuration Script

# Configure firewall rules
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (restrict to specific IPs in production)
ufw allow from 10.0.0.0/8 to any port 22

# Allow application port from load balancer only
ufw allow from 10.0.1.0/24 to any port 8080

# Allow monitoring
ufw allow from 10.0.2.0/24 to any port 9090

# Enable firewall
ufw --force enable

# Configure fail2ban for SSH protection
apt-get update
apt-get install -y fail2ban

cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

systemctl enable fail2ban
systemctl start fail2ban
```

## Best Practices

### 1. Deployment Best Practices

```yaml
# Best Practices Pipeline Template
bestPractices:
  preDeployment:
    - name: "Artifact Verification"
      steps:
        - verify_artifact_signature
        - security_scan
        - vulnerability_assessment
    
    - name: "Environment Validation"
      steps:
        - check_resource_availability
        - validate_network_connectivity
        - verify_dependencies
  
  deployment:
    - name: "Progressive Rollout"
      strategy: "canary"
      phases:
        - percentage: 10
          duration: "10m"
          success_criteria:
            - error_rate_below: "1%"
            - response_time_below: "500ms"
        - percentage: 50
          duration: "20m"
          success_criteria:
            - error_rate_below: "0.5%"
            - response_time_below: "300ms"
        - percentage: 100
  
  postDeployment:
    - name: "Health Verification"
      steps:
        - application_health_check
        - load_balancer_health_check
        - end_to_end_testing
    
    - name: "Monitoring Setup"
      steps:
        - enable_application_monitoring
        - configure_alerts
        - update_dashboards
```

### 2. Performance Optimization

```yaml
# Performance Optimization Configuration
performance:
  jvm_tuning:
    heap_size: "2048m"
    gc_algorithm: "G1GC"
    jvm_options:
      - "-XX:+UseG1GC"
      - "-XX:MaxGCPauseMillis=200"
      - "-XX:+UnlockExperimentalVMOptions"
      - "-XX:+UseCGroupMemoryLimitForHeap"
  
  application_tuning:
    connection_pool_size: 20
    thread_pool_size: 50
    cache_size: "512m"
    timeout_settings:
      read_timeout: "30s"
      write_timeout: "30s"
      connection_timeout: "10s"
  
  monitoring:
    metrics:
      - "jvm.memory.used"
      - "jvm.gc.pause"
      - "http.server.requests"
      - "system.cpu.usage"
      - "system.memory.usage"
```

### 3. Disaster Recovery

```yaml
# Disaster Recovery Configuration
disaster_recovery:
  backup_strategy:
    - name: "Application Backup"
      frequency: "daily"
      retention: "30 days"
      backup_script: |
        #!/bin/bash
        BACKUP_DIR="/backup/$(date +%Y%m%d)"
        mkdir -p $BACKUP_DIR
        
        # Backup application files
        tar -czf $BACKUP_DIR/app_files.tar.gz /opt/web-app/
        
        # Backup configuration
        tar -czf $BACKUP_DIR/config.tar.gz /etc/web-app/
        
        # Upload to S3
        aws s3 cp $BACKUP_DIR/ s3://backup-bucket/web-app/ --recursive
  
  recovery_procedures:
    - name: "Application Recovery"
      steps:
        - "Stop current application"
        - "Download backup from S3"
        - "Restore application files"
        - "Restore configuration"
        - "Start application"
        - "Verify health"
      
      recovery_script: |
        #!/bin/bash
        BACKUP_DATE=${1:-$(date +%Y%m%d)}
        RECOVERY_DIR="/tmp/recovery"
        
        # Download backup
        aws s3 cp s3://backup-bucket/web-app/$BACKUP_DATE/ $RECOVERY_DIR/ --recursive
        
        # Stop application
        systemctl stop web-app
        
        # Restore files
        tar -xzf $RECOVERY_DIR/app_files.tar.gz -C /
        tar -xzf $RECOVERY_DIR/config.tar.gz -C /
        
        # Start application
        systemctl start web-app
        
        # Health check
        sleep 30
        curl -f http://localhost:8080/health || exit 1
```

## Troubleshooting Guide

### 1. Common Issues and Solutions

```yaml
troubleshooting:
  deployment_failures:
    - issue: "Connection timeout during deployment"
      causes:
        - "Network connectivity issues"
        - "SSH key authentication failure"
        - "Security group restrictions"
      solutions:
        - "Check security group rules allow SSH (port 22)"
        - "Verify SSH key is correctly configured"
        - "Test network connectivity from delegate to target"
        - "Check VPC routing and NAT gateway configuration"
    
    - issue: "Application fails to start after deployment"
      causes:
        - "Port conflicts"
        - "Missing dependencies"
        - "Configuration errors"
        - "Insufficient resources"
      solutions:
        - "Check port availability: netstat -tlnp | grep :8080"
        - "Verify Java installation: java -version"
        - "Check application logs: journalctl -u web-app"
        - "Monitor resource usage: top, free -h, df -h"
    
    - issue: "Load balancer health checks failing"
      causes:
        - "Application not responding on health endpoint"
        - "Security group blocking health check traffic"
        - "Health check path incorrect"
      solutions:
        - "Test health endpoint locally: curl localhost:8080/health"
        - "Check security groups allow traffic from load balancer"
        - "Verify health check configuration in load balancer"
        - "Check application logs for errors"

  performance_issues:
    - issue: "High response times"
      diagnosis_commands:
        - "top -p $(pgrep java)"
        - "free -h"
        - "iostat -x 1"
        - "curl -w '%{time_total}' http://localhost:8080/health"
      solutions:
        - "Increase JVM heap size if memory constrained"
        - "Scale out if CPU utilization consistently high"
        - "Check database connection pool settings"
        - "Enable application profiling"
    
    - issue: "Memory leaks"
      diagnosis_commands:
        - "jstat -gc $(pgrep java) 5s"
        - "jmap -histo $(pgrep java)"
        - "ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head"
      solutions:
        - "Enable JVM GC logging"
        - "Use memory profiler (JProfiler, VisualVM)"
        - "Review application code for memory leaks"
        - "Implement memory monitoring alerts"

  connectivity_issues:
    - issue: "Cannot reach application from internet"
      diagnosis_commands:
        - "curl -I http://load-balancer-dns/health"
        - "nslookup load-balancer-dns"
        - "telnet load-balancer-ip 80"
        - "aws elbv2 describe-target-health --target-group-arn TARGET_GROUP_ARN"
      solutions:
        - "Check load balancer listener configuration"
        - "Verify target group health"
        - "Check security group rules"
        - "Validate DNS resolution"
```

### 2. Monitoring and Alerting

```yaml
# Monitoring Configuration
monitoring_alerts:
  application_alerts:
    - name: "High Error Rate"
      condition: "error_rate > 5%"
      duration: "5m"
      actions:
        - send_slack_notification
        - page_on_call_engineer
        - auto_scale_if_needed
    
    - name: "High Response Time"
      condition: "avg_response_time > 2000ms"
      duration: "10m"
      actions:
        - send_email_notification
        - check_resource_usage
        - consider_scaling
    
    - name: "Application Down"
      condition: "health_check_failure_count > 3"
      duration: "2m"
      actions:
        - immediate_page
        - auto_restart_service
        - escalate_to_senior_engineer

  infrastructure_alerts:
    - name: "High CPU Usage"
      condition: "cpu_usage > 80%"
      duration: "15m"
      actions:
        - scale_out_instances
        - notify_devops_team
    
    - name: "Low Disk Space"
      condition: "disk_usage > 85%"
      duration: "5m"
      actions:
        - clean_log_files
        - notify_operations
        - consider_increasing_volume_size
    
    - name: "Instance Unhealthy"
      condition: "instance_health_check_failed"
      duration: "3m"
      actions:
        - remove_from_load_balancer
        - replace_instance
        - investigate_root_cause
```

### 3. Debugging Commands

```bash
#!/bin/bash
# Debugging and Diagnostic Commands

# System Information
echo "=== System Information ==="
uname -a
cat /etc/os-release
uptime
free -h
df -h

# Process Information
echo "=== Application Process ==="
ps aux | grep java
systemctl status web-app
journalctl -u web-app --lines=50

# Network Information
echo "=== Network Configuration ==="
ip addr show
netstat -tlnp
ss -tlnp | grep :8080

# Application Logs
echo "=== Application Logs ==="
tail -n 100 /var/log/web-app/application.log
tail -n 100 /var/log/web-app/error.log

# JVM Information (if Java application)
echo "=== JVM Information ==="
java -version
jps -v
jstat -gc $(pgrep java)

# Load Balancer Health Check
echo "=== Health Check ==="
curl -v http://localhost:8080/health
curl -v http://localhost:8080/actuator/info

# Resource Usage
echo "=== Resource Usage ==="
top -b -n 1 | head -20
iostat -x 1 5
```

## Multi-Cloud Specific Configurations

### Azure VM Deployments

```yaml
# Azure Infrastructure Definition
apiVersion: v1
kind: Infrastructure
metadata:
  name: azure-vm-infrastructure
spec:
  environmentRef: prod_vm_env
  deploymentType: Ssh
  type: DirectConnection
  spec:
    connectorRef: azure_connector
    subscriptionId: "12345678-1234-1234-1234-123456789012"
    resourceGroup: "web-app-rg"
    region: "East US"
    hostConnectionType: PublicIP
    hostFilter:
      type: AzureVMSSFilter
      spec:
        resourceGroups:
          - "web-app-rg"
        tags:
          Environment: "production"
          Application: "web-app"
```

```hcl
# Azure Terraform Configuration
resource "azurerm_virtual_machine_scale_set" "web_app" {
  name                = "${var.app_name}-vmss"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  upgrade_policy_mode = "Manual"
  
  sku {
    name     = var.vm_size
    tier     = "Standard"
    capacity = var.instance_count
  }
  
  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  
  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }
  
  os_profile {
    computer_name_prefix = "${var.app_name}-vm"
    admin_username       = var.admin_username
    custom_data         = base64encode(file("${path.module}/cloud-init.yml"))
  }
  
  os_profile_linux_config {
    disable_password_authentication = true
    
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = var.public_key
    }
  }
  
  network_profile {
    name    = "networkprofile"
    primary = true
    
    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                             = azurerm_subnet.internal.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_app.id]
      primary = true
    }
  }
  
  tags = {
    Environment = var.environment
    ManagedBy   = "Harness"
  }
}

# Azure Load Balancer
resource "azurerm_lb" "web_app" {
  name                = "${var.app_name}-lb"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.web_app.id
  }
  
  tags = {
    Environment = var.environment
  }
}
```

### GCP VM Deployments

```yaml
# GCP Infrastructure Definition
apiVersion: v1
kind: Infrastructure
metadata:
  name: gcp-compute-infrastructure
spec:
  environmentRef: prod_vm_env
  deploymentType: Ssh
  type: DirectConnection
  spec:
    connectorRef: gcp_connector
    project: "web-app-project"
    region: "us-central1"
    zone: "us-central1-a"
    hostConnectionType: PublicIP
    hostFilter:
      type: GcpInstanceGroupFilter
      spec:
        zones:
          - "us-central1-a"
        tags:
          - "web-app"
          - "production"
```

```hcl
# GCP Terraform Configuration
resource "google_compute_instance_template" "web_app" {
  name         = "${var.app_name}-template"
  machine_type = var.machine_type
  region       = var.gcp_region
  
  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
    type         = "PERSISTENT"
    mode         = "READ_WRITE"
  }
  
  network_interface {
    network    = google_compute_network.main.name
    subnetwork = google_compute_subnetwork.main.name
    
    access_config {
      // Ephemeral public IP
    }
  }
  
  metadata_startup_script = file("${path.module}/startup-script.sh")
  
  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }
  
  tags = ["web-app", var.environment]
  
  labels = {
    environment = var.environment
    managed-by  = "harness"
  }
}

# Managed Instance Group
resource "google_compute_region_instance_group_manager" "web_app" {
  name   = "${var.app_name}-mig"
  region = var.gcp_region
  
  version {
    instance_template = google_compute_instance_template.web_app.id
    name              = "primary"
  }
  
  base_instance_name = "${var.app_name}-instance"
  target_size        = var.target_size
  
  named_port {
    name = "http"
    port = var.app_port
  }
  
  auto_healing_policies {
    health_check      = google_compute_health_check.web_app.id
    initial_delay_sec = 300
  }
}
```

## Cost Optimization Strategies

### 1. Instance Right-Sizing

```yaml
# Cost Optimization Pipeline
costOptimization:
  instanceSizing:
    development:
      instance_type: "t3.micro"    # AWS
      vm_size: "Standard_B1s"      # Azure  
      machine_type: "e2-micro"     # GCP
    
    staging:
      instance_type: "t3.small"
      vm_size: "Standard_B2s"
      machine_type: "e2-small"
    
    production:
      instance_type: "m5.large"
      vm_size: "Standard_D2s_v3"
      machine_type: "e2-standard-2"
  
  scheduledScaling:
    business_hours:
      schedule: "0 8 * * 1-5"  # 8 AM on weekdays
      min_instances: 3
      max_instances: 10
    
    off_hours:
      schedule: "0 18 * * 1-5"  # 6 PM on weekdays
      min_instances: 1
      max_instances: 5
    
    weekend:
      schedule: "0 20 * * 5"    # Friday 8 PM
      min_instances: 1
      max_instances: 2
```

### 2. Spot Instance Integration

```hcl
# AWS Spot Instance Configuration
resource "aws_autoscaling_group" "web_app_spot" {
  name                = "${var.app_name}-spot-asg"
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.web_app.arn]
  health_check_type   = "ELB"
  
  min_size         = var.min_spot_instances
  max_size         = var.max_spot_instances
  desired_capacity = var.desired_spot_instances
  
  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 25
      spot_allocation_strategy                 = "capacity-optimized"
    }
    
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.web_app_spot.id
        version           = "$Latest"
      }
      
      override {
        instance_type     = "m5.large"
        weighted_capacity = "1"
      }
      
      override {
        instance_type     = "m5a.large"
        weighted_capacity = "1"
      }
      
      override {
        instance_type     = "m4.large"
        weighted_capacity = "1"
      }
    }
  }
  
  tag {
    key                 = "InstanceType"
    value               = "Spot"
    propagate_at_launch = true
  }
}
```

### 3. Cost Monitoring and Alerts

```yaml
# Cost Monitoring Configuration
costMonitoring:
  budgets:
    - name: "VM Infrastructure Budget"
      amount: "$1000"
      period: "MONTHLY"
      threshold: 80
      alerts:
        - email: "finance@company.com"
        - slack: "#cost-alerts"
  
  policies:
    - name: "Instance Size Policy"
      rule: "instance_type not in ['m5.4xlarge', 'm5.8xlarge']"
      action: "WARN"
    
    - name: "Spot Instance Policy"
      rule: "environment == 'development' and spot_instances < 70%"
      action: "WARN"
    
    - name: "Idle Instance Policy"
      rule: "cpu_utilization < 5% for 2 hours"
      action: "TERMINATE"
```

## Advanced Scaling and Auto-Scaling

### 1. Predictive Scaling

```yaml
# Predictive Auto-Scaling Configuration
predictiveScaling:
  enabled: true
  predictionModel: "machine_learning"
  
  metrics:
    - name: "cpu_utilization"
      target: 70
      weight: 0.6
    
    - name: "memory_utilization"
      target: 80
      weight: 0.3
    
    - name: "request_count"
      target: 1000
      weight: 0.1
  
  scheduleBasedScaling:
    patterns:
      - name: "morning_traffic"
        time: "06:00-10:00"
        timezone: "UTC"
        scale_factor: 1.5
      
      - name: "lunch_traffic"
        time: "12:00-14:00"
        timezone: "UTC"
        scale_factor: 1.3
      
      - name: "evening_traffic"
        time: "17:00-21:00"
        timezone: "UTC"
        scale_factor: 1.8
  
  customMetrics:
    - name: "queue_depth"
      source: "cloudwatch"
      namespace: "AWS/SQS"
      metric: "ApproximateNumberOfMessages"
      target: 100
      scale_up_threshold: 150
      scale_down_threshold: 50
```

### 2. Multi-Metric Scaling

```yaml
# Complex Auto-Scaling Rules
autoScaling:
  policies:
    - name: "scale_up_policy"
      type: "StepScaling"
      adjustmentType: "PercentChangeInCapacity"
      conditions:
        - metric: "CPUUtilization"
          threshold: 70
          comparison: "GreaterThanThreshold"
          evaluationPeriods: 2
          period: 300
        
        - metric: "MemoryUtilization"
          threshold: 80
          comparison: "GreaterThanThreshold"
          evaluationPeriods: 2
          period: 300
      
      actions:
        - adjustment: 25
          lowerBound: 70
          upperBound: 85
        
        - adjustment: 50
          lowerBound: 85
          upperBound: 95
        
        - adjustment: 100
          lowerBound: 95
    
    - name: "scale_down_policy"
      type: "StepScaling"
      adjustmentType: "PercentChangeInCapacity"
      conditions:
        - metric: "CPUUtilization"
          threshold: 30
          comparison: "LessThanThreshold"
          evaluationPeriods: 5
          period: 300
      
      actions:
        - adjustment: -10
          upperBound: 30
```

## CI/CD Integration Workflows

### 1. Complete CI/CD Pipeline

```yaml
# Full CI/CD Pipeline with VM Deployment
apiVersion: v1
kind: Pipeline
metadata:
  name: complete-cicd-pipeline
spec:
  stages:
    # CI Stage
    - stage:
        name: Continuous Integration
        identifier: ci_stage
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
                  type: Run
                  name: Run Tests
                  identifier: run_tests
                  spec:
                    shell: Bash
                    command: |
                      echo "Running unit tests..."
                      mvn clean test
                      echo "Running integration tests..."
                      mvn integration-test
              
              - step:
                  type: Run
                  name: Security Scan
                  identifier: security_scan
                  spec:
                    shell: Bash
                    command: |
                      echo "Running security scan..."
                      mvn dependency-check:check
                      sonar-scanner
              
              - step:
                  type: Run
                  name: Build Application
                  identifier: build_app
                  spec:
                    shell: Bash
                    command: |
                      echo "Building application..."
                      mvn clean package -DskipTests
              
              - step:
                  type: BuildAndPushDockerRegistry
                  name: Build and Push Artifact
                  identifier: build_push_artifact
                  spec:
                    connectorRef: artifactory_connector
                    repo: web-app
                    tags:
                      - <+pipeline.executionId>
                      - latest
    
    # Infrastructure Stage
    - stage:
        name: Infrastructure Provisioning
        identifier: infra_stage
        type: Custom
        spec:
          execution:
            steps:
              - step:
                  type: TerraformPlan
                  name: Plan Infrastructure
                  identifier: plan_infra
                  spec:
                    configuration:
                      command: Apply
                      workspace: <+pipeline.variables.environment>
                      configFiles:
                        store:
                          type: Git
                          spec:
                            gitFetchType: Branch
                            repoName: infrastructure-repo
                            branch: main
                            folderPath: terraform/
              
              - step:
                  type: TerraformApply
                  name: Apply Infrastructure
                  identifier: apply_infra
                  spec:
                    configuration:
                      type: InheritFromPlan
                    provisionerIdentifier: plan_infra
    
    # Deployment Stages
    - stage:
        name: Deploy to Development
        identifier: deploy_dev
        type: Deployment
        spec:
          deploymentType: Ssh
          service:
            serviceRef: web_app_vm
          environment:
            environmentRef: dev_vm_env
          execution:
            steps:
              - step:
                  type: Command
                  name: Deploy Application
                  identifier: deploy_app_dev
                  spec:
                    onDelegate: false
                    commandUnits:
                      - identifier: deploy_artifact
                        name: Deploy Artifact
                        type: Copy
                        spec:
                          sourceType: Artifact
                          destinationPath: /opt/app/
              
              - step:
                  type: Command
                  name: Health Check
                  identifier: health_check_dev
                  spec:
                    onDelegate: false
                    commandUnits:
                      - identifier: verify_deployment
                        name: Verify Deployment
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                sleep 30
                                curl -f http://localhost:8080/health || exit 1
    
    - stage:
        name: Deploy to Production
        identifier: deploy_prod
        type: Deployment
        spec:
          deploymentType: Ssh
          service:
            serviceRef: web_app_vm
          environment:
            environmentRef: prod_vm_env
          execution:
            steps:
              - step:
                  type: HarnessApproval
                  name: Production Approval
                  identifier: prod_approval
                  spec:
                    approvalMessage: "Please approve production deployment"
                    includePipelineExecutionHistory: true
                    approvers:
                      userGroups:
                        - production_approvers
                    minimumCount: 2
                    disallowPipelineExecutor: true
              
              - step:
                  type: Command
                  name: Blue Green Deployment
                  identifier: blue_green_deploy
                  spec:
                    onDelegate: false
                    commandUnits:
                      - identifier: deploy_green
                        name: Deploy Green Environment
                        type: Copy
                        spec:
                          sourceType: Artifact
                          destinationPath: /opt/app-green/
              
              - step:
                  type: Command
                  name: Traffic Switch
                  identifier: traffic_switch
                  spec:
                    onDelegate: false
                    commandUnits:
                      - identifier: switch_traffic
                        name: Switch Load Balancer
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                # Switch load balancer to green environment
                                aws elbv2 modify-target-group \
                                  --target-group-arn <+pipeline.variables.green_target_group> \
                                  --health-check-path /health
```

### 2. GitOps Integration

```yaml
# GitOps Configuration for VM Deployments
gitOps:
  enabled: true
  repository:
    url: "https://github.com/company/vm-configs"
    branch: "main"
    path: "environments/"
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
  
  applicationSets:
    - name: "vm-applications"
      generators:
        - git:
            repoURL: "https://github.com/company/vm-configs"
            revision: "HEAD"
            directories:
              - path: "environments/*"
      
      template:
        metadata:
          name: "{{path.basename}}-vm-app"
        
        spec:
          project: "vm-deployments"
          source:
            repoURL: "https://github.com/company/vm-configs"
            targetRevision: "HEAD"
            path: "{{path}}"
          
          destination:
            server: "https://kubernetes.default.svc"
            namespace: "{{path.basename}}"
```

## Migration Strategies and Patterns

### 1. Legacy System Migration

```yaml
# Migration Pipeline Template
migrationStrategy:
  phases:
    - name: "Assessment Phase"
      duration: "2 weeks"
      activities:
        - inventory_legacy_systems
        - analyze_dependencies
        - assess_technical_debt
        - plan_migration_approach
    
    - name: "Preparation Phase"
      duration: "4 weeks"
      activities:
        - setup_harness_environment
        - create_infrastructure_templates
        - establish_ci_cd_pipelines
        - train_development_teams
    
    - name: "Migration Phase"
      duration: "8-12 weeks"
      activities:
        - parallel_deployment_setup
        - gradual_traffic_migration
        - data_synchronization
        - validation_testing
    
    - name: "Optimization Phase"
      duration: "4 weeks"
      activities:
        - performance_tuning
        - cost_optimization
        - monitoring_enhancement
        - documentation_completion

# Parallel Deployment Strategy
parallelDeployment:
  legacy_system:
    environment: "legacy"
    traffic_percentage: 90
    monitoring:
      - error_rates
      - response_times
      - business_metrics
  
  harness_system:
    environment: "new"
    traffic_percentage: 10
    monitoring:
      - application_health
      - infrastructure_metrics
      - cost_tracking
  
  migration_criteria:
    success_metrics:
      - error_rate_below: "0.1%"
      - response_time_below: "200ms"
      - zero_data_loss: true
    
    rollback_triggers:
      - error_rate_above: "1%"
      - response_time_above: "1000ms"
      - data_inconsistency_detected: true
```

### 2. Database Migration Patterns

```yaml
# Database Migration with VM Deployments
databaseMigration:
  strategy: "blue_green_with_shared_db"
  
  phases:
    - name: "Schema Migration"
      steps:
        - backup_production_database
        - apply_schema_changes
        - verify_schema_integrity
    
    - name: "Data Migration"
      steps:
        - sync_initial_data
        - setup_replication
        - validate_data_consistency
    
    - name: "Application Cutover"
      steps:
        - deploy_new_application_version
        - test_database_connectivity
        - switch_traffic_gradually
    
    - name: "Cleanup"
      steps:
        - remove_old_application_version
        - cleanup_temporary_resources
        - update_monitoring_dashboards

# Database Connection Configuration
databaseConfig:
  connection_pools:
    read_pool:
      max_connections: 20
      min_connections: 5
      connection_timeout: 30
    
    write_pool:
      max_connections: 10
      min_connections: 2
      connection_timeout: 30
  
  failover:
    enabled: true
    read_replica_endpoints:
      - "replica-1.database.com"
      - "replica-2.database.com"
    
    circuit_breaker:
      failure_threshold: 5
      timeout: 60
      half_open_max_calls: 3
```

## Template and Reusability Patterns

### 1. Pipeline Templates

```yaml
# Reusable Pipeline Template
apiVersion: v1
kind: Template
metadata:
  name: vm-deployment-template
  identifier: vm_deployment_template
spec:
  type: Pipeline
  spec:
    stages:
      - stage:
          name: Deploy to <+input>
          identifier: deploy_stage
          type: Deployment
          spec:
            deploymentType: Ssh
            service:
              serviceRef: <+input>
            environment:
              environmentRef: <+input>
              infrastructureDefinitions:
                - identifier: <+input>
            execution:
              steps:
                - step:
                    type: Command
                    name: Pre-Deployment Check
                    identifier: pre_deploy_check
                    spec:
                      onDelegate: false
                      commandUnits:
                        - identifier: health_check
                          name: Service Health Check
                          type: Script
                          spec:
                            shell: Bash
                            source:
                              type: Inline
                              spec:
                                script: |
                                  # Check if service is running
                                  systemctl is-active --quiet <+service.name> || echo "Service not running"
                
                - step:
                    type: Command
                    name: Deploy Application
                    identifier: deploy_app
                    spec:
                      onDelegate: false
                      commandUnits:
                        - identifier: stop_service
                          name: Stop Service
                          type: Script
                          spec:
                            shell: Bash
                            source:
                              type: Inline
                              spec:
                                script: sudo systemctl stop <+service.name>
                        
                        - identifier: deploy_artifact
                          name: Deploy Artifact
                          type: Copy
                          spec:
                            sourceType: Artifact
                            destinationPath: <+service.variables.deployment_path>
                        
                        - identifier: start_service
                          name: Start Service
                          type: Script
                          spec:
                            shell: Bash
                            source:
                              type: Inline
                              spec:
                                script: |
                                  sudo systemctl start <+service.name>
                                  sleep 30
                                  curl -f http://localhost:<+service.variables.port>/health
```

### 2. Environment Templates

```yaml
# Environment Template
apiVersion: v1
kind: Template
metadata:
  name: vm-environment-template
spec:
  type: Environment
  spec:
    type: <+input>
    tags:
      environment: <+input>
      deployment_type: vm
      managed_by: harness
    
    variables:
      - name: instance_type
        type: String
        value: <+input>
      
      - name: min_instances
        type: Number
        value: <+input>
      
      - name: max_instances
        type: Number
        value: <+input>
      
      - name: region
        type: String
        value: <+input>
    
    infrastructureDefinitions:
      - name: <+input>-infrastructure
        identifier: <+input>_infra
        spec:
          cloudProviderType: <+input>
          deploymentType: Ssh
          spec:
            cloudProviderRef: <+input>
            region: <+input>
            tags:
              Environment: <+input>
              ManagedBy: harness
```

### 3. Service Templates

```yaml
# Service Template
apiVersion: v1
kind: Template
metadata:
  name: vm-service-template
spec:
  type: Service
  spec:
    serviceDefinition:
      type: SSH
      spec:
        artifacts:
          primary:
            spec:
              connectorRef: <+input>
              artifactPath: <+input>
              tag: <+input>
            type: <+input>
        
        variables:
          - name: deployment_path
            type: String
            value: <+input>
          
          - name: port
            type: String
            value: <+input>
          
          - name: health_check_path
            type: String
            value: <+input>
          
          - name: max_memory
            type: String
            value: <+input>
          
          - name: environment_config
            type: String
            value: <+input>
```

## Testing Strategies

### 1. Automated Testing Pipeline

```yaml
# Comprehensive Testing Strategy
testingStrategy:
  unitTests:
    framework: "JUnit"
    coverage_threshold: 80
    execution:
      - step:
          type: Run
          name: Unit Tests
          spec:
            command: |
              mvn clean test
              mvn jacoco:report
              # Fail if coverage below threshold
              mvn jacoco:check
  
  integrationTests:
    framework: "TestContainers"
    execution:
      - step:
          type: Run
          name: Integration Tests
          spec:
            command: |
              # Start test database
              docker run -d --name test-db postgres:13
              
              # Run integration tests
              mvn integration-test
              
              # Cleanup
              docker stop test-db && docker rm test-db
  
  smokeTests:
    post_deployment: true
    execution:
      - step:
          type: Command
          name: Smoke Tests
          spec:
            onDelegate: false
            commandUnits:
              - identifier: api_smoke_test
                name: API Smoke Test
                type: Script
                spec:
                  shell: Bash
                  source:
                    type: Inline
                    spec:
                      script: |
                        #!/bin/bash
                        BASE_URL="http://<+instance.hostName>:<+service.variables.port>"
                        
                        # Test health endpoint
                        echo "Testing health endpoint..."
                        curl -f "${BASE_URL}/health" || exit 1
                        
                        # Test main API endpoints
                        echo "Testing API endpoints..."
                        curl -f "${BASE_URL}/api/v1/users" || exit 1
                        curl -f "${BASE_URL}/api/v1/products" || exit 1
                        
                        # Test database connectivity
                        echo "Testing database connectivity..."
                        curl -f "${BASE_URL}/api/v1/health/db" || exit 1
                        
                        echo "All smoke tests passed!"
  
  loadTests:
    tool: "Apache JMeter"
    execution:
      - step:
          type: Command
          name: Load Testing
          spec:
            onDelegate: true
            environmentVariables:
              - name: TARGET_URL
                value: "http://<+instance.hostName>:<+service.variables.port>"
              - name: CONCURRENT_USERS
                value: "100"
              - name: DURATION
                value: "300"
            commandUnits:
              - identifier: run_load_test
                name: Run Load Test
                type: Script
                spec:
                  shell: Bash
                  source:
                    type: Inline
                    spec:
                      script: |
                        # Install JMeter if not present
                        if ! command -v jmeter &> /dev/null; then
                          wget https://downloads.apache.org//jmeter/binaries/apache-jmeter-5.4.3.zip
                          unzip apache-jmeter-5.4.3.zip
                          export PATH=$PATH:$(pwd)/apache-jmeter-5.4.3/bin
                        fi
                        
                        # Create JMeter test plan
                        cat > load_test.jmx << EOF
                        <?xml version="1.0" encoding="UTF-8"?>
                        <jmeterTestPlan version="1.2">
                          <hashTree>
                            <TestPlan>
                              <elementProp name="TestPlan.arguments" elementType="Arguments" guiclass="ArgumentsPanel"/>
                            </TestPlan>
                            <hashTree>
                              <ThreadGroup>
                                <stringProp name="ThreadGroup.num_threads">${CONCURRENT_USERS}</stringProp>
                                <stringProp name="ThreadGroup.duration">${DURATION}</stringProp>
                                <elementProp name="HTTPSampler.Arguments" elementType="Arguments"/>
                              </ThreadGroup>
                              <hashTree>
                                <HTTPSamplerProxy>
                                  <stringProp name="HTTPSampler.domain"><+instance.hostName></stringProp>
                                  <stringProp name="HTTPSampler.port"><+service.variables.port></stringProp>
                                  <stringProp name="HTTPSampler.path">/api/v1/health</stringProp>
                                  <stringProp name="HTTPSampler.method">GET</stringProp>
                                </HTTPSamplerProxy>
                              </hashTree>
                            </hashTree>
                          </hashTree>
                        </jmeterTestPlan>
                        EOF
                        
                        # Run load test
                        jmeter -n -t load_test.jmx -l results.jtl
                        
                        # Analyze results
                        jmeter -g results.jtl -o report/
                        
                        # Check performance criteria
                        avg_response_time=$(awk -F',' 'NR>1{sum+=$2; count++} END{print sum/count}' results.jtl)
                        if (( $(echo "$avg_response_time > 1000" | bc -l) )); then
                          echo "Load test failed: Average response time $avg_response_time ms exceeds 1000ms threshold"
                          exit 1
                        fi
                        
                        echo "Load test passed: Average response time $avg_response_time ms"
  
  securityTests:
    tools:
      - "OWASP ZAP"
      - "SonarQube"
    execution:
      - step:
          type: Command
          name: Security Scanning
          spec:
            onDelegate: true
            commandUnits:
              - identifier: zap_security_scan
                name: OWASP ZAP Security Scan
                type: Script
                spec:
                  shell: Bash
                  source:
                    type: Inline
                    spec:
                      script: |
                        # Install OWASP ZAP
                        docker pull owasp/zap2docker-stable
                        
                        # Run security scan
                        docker run -v $(pwd):/zap/wrk/:rw \
                          -t owasp/zap2docker-stable \
                          zap-baseline.py \
                          -t http://<+instance.hostName>:<+service.variables.port> \
                          -g gen.conf \
                          -r zap_report.html
                        
                        # Check for high-risk vulnerabilities
                        if grep -q "High" zap_report.html; then
                          echo "High-risk security vulnerabilities found!"
                          exit 1
                        fi
                        
                        echo "Security scan completed successfully"
```

### 2. Environment-Specific Testing

```yaml
# Environment-Specific Test Configuration
environmentTesting:
  development:
    test_types:
      - unit_tests
      - integration_tests
      - smoke_tests
    
    test_data:
      database: "test_db"
      external_services: "mocked"
    
    performance_criteria:
      response_time_threshold: "2000ms"
      error_rate_threshold: "5%"
  
  staging:
    test_types:
      - integration_tests
      - smoke_tests
      - load_tests
      - security_tests
    
    test_data:
      database: "staging_db"
      external_services: "staging"
    
    performance_criteria:
      response_time_threshold: "1000ms"
      error_rate_threshold: "1%"
      concurrent_users: 50
  
  production:
    test_types:
      - smoke_tests
      - health_checks
      - synthetic_monitoring
    
    performance_criteria:
      response_time_threshold: "500ms"
      error_rate_threshold: "0.1%"
      availability_threshold: "99.9%"
```

## Rollback Procedures

### 1. Automated Rollback Strategy

```yaml
# Comprehensive Rollback Configuration
rollbackStrategy:
  triggers:
    - name: "High Error Rate"
      condition: "error_rate > 5%"
      evaluation_window: "5m"
      action: "automatic_rollback"
    
    - name: "Response Time Degradation"
      condition: "avg_response_time > 2000ms"
      evaluation_window: "10m"
      action: "automatic_rollback"
    
    - name: "Health Check Failure"
      condition: "health_check_success_rate < 80%"
      evaluation_window: "3m"
      action: "automatic_rollback"
    
    - name: "Manual Trigger"
      condition: "user_initiated"
      action: "immediate_rollback"
  
  rollbackTypes:
    - name: "Traffic Rollback"
      strategy: "load_balancer_switch"
      steps:
        - switch_load_balancer_to_previous_version
        - verify_traffic_routing
        - monitor_application_health
    
    - name: "Application Rollback"
      strategy: "previous_artifact_deployment"
      steps:
        - stop_current_application
        - deploy_previous_artifact_version
        - restart_application_services
        - run_smoke_tests
    
    - name: "Infrastructure Rollback"
      strategy: "terraform_state_revert"
      steps:
        - backup_current_terraform_state
        - revert_to_previous_terraform_state
        - apply_infrastructure_changes
        - validate_infrastructure_state

# Rollback Pipeline
rollbackPipeline:
  stages:
    - stage:
        name: Rollback Validation
        identifier: rollback_validation
        type: Custom
        spec:
          execution:
            steps:
              - step:
                  type: Command
                  name: Validate Rollback Prerequisites
                  identifier: validate_prereqs
                  spec:
                    onDelegate: false
                    commandUnits:
                      - identifier: check_previous_version
                        name: Check Previous Version Availability
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                # Check if previous version artifact exists
                                PREVIOUS_VERSION=$(cat /opt/app/.previous_version)
                                if [ -z "$PREVIOUS_VERSION" ]; then
                                  echo "No previous version found for rollback"
                                  exit 1
                                fi
                                
                                # Verify artifact availability
                                curl -f "https://artifactory.company.com/app/${PREVIOUS_VERSION}" || exit 1
                                echo "Previous version ${PREVIOUS_VERSION} available for rollback"
    
    - stage:
        name: Execute Rollback
        identifier: execute_rollback
        type: Deployment
        spec:
          deploymentType: Ssh
          service:
            serviceRef: web_app_vm
          environment:
            environmentRef: prod_vm_env
          execution:
            steps:
              - step:
                  type: Command
                  name: Backup Current State
                  identifier: backup_current
                  spec:
                    onDelegate: false
                    commandUnits:
                      - identifier: backup_application
                        name: Backup Current Application
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                BACKUP_DIR="/backup/rollback/$(date +%Y%m%d_%H%M%S)"
                                mkdir -p $BACKUP_DIR
                                
                                # Backup current application
                                cp -r /opt/app/ $BACKUP_DIR/
                                
                                # Backup configuration
                                cp -r /etc/app/ $BACKUP_DIR/
                                
                                # Store backup location
                                echo $BACKUP_DIR > /tmp/rollback_backup_path
                                echo "Current state backed up to $BACKUP_DIR"
              
              - step:
                  type: Command
                  name: Rollback Application
                  identifier: rollback_app
                  spec:
                    onDelegate: false
                    commandUnits:
                      - identifier: stop_current_app
                        name: Stop Current Application
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                sudo systemctl stop web-app
                                sleep 10
                      
                      - identifier: deploy_previous_version
                        name: Deploy Previous Version
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                PREVIOUS_VERSION=$(cat /opt/app/.previous_version)
                                
                                # Download previous version
                                curl -o /tmp/app-${PREVIOUS_VERSION}.tar.gz \
                                  "https://artifactory.company.com/app/${PREVIOUS_VERSION}"
                                
                                # Extract to application directory
                                tar -xzf /tmp/app-${PREVIOUS_VERSION}.tar.gz -C /opt/
                                
                                # Restore previous configuration
                                if [ -f "/backup/config-${PREVIOUS_VERSION}.tar.gz" ]; then
                                  tar -xzf "/backup/config-${PREVIOUS_VERSION}.tar.gz" -C /etc/
                                fi
                                
                                # Update permissions
                                chown -R app:app /opt/app/
                      
                      - identifier: start_previous_app
                        name: Start Previous Application
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                sudo systemctl start web-app
                                sleep 30
                                
                                # Verify application started successfully
                                systemctl is-active --quiet web-app || exit 1
                                echo "Previous application version started successfully"
              
              - step:
                  type: Command
                  name: Verify Rollback
                  identifier: verify_rollback
                  spec:
                    onDelegate: false
                    commandUnits:
                      - identifier: health_check_rollback
                        name: Health Check After Rollback
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                # Wait for application to be ready
                                sleep 60
                                
                                # Perform comprehensive health check
                                for i in {1..10}; do
                                  echo "Health check attempt $i/10"
                                  
                                  if curl -f "http://localhost:<+service.variables.port>/health"; then
                                    echo "Health check passed"
                                    break
                                  fi
                                  
                                  if [ $i -eq 10 ]; then
                                    echo "Health check failed after 10 attempts"
                                    exit 1
                                  fi
                                  
                                  sleep 30
                                done
                                
                                # Test critical API endpoints
                                curl -f "http://localhost:<+service.variables.port>/api/v1/users" || exit 1
                                curl -f "http://localhost:<+service.variables.port>/api/v1/products" || exit 1
                                
                                echo "Rollback verification completed successfully"
    
    - stage:
        name: Post-Rollback Actions
        identifier: post_rollback
        type: Custom
        spec:
          execution:
            steps:
              - step:
                  type: Command
                  name: Update Monitoring
                  identifier: update_monitoring
                  spec:
                    onDelegate: true
                    commandUnits:
                      - identifier: update_dashboards
                        name: Update Monitoring Dashboards
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                # Update Grafana annotations
                                PREVIOUS_VERSION=$(cat /opt/app/.previous_version)
                                
                                curl -X POST "http://grafana.company.com:3000/api/annotations" \
                                  -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
                                  -H "Content-Type: application/json" \
                                  -d '{
                                    "dashboardId": 1,
                                    "text": "Rollback to version '${PREVIOUS_VERSION}' completed",
                                    "tags": ["rollback", "deployment"],
                                    "time": '$(date +%s000)'
                                  }'
                                
                                echo "Monitoring dashboards updated"
              
              - step:
                  type: Command
                  name: Notify Teams
                  identifier: notify_teams
                  spec:
                    onDelegate: true
                    commandUnits:
                      - identifier: send_notifications
                        name: Send Rollback Notifications
                        type: Script
                        spec:
                          shell: Bash
                          source:
                            type: Inline
                            spec:
                              script: |
                                PREVIOUS_VERSION=$(cat /opt/app/.previous_version)
                                
                                # Send Slack notification
                                curl -X POST "$SLACK_WEBHOOK_URL" \
                                  -H "Content-Type: application/json" \
                                  -d '{
                                    "text": "🔄 Rollback Completed",
                                    "attachments": [{
                                      "color": "warning",
                                      "fields": [{
                                        "title": "Environment",
                                        "value": "<+env.name>",
                                        "short": true
                                      }, {
                                        "title": "Previous Version",
                                        "value": "'${PREVIOUS_VERSION}'",
                                        "short": true
                                      }, {
                                        "title": "Rollback Reason",
                                        "value": "<+pipeline.variables.rollback_reason>",
                                        "short": false
                                      }]
                                    }]
                                  }'
                                
                                # Send email notification
                                echo "Rollback to ${PREVIOUS_VERSION} completed for <+env.name> environment" | \
                                  mail -s "Rollback Notification - <+env.name>" \
                                  devops@company.com
```

### 2. Manual Rollback Procedures

```bash
#!/bin/bash
# Manual Rollback Script

set -e

ENVIRONMENT=${1:-production}
ROLLBACK_VERSION=${2}
LOG_FILE="/var/log/rollback-$(date +%Y%m%d_%H%M%S).log"

echo "Starting manual rollback process..." | tee -a $LOG_FILE
echo "Environment: $ENVIRONMENT" | tee -a $LOG_FILE
echo "Target Version: $ROLLBACK_VERSION" | tee -a $LOG_FILE

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Function to check if rollback is safe
check_rollback_safety() {
    log "Checking rollback safety..."
    
    # Check if previous version exists
    if [ -z "$ROLLBACK_VERSION" ]; then
        ROLLBACK_VERSION=$(cat /opt/app/.previous_version 2>/dev/null || echo "")
        if [ -z "$ROLLBACK_VERSION" ]; then
            log "ERROR: No rollback version specified and no previous version found"
            exit 1
        fi
    fi
    
    # Check if backup exists
    if [ ! -f "/backup/app-${ROLLBACK_VERSION}.tar.gz" ]; then
        log "ERROR: Backup for version $ROLLBACK_VERSION not found"
        exit 1
    fi
    
    # Check disk space
    AVAILABLE_SPACE=$(df /opt | awk 'NR==2 {print $4}')
    REQUIRED_SPACE=1048576  # 1GB in KB
    
    if [ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]; then
        log "ERROR: Insufficient disk space for rollback"
        exit 1
    fi
    
    log "Rollback safety checks passed"
}

# Function to create emergency backup
create_emergency_backup() {
    log "Creating emergency backup of current state..."
    
    EMERGENCY_BACKUP="/backup/emergency-$(date +%Y%m%d_%H%M%S)"
    mkdir -p $EMERGENCY_BACKUP
    
    # Backup application
    tar -czf "$EMERGENCY_BACKUP/current-app.tar.gz" -C /opt app/ 2>/dev/null || true
    
    # Backup configuration
    tar -czf "$EMERGENCY_BACKUP/current-config.tar.gz" -C /etc app/ 2>/dev/null || true
    
    # Backup database (if applicable)
    if command -v mysqldump &> /dev/null; then
        mysqldump --all-databases > "$EMERGENCY_BACKUP/database-backup.sql" 2>/dev/null || true
    fi
    
    echo $EMERGENCY_BACKUP > /tmp/emergency_backup_path
    log "Emergency backup created at $EMERGENCY_BACKUP"
}

# Function to stop application gracefully
stop_application() {
    log "Stopping current application..."
    
    # Try graceful shutdown first
    if systemctl is-active --quiet web-app; then
        systemctl stop web-app
        
        # Wait for graceful shutdown
        for i in {1..30}; do
            if ! systemctl is-active --quiet web-app; then
                log "Application stopped gracefully"
                return 0
            fi
            sleep 1
        done
        
        # Force kill if graceful shutdown failed
        log "WARNING: Forcefully stopping application"
        pkill -9 -f "java.*web-app" || true
    fi
    
    log "Application stopped"
}

# Function to rollback application
rollback_application() {
    log "Rolling back to version $ROLLBACK_VERSION..."
    
    # Remove current application
    rm -rf /opt/app.old 2>/dev/null || true
    mv /opt/app /opt/app.old
    
    # Extract rollback version
    mkdir -p /opt/app
    tar -xzf "/backup/app-${ROLLBACK_VERSION}.tar.gz" -C /opt/app/
    
    # Restore configuration if available
    if [ -f "/backup/config-${ROLLBACK_VERSION}.tar.gz" ]; then
        tar -xzf "/backup/config-${ROLLBACK_VERSION}.tar.gz" -C /etc/
    fi
    
    # Set correct permissions
    chown -R app:app /opt/app/
    chmod +x /opt/app/bin/* 2>/dev/null || true
    
    log "Application rollback completed"
}

# Function to start application
start_application() {
    log "Starting rolled-back application..."
    
    systemctl start web-app
    
    # Wait for startup
    for i in {1..60}; do
        if systemctl is-active --quiet web-app; then
            log "Application started successfully"
            return 0
        fi
        sleep 1
    done
    
    log "ERROR: Application failed to start after rollback"
    exit 1
}

# Function to verify rollback
verify_rollback() {
    log "Verifying rollback..."
    
    # Check application health
    for i in {1..20}; do
        if curl -f "http://localhost:8080/health" &>/dev/null; then
            log "Health check passed"
            break
        fi
        
        if [ $i -eq 20 ]; then
            log "ERROR: Health check failed after rollback"
            return 1
        fi
        
        sleep 10
    done
    
    # Check application version
    CURRENT_VERSION=$(curl -s "http://localhost:8080/version" | jq -r '.version' 2>/dev/null || echo "unknown")
    if [ "$CURRENT_VERSION" = "$ROLLBACK_VERSION" ]; then
        log "Version verification passed: $CURRENT_VERSION"
    else
        log "WARNING: Version mismatch. Expected: $ROLLBACK_VERSION, Actual: $CURRENT_VERSION"
    fi
    
    # Test critical endpoints
    if curl -f "http://localhost:8080/api/v1/users" &>/dev/null && \
       curl -f "http://localhost:8080/api/v1/products" &>/dev/null; then
        log "Critical endpoints verification passed"
    else
        log "WARNING: Some critical endpoints are not responding"
    fi
    
    log "Rollback verification completed"
}

# Function to cleanup
cleanup() {
    log "Performing post-rollback cleanup..."
    
    # Update version tracking
    echo "$ROLLBACK_VERSION" > /opt/app/.current_version
    
    # Update monitoring annotations
    if command -v curl &> /dev/null && [ -n "$GRAFANA_API_TOKEN" ]; then
        curl -X POST "http://grafana.company.com:3000/api/annotations" \
          -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
          -H "Content-Type: application/json" \
          -d '{
            "text": "Manual rollback to version '${ROLLBACK_VERSION}' completed",
            "tags": ["rollback", "manual", "'${ENVIRONMENT}'"],
            "time": '$(date +%s000)'
          }' &>/dev/null || log "WARNING: Failed to update monitoring annotations"
    fi
    
    log "Cleanup completed"
}

# Main rollback process
main() {
    log "=== Starting Manual Rollback Process ==="
    
    check_rollback_safety
    
    # Ask for confirmation
    echo -n "Are you sure you want to rollback to version $ROLLBACK_VERSION? (yes/no): "
    read -r CONFIRMATION
    
    if [ "$CONFIRMATION" != "yes" ]; then
        log "Rollback cancelled by user"
        exit 0
    fi
    
    create_emergency_backup
    stop_application
    rollback_application
    start_application
    
    if verify_rollback; then
        cleanup
        log "=== Manual Rollback Completed Successfully ==="
        log "Emergency backup available at: $(cat /tmp/emergency_backup_path)"
    else
        log "=== Manual Rollback Completed with Warnings ==="
        log "Please check application logs for any issues"
        log "Emergency backup available at: $(cat /tmp/emergency_backup_path)"
    fi
}

# Run main function
main "$@"
```

## Delegate Management

### 1. Delegate Configuration and Deployment

```yaml
# Delegate Deployment Configuration
delegateManagement:
  deployment:
    kubernetes:
      namespace: "harness-delegate"
      replicas: 2
      resources:
        requests:
          memory: "2Gi"
          cpu: "1"
        limits:
          memory: "4Gi"
          cpu: "2"
      
      nodeSelector:
        kubernetes.io/arch: amd64
        node-type: delegate
      
      tolerations:
        - key: "delegate"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
    
    vm_based:
      instance_type: "m5.large"  # AWS
      vm_size: "Standard_D2s_v3"  # Azure
      machine_type: "e2-standard-2"  # GCP
      
      security_groups:
        - "delegate-sg"
        - "monitoring-sg"
      
      user_data: |
        #!/bin/bash
        # Install delegate
        curl -LO https://app.harness.io/public/shared/tools/delegate/latest/delegate.tar.gz
        tar -xzf delegate.tar.gz
        
        # Configure delegate
        export DELEGATE_NAME="vm-delegate-$(hostname)"
        export MANAGER_HOST_AND_PORT="https://app.harness.io"
        export ACCOUNT_ID="<account_id>"
        export DELEGATE_TOKEN="<delegate_token>"
        
        # Start delegate service
        ./start.sh
  
  configuration:
    environment_variables:
      - name: "JAVA_OPTS"
        value: "-Xms2048m -Xmx4096m"
      
      - name: "DELEGATE_CPU_THRESHOLD"
        value: "80"
      
      - name: "DELEGATE_MEMORY_THRESHOLD"
        value: "85"
      
      - name: "POLL_FOR_TASKS"
        value: "true"
      
      - name: "HEARTBEAT_INTERVAL_MS"
        value: "60000"
    
    networking:
      allowed_domains:
        - "app.harness.io"
        - "*.harness.io"
        - "storage.googleapis.com"
        - "*.amazonaws.com"
        - "*.azure.com"
      
      proxy_configuration:
        enabled: false
        http_proxy: ""
        https_proxy: ""
        no_proxy: "localhost,127.0.0.1"
    
    security:
      run_as_root: false
      seccomp_profile: "runtime/default"
      capabilities:
        drop:
          - "ALL"
        add:
          - "NET_BIND_SERVICE"
```

### 2. Delegate Monitoring and Health Management

```yaml
# Delegate Monitoring Configuration
delegateMonitoring:
  health_checks:
    - name: "CPU Usage"
      metric: "delegate_cpu_usage"
      threshold: 80
      action: "alert_and_scale"
    
    - name: "Memory Usage"
      metric: "delegate_memory_usage"
      threshold: 85
      action: "restart_delegate"
    
    - name: "Task Queue Length"
      metric: "delegate_task_queue"
      threshold: 100
      action: "scale_out"
    
    - name: "Connectivity"
      metric: "delegate_connectivity"
      threshold: 1
      action: "immediate_alert"
  
  auto_scaling:
    enabled: true
    min_delegates: 1
    max_delegates: 5
    
    scale_up_conditions:
      - metric: "task_queue_length > 50"
        duration: "5m"
      
      - metric: "cpu_usage > 70%"
        duration: "10m"
    
    scale_down_conditions:
      - metric: "task_queue_length < 10"
        duration: "15m"
      
      - metric: "cpu_usage < 30%"
        duration: "20m"
  
  alerting:
    slack:
      webhook_url: "${SLACK_WEBHOOK_URL}"
      channel: "#delegate-alerts"
    
    email:
      recipients:
        - "devops@company.com"
        - "platform@company.com"
    
    pagerduty:
      integration_key: "${PAGERDUTY_KEY}"
      severity: "critical"

# Delegate Auto-Upgrade Configuration
delegateUpgrade:
  auto_upgrade:
    enabled: true
    schedule: "0 2 * * 0"  # Sunday 2 AM
    upgrade_strategy: "rolling"
    
    pre_upgrade_checks:
      - verify_delegate_connectivity
      - check_running_tasks
      - backup_delegate_configuration
    
    post_upgrade_verification:
      - health_check
      - connectivity_test
      - task_execution_test
    
    rollback_conditions:
      - health_check_failure
      - connectivity_failure
      - task_execution_failure
```

### 3. Multi-Environment Delegate Strategy

```yaml
# Multi-Environment Delegate Configuration
delegateStrategy:
  environments:
    production:
      dedicated_delegates: true
      delegate_count: 3
      tags:
        - "production"
        - "critical"
      
      resource_requirements:
        memory: "4Gi"
        cpu: "2"
      
      security:
        network_isolation: true
        encrypted_communication: true
        audit_logging: true
    
    staging:
      shared_delegates: false
      delegate_count: 2
      tags:
        - "staging"
        - "pre-production"
      
      resource_requirements:
        memory: "2Gi"
        cpu: "1"
    
    development:
      shared_delegates: true
      delegate_count: 1
      tags:
        - "development"
        - "testing"
      
      resource_requirements:
        memory: "1Gi"
        cpu: "0.5"
  
  delegate_selection:
    production_pipelines:
      selector_strategy: "tag_based"
      required_tags:
        - "production"
      
      fallback_strategy: "none"
      
    staging_pipelines:
      selector_strategy: "tag_based"
      required_tags:
        - "staging"
      
      fallback_strategy: "development"
    
    development_pipelines:
      selector_strategy: "least_loaded"
      allowed_tags:
        - "development"
        - "testing"
```

## Conclusion

This comprehensive technical deep-dive provides detailed guidance for implementing VM deployments with Harness across multiple cloud providers. The enhanced documentation now includes:

**New Additions:**
- **Multi-cloud specific configurations** for Azure and GCP
- **Cost optimization strategies** including spot instances and right-sizing
- **Advanced scaling patterns** with predictive and multi-metric scaling
- **Complete CI/CD integration workflows** with GitOps
- **Migration strategies** for legacy systems and databases
- **Template and reusability patterns** for standardization
- **Comprehensive testing strategies** across all deployment phases
- **Detailed rollback procedures** with automation and manual processes
- **Delegate management** with monitoring, auto-scaling, and multi-environment strategies

**Key Implementation Principles:**
- Infrastructure as code for consistency and reproducibility
- Progressive deployment strategies for risk mitigation  
- Comprehensive monitoring and observability
- Automated testing at every stage
- Cost optimization through intelligent resource management
- Security-first approach with RBAC and compliance
- Disaster recovery and rollback preparedness
- Template-driven standardization for reusability

This document serves as a complete reference for organizations implementing VM deployments with Harness, covering everything from initial setup to production operations and maintenance.

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"id": "1", "content": "Review document for missing content areas", "status": "completed"}, {"id": "2", "content": "Add multi-cloud specific configurations (Azure/GCP)", "status": "completed"}, {"id": "3", "content": "Add cost optimization strategies", "status": "completed"}, {"id": "4", "content": "Add advanced scaling and auto-scaling details", "status": "completed"}, {"id": "5", "content": "Add CI/CD integration workflows", "status": "completed"}, {"id": "6", "content": "Add migration strategies and patterns", "status": "completed"}, {"id": "7", "content": "Add template and reusability patterns", "status": "completed"}, {"id": "8", "content": "Add testing strategies", "status": "completed"}, {"id": "9", "content": "Add rollback procedures", "status": "completed"}, {"id": "10", "content": "Add delegate management details", "status": "completed"}]