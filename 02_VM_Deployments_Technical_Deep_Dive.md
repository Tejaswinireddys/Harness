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

## Conclusion

This technical deep-dive provides comprehensive guidance for implementing VM deployments with Harness. The architecture supports multi-cloud deployments with strong security, monitoring, and operational practices.

Key takeaways:
- Use infrastructure as code for consistent environments
- Implement progressive deployment strategies
- Monitor application and infrastructure health
- Follow security best practices
- Plan for disaster recovery scenarios
- Use automation for configuration management

For additional support and advanced configurations, refer to the [Harness documentation](https://docs.harness.io) and engage with the Harness community.