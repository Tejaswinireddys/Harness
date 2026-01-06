# Harness CD (Continuous Delivery/Deployment) Setup Guide

## What is Harness CD?

Harness CD is a modern Continuous Delivery and Deployment platform that automates the deployment of applications to various environments (dev, staging, production) with advanced deployment strategies, automated verification, and rollback capabilities.

## Key Features of Harness CD

### 1. **Advanced Deployment Strategies**
- **Blue-Green Deployments**: Zero-downtime deployments with instant rollback
- **Canary Deployments**: Gradual rollout with automatic verification
- **Rolling Deployments**: Incremental updates with health checks
- **Multi-Service Deployments**: Coordinate deployments across multiple services

### 2. **Continuous Verification**
- **AI-Powered Monitoring**: Automatically detects anomalies post-deployment
- **Auto-Rollback**: Intelligent rollback when issues are detected
- **Health Checks**: Custom health checks and verification steps
- **Integration**: Works with APM tools (New Relic, Datadog, Prometheus, etc.)

### 3. **Multi-Cloud & Multi-Platform Support**
- **Kubernetes**: Native K8s support (GKE, EKS, AKS, on-prem)
- **Docker**: Container-based deployments
- **Cloud Providers**: AWS, Azure, GCP, PCF
- **Serverless**: Lambda, Cloud Functions
- **Traditional**: VM-based deployments

### 4. **Infrastructure as Code**
- **Terraform Integration**: Deploy infrastructure alongside applications
- **CloudFormation**: AWS CloudFormation support
- **ARM Templates**: Azure Resource Manager templates
- **Helm Charts**: Kubernetes Helm support

### 5. **Security & Compliance**
- **Policy as Code**: Open Policy Agent (OPA) integration
- **Secrets Management**: Built-in secrets management
- **RBAC**: Role-based access control
- **Audit Trails**: Complete deployment audit logs
- **Approval Workflows**: Manual approval gates

## How Harness CD Works

### Deployment Pipeline Flow

```
1. Trigger Deployment
   ↓
2. Pre-Deployment Steps
   - Environment validation
   - Secrets verification
   - Infrastructure checks
   ↓
3. Deploy Application
   - Execute deployment strategy
   - Monitor deployment progress
   ↓
4. Post-Deployment Verification
   - Health checks
   - Smoke tests
   - Performance monitoring
   ↓
5. Continuous Verification
   - Monitor metrics
   - Detect anomalies
   - Auto-rollback if needed
   ↓
6. Success/Notification
```

## Prerequisites for Using Harness CD

1. **Harness Account**: Sign up at https://app.harness.io
2. **Target Infrastructure**: Kubernetes cluster, cloud account, or VMs
3. **Application Artifacts**: Docker images, Helm charts, or deployment packages
4. **Connectors**: Set up connectors for your infrastructure

## Setting Up Harness CD

### Step 1: Create Environment

Environments represent your deployment targets:
- **Production**
- **Staging**
- **Development**
- **QA**

### Step 2: Create Service

Services represent your application:
- Define service configuration
- Specify artifact source (Docker registry, Artifactory, etc.)
- Configure manifests (Kubernetes, Helm, etc.)

### Step 3: Create Infrastructure Definition

Define where to deploy:
- **Kubernetes**: Cluster and namespace
- **AWS**: ECS, EC2, Lambda
- **Azure**: AKS, App Service
- **GCP**: GKE, Cloud Run

### Step 4: Create Deployment Pipeline

Define deployment stages:
- **Deploy Stage**: Execute deployment
- **Verify Stage**: Run verification steps
- **Approval Stage**: Manual approval gates
- **Rollback Stage**: Automatic rollback logic

## Example CD Pipeline Configurations

### Kubernetes Deployment Example

```yaml
pipeline:
  name: Kubernetes CD Pipeline
  identifier: k8s_cd_pipeline
  projectIdentifier: default_project
  orgIdentifier: default
  stages:
    - stage:
        name: Deploy to Staging
        identifier: Deploy_to_Staging
        type: Deployment
        spec:
          serviceConfig:
            serviceRef: my-service
            serviceDefinition:
              type: Kubernetes
              spec:
                artifacts:
                  primary:
                    type: DockerRegistry
                    spec:
                      connectorRef: docker-connector
                      imagePath: myapp
                      tag: <+pipeline.sequenceId>
                manifests:
                  - manifest:
                      identifier: k8s-manifest
                      type: K8sManifest
                      spec:
                        store:
                          type: Github
                          spec:
                            connectorRef: github-connector
                            gitFetchType: Branch
                            paths:
                              - k8s/manifests/
                            repoName: my-repo
                            branch: main
          infrastructure:
            environmentRef: staging
            infrastructureDefinition:
              type: KubernetesDirect
              spec:
                connectorRef: k8s-connector
                namespace: staging
                releaseName: release-<+INFRA_KEY>
          execution:
            steps:
              - step:
                  type: K8sRollingDeploy
                  name: Rolling Deployment
                  identifier: Rolling_Deployment
                  spec:
                    skipDryRun: false
              - step:
                  type: K8sBlueGreenDeploy
                  name: Blue Green Deployment
                  identifier: Blue_Green_Deployment
                  spec:
                    skipDryRun: false
            rollbackSteps:
              - step:
                  type: K8sRollingRollback
                  name: Rolling Rollback
                  identifier: Rolling_Rollback
```

### Blue-Green Deployment Example

```yaml
execution:
  steps:
    - step:
        type: K8sBlueGreenDeploy
        name: Blue Green Deploy
        identifier: Blue_Green_Deploy
        spec:
          skipDryRun: false
          pruningEnabled: false
    - step:
        type: Verify
        name: Verify Deployment
        identifier: Verify_Deployment
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
    - step:
        type: K8sBlueGreenSwapServices
        name: Swap Services
        identifier: Swap_Services
        spec:
          skipDryRun: false
```

### Canary Deployment Example

```yaml
execution:
  steps:
    - step:
        type: K8sCanaryDeploy
        name: Canary Deploy
        identifier: Canary_Deploy
        spec:
          instanceSelection:
            type: Count
            spec:
              count: 1
          skipDryRun: false
    - step:
        type: Verify
        name: Verify Canary
        identifier: Verify_Canary
        spec:
          type: Datadog
          spec:
            connectorRef: datadog-connector
            metricName: request.error_rate
            baseline: <+serviceConfig.artifacts.primary.tag>
            canary: <+serviceConfig.artifacts.primary.tag>
            query: avg:request.error_rate{*}
            threshold:
              type: Percentage
              spec:
                value: 5
    - step:
        type: K8sCanaryDelete
        name: Delete Canary
        identifier: Delete_Canary
        spec:
          skipDryRun: false
    - step:
        type: K8sRollingDeploy
        name: Full Deployment
        identifier: Full_Deployment
        spec:
          skipDryRun: false
```

## Continuous Verification Setup

### Prometheus Integration

```yaml
- step:
    type: Verify
    name: Prometheus Verification
    identifier: Prometheus_Verification
    spec:
      type: Prometheus
      spec:
        connectorRef: prometheus-connector
        metricName: error_rate
        baseline: <+serviceConfig.artifacts.primary.tag>
        canary: <+serviceConfig.artifacts.primary.tag>
        query: sum(rate(http_requests_total{status=~"5.."}[5m]))
        threshold:
          type: Absolute
          spec:
            value: 10
```

### Datadog Integration

```yaml
- step:
    type: Verify
    name: Datadog Verification
    identifier: Datadog_Verification
    spec:
      type: Datadog
      spec:
        connectorRef: datadog-connector
        metricName: request.error_rate
        baseline: <+serviceConfig.artifacts.primary.tag>
        canary: <+serviceConfig.artifacts.primary.tag>
        query: avg:request.error_rate{*}
        threshold:
          type: Percentage
          spec:
            value: 5
```

## Deployment Strategies Comparison

| Strategy | Use Case | Downtime | Rollback Speed | Risk Level |
|----------|----------|----------|----------------|------------|
| **Blue-Green** | Production, zero-downtime | None | Instant | Low |
| **Canary** | Gradual rollout, testing | None | Fast | Very Low |
| **Rolling** | Standard deployments | Minimal | Medium | Medium |
| **Recreate** | Non-critical apps | Yes | Fast | High |

## Benefits of Harness CD

### 1. **Reduced Deployment Risk**
- Automated verification reduces production incidents
- Instant rollback capabilities
- Canary deployments minimize blast radius

### 2. **Faster Time to Market**
- Automated deployment pipelines
- Parallel deployments across environments
- Reduced manual intervention

### 3. **Better Visibility**
- Real-time deployment dashboards
- Complete audit trails
- Deployment analytics

### 4. **Cost Efficiency**
- Reduced downtime costs
- Fewer production incidents
- Optimized resource usage

### 5. **Compliance & Security**
- Policy as Code enforcement
- Automated compliance checks
- Secure secrets management

## Getting Started Checklist

- [ ] Create Harness account
- [ ] Set up infrastructure connectors (K8s, Cloud, etc.)
- [ ] Create environments (dev, staging, prod)
- [ ] Create services for your applications
- [ ] Define infrastructure definitions
- [ ] Create deployment pipelines
- [ ] Configure verification steps
- [ ] Set up approval workflows
- [ ] Test deployment pipeline
- [ ] Enable continuous verification

## Resources

- Harness CD Documentation: https://developer.harness.io/docs/continuous-delivery
- Deployment Strategies Guide: https://developer.harness.io/docs/continuous-delivery/manage-deployments/deployment-concepts
- Continuous Verification: https://developer.harness.io/docs/continuous-delivery/verify/verify-deployments-with-the-verify-step

