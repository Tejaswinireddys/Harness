# Harness CD Architecture Documentation - Confluence Pages

> **Instructions:** Copy each architecture section below and paste into separate Confluence pages. Replace ASCII diagrams with proper Confluence diagrams using draw.io or Gliffy.

---

# ARCHITECTURE 1: CD High-Level Architecture

## Overview

This document provides a comprehensive high-level architecture view of Harness Continuous Delivery (CD) platform, including key components, integrations, and data flow.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         HARNESS CD HIGH-LEVEL ARCHITECTURE                      │
└─────────────────────────────────────────────────────────────────────────────────┘

                                  ┌─────────────────────┐
                                  │   Harness SaaS      │
                                  │   Control Plane     │
                                  │                     │
                                  │  - Pipeline Engine  │
                                  │  - UI/API           │
                                  │  - RBAC/Auth        │
                                  │  - Secrets Mgmt     │
                                  │  - Audit Logs       │
                                  └──────────┬──────────┘
                                             │
                                             │ HTTPS/WSS
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    │                        │                        │
                    │                        │                        │
         ┌──────────▼──────────┐  ┌─────────▼────────┐  ┌───────────▼──────────┐
         │   Harness Delegate  │  │  Harness Delegate│  │  Harness Delegate    │
         │   (Dev/QA)          │  │  (Staging)       │  │  (Production)        │
         │                     │  │                  │  │                      │
         │  - Executes tasks   │  │  - Executes tasks│  │  - Executes tasks    │
         │  - Secure agent     │  │  - Secure agent  │  │  - Secure agent      │
         └──────────┬──────────┘  └─────────┬────────┘  └───────────┬──────────┘
                    │                        │                        │
                    │                        │                        │
    ┌───────────────┼────────────┬───────────┼───────────┬───────────┼───────────┐
    │               │            │           │           │           │           │
    │               │            │           │           │           │           │
┌───▼────┐    ┌────▼─────┐  ┌──▼────┐  ┌───▼────┐  ┌──▼────┐  ┌───▼────┐  ┌──▼────┐
│  Git   │    │ Artifact │  │Cloud  │  │Infra   │  │Monitor│  │Secrets │  │Notif  │
│Repos   │    │Registry  │  │APIs   │  │Target  │  │Tools  │  │Vault   │  │Tools  │
│        │    │          │  │       │  │        │  │       │  │        │  │       │
│GitHub  │    │Docker    │  │AWS    │  │K8s     │  │Prom   │  │Vault   │  │Slack  │
│GitLab  │    │ECR       │  │Azure  │  │ECS     │  │Datadog│  │AWS SM  │  │Email  │
│BitBucket│   │Artifactory│ │GCP    │  │VMs     │  │NewRelic│ │Azure KV│  │Jira   │
└────────┘    └──────────┘  └───────┘  └────────┘  └───────┘  └────────┘  └───────┘

         EXTERNAL INTEGRATIONS          DEPLOYMENT TARGETS        OBSERVABILITY
```

---

## Key Components

### 1. Harness SaaS Control Plane

**Purpose:** Central management and orchestration platform

**Key Features:**
* **Pipeline Engine** - Orchestrates deployment workflows
* **UI/API** - User interface and REST API access
* **RBAC/Authentication** - Role-based access control and SSO
* **Secrets Management** - Secure credential storage
* **Audit Logs** - Complete audit trail of all activities
* **Policy Engine** - OPA-based policy enforcement
* **Analytics Dashboard** - Deployment metrics and insights

**Characteristics:**
* Fully managed SaaS platform
* High availability and scalability
* Multi-tenant architecture
* Global CDN for UI delivery
* API-first design

---

### 2. Harness Delegates

**Purpose:** Secure execution agents that run in your infrastructure

**Key Features:**
* **Task Execution** - Executes deployment tasks
* **Secure Communication** - Outbound-only HTTPS/WSS to control plane
* **Multi-Environment Support** - Deploy across multiple environments
* **Plugin Support** - Extensible with custom scripts
* **Auto-Upgrade** - Automatic version updates

**Deployment Models:**
* **Kubernetes Delegate** - Runs as Kubernetes deployment
* **Docker Delegate** - Runs as Docker container
* **Shell Delegate** - Runs as system service

**Best Practices:**
* Deploy delegates per environment (Dev, QA, Staging, Production)
* Use high availability configuration (2+ replicas)
* Place delegates close to deployment targets
* Implement network segmentation for security

---

### 3. External Integrations

#### Git Repositories
* **Purpose:** Source control for configurations and manifests
* **Supported:** GitHub, GitLab, Bitbucket, Azure Repos
* **Integration:** OAuth, SSH Keys, Personal Access Tokens
* **Use Cases:**
  - Pipeline configurations
  - Kubernetes manifests
  - Helm charts
  - Configuration files

#### Artifact Registries
* **Purpose:** Store and retrieve deployment artifacts
* **Supported:** Docker Hub, ECR, ACR, GCR, Artifactory, Nexus
* **Integration:** API keys, service accounts
* **Use Cases:**
  - Docker images
  - Helm charts
  - JAR/WAR files
  - Binary artifacts

#### Cloud Providers
* **Purpose:** Deploy to cloud infrastructure
* **Supported:** AWS, Azure, GCP, OpenStack
* **Integration:** IAM roles, service principals, API keys
* **Use Cases:**
  - Infrastructure provisioning
  - Resource management
  - Cloud-native services

#### Monitoring & Observability
* **Purpose:** Continuous verification and health monitoring
* **Supported:** Prometheus, Datadog, New Relic, CloudWatch, Splunk
* **Integration:** API keys, webhooks
* **Use Cases:**
  - Health verification
  - Performance monitoring
  - Anomaly detection
  - Automated rollback triggers

#### Secrets Management
* **Purpose:** Secure credential management
* **Supported:** HashiCorp Vault, AWS Secrets Manager, Azure Key Vault
* **Integration:** API tokens, service accounts
* **Use Cases:**
  - Database credentials
  - API keys
  - Certificates
  - SSH keys

#### Notification Tools
* **Purpose:** Deployment notifications and alerts
* **Supported:** Slack, Microsoft Teams, Email, Jira, PagerDuty
* **Integration:** Webhooks, API keys
* **Use Cases:**
  - Deployment notifications
  - Approval requests
  - Failure alerts
  - Status updates

---

### 4. Deployment Targets

#### Kubernetes (K8s)
* **Deployment Types:** Rolling, Blue-Green, Canary
* **Manifest Types:** Kubernetes YAML, Helm Charts, Kustomize
* **Access:** Kubeconfig, Service Account

#### Amazon ECS
* **Deployment Types:** Rolling, Blue-Green, Canary
* **Task Definitions:** ECS task definitions, service definitions
* **Access:** IAM roles, AWS credentials

#### Virtual Machines (VMs)
* **Deployment Types:** Rolling, Blue-Green, Canary
* **Protocols:** SSH, WinRM
* **Access:** SSH keys, passwords, certificates

#### Serverless
* **Platforms:** AWS Lambda, Azure Functions, Google Cloud Functions
* **Deployment:** Function code and configurations

---

## Data Flow

### Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           DEPLOYMENT DATA FLOW                          │
└─────────────────────────────────────────────────────────────────────────┘

1. USER INITIATES DEPLOYMENT
   │
   ├─► User triggers pipeline via UI/API/Webhook
   │
   ▼
2. HARNESS CONTROL PLANE
   │
   ├─► Validates permissions (RBAC)
   ├─► Retrieves pipeline configuration
   ├─► Resolves secrets and variables
   ├─► Creates execution plan
   │
   ▼
3. DELEGATE RECEIVES TASKS
   │
   ├─► Delegate polls for tasks via HTTPS
   ├─► Receives task payload
   ├─► Validates task signature
   │
   ▼
4. DELEGATE EXECUTES TASKS
   │
   ├─► Fetches artifacts from registry
   ├─► Retrieves manifests from Git
   ├─► Resolves configuration templates
   ├─► Executes deployment commands
   │
   ▼
5. DEPLOYMENT TO TARGET
   │
   ├─► Connects to deployment target (K8s/ECS/VM)
   ├─► Applies configurations/manifests
   ├─► Monitors deployment progress
   │
   ▼
6. VERIFICATION
   │
   ├─► Queries monitoring tools
   ├─► Analyzes metrics and logs
   ├─► AI-powered anomaly detection
   ├─► Health checks
   │
   ▼
7. RESULT REPORTING
   │
   ├─► Sends status updates to control plane
   ├─► Updates execution logs
   ├─► Triggers notifications
   ├─► Updates audit logs
   │
   ▼
8. COMPLETION/ROLLBACK
   │
   ├─► Mark deployment as successful
   └─► OR trigger automated rollback if failures detected
```

---

## Security Architecture

### Security Layers

| Layer | Components | Security Features |
|-------|------------|-------------------|
| **Authentication** | Users, Service Accounts | SSO (SAML, OAuth), MFA, API Keys |
| **Authorization** | RBAC, Policies | Role-based permissions, OPA policies |
| **Communication** | Delegate ↔ Control Plane | TLS 1.2+, Outbound-only, Certificate pinning |
| **Secrets** | Credentials, Keys | Encrypted at rest, Encrypted in transit, External vault integration |
| **Audit** | All operations | Complete audit trail, Immutable logs |
| **Network** | Delegate placement | Private networks, No inbound connections required |

### Security Best Practices

1. **Delegate Security**
   * Deploy delegates in private subnets
   * Use service accounts with minimal permissions
   * Enable delegate token rotation
   * Implement network segmentation

2. **Secrets Management**
   * Never hardcode secrets in pipelines
   * Use external secret managers (Vault, AWS Secrets Manager)
   * Rotate secrets regularly
   * Audit secret access

3. **Access Control**
   * Implement least privilege principle
   * Use SSO for user authentication
   * Require MFA for production access
   * Regular access reviews

4. **Compliance**
   * Enable audit logging
   * Implement policy as code
   * Regular compliance scans
   * Document security procedures

---

## High Availability & Scalability

### Control Plane HA
* **Multi-region deployment** - Global availability
* **Auto-scaling** - Handles variable load
* **Load balancing** - Distributes traffic
* **Data replication** - Cross-region replication
* **Disaster recovery** - Automated failover

### Delegate HA
* **Multiple replicas** - Minimum 2 delegates per environment
* **Auto-healing** - Automatic restart on failure
* **Load distribution** - Task distribution across delegates
* **Upgrade strategy** - Rolling upgrades with zero downtime

### Scalability Considerations
* **Horizontal scaling** - Add more delegates as needed
* **Parallel execution** - Multiple deployments simultaneously
* **Queue management** - Task queuing and prioritization
* **Resource optimization** - Efficient resource utilization

---

## Network Architecture

### Network Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      NETWORK ARCHITECTURE                        │
└─────────────────────────────────────────────────────────────────┘

INTERNET
    │
    │ HTTPS (443)
    │
    ▼
┌──────────────────────┐
│  Harness SaaS        │
│  (Control Plane)     │
│                      │
│  app.harness.io      │
└──────────┬───────────┘
           │
           │ Outbound HTTPS/WSS
           │ (Initiated by Delegate)
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    YOUR INFRASTRUCTURE                           │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              DMZ / Public Subnet                        │    │
│  │                                                         │    │
│  │  ┌──────────────┐        ┌──────────────┐            │    │
│  │  │  NAT Gateway │        │  Load Balancer│            │    │
│  │  └──────────────┘        └──────────────┘            │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                  │
│  ┌───────────────────────────┼────────────────────────────┐   │
│  │           Private Subnet  │                             │   │
│  │                           │                             │   │
│  │  ┌────────────────────────▼───────────────────┐        │   │
│  │  │       Harness Delegate                      │        │   │
│  │  │  - Outbound only communication              │        │   │
│  │  │  - No inbound ports required                │        │   │
│  │  └────────────┬────────────────────────────────┘        │   │
│  │               │                                          │   │
│  │               │ Internal Network                         │   │
│  │               │                                          │   │
│  │  ┌────────────▼────────────────────────────────────┐   │   │
│  │  │  Deployment Targets                             │   │   │
│  │  │  - Kubernetes Clusters                          │   │   │
│  │  │  - ECS Clusters                                 │   │   │
│  │  │  - VM Instances                                 │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Network Requirements

**Outbound Connectivity (Delegate → Harness):**
* **Destination:** `app.harness.io` (or your specific subdomain)
* **Ports:** 443 (HTTPS), 9879 (WebSocket)
* **Protocol:** HTTPS/WSS
* **Direction:** Outbound only

**No Inbound Requirements:**
* Delegates initiate all connections
* No firewall rules needed for inbound traffic
* Secure by design

**Internal Connectivity (Delegate → Targets):**
* Kubernetes: Port 443 (API server)
* ECS: AWS API endpoints
* VMs: Port 22 (SSH) or 5985/5986 (WinRM)

---

## Integration Patterns

### Pattern 1: GitOps Workflow

```
Git Repository (Source of Truth)
        │
        ├─► Pipeline configurations
        ├─► Kubernetes manifests
        ├─► Helm charts
        │
        ▼
Harness Pipeline (Triggered by Git webhook)
        │
        ▼
Deployment to Kubernetes
```

### Pattern 2: CI/CD Integration

```
CI Tool (Jenkins/GitHub Actions/GitLab CI)
        │
        ├─► Build application
        ├─► Run tests
        ├─► Push artifact to registry
        │
        ▼
Trigger Harness Pipeline (Webhook/API)
        │
        ▼
Harness CD Deployment
```

### Pattern 3: Multi-Cloud Deployment

```
Harness Pipeline
        │
        ├─► Deploy to AWS (ECS)
        ├─► Deploy to Azure (AKS)
        └─► Deploy to GCP (GKE)
```

---

## Monitoring & Observability

### Metrics Collection

| Metric Type | Source | Purpose |
|-------------|--------|---------|
| Deployment Metrics | Harness Platform | Success rate, duration, frequency |
| Application Metrics | Prometheus/Datadog | Performance, errors, latency |
| Infrastructure Metrics | Cloud providers | Resource utilization, costs |
| Business Metrics | Custom APIs | User engagement, revenue impact |

### Continuous Verification

```
Deploy New Version
        │
        ▼
Monitor Metrics (5-15 min)
        │
        ├─► Compare with baseline
        ├─► AI-powered anomaly detection
        ├─► Error rate analysis
        ├─► Performance analysis
        │
        ▼
Decision Point
        │
        ├─► ✅ Metrics normal → Continue
        └─► ❌ Anomaly detected → Rollback
```

---

## Summary

### Key Architectural Principles

1. **Security First** - All communication encrypted, secrets managed securely
2. **Scalability** - Horizontal scaling of delegates and control plane
3. **High Availability** - Redundancy at every level
4. **Zero Trust** - No inbound connectivity required for delegates
5. **Extensibility** - Plugin architecture for custom integrations
6. **Observability** - Comprehensive monitoring and audit logging

### Benefits

* ✅ **Reduced Deployment Time** - 70% faster deployments
* ✅ **Increased Reliability** - 40-60% fewer production incidents
* ✅ **Enhanced Security** - Zero inbound connectivity, encrypted secrets
* ✅ **Better Visibility** - Complete audit trail and analytics
* ✅ **Multi-Cloud Support** - Deploy anywhere
* ✅ **Automated Rollback** - AI-powered failure detection

---

# ARCHITECTURE 2: VM Deployment Architecture

## Overview

This document details the architecture for deploying applications to Virtual Machines (VMs) using Harness CD, including SSH-based deployments, deployment strategies, and best practices.

---

## VM Deployment Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         VM DEPLOYMENT ARCHITECTURE                               │
└─────────────────────────────────────────────────────────────────────────────────┘

                            ┌─────────────────────┐
                            │  Harness Platform   │
                            │  - Pipeline Engine  │
                            │  - UI/API           │
                            └──────────┬──────────┘
                                       │
                                       │ HTTPS/WSS
                                       │
                            ┌──────────▼──────────┐
                            │  Harness Delegate   │
                            │                     │
                            │  - Task Executor    │
                            │  - SSH Client       │
                            │  - Script Engine    │
                            └──────────┬──────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
           ┌────────▼────────┐  ┌─────▼──────┐  ┌───────▼────────┐
           │  Artifact Repo  │  │ Git Repo   │  │ Secrets Vault  │
           │                 │  │            │  │                │
           │  - Docker Reg   │  │ - Scripts  │  │ - SSH Keys     │
           │  - Artifactory  │  │ - Configs  │  │ - Credentials  │
           └─────────────────┘  └────────────┘  └────────────────┘
                                       │
                                       │ SSH (Port 22)
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        │                              │                              │
        │          VM INFRASTRUCTURE (Target Servers)                 │
        │                                                             │
        │  ┌───────────────────────────────────────────────────────┐ │
        │  │                    Load Balancer                       │ │
        │  │  - Route traffic to healthy instances                 │ │
        │  │  - Health checks                                       │ │
        │  └─────────┬─────────────────────────┬───────────────────┘ │
        │            │                         │                      │
        │  ┌─────────▼─────────┐     ┌────────▼──────────┐          │
        │  │   VM Group 1      │     │   VM Group 2      │          │
        │  │   (e.g., Web)     │     │   (e.g., API)     │          │
        │  │                   │     │                   │          │
        │  │ ┌───────────────┐ │     │ ┌───────────────┐ │          │
        │  │ │   VM-1        │ │     │ │   VM-3        │ │          │
        │  │ │ - App v1.0    │ │     │ │ - App v1.0    │ │          │
        │  │ │ - Supervisor  │ │     │ │ - Systemd     │ │          │
        │  │ └───────────────┘ │     │ └───────────────┘ │          │
        │  │ ┌───────────────┐ │     │ ┌───────────────┐ │          │
        │  │ │   VM-2        │ │     │ │   VM-4        │ │          │
        │  │ │ - App v1.0    │ │     │ │ - App v1.0    │ │          │
        │  │ │ - Supervisor  │ │     │ │ - Systemd     │ │          │
        │  │ └───────────────┘ │     │ └───────────────┘ │          │
        │  └───────────────────┘     └───────────────────┘          │
        │                                                             │
        │  ┌──────────────────────────────────────────────────────┐ │
        │  │  Monitoring & Logging                                 │ │
        │  │  - Prometheus/Datadog (Metrics)                       │ │
        │  │  - ELK Stack (Logs)                                   │ │
        │  │  - Health check endpoints                             │ │
        │  └──────────────────────────────────────────────────────┘ │
        └─────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Harness Delegate
**Purpose:** Execute deployment tasks on VMs via SSH

**Capabilities:**
* SSH connection management
* File transfer (SCP/SFTP)
* Script execution
* Process management
* Health check validation

**Requirements:**
* Network connectivity to target VMs
* SSH client installed
* Access to SSH keys/credentials

---

### 2. Target VM Infrastructure

#### VM Groups
* **Logical grouping** of VMs by function (Web, API, Database, etc.)
* **Tagging** for easy identification
* **Configuration management** for consistent setup

#### VM Requirements
* **Operating System:** Linux (Ubuntu, RHEL, CentOS) or Windows
* **SSH Access:** Port 22 open from Delegate
* **User Account:** Dedicated deployment user with sudo privileges
* **Directory Structure:** Standardized application directories
* **Process Manager:** Systemd, Supervisor, or PM2

---

### 3. Deployment Artifacts

#### Artifact Types
* **Binary packages:** JAR, WAR, EXE
* **Archives:** TAR.GZ, ZIP
* **Scripts:** Shell scripts, PowerShell
* **Configuration files:** Properties, YAML, JSON
* **Docker images:** For containerized apps on VMs

#### Artifact Storage
* Artifactory, Nexus
* AWS S3, Azure Blob Storage
* Docker Registry (for container deployments)

---

## Deployment Strategies for VMs

### 1. Rolling Deployment

```
┌─────────────────────────────────────────────────────────────────┐
│                     ROLLING DEPLOYMENT                           │
└─────────────────────────────────────────────────────────────────┘

Load Balancer: [VM-1] [VM-2] [VM-3] [VM-4]
                v1.0   v1.0   v1.0   v1.0

Step 1: Deploy to VM-1
        [VM-1] [VM-2] [VM-3] [VM-4]
         v2.0   v1.0   v1.0   v1.0
         (Deploy, verify, add to LB)

Step 2: Deploy to VM-2
        [VM-1] [VM-2] [VM-3] [VM-4]
         v2.0   v2.0   v1.0   v1.0

Step 3: Deploy to VM-3
        [VM-1] [VM-2] [VM-3] [VM-4]
         v2.0   v2.0   v2.0   v1.0

Step 4: Deploy to VM-4
        [VM-1] [VM-2] [VM-3] [VM-4]
         v2.0   v2.0   v2.0   v2.0
         (Deployment Complete)

Characteristics:
- Gradual rollout
- Instances updated one at a time (or in small batches)
- Mixed version state during deployment
- Minimal additional infrastructure needed
```

**Deployment Steps:**
1. Remove VM from load balancer
2. Stop application service
3. Backup current version
4. Deploy new artifact
5. Update configuration
6. Start application service
7. Health check validation
8. Add VM back to load balancer
9. Repeat for next VM

---

### 2. Blue-Green Deployment

```
┌─────────────────────────────────────────────────────────────────┐
│                    BLUE-GREEN DEPLOYMENT                         │
└─────────────────────────────────────────────────────────────────┘

Initial State:
Load Balancer → BLUE Environment (v1.0)
                [VM-1] [VM-2] [VM-3] [VM-4]

                GREEN Environment (Idle)
                [VM-5] [VM-6] [VM-7] [VM-8]

Step 1: Deploy to GREEN
                BLUE Environment (v1.0)
                [VM-1] [VM-2] [VM-3] [VM-4]
                (Still serving traffic)

                GREEN Environment (v2.0)
                [VM-5] [VM-6] [VM-7] [VM-8]
                (Deploy new version, test)

Step 2: Switch Traffic
Load Balancer → GREEN Environment (v2.0)
                [VM-5] [VM-6] [VM-7] [VM-8]
                (Now serving traffic)

                BLUE Environment (v1.0)
                [VM-1] [VM-2] [VM-3] [VM-4]
                (Standby for rollback)

Step 3: Rollback (if needed)
Load Balancer → BLUE Environment (v1.0)
                [VM-1] [VM-2] [VM-3] [VM-4]
                (Instant rollback)

Characteristics:
- Zero downtime
- Instant rollback capability
- Full environment testing before switch
- Requires 2x infrastructure
```

---

### 3. Canary Deployment

```
┌─────────────────────────────────────────────────────────────────┐
│                     CANARY DEPLOYMENT                            │
└─────────────────────────────────────────────────────────────────┘

Initial State: All VMs on v1.0
Load Balancer: [VM-1] [VM-2] [VM-3] [VM-4]
                v1.0   v1.0   v1.0   v1.0
                100% traffic

Step 1: Deploy to 25% (Canary)
        [VM-1] [VM-2] [VM-3] [VM-4]
         v2.0   v1.0   v1.0   v1.0
         25%    75% traffic
         ↓
        Monitor metrics (error rate, latency, etc.)

Step 2: Increase to 50%
        [VM-1] [VM-2] [VM-3] [VM-4]
         v2.0   v2.0   v1.0   v1.0
         50%    50% traffic
         ↓
        Continue monitoring

Step 3: Increase to 75%
        [VM-1] [VM-2] [VM-3] [VM-4]
         v2.0   v2.0   v2.0   v1.0
         75%    25% traffic

Step 4: Complete rollout (100%)
        [VM-1] [VM-2] [VM-3] [VM-4]
         v2.0   v2.0   v2.0   v2.0
         100% traffic

Auto-Rollback: If anomalies detected at any stage
        [VM-1] [VM-2] [VM-3] [VM-4]
         v1.0   v1.0   v1.0   v1.0
         (Automatic rollback to v1.0)

Characteristics:
- Gradual traffic shift
- Continuous monitoring
- Risk mitigation
- Automated rollback on anomalies
```

---

## Deployment Workflow

### Standard VM Deployment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    VM DEPLOYMENT WORKFLOW                        │
└─────────────────────────────────────────────────────────────────┘

1. PRE-DEPLOYMENT
   │
   ├─► Fetch artifact from repository
   ├─► Retrieve deployment scripts from Git
   ├─► Resolve configuration variables
   └─► Validate SSH connectivity

2. DEPLOYMENT EXECUTION (Per VM or VM Group)
   │
   ├─► Connect to VM via SSH
   ├─► Remove VM from load balancer
   │   └─► Update LB configuration OR
   │       └─► Call LB API
   │
   ├─► Stop application service
   │   └─► systemctl stop myapp OR
   │       └─► supervisorctl stop myapp
   │
   ├─► Backup current version
   │   └─► mv /opt/app /opt/app.backup.$(date +%s)
   │
   ├─► Transfer new artifact
   │   └─► SCP/SFTP artifact to VM
   │       └─► /tmp/myapp-v2.0.jar
   │
   ├─► Extract/Install artifact
   │   └─► Copy to application directory
   │       └─► cp /tmp/myapp-v2.0.jar /opt/app/app.jar
   │
   ├─► Update configuration files
   │   └─► Replace environment-specific configs
   │       └─► Database URLs, API endpoints, etc.
   │
   ├─► Set permissions
   │   └─► chown -R appuser:appuser /opt/app
   │       └─► chmod +x /opt/app/startup.sh
   │
   ├─► Start application service
   │   └─► systemctl start myapp OR
   │       └─► supervisorctl start myapp
   │
   ├─► Health check validation
   │   └─► Wait for application to start
   │       └─► curl http://localhost:8080/health
   │           └─► Retry with exponential backoff
   │
   ├─► Verify application logs
   │   └─► tail -f /var/log/myapp/app.log
   │       └─► Check for errors
   │
   └─► Add VM back to load balancer
       └─► Update LB configuration
           └─► Verify traffic routing

3. POST-DEPLOYMENT
   │
   ├─► Continuous Verification
   │   └─► Monitor metrics (5-15 minutes)
   │       └─► Error rates, response times, CPU, memory
   │
   ├─► Smoke tests
   │   └─► Execute automated tests
   │       └─► Validate critical functionality
   │
   └─► Update deployment status
       └─► Mark deployment as successful
           └─► OR trigger rollback if failures detected

4. ROLLBACK (If needed)
   │
   ├─► Stop application service
   ├─► Restore backup version
   │   └─► rm -rf /opt/app
   │       └─► mv /opt/app.backup.TIMESTAMP /opt/app
   ├─► Start application service
   └─► Verify health
```

---

## Configuration Management

### Directory Structure

```
/opt/myapp/
├── app/                    # Application binaries
│   ├── app.jar
│   └── lib/
├── config/                 # Configuration files
│   ├── application.yml
│   ├── database.properties
│   └── log4j.properties
├── scripts/                # Deployment scripts
│   ├── start.sh
│   ├── stop.sh
│   └── health-check.sh
├── logs/                   # Application logs
│   ├── app.log
│   └── error.log
└── backups/                # Version backups
    ├── v1.0.backup
    └── v1.1.backup
```

### Configuration Templates

**Template Variables in Harness:**
```yaml
# application.yml
server:
  port: ${PORT}
  host: ${HOST}

database:
  url: ${DB_URL}
  username: ${DB_USERNAME}
  password: ${DB_PASSWORD}

api:
  endpoint: ${API_ENDPOINT}
  timeout: ${API_TIMEOUT}
```

**Environment-Specific Values:**
* Development: `DB_URL=dev-db.internal:5432`
* Staging: `DB_URL=staging-db.internal:5432`
* Production: `DB_URL=prod-db.internal:5432`

---

## SSH Configuration

### SSH Key Management

**Best Practices:**
1. Use SSH keys instead of passwords
2. One key pair per environment
3. Rotate keys regularly
4. Store keys in Harness secrets manager
5. Use jump hosts/bastions for production access

### SSH User Setup

```bash
# Create deployment user
sudo useradd -m -s /bin/bash deployuser

# Add to appropriate groups
sudo usermod -aG sudo deployuser

# Setup SSH key
sudo mkdir -p /home/deployuser/.ssh
sudo vi /home/deployuser/.ssh/authorized_keys
# (Paste public key)

sudo chmod 700 /home/deployuser/.ssh
sudo chmod 600 /home/deployuser/.ssh/authorized_keys
sudo chown -R deployuser:deployuser /home/deployuser/.ssh

# Configure sudo without password (for service management)
sudo visudo
# Add: deployuser ALL=(ALL) NOPASSWD: /bin/systemctl, /usr/bin/supervisorctl
```

---

## Process Management

### Systemd Service (Linux)

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target

[Service]
Type=simple
User=appuser
Group=appuser
WorkingDirectory=/opt/myapp/app
ExecStart=/usr/bin/java -jar /opt/myapp/app/app.jar
ExecStop=/bin/kill -TERM $MAINPID
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Commands:**
```bash
# Reload systemd
sudo systemctl daemon-reload

# Start service
sudo systemctl start myapp

# Stop service
sudo systemctl stop myapp

# Restart service
sudo systemctl restart myapp

# Check status
sudo systemctl status myapp

# Enable on boot
sudo systemctl enable myapp
```

### Supervisor (Process Manager)

```ini
# /etc/supervisor/conf.d/myapp.conf
[program:myapp]
command=/usr/bin/java -jar /opt/myapp/app/app.jar
directory=/opt/myapp/app
user=appuser
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/opt/myapp/logs/app.log
```

**Commands:**
```bash
# Update supervisor config
sudo supervisorctl reread
sudo supervisorctl update

# Start process
sudo supervisorctl start myapp

# Stop process
sudo supervisorctl stop myapp

# Restart process
sudo supervisorctl restart myapp

# Check status
sudo supervisorctl status myapp
```

---

## Health Checks

### Application Health Endpoint

```bash
# Health check script
#!/bin/bash
# /opt/myapp/scripts/health-check.sh

HEALTH_URL="http://localhost:8080/health"
MAX_RETRIES=30
RETRY_INTERVAL=5

for i in $(seq 1 $MAX_RETRIES); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL)

  if [ "$HTTP_CODE" = "200" ]; then
    echo "Health check passed"
    exit 0
  fi

  echo "Attempt $i/$MAX_RETRIES: Health check failed (HTTP $HTTP_CODE). Retrying in ${RETRY_INTERVAL}s..."
  sleep $RETRY_INTERVAL
done

echo "Health check failed after $MAX_RETRIES attempts"
exit 1
```

### Load Balancer Health Checks

**HAProxy Example:**
```
backend myapp_backend
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    server vm1 10.0.1.10:8080 check inter 5s fall 3 rise 2
    server vm2 10.0.1.11:8080 check inter 5s fall 3 rise 2
    server vm3 10.0.1.12:8080 check inter 5s fall 3 rise 2
```

**Nginx Example:**
```nginx
upstream myapp {
    server 10.0.1.10:8080 max_fails=3 fail_timeout=30s;
    server 10.0.1.11:8080 max_fails=3 fail_timeout=30s;
    server 10.0.1.12:8080 max_fails=3 fail_timeout=30s;
}
```

---

## Monitoring & Verification

### Metrics to Monitor

| Metric | Tool | Threshold | Action |
|--------|------|-----------|--------|
| Error Rate | Prometheus/Datadog | >5% | Rollback |
| Response Time (P95) | Prometheus/Datadog | >500ms | Alert |
| CPU Usage | CloudWatch/Datadog | >80% | Scale/Optimize |
| Memory Usage | CloudWatch/Datadog | >85% | Scale/Optimize |
| Disk Usage | CloudWatch/Datadog | >90% | Alert |
| Request Rate | Prometheus | Baseline ±50% | Investigate |

### Continuous Verification Setup

```yaml
# Harness Continuous Verification Config
verification:
  provider: Prometheus
  query: |
    rate(http_requests_total{status=~"5.."}[5m]) /
    rate(http_requests_total[5m]) * 100

  baseline: previous_deployment
  sensitivity: medium
  duration: 10m

  fail_on:
    - error_rate > 5%
    - p95_latency > 500ms
```

---

## Security Best Practices

### 1. SSH Security
* ✅ Use SSH keys, not passwords
* ✅ Disable root login
* ✅ Use jump hosts/bastions for production
* ✅ Implement key rotation policy
* ✅ Use different keys per environment

### 2. Application Security
* ✅ Run applications as non-root user
* ✅ Implement file system permissions
* ✅ Use secrets management for credentials
* ✅ Enable application-level authentication
* ✅ Implement audit logging

### 3. Network Security
* ✅ Use private subnets for application VMs
* ✅ Implement security groups/firewall rules
* ✅ Use VPN for management access
* ✅ Enable intrusion detection
* ✅ Regular security scans

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| SSH Connection Failed | Firewall, key issues | Verify security groups, SSH key permissions |
| Service Won't Start | Port conflict, config error | Check logs, verify configuration |
| Health Check Fails | App not ready, wrong endpoint | Increase timeout, verify health endpoint |
| Deployment Timeout | Slow download, long startup | Increase timeout, optimize startup |
| Permission Denied | Wrong user/permissions | Fix file permissions, sudo configuration |

### Debug Commands

```bash
# Check SSH connectivity
ssh -v deployuser@vm-hostname

# Check service status
sudo systemctl status myapp
sudo journalctl -u myapp -f

# Check application logs
tail -f /opt/myapp/logs/app.log

# Check process
ps aux | grep myapp

# Check ports
netstat -tulpn | grep 8080
sudo lsof -i :8080

# Check disk space
df -h

# Check memory
free -h

# Check system logs
sudo tail -f /var/log/syslog
```

---

## Best Practices Summary

### Deployment
* ✅ Always backup before deploying
* ✅ Use health checks at every step
* ✅ Implement gradual rollouts for production
* ✅ Test rollback procedures regularly
* ✅ Automate deployment scripts

### Configuration
* ✅ Externalize configuration from code
* ✅ Use template variables for environment-specific values
* ✅ Version control all configurations
* ✅ Use consistent directory structure across VMs

### Monitoring
* ✅ Implement comprehensive health checks
* ✅ Monitor application and infrastructure metrics
* ✅ Set up alerts for critical failures
* ✅ Use continuous verification for automated rollback

### Security
* ✅ Use SSH keys, rotate regularly
* ✅ Implement least privilege principle
* ✅ Secure secrets with external vault
* ✅ Regular security audits and patches

---

# ARCHITECTURE 3: ECS Deployment Architecture

## Overview

This document details the architecture for deploying containerized applications to Amazon ECS (Elastic Container Service) using Harness CD, including task definitions, service configurations, and deployment strategies.

---

## ECS Deployment Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         ECS DEPLOYMENT ARCHITECTURE                              │
└─────────────────────────────────────────────────────────────────────────────────┘

                            ┌─────────────────────┐
                            │  Harness Platform   │
                            │  - Pipeline Engine  │
                            │  - UI/API           │
                            └──────────┬──────────┘
                                       │
                                       │ HTTPS/WSS
                                       │
                            ┌──────────▼──────────┐
                            │  Harness Delegate   │
                            │                     │
                            │  - AWS SDK          │
                            │  - ECS API Client   │
                            │  - Task Executor    │
                            └──────────┬──────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
           ┌────────▼────────┐  ┌─────▼──────┐  ┌───────▼────────┐
           │  ECR (Registry) │  │  Git Repo  │  │ AWS Secrets Mgr│
           │                 │  │            │  │                │
           │  - Docker Images│  │ - Task Def │  │ - DB Passwords │
           │  - Image Tags   │  │ - Configs  │  │ - API Keys     │
           └─────────────────┘  └────────────┘  └────────────────┘
                                       │
                                       │ AWS API Calls
                                       │
        ┌──────────────────────────────▼──────────────────────────────┐
        │                       AWS CLOUD                              │
        │                                                              │
        │  ┌──────────────────────────────────────────────────────┐  │
        │  │              Application Load Balancer                │  │
        │  │  - SSL Termination                                    │  │
        │  │  - Target Group Management                            │  │
        │  │  - Health Checks                                      │  │
        │  └────┬─────────────────────────────────┬────────────────┘  │
        │       │                                 │                   │
        │       │                                 │                   │
        │  ┌────▼─────────────────────┐  ┌───────▼────────────────┐  │
        │  │   ECS Cluster (Dev/QA)   │  │ ECS Cluster (Prod)     │  │
        │  │                          │  │                        │  │
        │  │  ┌────────────────────┐  │  │  ┌──────────────────┐ │  │
        │  │  │   ECS Service      │  │  │  │   ECS Service    │ │  │
        │  │  │   (Blue)           │  │  │  │   (Blue)         │ │  │
        │  │  │                    │  │  │  │                  │ │  │
        │  │  │ ┌────────────────┐ │  │  │  │ ┌──────────────┐ │ │  │
        │  │  │ │ ECS Task 1     │ │  │  │  │ │ ECS Task 1   │ │ │  │
        │  │  │ │ ┌────────────┐ │ │  │  │  │ │ ┌──────────┐ │ │ │  │
        │  │  │ │ │ Container  │ │ │  │  │  │ │ │Container │ │ │ │  │
        │  │  │ │ │ App v2.0   │ │ │  │  │  │ │ │App v2.0  │ │ │ │  │
        │  │  │ │ └────────────┘ │ │  │  │  │ │ └──────────┘ │ │ │  │
        │  │  │ └────────────────┘ │  │  │  │ └──────────────┘ │ │  │
        │  │  │ ┌────────────────┐ │  │  │  │ ┌──────────────┐ │ │  │
        │  │  │ │ ECS Task 2     │ │  │  │  │ │ ECS Task 2   │ │ │  │
        │  │  │ │ ┌────────────┐ │ │  │  │  │ │ ┌──────────┐ │ │ │  │
        │  │  │ │ │ Container  │ │ │  │  │  │ │ │Container │ │ │ │  │
        │  │  │ │ │ App v2.0   │ │ │  │  │  │ │ │App v2.0  │ │ │ │  │
        │  │  │ │ └────────────┘ │ │  │  │  │ │ └──────────┘ │ │ │  │
        │  │  │ └────────────────┘ │  │  │  │ └──────────────┘ │ │  │
        │  │  └────────────────────┘  │  │  └──────────────────┘ │  │
        │  │                          │  │                        │  │
        │  │  ┌────────────────────┐  │  │  ┌──────────────────┐ │  │
        │  │  │   ECS Service      │  │  │  │   ECS Service    │ │  │
        │  │  │   (Green) Standby  │  │  │  │   (Green) Standby│ │  │
        │  │  └────────────────────┘  │  │  └──────────────────┘ │  │
        │  └──────────────────────────┘  └────────────────────────┘  │
        │                                                              │
        │  ┌──────────────────────────────────────────────────────┐  │
        │  │              EC2 Instances (ECS Capacity)             │  │
        │  │  - Auto Scaling Group                                 │  │
        │  │  - ECS Agent running                                  │  │
        │  │  - Or AWS Fargate (Serverless)                        │  │
        │  └──────────────────────────────────────────────────────┘  │
        │                                                              │
        │  ┌──────────────────────────────────────────────────────┐  │
        │  │  Monitoring & Logging                                 │  │
        │  │  - CloudWatch Logs (Container logs)                   │  │
        │  │  - CloudWatch Metrics (CPU, Memory, Network)          │  │
        │  │  - X-Ray (Distributed tracing)                        │  │
        │  │  - Container Insights                                 │  │
        │  └──────────────────────────────────────────────────────┘  │
        └──────────────────────────────────────────────────────────────┘
```

---

## ECS Components

### 1. ECS Cluster
**Purpose:** Logical grouping of ECS resources

**Types:**
* **EC2 Launch Type** - Containers run on managed EC2 instances
* **Fargate Launch Type** - Serverless, AWS manages infrastructure
* **External Launch Type** - Run on external infrastructure

**Best Practices:**
* Separate clusters by environment (Dev, QA, Staging, Prod)
* Enable Container Insights for monitoring
* Use Fargate for simpler management, EC2 for cost optimization

---

### 2. ECS Service
**Purpose:** Maintains desired number of tasks running

**Key Features:**
* **Desired Count** - Number of tasks to run
* **Load Balancer Integration** - ALB/NLB target groups
* **Auto Scaling** - Scale based on metrics
* **Deployment Configuration** - Rolling, Blue-Green, Canary
* **Service Discovery** - AWS Cloud Map integration

---

### 3. ECS Task Definition
**Purpose:** Blueprint for running containers

**Components:**
```json
{
  "family": "myapp-task",
  "taskRoleArn": "arn:aws:iam::123456789:role/ecsTaskRole",
  "executionRoleArn": "arn:aws:iam::123456789:role/ecsTaskExecutionRole",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [
    {
      "name": "myapp-container",
      "image": "123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:2.0",
      "cpu": 512,
      "memory": 1024,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "ENV", "value": "production"},
        {"name": "LOG_LEVEL", "value": "info"}
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789:secret:db-password"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/myapp",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

---

### 4. Application Load Balancer (ALB)
**Purpose:** Distribute traffic to ECS tasks

**Components:**
* **Listeners** - Port and protocol configuration
* **Target Groups** - Health checks and routing
* **Rules** - Path-based or host-based routing

---

## ECS Deployment Strategies

### 1. Rolling Deployment

```
┌─────────────────────────────────────────────────────────────────┐
│                  ECS ROLLING DEPLOYMENT                          │
└─────────────────────────────────────────────────────────────────┘

Initial State: 4 tasks running v1.0
ALB → [Task-1] [Task-2] [Task-3] [Task-4]
       v1.0    v1.0    v1.0    v1.0

Step 1: Stop 2 tasks (50%), Start 2 new tasks
ALB → [Task-1] [Task-2] [Task-5] [Task-6]
       v1.0    v1.0    v2.0    v2.0
       (Old)   (Old)   (New)   (New)

Step 2: Health checks pass, Stop remaining old tasks, Start new tasks
ALB → [Task-5] [Task-6] [Task-7] [Task-8]
       v2.0    v2.0    v2.0    v2.0
       (All new version)

Configuration:
  minimumHealthyPercent: 50
  maximumPercent: 100

Characteristics:
- Mixed version state during deployment
- No additional infrastructure needed
- Moderate risk
- Default ECS deployment strategy
```

**Harness Configuration:**
```yaml
deploymentStrategy:
  type: EcsRolling
  spec:
    minimumHealthyPercent: 50
    maximumPercent: 100
```

---

### 2. Blue-Green Deployment

```
┌─────────────────────────────────────────────────────────────────┐
│                 ECS BLUE-GREEN DEPLOYMENT                        │
└─────────────────────────────────────────────────────────────────┘

Initial State:
ALB → Target Group 1 (BLUE) → ECS Service (Blue)
                               [Task-1] [Task-2] [Task-3] [Task-4]
                                v1.0    v1.0    v1.0    v1.0
                                (Serving 100% traffic)

      Target Group 2 (GREEN) → (Empty)

Step 1: Deploy to GREEN
ALB → Target Group 1 (BLUE) → ECS Service (Blue)
                               [Task-1] [Task-2] [Task-3] [Task-4]
                                v1.0    v1.0    v1.0    v1.0
                                (Still serving 100% traffic)

      Target Group 2 (GREEN) → ECS Service (Green)
                                [Task-5] [Task-6] [Task-7] [Task-8]
                                 v2.0    v2.0    v2.0    v2.0
                                 (Testing, 0% traffic)

Step 2: Switch ALB to GREEN
ALB → Target Group 2 (GREEN) → ECS Service (Green)
                                [Task-5] [Task-6] [Task-7] [Task-8]
                                 v2.0    v2.0    v2.0    v2.0
                                 (Now serving 100% traffic)

      Target Group 1 (BLUE) → ECS Service (Blue)
                               [Task-1] [Task-2] [Task-3] [Task-4]
                                v1.0    v1.0    v1.0    v1.0
                                (Standby for rollback)

Step 3: Cleanup (After validation)
      Target Group 1 (BLUE) → (Terminate old tasks)

Instant Rollback: Switch ALB back to BLUE

Characteristics:
- Zero downtime
- Instant rollback (just switch ALB)
- Full testing before switch
- Requires 2x capacity during deployment
```

**Harness Configuration:**
```yaml
deploymentStrategy:
  type: EcsBlueGreen
  spec:
    stableTargetGroup: target-group-blue
    stageTargetGroup: target-group-green
    loadBalancers:
      - loadBalancerArn: arn:aws:elasticloadbalancing:...
        listenerArn: arn:aws:elasticloadbalancing:...
```

---

### 3. Canary Deployment

```
┌─────────────────────────────────────────────────────────────────┐
│                  ECS CANARY DEPLOYMENT                           │
└─────────────────────────────────────────────────────────────────┘

Initial State: 4 tasks running v1.0
ALB → [Task-1] [Task-2] [Task-3] [Task-4]
       v1.0    v1.0    v1.0    v1.0
       100% traffic

Step 1: Deploy 1 Canary task (25%)
ALB → [Task-1] [Task-2] [Task-3] [Task-5]
       v1.0    v1.0    v1.0    v2.0
       75%     ←───────────→   25%
       (Baseline)              (Canary)
       ↓
Monitor metrics for 5-10 minutes
Compare canary vs baseline

Step 2: If metrics OK, increase to 50%
ALB → [Task-1] [Task-2] [Task-5] [Task-6]
       v1.0    v1.0    v2.0    v2.0
       50%     ←───→   50%
       ↓
Continue monitoring

Step 3: Increase to 75%
ALB → [Task-1] [Task-5] [Task-6] [Task-7]
       v1.0    v2.0    v2.0    v2.0
       25%     75%
       ↓
Continue monitoring

Step 4: Complete rollout (100%)
ALB → [Task-5] [Task-6] [Task-7] [Task-8]
       v2.0    v2.0    v2.0    v2.0
       100% traffic

Auto-Rollback: If anomalies detected
ALB → [Task-1] [Task-2] [Task-3] [Task-4]
       v1.0    v1.0    v1.0    v1.0
       (Automatic rollback)

Characteristics:
- Gradual rollout with monitoring
- Automated rollback on anomalies
- Risk mitigation
- Requires continuous verification
```

**Harness Configuration:**
```yaml
deploymentStrategy:
  type: EcsCanary
  spec:
    canarySteps:
      - percentage: 25
        verificationDuration: 10m
      - percentage: 50
        verificationDuration: 10m
      - percentage: 75
        verificationDuration: 5m
      - percentage: 100
```

---

## ECS Deployment Workflow

### Complete Deployment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  ECS DEPLOYMENT WORKFLOW                         │
└─────────────────────────────────────────────────────────────────┘

1. PRE-DEPLOYMENT
   │
   ├─► Fetch Docker image from ECR
   │   └─► Verify image exists
   │       └─► 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:2.0
   │
   ├─► Retrieve task definition from Git/Harness
   │   └─► Render template with variables
   │       └─► Environment: Production
   │       └─► CPU: 512, Memory: 1024
   │       └─► Secrets: DB_PASSWORD from AWS Secrets Manager
   │
   ├─► Validate AWS permissions
   │   └─► ECS service update permissions
   │   └─► ECR image pull permissions
   │   └─► CloudWatch logs permissions
   │
   └─► Create new task definition revision
       └─► Register task definition with AWS ECS
           └─► Task Definition: myapp-task:42

2. DEPLOYMENT EXECUTION
   │
   ├─► Update ECS Service
   │   └─► aws ecs update-service \
   │       --cluster production-cluster \
   │       --service myapp-service \
   │       --task-definition myapp-task:42 \
   │       --desired-count 4 \
   │       --deployment-configuration \
   │         minimumHealthyPercent=50,maximumPercent=100
   │
   ├─► ECS starts new tasks
   │   └─► Pull Docker image from ECR
   │   └─► Start container with environment variables
   │   └─► Container initialization
   │
   ├─► Health checks
   │   ├─► Container health check (defined in task definition)
   │   │   └─► curl -f http://localhost:8080/health
   │   │       └─► Interval: 30s, Retries: 3
   │   │
   │   └─► ALB target group health check
   │       └─► HTTP GET /health
   │           └─► Healthy threshold: 2 consecutive successes
   │           └─► Unhealthy threshold: 2 consecutive failures
   │
   ├─► Task reaches RUNNING state
   │   └─► Passes container health check
   │   └─► Registered with ALB target group
   │   └─► Begins receiving traffic
   │
   └─► ECS stops old tasks
       └─► Once new tasks are healthy
       └─► Graceful shutdown (SIGTERM → 30s → SIGKILL)

3. POST-DEPLOYMENT VERIFICATION
   │
   ├─► Continuous Verification (10-15 minutes)
   │   ├─► CloudWatch Metrics
   │   │   └─► CPUUtilization
   │   │   └─► MemoryUtilization
   │   │   └─► TargetResponseTime
   │   │   └─► TargetHealthyHostCount
   │   │
   │   ├─► Application Metrics (via Prometheus/Datadog)
   │   │   └─► Error rate
   │   │   └─► Request rate
   │   │   └─► P95 latency
   │   │
   │   └─► Container Logs Analysis
   │       └─► Error patterns
   │       └─► Exception counts
   │
   ├─► Smoke Tests
   │   └─► Execute automated test suite
   │   └─► Validate critical API endpoints
   │   └─► Check database connectivity
   │
   └─► Update deployment status
       └─► Mark as successful
       └─► OR trigger rollback

4. ROLLBACK (If anomalies detected)
   │
   ├─► For Rolling Deployment:
   │   └─► Update service with previous task definition
   │       └─► aws ecs update-service \
   │           --task-definition myapp-task:41
   │
   ├─► For Blue-Green Deployment:
   │   └─► Switch ALB back to old target group (instant)
   │       └─► aws elbv2 modify-listener \
   │           --default-actions TargetGroupArn=blue-tg
   │
   └─► For Canary Deployment:
       └─► Scale down canary tasks
       └─► Keep baseline tasks running
```

---

## Task Definition Management

### Template with Variables

```json
{
  "family": "{{SERVICE_NAME}}-task",
  "taskRoleArn": "{{TASK_ROLE_ARN}}",
  "executionRoleArn": "{{EXECUTION_ROLE_ARN}}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["{{LAUNCH_TYPE}}"],
  "cpu": "{{CPU}}",
  "memory": "{{MEMORY}}",
  "containerDefinitions": [
    {
      "name": "{{SERVICE_NAME}}-container",
      "image": "{{ECR_IMAGE}}:{{IMAGE_TAG}}",
      "cpu": {{CPU}},
      "memory": {{MEMORY}},
      "essential": true,
      "portMappings": [
        {
          "containerPort": {{CONTAINER_PORT}},
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "ENVIRONMENT", "value": "{{ENVIRONMENT}}"},
        {"name": "LOG_LEVEL", "value": "{{LOG_LEVEL}}"},
        {"name": "API_ENDPOINT", "value": "{{API_ENDPOINT}}"}
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "{{DB_PASSWORD_SECRET_ARN}}"
        },
        {
          "name": "API_KEY",
          "valueFrom": "{{API_KEY_SECRET_ARN}}"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/{{SERVICE_NAME}}",
          "awslogs-region": "{{AWS_REGION}}",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:{{CONTAINER_PORT}}/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

### Environment-Specific Values

**Development:**
```yaml
SERVICE_NAME: myapp
LAUNCH_TYPE: FARGATE
CPU: "256"
MEMORY: "512"
ECR_IMAGE: 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp
IMAGE_TAG: dev-latest
ENVIRONMENT: development
LOG_LEVEL: debug
CONTAINER_PORT: 8080
```

**Production:**
```yaml
SERVICE_NAME: myapp
LAUNCH_TYPE: FARGATE
CPU: "1024"
MEMORY: "2048"
ECR_IMAGE: 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp
IMAGE_TAG: v2.0.5
ENVIRONMENT: production
LOG_LEVEL: info
CONTAINER_PORT: 8080
```

---

## Networking Configuration

### VPC and Subnets

```
┌─────────────────────────────────────────────────────────────────┐
│                     VPC NETWORK ARCHITECTURE                     │
└─────────────────────────────────────────────────────────────────┘

VPC: 10.0.0.0/16

┌─────────────────────────────────────────────────────────────────┐
│  Public Subnets (ALB)                                            │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │ us-east-1a     │  │ us-east-1b     │  │ us-east-1c     │   │
│  │ 10.0.1.0/24    │  │ 10.0.2.0/24    │  │ 10.0.3.0/24    │   │
│  │ [ALB]          │  │ [ALB]          │  │ [ALB]          │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Private Subnets (ECS Tasks)                                     │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │ us-east-1a     │  │ us-east-1b     │  │ us-east-1c     │   │
│  │ 10.0.11.0/24   │  │ 10.0.12.0/24   │  │ 10.0.13.0/24   │   │
│  │ [ECS Tasks]    │  │ [ECS Tasks]    │  │ [ECS Tasks]    │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Private Subnets (Database)                                      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │ us-east-1a     │  │ us-east-1b     │  │ us-east-1c     │   │
│  │ 10.0.21.0/24   │  │ 10.0.22.0/24   │  │ 10.0.23.0/24   │   │
│  │ [RDS]          │  │ [RDS]          │  │ [RDS]          │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

NAT Gateways: Public subnets for ECS tasks outbound traffic
```

### Security Groups

**ALB Security Group:**
```
Inbound:
- Port 443 (HTTPS) from 0.0.0.0/0
- Port 80 (HTTP) from 0.0.0.0/0

Outbound:
- Port 8080 to ECS Tasks Security Group
```

**ECS Tasks Security Group:**
```
Inbound:
- Port 8080 from ALB Security Group

Outbound:
- Port 443 to 0.0.0.0/0 (HTTPS API calls)
- Port 5432 to RDS Security Group (PostgreSQL)
```

**RDS Security Group:**
```
Inbound:
- Port 5432 from ECS Tasks Security Group

Outbound:
- None
```

---

## Auto Scaling

### Service Auto Scaling

```yaml
# Target Tracking Scaling - CPU
ScalingPolicy:
  PolicyType: TargetTrackingScaling
  TargetTrackingScalingPolicyConfiguration:
    PredefinedMetricSpecification:
      PredefinedMetricType: ECSServiceAverageCPUUtilization
    TargetValue: 70.0
    ScaleInCooldown: 300
    ScaleOutCooldown: 60

# Target Tracking Scaling - Memory
ScalingPolicy:
  PolicyType: TargetTrackingScaling
  TargetTrackingScalingPolicyConfiguration:
    PredefinedMetricSpecification:
      PredefinedMetricType: ECSServiceAverageMemoryUtilization
    TargetValue: 80.0
    ScaleInCooldown: 300
    ScaleOutCooldown: 60

# ALB Request Count Per Target
ScalingPolicy:
  PolicyType: TargetTrackingScaling
  TargetTrackingScalingPolicyConfiguration:
    PredefinedMetricSpecification:
      PredefinedMetricType: ALBRequestCountPerTarget
      ResourceLabel: app/my-alb/123/targetgroup/my-tg/456
    TargetValue: 1000.0
```

### Capacity Configuration

```
Minimum Capacity: 2 tasks (HA)
Maximum Capacity: 20 tasks
Desired Capacity: 4 tasks

Scale Out: When CPU > 70% or Memory > 80%
Scale In: When CPU < 50% and Memory < 60% (with cooldown)
```

---

## Monitoring & Logging

### CloudWatch Metrics

| Metric | Description | Alarm Threshold |
|--------|-------------|-----------------|
| CPUUtilization | Task CPU usage | >80% for 5 min |
| MemoryUtilization | Task memory usage | >85% for 5 min |
| TargetResponseTime | ALB target response time | >500ms (P95) |
| TargetHealthyHostCount | Healthy tasks count | <2 tasks |
| TargetUnhealthyHostCount | Unhealthy tasks count | >0 for 2 min |
| HTTPCode_Target_5XX_Count | 5XX errors from tasks | >10 in 5 min |
| RequestCount | Total requests | Baseline ±50% |

### Container Logs

```bash
# CloudWatch Logs configuration in task definition
"logConfiguration": {
  "logDriver": "awslogs",
  "options": {
    "awslogs-group": "/ecs/myapp",
    "awslogs-region": "us-east-1",
    "awslogs-stream-prefix": "ecs",
    "awslogs-datetime-format": "%Y-%m-%d %H:%M:%S"
  }
}

# Query logs using CloudWatch Insights
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

### Container Insights

Enable Container Insights for detailed metrics:
```bash
aws ecs put-account-setting \
  --name containerInsights \
  --value enabled
```

**Metrics provided:**
* Container CPU and memory utilization
* Network metrics (bytes in/out)
* Storage metrics
* Task and service level metrics

---

## Security Best Practices

### 1. IAM Roles

**Task Execution Role** (Used by ECS agent):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "*"
    }
  ]
}
```

**Task Role** (Used by application):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "dynamodb:Query",
        "dynamodb:PutItem",
        "sqs:SendMessage",
        "sqs:ReceiveMessage"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket/*",
        "arn:aws:dynamodb:us-east-1:123456789:table/MyTable",
        "arn:aws:sqs:us-east-1:123456789:MyQueue"
      ]
    }
  ]
}
```

### 2. Secrets Management

**Using AWS Secrets Manager:**
```json
"secrets": [
  {
    "name": "DB_PASSWORD",
    "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789:secret:prod/db/password-AbCdEf"
  },
  {
    "name": "API_KEY",
    "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789:secret:prod/api/key-XyZ123"
  }
]
```

**Best Practices:**
* Store all secrets in AWS Secrets Manager or Systems Manager Parameter Store
* Use IAM roles for authentication (no hardcoded credentials)
* Rotate secrets regularly
* Use different secrets per environment
* Enable secret version tracking

### 3. Network Security

* ✅ Deploy ECS tasks in private subnets
* ✅ Use NAT Gateway for outbound traffic
* ✅ Restrict security group rules (principle of least privilege)
* ✅ Enable VPC Flow Logs
* ✅ Use AWS PrivateLink for AWS service access

### 4. Image Security

* ✅ Scan images for vulnerabilities (ECR image scanning)
* ✅ Use minimal base images (Alpine, Distroless)
* ✅ Don't run containers as root
* ✅ Sign images for integrity
* ✅ Regularly update base images

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Tasks fail to start | Image not found, insufficient resources | Verify ECR image exists, check task CPU/memory |
| Tasks fail health checks | App not responding, wrong health endpoint | Check logs, verify health check configuration |
| Tasks can't pull image | IAM permissions, ECR auth | Verify execution role has ECR permissions |
| Service stuck in deployment | Health checks failing | Check ALB target group health checks |
| High CPU/Memory | Undersized tasks, memory leaks | Increase task resources, investigate app |

### Debug Commands

```bash
# List ECS services
aws ecs list-services --cluster production-cluster

# Describe ECS service
aws ecs describe-services \
  --cluster production-cluster \
  --services myapp-service

# List running tasks
aws ecs list-tasks \
  --cluster production-cluster \
  --service-name myapp-service

# Describe task
aws ecs describe-tasks \
  --cluster production-cluster \
  --tasks arn:aws:ecs:us-east-1:123456789:task/abc123

# View task logs
aws logs tail /ecs/myapp --follow

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...

# Execute command in running container
aws ecs execute-command \
  --cluster production-cluster \
  --task arn:aws:ecs:us-east-1:123456789:task/abc123 \
  --container myapp-container \
  --interactive \
  --command "/bin/bash"
```

---

## Best Practices Summary

### Deployment
* ✅ Use Blue-Green for zero-downtime deployments
* ✅ Implement Canary with continuous verification for risk mitigation
* ✅ Always test in non-production first
* ✅ Use immutable task definitions (version control)
* ✅ Automate rollback procedures

### Resource Configuration
* ✅ Right-size CPU and memory (monitor and adjust)
* ✅ Use Fargate for simplicity, EC2 for cost optimization
* ✅ Enable auto-scaling based on metrics
* ✅ Maintain minimum 2 tasks for HA
* ✅ Distribute tasks across multiple AZs

### Security
* ✅ Use IAM roles, never hardcode credentials
* ✅ Store secrets in AWS Secrets Manager
* ✅ Deploy tasks in private subnets
* ✅ Scan container images regularly
* ✅ Implement least privilege security groups

### Monitoring
* ✅ Enable Container Insights
* ✅ Configure CloudWatch alarms
* ✅ Implement comprehensive health checks
* ✅ Use structured logging (JSON)
* ✅ Monitor both infrastructure and application metrics

### Operations
* ✅ Use descriptive naming conventions
* ✅ Tag all resources appropriately
* ✅ Document runbooks for common scenarios
* ✅ Implement automated testing
* ✅ Regular disaster recovery testing

---

**End of Architecture Documentation**

---

## Using These Diagrams in Confluence

### Steps to Create Visual Diagrams

1. **Use draw.io (Diagrams.net) in Confluence**
   * Install draw.io app for Confluence
   * Create new diagram page
   * Use shapes library for AWS/Architecture diagrams
   * Replace ASCII art with professional diagrams

2. **Export from Lucidchart**
   * Create diagrams in Lucidchart
   * Export as PNG/SVG
   * Insert images into Confluence pages

3. **Use Confluence's Built-in Drawing Tools**
   * Use Confluence's native diagram tool
   * Create flowcharts and architecture diagrams
   * Embed directly in pages

4. **AWS Architecture Icons**
   * Download official AWS architecture icons
   * Use in your diagramming tool
   * Maintain consistency across all diagrams

---

## Document Structure Recommendations

### Confluence Page Hierarchy

```
📄 Harness CD Architecture (Parent Page)
├── 📄 High-Level Architecture
│   ├── 📄 Components Overview
│   ├── 📄 Data Flow
│   ├── 📄 Security Architecture
│   └── 📄 Network Architecture
├── 📄 VM Deployment Architecture
│   ├── 📄 Deployment Strategies
│   ├── 📄 Configuration Management
│   ├── 📄 Monitoring & Verification
│   └── 📄 Troubleshooting Guide
└── 📄 ECS Deployment Architecture
    ├── 📄 ECS Components
    ├── 📄 Deployment Strategies
    ├── 📄 Task Definition Management
    ├── 📄 Networking & Security
    └── 📄 Monitoring & Troubleshooting
```

### Tips for Confluence
* Use **info panels** for important notes
* Use **warning panels** for critical information
* Use **expand sections** for detailed content
* Add **table of contents** macro for navigation
* Use **code blocks** with syntax highlighting
* Add **labels/tags** for easy searching
