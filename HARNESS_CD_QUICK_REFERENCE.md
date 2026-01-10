# Harness CD - Quick Reference Guide

> **One-page cheat sheet for DevOps teams**
> **Print-friendly format for easy reference**

---

## 🚀 Quick Start Commands

### Delegate Management
```bash
# Check delegate status
kubectl get pods -n harness-delegate-ng

# View delegate logs
kubectl logs -f <delegate-pod> -n harness-delegate-ng

# Restart delegate
kubectl rollout restart deployment/<delegate-name> -n harness-delegate-ng
```

### Pipeline Execution
```bash
# Trigger pipeline via API
curl -X POST 'https://app.harness.io/gateway/pipeline/api/pipeline/execute/{pipelineId}' \
  -H 'x-api-key: <your-api-key>'

# Check pipeline status
curl -X GET 'https://app.harness.io/gateway/pipeline/api/pipeline/execution/{executionId}/status' \
  -H 'x-api-key: <your-api-key>'
```

---

## 📋 Common YAML Configurations

### VM Deployment Pipeline (SSH)
```yaml
pipeline:
  name: VM Rolling Deployment
  identifier: vm_rolling_deploy
  stages:
    - stage:
        name: Deploy to Production
        identifier: deploy_prod
        type: Deployment
        spec:
          deploymentType: Ssh
          service:
            serviceRef: my_service
            serviceInputs:
              serviceDefinition:
                type: Ssh
                spec:
                  artifacts:
                    primary:
                      primaryArtifactRef: <+input>
          infrastructure:
            environmentRef: production
            infrastructureDefinition:
              type: SshWinRmAws
              spec:
                credentialsRef: ssh_key_prod
                hosts:
                  - host1.example.com
                  - host2.example.com
          execution:
            steps:
              - step:
                  type: Command
                  name: Stop Service
                  identifier: stop_service
                  spec:
                    commandType: Script
                    script: |
                      sudo systemctl stop myapp
              - step:
                  type: Command
                  name: Deploy Artifact
                  identifier: deploy_artifact
                  spec:
                    commandType: Copy
                    destinationPath: /opt/myapp
              - step:
                  type: Command
                  name: Start Service
                  identifier: start_service
                  spec:
                    commandType: Script
                    script: |
                      sudo systemctl start myapp
                      sleep 10
                      curl -f http://localhost:8080/health || exit 1
            rollbackSteps:
              - step:
                  type: Command
                  name: Rollback
                  identifier: rollback
                  spec:
                    commandType: Script
                    script: |
                      sudo systemctl stop myapp
                      sudo cp -r /opt/myapp.backup/* /opt/myapp/
                      sudo systemctl start myapp
```

### ECS Blue-Green Deployment
```yaml
pipeline:
  name: ECS Blue-Green Deployment
  identifier: ecs_bluegreen_deploy
  stages:
    - stage:
        name: Deploy to ECS
        identifier: deploy_ecs
        type: Deployment
        spec:
          deploymentType: ECS
          service:
            serviceRef: my_ecs_service
            serviceInputs:
              serviceDefinition:
                type: ECS
                spec:
                  artifacts:
                    primary:
                      primaryArtifactRef: <+input>
                      type: Ecr
          infrastructure:
            environmentRef: production
            infrastructureDefinition:
              type: EcsAws
              spec:
                connectorRef: aws_connector
                cluster: prod-ecs-cluster
                region: us-east-1
          execution:
            steps:
              - step:
                  type: EcsBlueGreenCreateService
                  name: Create Green Service
                  identifier: createGreenService
                  spec:
                    loadBalancer:
                      loadBalancerArn: <+loadBalancerArn>
                      prodListenerArn: <+prodListenerArn>
                      stageListenerArn: <+stageListenerArn>
              - step:
                  type: EcsBlueGreenSwapTargetGroups
                  name: Swap Target Groups
                  identifier: swapTargetGroups
                  spec:
                    doNotDownsizeOldService: false
            rollbackSteps:
              - step:
                  type: EcsBlueGreenRollback
                  name: Rollback
                  identifier: rollback
```

---

## 🔍 Troubleshooting Checklist

### Deployment Failures

| Issue | Check | Solution |
|-------|-------|----------|
| **Delegate offline** | `kubectl get pods -n harness-delegate-ng` | Restart delegate |
| **SSH connection failed** | Test SSH: `ssh -i key.pem user@host` | Verify keys & network |
| **Artifact not found** | Check artifact path/tag | Verify registry connector |
| **Health check failed** | Check app logs: `journalctl -u myapp` | Fix app health endpoint |
| **Timeout** | Check execution timeout setting | Increase timeout value |

### Common Errors & Fixes

```bash
# Error: "No eligible delegates"
# Fix: Check delegate selectors match pipeline configuration

# Error: "Unable to connect to AWS"
# Fix: Verify IAM role attached to delegate

# Error: "SSH authentication failed"
# Fix: Verify SSH key uploaded to Harness and has correct permissions

# Error: "ECR authentication failed"
# Fix: Ensure delegate IAM role has ECR pull permissions

# Error: "Task definition registration failed"
# Fix: Check ECS task definition CPU/memory limits
```

---

## ⚙️ Environment Variables

### Service Variables
```yaml
variables:
  - name: APP_ENV
    type: String
    value: production
  - name: DATABASE_URL
    type: Secret
    value: <+secrets.getValue("db_url_prod")>
  - name: API_KEY
    type: Secret
    value: <+secrets.getValue("api_key")>
```

### Runtime Inputs
```yaml
# Use in pipeline
<+input>                           # Request input at runtime
<+input>.default(value)            # Input with default
<+input>.allowedValues(v1,v2,v3)   # Input with allowed values
```

### Built-in Expressions
```yaml
<+pipeline.name>                   # Pipeline name
<+pipeline.executionId>            # Unique execution ID
<+stage.name>                      # Current stage name
<+service.name>                    # Service name
<+env.name>                        # Environment name
<+artifact.image>                  # Docker image with tag
<+artifact.tag>                    # Artifact tag
<+secrets.getValue("secret_name")> # Secret value
```

---

## 🔐 Security Best Practices

### SSH Keys
```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "harness-deploy"

# Add public key to target servers
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Upload private key to Harness as secret
# Path: Secrets > + New Secret > File > Upload private key
```

### AWS IAM Roles

**Delegate IAM Policy (Minimum Required):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeTaskDefinition",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

### Secrets Management
```bash
# Reference AWS Secrets Manager
<+secrets.getValue("aws_secret_name")>

# Reference HashiCorp Vault
<+secrets.getValue("vault://secret/data/myapp#password")>

# Reference Custom Secret Manager
<+secrets.getValue("custom_secret_name")>
```

---

## 📊 Monitoring & Verification

### Health Check Endpoints
```bash
# VM Health Check
curl -f http://localhost:8080/health || exit 1

# ECS Health Check (via ALB)
curl -f https://myapp.example.com/health
```

### Continuous Verification Metrics
```yaml
# CloudWatch Metrics
analysis:
  - metric: CPUUtilization
    threshold: 80
    duration: 5m
  - metric: ErrorRate
    threshold: 5
    duration: 10m

# Prometheus Queries
analysis:
  - query: rate(http_requests_total{status="500"}[5m])
    threshold: 0.01
```

### Log Analysis
```bash
# VM Logs
sudo journalctl -u myapp -f

# ECS Logs (CloudWatch)
aws logs tail /ecs/myapp-prod --follow

# Harness Execution Logs
# Navigate to: Deployments > [Execution] > Logs
```

---

## 🔄 Rollback Procedures

### Manual Rollback
```bash
# VM Rollback
ssh user@host 'sudo systemctl stop myapp && \
               sudo cp -r /opt/myapp.backup/* /opt/myapp/ && \
               sudo systemctl start myapp'

# ECS Rollback (via AWS CLI)
aws ecs update-service --cluster prod-cluster \
  --service myapp-prod \
  --task-definition myapp-prod:123
```

### Automatic Rollback Configuration
```yaml
# In pipeline execution strategy
failureStrategies:
  - onFailure:
      errors:
        - AllErrors
      action:
        type: StageRollback
```

---

## 📈 Performance Optimization

### Parallel Deployments
```yaml
# Deploy to multiple instances simultaneously
execution:
  steps:
    - parallel:
        - step: # Deploy instance 1
        - step: # Deploy instance 2
        - step: # Deploy instance 3
```

### Conditional Execution
```yaml
# Skip steps based on conditions
step:
  when:
    stageStatus: Success
    condition: <+env.name> == "production"
```

### Caching Artifacts
```bash
# Enable delegate caching
# In delegate YAML, add:
env:
  - name: CACHE_ARTIFACTS
    value: "true"
```

---

## 🎯 Deployment Strategy Cheat Sheet

| Strategy | Use Case | Downtime | Rollback Speed | Risk |
|----------|----------|----------|----------------|------|
| **Rolling** | Standard updates | Minimal | Medium (5-10 min) | Medium |
| **Blue-Green** | Zero-downtime required | None | Instant (<1 min) | Low |
| **Canary** | High-risk changes | None | Fast (2-3 min) | Very Low |
| **Recreate** | Dev/Test only | Full | N/A | High |

### When to Use Each Strategy

**Rolling**:
- ✅ Standard production updates
- ✅ Stateless applications
- ✅ Cost-sensitive deployments

**Blue-Green**:
- ✅ Critical production services
- ✅ Database migrations
- ✅ Major version upgrades

**Canary**:
- ✅ New features with unknown impact
- ✅ Performance-sensitive changes
- ✅ A/B testing scenarios

---

## 🛠️ Common Tasks

### Update Service Configuration
```bash
# 1. Update service definition in Harness UI
# 2. Or update via API:
curl -X PUT 'https://app.harness.io/gateway/ng/api/servicesV2/{serviceId}' \
  -H 'x-api-key: <your-api-key>' \
  -H 'Content-Type: application/json' \
  -d @service.json
```

### Add New Infrastructure
```yaml
# Create infrastructure definition
infrastructureDefinition:
  name: New Environment
  identifier: new_env
  type: SshWinRmAws
  spec:
    credentialsRef: ssh_key
    region: us-west-2
    hosts:
      - newhost1.example.com
      - newhost2.example.com
```

### Configure Notifications
```yaml
# Add notification rules
notificationRules:
  - name: Deployment Failed
    enabled: true
    pipelineEvents:
      - type: PipelineFailed
    notificationMethod:
      type: Slack
      spec:
        webhookUrl: <+secrets.getValue("slack_webhook")>
```

---

## 📞 Quick Links

| Resource | URL |
|----------|-----|
| **Harness Platform** | https://app.harness.io |
| **Documentation** | https://developer.harness.io |
| **University** | https://university.harness.io |
| **Community** | https://community.harness.io |
| **Support** | support@harness.io |
| **Status Page** | https://status.harness.io |

---

## 🆘 Emergency Contacts

| Issue | Contact | Response Time |
|-------|---------|---------------|
| **Critical Production Issue** | support@harness.io | 1 hour |
| **Deployment Failure** | DevOps Team Lead | 15 minutes |
| **Security Incident** | Security Team | Immediate |
| **Platform Outage** | Harness Support | 30 minutes |

---

## ✅ Pre-Deployment Checklist

- [ ] Delegate is healthy and connected
- [ ] Artifact is available and verified
- [ ] Infrastructure targets are reachable
- [ ] Secrets are configured correctly
- [ ] Rollback strategy is defined
- [ ] Monitoring is enabled
- [ ] Notification rules are set
- [ ] Change approval obtained (if required)
- [ ] Backup completed (for VMs)
- [ ] Off-peak deployment time (for critical systems)

---

## 🔖 Keyboard Shortcuts (Harness UI)

| Action | Shortcut |
|--------|----------|
| Search | `Ctrl/Cmd + K` |
| New Pipeline | `Ctrl/Cmd + N` |
| Save | `Ctrl/Cmd + S` |
| Run Pipeline | `Ctrl/Cmd + Enter` |
| View Logs | `Ctrl/Cmd + L` |

---

**Version**: 1.0 | **Updated**: January 10, 2026 | **Format**: Print-friendly
**Quick Help**: For detailed information, refer to HARNESS_CD_ARCHITECTURE_GUIDE.md

---

**END OF QUICK REFERENCE GUIDE**
