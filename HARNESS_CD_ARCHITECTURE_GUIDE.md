# Harness CD: End-to-End Architecture Guide
## VM and ECS Deployment - Customer Architecture Documentation

**Document Version:** 2.0
**Last Updated:** January 2026
**Audience:** Customers, Architects, DevOps Teams, Technical Decision Makers
**Purpose:** Comprehensive architectural guide for implementing Harness CD for VM and ECS deployments

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [VM Deployment Architecture](#vm-deployment-architecture)
4. [ECS Deployment Architecture](#ecs-deployment-architecture)
5. [Network Architecture](#network-architecture)
6. [Security Architecture](#security-architecture)
7. [Integration Architecture](#integration-architecture)
8. [Deployment Flows](#deployment-flows)
9. [Component Deep Dive](#component-deep-dive)
10. [Scalability and High Availability](#scalability-and-high-availability)
11. [Disaster Recovery](#disaster-recovery)
12. [Appendix](#appendix)

---

## Executive Summary

This document provides a comprehensive architectural overview of Harness Continuous Delivery (CD) platform implementation for Virtual Machine (VM) and Amazon Elastic Container Service (ECS) deployments. It is designed to help technical teams understand the end-to-end architecture, component interactions, data flows, and deployment patterns.

### Key Benefits

- **Zero-Downtime Deployments**: Multiple deployment strategies ensure continuous availability
- **Multi-Cloud Support**: Deploy to any cloud provider or on-premise infrastructure
- **Automated Verification**: AI-powered continuous verification with automatic rollback
- **Security & Compliance**: Built-in secrets management, RBAC, and audit trails
- **Scalability**: Distributed architecture supporting thousands of deployments

### Target Deployment Models

1. **VM-Based Deployments**: Traditional server-based applications on physical or virtual machines
2. **ECS-Based Deployments**: Containerized applications on AWS Elastic Container Service

---

## Architecture Overview

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                            HARNESS CD PLATFORM (SaaS/Self-Managed)                   │
│                                                                                       │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                          CONTROL PLANE                                       │   │
│  │  ┌───────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │   │
│  │  │   Pipeline    │  │   Service    │  │ Environment  │  │ Infrastructure │ │   │
│  │  │  Orchestrator │  │  Management  │  │  Management  │  │   Management   │ │   │
│  │  └───────────────┘  └──────────────┘  └──────────────┘  └──────────────┘ │   │
│  │                                                                             │   │
│  │  ┌───────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │   │
│  │  │   Secrets     │  │    RBAC &    │  │   Audit &    │  │  Continuous  │ │   │
│  │  │  Management   │  │   Governance │  │   Logging    │  │ Verification │ │   │
│  │  └───────────────┘  └──────────────┘  └──────────────┘  └──────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                           │                                          │
│                            ┌──────────────┴──────────────┐                          │
│                            │     Communication Layer      │                          │
│                            │  (WebSocket/HTTPS - TLS 1.3) │                          │
│                            └──────────────┬──────────────┘                          │
└───────────────────────────────────────────┼──────────────────────────────────────────┘
                                            │
                                            │ Encrypted Communication
                                            │ (Outbound only from Delegate)
                            ┌───────────────┴────────────────┐
                            │                                │
                ┌───────────▼──────────┐        ┌───────────▼──────────┐
                │  DELEGATE CLUSTER    │        │  DELEGATE CLUSTER    │
                │  (Customer Network)  │        │    (AWS VPC)         │
                │                      │        │                      │
                │  ┌────────────────┐ │        │  ┌────────────────┐ │
                │  │  Delegate 1    │ │        │  │  Delegate 1    │ │
                │  │  (Active)      │ │        │  │  (Active)      │ │
                │  └────────────────┘ │        │  └────────────────┘ │
                │  ┌────────────────┐ │        │  ┌────────────────┐ │
                │  │  Delegate 2    │ │        │  │  Delegate 2    │ │
                │  │  (Active)      │ │        │  │  (Active)      │ │
                │  └────────────────┘ │        │  └────────────────┘ │
                │  ┌────────────────┐ │        │  ┌────────────────┐ │
                │  │  Delegate 3    │ │        │  │  Delegate 3    │ │
                │  │  (Standby)     │ │        │  │  (Standby)     │ │
                │  └────────────────┘ │        │  └────────────────┘ │
                └──────────┬──────────┘        └──────────┬──────────┘
                           │                              │
         ┌─────────────────┴───────────┐    ┌────────────┴─────────────────┐
         │                             │    │                              │
    ┌────▼─────┐              ┌────────▼────▼─┐                  ┌─────────▼──────┐
    │   VM     │              │  Artifact      │                  │   AWS ECS      │
    │  Servers │              │  Repositories  │                  │   Clusters     │
    │          │              │                │                  │                │
    │ • Dev    │              │ • Docker       │                  │ • Services     │
    │ • QA     │              │ • ECR          │                  │ • Tasks        │
    │ • Staging│              │ • Artifactory  │                  │ • ALB/NLB      │
    │ • Prod   │              │ • Nexus        │                  │ • Target Groups│
    └──────────┘              │ • S3           │                  └────────────────┘
                              └────────────────┘

                              ┌────────────────┐
                              │   Monitoring   │
                              │   & Metrics    │
                              │                │
                              │ • Prometheus   │
                              │ • Datadog      │
                              │ • CloudWatch   │
                              │ • NewRelic     │
                              └────────────────┘
```

### Architecture Layers

#### 1. Control Plane Layer (Harness SaaS/Self-Managed)
- **Pipeline Orchestrator**: Manages pipeline execution, workflow orchestration
- **Service Management**: Defines applications, artifacts, and configurations
- **Environment Management**: Manages deployment environments (Dev, QA, Staging, Prod)
- **Infrastructure Management**: Defines target infrastructure (VMs, ECS, K8s)
- **Secrets Management**: Secure storage and injection of secrets
- **RBAC & Governance**: Role-based access control and policy enforcement
- **Audit & Logging**: Complete audit trails and compliance reporting
- **Continuous Verification**: AI-powered deployment verification

#### 2. Communication Layer
- **Protocol**: WebSocket over HTTPS with TLS 1.3
- **Direction**: Outbound only from Delegate (no inbound connections required)
- **Security**: mTLS authentication, encrypted payloads
- **Resilience**: Automatic reconnection, message queuing

#### 3. Execution Layer (Delegates)
- **Deployment**: Kubernetes pods, Docker containers, or VM processes
- **Location**: Customer's private network or VPC
- **Responsibilities**: Execute deployment tasks, connect to target infrastructure
- **High Availability**: Multiple delegates with automatic failover
- **Scaling**: Horizontal scaling based on workload

#### 4. Target Infrastructure Layer
- **VM Servers**: Physical or virtual machines across environments
- **AWS ECS**: Container orchestration on AWS
- **Artifact Repositories**: Store and serve application artifacts
- **Monitoring Tools**: Observability and metrics collection

---

## VM Deployment Architecture

### Detailed VM Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              HARNESS CD CONTROL PLANE                                    │
│                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐  │
│  │                            PIPELINE EXECUTION ENGINE                              │  │
│  │                                                                                    │  │
│  │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐       │  │
│  │  │   Trigger   │ → │   Build     │ → │   Deploy    │ → │   Verify    │       │  │
│  │  │   Stage     │   │   Stage     │   │   Stage     │   │   Stage     │       │  │
│  │  └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘       │  │
│  │         │                  │                  │                  │                │  │
│  │         └──────────────────┴──────────────────┴──────────────────┘                │  │
│  │                                      │                                             │  │
│  └──────────────────────────────────────┼─────────────────────────────────────────────┘  │
│                                         │                                                │
│  ┌──────────────────────────────────────▼─────────────────────────────────────────────┐  │
│  │                         SERVICE DEFINITION                                         │  │
│  │                                                                                    │  │
│  │  Service Name: myapp-vm-service                                                   │  │
│  │  Type: SSH                                                                        │  │
│  │  Artifacts:                                                                       │  │
│  │    - Type: Docker / TAR / RPM / DEB                                              │  │
│  │    - Location: Docker Registry / Artifactory / S3                                │  │
│  │    - Version: Tagged with <+pipeline.sequenceId>                                 │  │
│  │  Configuration Files:                                                             │  │
│  │    - app.properties (from Git)                                                   │  │
│  │    - log4j.xml (from Git)                                                        │  │
│  │    - env-specific configs                                                        │  │
│  │  Variables:                                                                       │  │
│  │    - ENVIRONMENT: ${env.name}                                                    │  │
│  │    - LOG_LEVEL: INFO                                                             │  │
│  │    - APP_PORT: 8080                                                              │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                         │                                                │
│  ┌──────────────────────────────────────▼─────────────────────────────────────────────┐  │
│  │                    ENVIRONMENT & INFRASTRUCTURE DEFINITIONS                        │  │
│  │                                                                                    │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │  │
│  │  │     DEV      │  │      QA      │  │   STAGING    │  │  PRODUCTION  │      │  │
│  │  │              │  │              │  │              │  │              │      │  │
│  │  │ Infrastructure│  │ Infrastructure│  │ Infrastructure│  │ Infrastructure│      │  │
│  │  │ Type: SSH    │  │ Type: SSH    │  │ Type: SSH    │  │ Type: SSH    │      │  │
│  │  │ Hosts: 2     │  │ Hosts: 3     │  │ Hosts: 5     │  │ Hosts: 10+   │      │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘      │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────┬───────────────────────────────────────────────────┘
                                       │
                                       │ WebSocket over HTTPS (TLS 1.3)
                                       │ Outbound Connection Only
                                       │
┌──────────────────────────────────────▼───────────────────────────────────────────────────┐
│                          CUSTOMER DATA CENTER / PRIVATE CLOUD                           │
│                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐  │
│  │                           DELEGATE CLUSTER (HA)                                   │  │
│  │                                                                                    │  │
│  │  ┌────────────────────────┐  ┌────────────────────────┐  ┌───────────────────┐ │  │
│  │  │     Delegate-1         │  │     Delegate-2         │  │    Delegate-3     │ │  │
│  │  │     (Primary)          │  │     (Primary)          │  │    (Standby)      │ │  │
│  │  │                        │  │                        │  │                   │ │  │
│  │  │  Responsibilities:     │  │  Responsibilities:     │  │  Responsibilities: │ │  │
│  │  │  • SSH Connections     │  │  • Artifact Downloads  │  │  • Failover       │ │  │
│  │  │  • Script Execution    │  │  • Health Checks       │  │  • Load Balancing │ │  │
│  │  │  • File Transfers      │  │  • Monitoring          │  │                   │ │  │
│  │  │                        │  │                        │  │                   │ │  │
│  │  │  Resources:            │  │  Resources:            │  │  Resources:       │ │  │
│  │  │  • CPU: 2 cores        │  │  • CPU: 2 cores        │  │  • CPU: 2 cores   │ │  │
│  │  │  • Memory: 8 GB        │  │  • Memory: 8 GB        │  │  • Memory: 8 GB   │ │  │
│  │  │  • Disk: 50 GB         │  │  • Disk: 50 GB         │  │  • Disk: 50 GB    │ │  │
│  │  └────────────────────────┘  └────────────────────────┘  └───────────────────┘ │  │
│  │                   │                        │                        │            │  │
│  └───────────────────┼────────────────────────┼────────────────────────┼────────────┘  │
│                      │                        │                        │               │
│                      └────────────────────────┴────────────────────────┘               │
│                                               │                                        │
│                                SSH/SFTP (Port 22)                                      │
│                      ┌────────────────────────┴────────────────────────┐               │
│                      │                                                 │               │
│  ┌───────────────────▼───────────────┐          ┌─────────────────────▼─────────────┐ │
│  │     ARTIFACT REPOSITORY           │          │       TARGET VM SERVERS            │ │
│  │                                   │          │                                    │ │
│  │  ┌─────────────────────────────┐ │          │  ┌──────────────────────────────┐ │ │
│  │  │   Docker Registry           │ │          │  │    DEVELOPMENT SERVERS       │ │ │
│  │  │   - myapp:latest            │ │          │  │                              │ │ │
│  │  │   - myapp:v1.2.3            │ │          │  │  dev-vm-01: 192.168.1.10    │ │ │
│  │  └─────────────────────────────┘ │          │  │  dev-vm-02: 192.168.1.11    │ │ │
│  │                                   │          │  │                              │ │ │
│  │  ┌─────────────────────────────┐ │          │  │  OS: Ubuntu 22.04 LTS       │ │ │
│  │  │   Artifactory/Nexus         │ │          │  │  App Path: /opt/myapp       │ │ │
│  │  │   - myapp-1.2.3.tar.gz      │ │          │  │  Service: myapp.service     │ │ │
│  │  │   - myapp-1.2.3.rpm         │ │          │  │  Port: 8080                 │ │ │
│  │  └─────────────────────────────┘ │          │  └──────────────────────────────┘ │ │
│  │                                   │          │                                    │ │
│  │  ┌─────────────────────────────┐ │          │  ┌──────────────────────────────┐ │ │
│  │  │   S3 Bucket                 │ │          │  │      QA SERVERS              │ │ │
│  │  │   - s3://artifacts/myapp/   │ │          │  │                              │ │ │
│  │  └─────────────────────────────┘ │          │  │  qa-vm-01: 192.168.2.10     │ │ │
│  └───────────────────────────────────┘          │  │  qa-vm-02: 192.168.2.11     │ │ │
│                                                  │  │  qa-vm-03: 192.168.2.12     │ │ │
│  ┌───────────────────────────────────┐          │  └──────────────────────────────┘ │ │
│  │     CONFIGURATION REPOSITORY      │          │                                    │ │
│  │                                   │          │  ┌──────────────────────────────┐ │ │
│  │  ┌─────────────────────────────┐ │          │  │    STAGING SERVERS           │ │ │
│  │  │   Git Repository            │ │          │  │                              │ │ │
│  │  │   - config/dev/             │ │          │  │  stg-vm-01: 192.168.3.10    │ │ │
│  │  │   - config/qa/              │ │          │  │  stg-vm-02: 192.168.3.11    │ │ │
│  │  │   - config/staging/         │ │          │  │  stg-vm-03: 192.168.3.12    │ │ │
│  │  │   - config/prod/            │ │          │  │  stg-vm-04: 192.168.3.13    │ │ │
│  │  │   - scripts/                │ │          │  │  stg-vm-05: 192.168.3.14    │ │ │
│  │  └─────────────────────────────┘ │          │  └──────────────────────────────┘ │ │
│  └───────────────────────────────────┘          │                                    │ │
│                                                  │  ┌──────────────────────────────┐ │ │
│  ┌───────────────────────────────────┐          │  │   PRODUCTION SERVERS         │ │ │
│  │     MONITORING & OBSERVABILITY    │          │  │                              │ │ │
│  │                                   │          │  │  prod-vm-01: 10.0.1.10      │ │ │
│  │  ┌─────────────────────────────┐ │          │  │  prod-vm-02: 10.0.1.11      │ │ │
│  │  │   Prometheus                │ │          │  │  prod-vm-03: 10.0.1.12      │ │ │
│  │  │   - Metrics Collection      │◄┼──────────┼──│  prod-vm-04: 10.0.1.13      │ │ │
│  │  │   - Alerting                │ │          │  │  prod-vm-05: 10.0.1.14      │ │ │
│  │  └─────────────────────────────┘ │          │  │  ...                         │ │ │
│  │                                   │          │  │  prod-vm-10: 10.0.1.19      │ │ │
│  │  ┌─────────────────────────────┐ │          │  │                              │ │ │
│  │  │   Datadog / NewRelic        │ │          │  │  Load Balancer: 10.0.1.100  │ │ │
│  │  │   - APM                     │◄┼──────────┼──│  Health Check: /health       │ │ │
│  │  │   - Log Aggregation         │ │          │  └──────────────────────────────┘ │ │
│  │  └─────────────────────────────┘ │          │                                    │ │
│  └───────────────────────────────────┘          └────────────────────────────────────┘ │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### VM Deployment Components

#### 1. Control Plane Components

##### Pipeline Execution Engine
- **Purpose**: Orchestrates the entire deployment workflow
- **Key Features**:
  - Multi-stage pipeline support
  - Parallel and serial execution
  - Conditional execution based on success/failure
  - Manual approval gates
  - Automated triggers (Git webhook, cron, API)

##### Service Definition
- **Artifacts Configuration**:
  - Docker images from registry
  - TAR/ZIP archives from Artifactory
  - RPM/DEB packages from package repositories
  - Raw files from S3/Azure Blob/GCS
- **Configuration Management**:
  - Git-based configuration files
  - Environment-specific variables
  - Template-based configuration generation
  - Secrets injection at runtime

##### Infrastructure Definition
- **SSH Connection Details**:
  - Hostname/IP address
  - Port (default: 22)
  - Authentication method (SSH key/password)
  - Connection timeout settings
  - Retry configuration
- **Host Management**:
  - Static host lists
  - Dynamic host discovery
  - Tag-based selection
  - Load balancing across hosts

#### 2. Execution Layer (Delegates)

##### Delegate Responsibilities
- **Connection Management**: Establish and maintain SSH connections
- **Artifact Management**: Download, cache, and transfer artifacts
- **Script Execution**: Run deployment scripts on target VMs
- **Health Checking**: Verify application and service health
- **Monitoring**: Collect and report deployment metrics

##### Delegate High Availability
- **Active-Active Configuration**: Multiple delegates handle requests simultaneously
- **Load Balancing**: Automatic distribution of tasks across delegates
- **Failover**: Automatic failover to healthy delegates
- **Scaling**: Horizontal scaling based on workload

##### Delegate Placement
- **Network Location**: Inside customer's private network/VPC
- **Connectivity**: Must reach target VMs and artifact repositories
- **Security**: No inbound connections required from internet
- **Resource Requirements**:
  - CPU: 2-4 cores
  - Memory: 8-16 GB
  - Disk: 50-100 GB (for artifact caching)
  - Network: 1 Gbps+

#### 3. Target Infrastructure (VM Servers)

##### Environment Configuration

**Development Environment**
- **Purpose**: Developer testing and feature validation
- **Host Count**: 2-5 servers
- **Deployment Frequency**: Multiple times per day
- **Deployment Strategy**: Rolling update
- **Monitoring**: Basic health checks

**QA Environment**
- **Purpose**: Quality assurance and integration testing
- **Host Count**: 3-8 servers
- **Deployment Frequency**: Daily
- **Deployment Strategy**: Rolling update
- **Monitoring**: Comprehensive testing and validation

**Staging Environment**
- **Purpose**: Pre-production validation
- **Host Count**: 5-10 servers (mirrors production)
- **Deployment Frequency**: 2-3 times per week
- **Deployment Strategy**: Blue-Green or Canary
- **Monitoring**: Production-like monitoring

**Production Environment**
- **Purpose**: Live customer-facing applications
- **Host Count**: 10+ servers (based on load)
- **Deployment Frequency**: Weekly or on-demand
- **Deployment Strategy**: Blue-Green or Canary with verification
- **Monitoring**: Full observability stack

##### VM Server Configuration
- **Operating System**: Linux (Ubuntu, CentOS, RHEL) or Windows Server
- **Application Path**: Standard directory structure (e.g., /opt/myapp)
- **Service Management**: systemd (Linux) or Windows Services
- **Firewall Rules**: Allow SSH from delegate IPs
- **User Permissions**: Dedicated deployment user with sudo privileges
- **Backup**: Regular backups before deployments

---

### VM Deployment End-to-End Flow

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        VM DEPLOYMENT END-TO-END FLOW                                   │
│                                                                                         │
│  PHASE 1: TRIGGER & INITIALIZATION                                                     │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌──────────────┐                                                                      │
│  │   Developer  │                                                                      │
│  │  Commits Code│                                                                      │
│  └──────┬───────┘                                                                      │
│         │                                                                               │
│         ▼                                                                               │
│  ┌─────────────────────────┐                                                          │
│  │   Git Repository        │                                                          │
│  │   (GitHub/GitLab)       │                                                          │
│  │                         │                                                          │
│  │   • Code commit         │                                                          │
│  │   • Webhook triggered   │                                                          │
│  │   • Branch: main        │                                                          │
│  └──────┬──────────────────┘                                                          │
│         │                                                                               │
│         │ Webhook Event                                                                │
│         │ (HTTP POST)                                                                  │
│         ▼                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │                  HARNESS CD CONTROL PLANE                                │         │
│  │                                                                           │         │
│  │  Step 1: Pipeline Trigger                                                │         │
│  │  ──────────────────────────                                              │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Webhook received                                   │              │         │
│  │  │  • Validate webhook signature                         │              │         │
│  │  │  • Extract branch and commit info                     │              │         │
│  │  │  • Match with pipeline triggers                       │              │         │
│  │  │  • Create pipeline execution instance                 │              │         │
│  │  │  • Assign execution ID: exec-20260110-001234         │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │                                                                           │         │
│  │  Step 2: Service Resolution                                              │         │
│  │  ───────────────────────────                                             │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Fetch service definition: myapp-vm-service        │              │         │
│  │  │  • Resolve artifact tag: v1.2.3                      │              │         │
│  │  │  • Load configuration files from Git                 │              │         │
│  │  │  • Resolve variables and secrets                     │              │         │
│  │  │  • Validate service configuration                    │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │                                                                           │         │
│  │  Step 3: Environment Selection                                           │         │
│  │  ──────────────────────────────                                          │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Target environment: Production                     │              │         │
│  │  │  • Load infrastructure definition                     │              │         │
│  │  │  • Fetch target VM hosts (10 servers)                │              │         │
│  │  │  • Validate SSH connectivity                          │              │         │
│  │  │  • Check prerequisites and dependencies               │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │                                                                           │         │
│  │  Step 4: Delegate Selection                                              │         │
│  │  ───────────────────────────                                             │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Query available delegates                          │              │         │
│  │  │  • Filter by selector tags                            │              │         │
│  │  │  • Check delegate health and capacity                 │              │         │
│  │  │  • Select delegate: delegate-prod-01                  │              │         │
│  │  │  • Assign deployment task to delegate                 │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │                                                                           │         │
│  └───────────────────────────────────┬───────────────────────────────────────┘         │
│                                      │                                                 │
│                                      │ Task Assignment                                 │
│                                      │ (WebSocket Message)                             │
│                                      ▼                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              CUSTOMER NETWORK - DELEGATE                                 │         │
│  │                                                                           │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Delegate: delegate-prod-01                          │              │         │
│  │  │  Status: Receiving deployment task                   │              │         │
│  │  │  Task ID: task-20260110-001234                       │              │         │
│  │  │  Target: Production VMs (10 hosts)                   │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  PHASE 2: ARTIFACT ACQUISITION                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              DELEGATE - ARTIFACT DOWNLOAD                                │         │
│  │                                                                           │         │
│  │  Step 1: Artifact Repository Connection                                  │         │
│  │  ───────────────────────────────────────                                 │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Connect to Docker Registry                         │              │         │
│  │  │  • Authenticate using credentials from secrets        │              │         │
│  │  │  • Query for image: myapp:v1.2.3                     │              │         │
│  │  │  • Verify image exists and is accessible             │              │         │
│  │  │  • Check image digest/checksum                        │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │   Docker Registry: registry.example.com              │              │         │
│  │  │   Image: myapp:v1.2.3                                │              │         │
│  │  │   Size: 250 MB                                       │              │         │
│  │  │   Layers: 12                                         │              │         │
│  │  │   Digest: sha256:abc123...                           │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 2: Artifact Download & Caching                                     │         │
│  │  ────────────────────────────────────                                    │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Pull Docker image to delegate                      │              │         │
│  │  │  • Progress: [=========>    ] 65% (162 MB / 250 MB)  │              │         │
│  │  │  • Download speed: 50 MB/s                            │              │         │
│  │  │  • Verify image integrity (checksum)                  │              │         │
│  │  │  • Cache locally for future deployments               │              │         │
│  │  │  • Extract/convert to deployment format (tar.gz)      │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Artifact Ready:                                      │              │         │
│  │  │  • Location: /opt/harness-delegate/cache/            │              │         │
│  │  │  • File: myapp-v1.2.3.tar.gz                         │              │         │
│  │  │  • Size: 245 MB (compressed)                         │              │         │
│  │  │  • Checksum: Verified ✓                               │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │                                                                           │         │
│  │  Step 3: Configuration Files Download                                    │         │
│  │  ─────────────────────────────────────                                   │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  • Connect to Git repository                          │              │         │
│  │  │  • Clone config repository                            │              │         │
│  │  │  • Fetch: config/prod/app.properties                 │              │         │
│  │  │  • Fetch: config/prod/log4j.xml                      │              │         │
│  │  │  • Fetch: scripts/deploy.sh                          │              │         │
│  │  │  • Template processing with variables                 │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  PHASE 3: PRE-DEPLOYMENT ACTIVITIES                                                    │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              DELEGATE → TARGET VM SERVERS                                │         │
│  │                                                                           │         │
│  │  Step 1: SSH Connection Establishment                                    │         │
│  │  ─────────────────────────────────────                                   │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  For each target VM (prod-vm-01 to prod-vm-10):     │              │         │
│  │  │                                                       │              │         │
│  │  │  • Establish SSH connection                          │              │         │
│  │  │    - Host: prod-vm-01.internal (10.0.1.10)          │              │         │
│  │  │    - Port: 22                                        │              │         │
│  │  │    - User: deploy-user                               │              │         │
│  │  │    - Auth: SSH private key from secrets             │              │         │
│  │  │    - Timeout: 30 seconds                             │              │         │
│  │  │                                                       │              │         │
│  │  │  • Verify SSH connectivity                           │              │         │
│  │  │  • Test sudo privileges                              │              │         │
│  │  │  • Verify network connectivity                       │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: Connected to prod-vm-01 ✓                   │              │         │
│  │  │  Status: Connected to prod-vm-02 ✓                   │              │         │
│  │  │  Status: Connected to prod-vm-03 ✓                   │              │         │
│  │  │  ... (all 10 VMs)                                    │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 2: Environment Validation                                          │         │
│  │  ───────────────────────────                                             │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Execute validation script on each VM:               │              │         │
│  │  │                                                       │              │         │
│  │  │  #!/bin/bash                                         │              │         │
│  │  │  echo "Validating environment..."                    │              │         │
│  │  │                                                       │              │         │
│  │  │  # Check disk space                                  │              │         │
│  │  │  DISK_AVAIL=$(df -h /opt | tail -1 | awk '{print $4}')            │              │         │
│  │  │  echo "Available disk: $DISK_AVAIL"                  │              │         │
│  │  │  Required: 5 GB minimum                              │              │         │
│  │  │  Status: 15 GB available ✓                           │              │         │
│  │  │                                                       │              │         │
│  │  │  # Check memory                                      │              │         │
│  │  │  MEM_AVAIL=$(free -h | grep Mem | awk '{print $7}') │              │         │
│  │  │  echo "Available memory: $MEM_AVAIL"                 │              │         │
│  │  │  Required: 2 GB minimum                              │              │         │
│  │  │  Status: 8 GB available ✓                            │              │         │
│  │  │                                                       │              │         │
│  │  │  # Check dependencies                                │              │         │
│  │  │  which java || exit 1                                │              │         │
│  │  │  java -version                                       │              │         │
│  │  │  Status: Java 17 installed ✓                         │              │         │
│  │  │                                                       │              │         │
│  │  │  # Verify port availability                          │              │         │
│  │  │  netstat -tuln | grep 8080 || echo "Port free"      │              │         │
│  │  │  Status: Port 8080 available ✓                       │              │         │
│  │  │                                                       │              │         │
│  │  │  echo "Validation complete"                          │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 3: Backup Current Application                                      │         │
│  │  ────────────────────────────────                                        │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Execute backup script on each VM:                   │              │         │
│  │  │                                                       │              │         │
│  │  │  #!/bin/bash                                         │              │         │
│  │  │  TIMESTAMP=$(date +%Y%m%d_%H%M%S)                    │              │         │
│  │  │  BACKUP_DIR="/opt/backups/$TIMESTAMP"               │              │         │
│  │  │                                                       │              │         │
│  │  │  echo "Creating backup..."                           │              │         │
│  │  │  mkdir -p $BACKUP_DIR                                │              │         │
│  │  │                                                       │              │         │
│  │  │  # Backup application files                          │              │         │
│  │  │  cp -r /opt/myapp/* $BACKUP_DIR/                    │              │         │
│  │  │  Status: Files backed up ✓                           │              │         │
│  │  │                                                       │              │         │
│  │  │  # Backup configuration                              │              │         │
│  │  │  cp -r /etc/myapp/* $BACKUP_DIR/config/             │              │         │
│  │  │  Status: Config backed up ✓                          │              │         │
│  │  │                                                       │              │         │
│  │  │  # Create archive                                    │              │         │
│  │  │  tar -czf $BACKUP_DIR.tar.gz -C /opt/backups \     │              │         │
│  │  │      $TIMESTAMP                                      │              │         │
│  │  │  Status: Archive created ✓                           │              │         │
│  │  │                                                       │              │         │
│  │  │  # Record backup metadata                            │              │         │
│  │  │  echo "Version: v1.2.2" > $BACKUP_DIR/metadata.txt  │              │         │
│  │  │  echo "Date: $TIMESTAMP" >> $BACKUP_DIR/metadata.txt│              │         │
│  │  │                                                       │              │         │
│  │  │  Backup location: /opt/backups/20260110_143022/     │              │         │
│  │  │  Backup size: 240 MB                                 │              │         │
│  │  │  echo "Backup complete"                              │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 4: Stop Running Services                                           │         │
│  │  ───────────────────────────────                                         │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Execute on each VM sequentially (rolling):          │              │         │
│  │  │                                                       │              │         │
│  │  │  echo "Stopping application service..."              │              │         │
│  │  │                                                       │              │         │
│  │  │  # Stop service                                      │              │         │
│  │  │  sudo systemctl stop myapp.service                   │              │         │
│  │  │  Status: Service stop initiated ✓                    │              │         │
│  │  │                                                       │              │         │
│  │  │  # Wait for graceful shutdown                        │              │         │
│  │  │  sleep 10                                            │              │         │
│  │  │                                                       │              │         │
│  │  │  # Verify service stopped                            │              │         │
│  │  │  systemctl is-active myapp.service                   │              │         │
│  │  │  Status: inactive ✓                                  │              │         │
│  │  │                                                       │              │         │
│  │  │  # Check for lingering processes                     │              │         │
│  │  │  pgrep -f myapp || echo "No processes running"      │              │         │
│  │  │  Status: All processes terminated ✓                  │              │         │
│  │  │                                                       │              │         │
│  │  │  # Deregister from load balancer (if applicable)    │              │         │
│  │  │  curl -X DELETE http://lb:8080/pool/prod-vm-01      │              │         │
│  │  │  Status: Deregistered from LB ✓                      │              │         │
│  │  │                                                       │              │         │
│  │  │  echo "Service stopped successfully"                 │              │         │
│  │  │                                                       │              │         │
│  │  │  Stopped on: prod-vm-01 ✓ (9 more VMs remaining)    │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  PHASE 4: DEPLOYMENT EXECUTION                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              ARTIFACT TRANSFER & INSTALLATION                            │         │
│  │                                                                           │         │
│  │  Step 1: Transfer Artifacts to Target VM                                 │         │
│  │  ────────────────────────────────────────                                │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  For each VM (rolling deployment):                   │              │         │
│  │  │                                                       │              │         │
│  │  │  # Transfer artifact via SCP                         │              │         │
│  │  │  echo "Transferring artifact to prod-vm-01..."       │              │         │
│  │  │                                                       │              │         │
│  │  │  scp -i ~/.ssh/deploy_key \                          │              │         │
│  │  │      myapp-v1.2.3.tar.gz \                           │              │         │
│  │  │      deploy-user@prod-vm-01:/tmp/                   │              │         │
│  │  │                                                       │              │         │
│  │  │  Transfer progress:                                  │              │         │
│  │  │  [===================================>   ] 87%        │              │         │
│  │  │  245 MB transferred at 125 MB/s                      │              │         │
│  │  │  ETA: 2 seconds                                      │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: Transfer complete ✓                         │              │         │
│  │  │                                                       │              │         │
│  │  │  # Verify file integrity                             │              │         │
│  │  │  ssh deploy-user@prod-vm-01 \                       │              │         │
│  │  │      "sha256sum /tmp/myapp-v1.2.3.tar.gz"           │              │         │
│  │  │  Expected: abc123...def456                           │              │         │
│  │  │  Actual:   abc123...def456                           │              │         │
│  │  │  Status: Checksum verified ✓                         │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 2: Extract and Install Application                                 │         │
│  │  ────────────────────────────────────────                                │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Execute installation script on target VM:           │              │         │
│  │  │                                                       │              │         │
│  │  │  #!/bin/bash                                         │              │         │
│  │  │  echo "Installing application..."                    │              │         │
│  │  │                                                       │              │         │
│  │  │  # Clean old installation                            │              │         │
│  │  │  rm -rf /opt/myapp/old                               │              │         │
│  │  │  mkdir -p /opt/myapp/old                             │              │         │
│  │  │  mv /opt/myapp/* /opt/myapp/old/ 2>/dev/null        │              │         │
│  │  │  Status: Old version cleaned ✓                       │              │         │
│  │  │                                                       │              │         │
│  │  │  # Extract new version                               │              │         │
│  │  │  cd /opt/myapp                                       │              │         │
│  │  │  tar -xzf /tmp/myapp-v1.2.3.tar.gz                  │              │         │
│  │  │  Status: Artifact extracted ✓                        │              │         │
│  │  │                                                       │              │         │
│  │  │  # Set ownership and permissions                     │              │         │
│  │  │  chown -R myapp:myapp /opt/myapp                    │              │         │
│  │  │  chmod +x /opt/myapp/bin/*                          │              │         │
│  │  │  chmod 600 /opt/myapp/config/*.properties           │              │         │
│  │  │  Status: Permissions set ✓                           │              │         │
│  │  │                                                       │              │         │
│  │  │  # Create necessary directories                      │              │         │
│  │  │  mkdir -p /opt/myapp/logs                           │              │         │
│  │  │  mkdir -p /opt/myapp/data                           │              │         │
│  │  │  mkdir -p /opt/myapp/cache                          │              │         │
│  │  │  Status: Directory structure created ✓               │              │         │
│  │  │                                                       │              │         │
│  │  │  # Install system dependencies (if needed)          │              │         │
│  │  │  apt-get update && apt-get install -y libssl1.1     │              │         │
│  │  │  Status: Dependencies installed ✓                    │              │         │
│  │  │                                                       │              │         │
│  │  │  echo "Installation complete"                        │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 3: Update Configuration Files                                      │         │
│  │  ───────────────────────────────────                                     │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Configure application for target environment:       │              │         │
│  │  │                                                       │              │         │
│  │  │  # Transfer config files                             │              │         │
│  │  │  scp config/prod/app.properties \                    │              │         │
│  │  │      deploy-user@prod-vm-01:/opt/myapp/config/      │              │         │
│  │  │  Status: app.properties transferred ✓                │              │         │
│  │  │                                                       │              │         │
│  │  │  scp config/prod/log4j.xml \                         │              │         │
│  │  │      deploy-user@prod-vm-01:/opt/myapp/config/      │              │         │
│  │  │  Status: log4j.xml transferred ✓                     │              │         │
│  │  │                                                       │              │         │
│  │  │  # Update environment-specific variables             │              │         │
│  │  │  ssh deploy-user@prod-vm-01 << 'EOF'                │              │         │
│  │  │  cd /opt/myapp/config                                │              │         │
│  │  │                                                       │              │         │
│  │  │  # Replace placeholders with actual values           │              │         │
│  │  │  sed -i 's/${ENVIRONMENT}/production/g' \           │              │         │
│  │  │      app.properties                                  │              │         │
│  │  │  sed -i 's/${LOG_LEVEL}/INFO/g' app.properties      │              │         │
│  │  │  sed -i 's/${DB_HOST}/prod-db.internal/g' \         │              │         │
│  │  │      app.properties                                  │              │         │
│  │  │  sed -i 's/${APP_PORT}/8080/g' app.properties       │              │         │
│  │  │                                                       │              │         │
│  │  │  # Inject secrets from Harness                       │              │         │
│  │  │  echo "db.password=${DB_PASSWORD}" >> app.properties│              │         │
│  │  │  echo "api.key=${API_KEY}" >> app.properties        │              │         │
│  │  │                                                       │              │         │
│  │  │  # Validate configuration syntax                     │              │         │
│  │  │  /opt/myapp/bin/validate-config.sh                  │              │         │
│  │  │  Status: Configuration validated ✓                   │              │         │
│  │  │  EOF                                                  │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: Configuration updated ✓                     │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 4: Update Systemd Service                                          │         │
│  │  ───────────────────────────────                                         │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Update service definition (if changed):             │              │         │
│  │  │                                                       │              │         │
│  │  │  # Update systemd service file                       │              │         │
│  │  │  cat > /etc/systemd/system/myapp.service << 'EOF'   │              │         │
│  │  │  [Unit]                                              │              │         │
│  │  │  Description=MyApp Application                       │              │         │
│  │  │  After=network.target                                │              │         │
│  │  │                                                       │              │         │
│  │  │  [Service]                                           │              │         │
│  │  │  Type=simple                                         │              │         │
│  │  │  User=myapp                                          │              │         │
│  │  │  Group=myapp                                         │              │         │
│  │  │  WorkingDirectory=/opt/myapp                         │              │         │
│  │  │  ExecStart=/opt/myapp/bin/start.sh                  │              │         │
│  │  │  ExecStop=/opt/myapp/bin/stop.sh                    │              │         │
│  │  │  Restart=always                                      │              │         │
│  │  │  RestartSec=10                                       │              │         │
│  │  │                                                       │              │         │
│  │  │  [Install]                                           │              │         │
│  │  │  WantedBy=multi-user.target                         │              │         │
│  │  │  EOF                                                  │              │         │
│  │  │                                                       │              │         │
│  │  │  # Reload systemd                                    │              │         │
│  │  │  sudo systemctl daemon-reload                        │              │         │
│  │  │  Status: Systemd reloaded ✓                          │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  PHASE 5: POST-DEPLOYMENT ACTIVITIES                                                   │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              SERVICE STARTUP & VERIFICATION                              │         │
│  │                                                                           │         │
│  │  Step 1: Start Application Service                                       │         │
│  │  ──────────────────────────────────                                      │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Start service on the target VM:                     │              │         │
│  │  │                                                       │              │         │
│  │  │  echo "Starting application service..."              │              │         │
│  │  │                                                       │              │         │
│  │  │  # Start service                                     │              │         │
│  │  │  sudo systemctl start myapp.service                  │              │         │
│  │  │  Status: Service start initiated ✓                   │              │         │
│  │  │                                                       │              │         │
│  │  │  # Wait for startup                                  │              │         │
│  │  │  echo "Waiting for application to start..."          │              │         │
│  │  │  sleep 15                                            │              │         │
│  │  │                                                       │              │         │
│  │  │  # Verify service status                             │              │         │
│  │  │  systemctl is-active myapp.service                   │              │         │
│  │  │  Output: active                                      │              │         │
│  │  │  Status: Service running ✓                           │              │         │
│  │  │                                                       │              │         │
│  │  │  # Check process                                     │              │         │
│  │  │  ps aux | grep myapp                                 │              │         │
│  │  │  PID: 12345                                          │              │         │
│  │  │  Status: Process running ✓                           │              │         │
│  │  │                                                       │              │         │
│  │  │  # Check logs for startup messages                   │              │         │
│  │  │  tail -n 50 /opt/myapp/logs/application.log         │              │         │
│  │  │  [INFO] Application started successfully             │              │         │
│  │  │  [INFO] Listening on port 8080                       │              │         │
│  │  │  Status: No errors in logs ✓                         │              │         │
│  │  │                                                       │              │         │
│  │  │  echo "Service started successfully"                 │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 2: Health Checks                                                   │         │
│  │  ──────────────────────                                                  │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Execute health check validation:                    │              │         │
│  │  │                                                       │              │         │
│  │  │  # Check 1: Port Listening                           │              │         │
│  │  │  netstat -tuln | grep :8080                          │              │         │
│  │  │  Output: tcp 0.0.0.0:8080 LISTEN                     │              │         │
│  │  │  Status: Port 8080 listening ✓                       │              │         │
│  │  │                                                       │              │         │
│  │  │  # Check 2: HTTP Health Endpoint                     │              │         │
│  │  │  curl -f http://localhost:8080/health                │              │         │
│  │  │  Response: {"status":"UP","version":"v1.2.3"}        │              │         │
│  │  │  HTTP Status: 200 OK                                 │              │         │
│  │  │  Status: Health endpoint OK ✓                        │              │         │
│  │  │                                                       │              │         │
│  │  │  # Check 3: Database Connectivity                    │              │         │
│  │  │  curl http://localhost:8080/health/db                │              │         │
│  │  │  Response: {"database":"UP","connectionPool":"OK"}   │              │         │
│  │  │  Status: Database connection OK ✓                    │              │         │
│  │  │                                                       │              │         │
│  │  │  # Check 4: External Dependencies                    │              │         │
│  │  │  curl http://localhost:8080/health/dependencies      │              │         │
│  │  │  Response: {"redis":"UP","kafka":"UP","s3":"UP"}     │              │         │
│  │  │  Status: All dependencies OK ✓                       │              │         │
│  │  │                                                       │              │         │
│  │  │  # Check 5: Resource Usage                           │              │         │
│  │  │  top -bn1 | grep myapp                               │              │         │
│  │  │  CPU: 2.3%  Memory: 512 MB (within limits)          │              │         │
│  │  │  Status: Resource usage normal ✓                     │              │         │
│  │  │                                                       │              │         │
│  │  │  echo "All health checks passed"                     │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 3: Smoke Tests                                                     │         │
│  │  ────────────────────                                                    │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Execute smoke test suite:                           │              │         │
│  │  │                                                       │              │         │
│  │  │  echo "Running smoke tests..."                       │              │         │
│  │  │                                                       │              │         │
│  │  │  # Test 1: API Status Endpoint                       │              │         │
│  │  │  curl -f http://localhost:8080/api/v1/status         │              │         │
│  │  │  Expected: {"status":"running"}                      │              │         │
│  │  │  Status: PASS ✓                                      │              │         │
│  │  │                                                       │              │         │
│  │  │  # Test 2: User Authentication                       │              │         │
│  │  │  curl -X POST http://localhost:8080/api/v1/login \  │              │         │
│  │  │      -d '{"username":"test","password":"test123"}'   │              │         │
│  │  │  Expected: {"token":"..."}                           │              │         │
│  │  │  Status: PASS ✓                                      │              │         │
│  │  │                                                       │              │         │
│  │  │  # Test 3: Database Query                            │              │         │
│  │  │  curl http://localhost:8080/api/v1/users/count       │              │         │
│  │  │  Expected: {"count":1250}                            │              │         │
│  │  │  Status: PASS ✓                                      │              │         │
│  │  │                                                       │              │         │
│  │  │  # Test 4: Cache Functionality                       │              │         │
│  │  │  curl http://localhost:8080/api/v1/cache/test        │              │         │
│  │  │  Response time: 45ms (cached)                        │              │         │
│  │  │  Status: PASS ✓                                      │              │         │
│  │  │                                                       │              │         │
│  │  │  # Test 5: File Upload                               │              │         │
│  │  │  curl -X POST -F "file=@test.txt" \                 │              │         │
│  │  │      http://localhost:8080/api/v1/upload             │              │         │
│  │  │  Expected: {"uploaded":true}                         │              │         │
│  │  │  Status: PASS ✓                                      │              │         │
│  │  │                                                       │              │         │
│  │  │  echo "Smoke tests: 5/5 passed ✓"                    │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Step 4: Register with Load Balancer                                     │         │
│  │  ────────────────────────────────────                                    │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Add VM back to load balancer pool:                  │              │         │
│  │  │                                                       │              │         │
│  │  │  # Register with load balancer                       │              │         │
│  │  │  curl -X POST http://lb.internal:8080/pool \         │              │         │
│  │  │      -d '{"host":"prod-vm-01","port":8080}'          │              │         │
│  │  │  Response: {"registered":true}                       │              │         │
│  │  │  Status: Registered with LB ✓                        │              │         │
│  │  │                                                       │              │         │
│  │  │  # Wait for health checks from LB                    │              │         │
│  │  │  echo "Waiting for LB health checks..."              │              │         │
│  │  │  sleep 30                                            │              │         │
│  │  │                                                       │              │         │
│  │  │  # Verify health status in LB                        │              │         │
│  │  │  curl http://lb.internal:8080/pool/prod-vm-01/health│              │         │
│  │  │  Response: {"status":"healthy","checks":3}           │              │         │
│  │  │  Status: LB health checks passing ✓                  │              │         │
│  │  │                                                       │              │         │
│  │  │  # VM is now receiving production traffic            │              │         │
│  │  │  echo "VM added to production pool"                  │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  Repeat Steps 1-4 for remaining VMs (prod-vm-02 to prod-vm-10)          │         │
│  │  Rolling deployment: One VM at a time                                    │         │
│  │  Total deployment time: ~15 minutes per VM = 150 minutes total          │         │
│  │                                                                           │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  PHASE 6: CONTINUOUS VERIFICATION                                                      │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              HARNESS CD - CONTINUOUS VERIFICATION                        │         │
│  │                                                                           │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Verification Period: 30 minutes                     │              │         │
│  │  │  Start Time: 15:00:00                                │              │         │
│  │  │  End Time: 15:30:00                                  │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Metric Collection from Monitoring Systems:          │              │         │
│  │  │                                                       │              │         │
│  │  │  Prometheus Metrics:                                 │              │         │
│  │  │  ├─ http_requests_total                              │              │         │
│  │  │  │  Baseline (v1.2.2): 1,250 req/min                │              │         │
│  │  │  │  Current (v1.2.3):  1,248 req/min                │              │         │
│  │  │  │  Variance: -0.16%                                 │              │         │
│  │  │  │  Status: PASS ✓                                   │              │         │
│  │  │  │                                                    │              │         │
│  │  │  ├─ http_request_duration_seconds (P95)              │              │         │
│  │  │  │  Baseline: 125ms                                  │              │         │
│  │  │  │  Current: 118ms                                   │              │         │
│  │  │  │  Variance: -5.6% (improvement)                    │              │         │
│  │  │  │  Status: PASS ✓                                   │              │         │
│  │  │  │                                                    │              │         │
│  │  │  ├─ http_request_errors_total                        │              │         │
│  │  │  │  Baseline: 2.5 errors/min (0.2%)                 │              │         │
│  │  │  │  Current: 1.8 errors/min (0.14%)                 │              │         │
│  │  │  │  Variance: -28% (improvement)                     │              │         │
│  │  │  │  Status: PASS ✓                                   │              │         │
│  │  │  │                                                    │              │         │
│  │  │  ├─ cpu_usage_percent                                │              │         │
│  │  │  │  Baseline: 35%                                    │              │         │
│  │  │  │  Current: 32%                                     │              │         │
│  │  │  │  Variance: -8.6% (improvement)                    │              │         │
│  │  │  │  Status: PASS ✓                                   │              │         │
│  │  │  │                                                    │              │         │
│  │  │  └─ memory_usage_bytes                               │              │         │
│  │  │     Baseline: 1.2 GB                                 │              │         │
│  │  │     Current: 1.15 GB                                 │              │         │
│  │  │     Variance: -4.2%                                  │              │         │
│  │  │     Status: PASS ✓                                   │              │         │
│  │  │                                                       │              │         │
│  │  │  Datadog APM Metrics:                                │              │         │
│  │  │  ├─ Average Response Time: 95ms (baseline: 102ms)   │              │         │
│  │  │  ├─ Error Rate: 0.12% (baseline: 0.18%)             │              │         │
│  │  │  ├─ Apdex Score: 0.96 (baseline: 0.94)              │              │         │
│  │  │  └─ Database Query Time: 15ms (baseline: 18ms)      │              │         │
│  │  │                                                       │              │         │
│  │  │  CloudWatch Custom Metrics:                          │              │         │
│  │  │  ├─ Business Transactions: 850/min (baseline: 845)  │              │         │
│  │  │  ├─ User Logins: 125/min (baseline: 122)            │              │         │
│  │  │  └─ API Calls to Partners: 450/min (baseline: 448)  │              │         │
│  │  │                                                       │              │         │
│  │  │  Overall Verification Score: 98/100                  │              │         │
│  │  │  Status: PASS ✓                                      │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  AI/ML Analysis (Harness CV):                        │              │         │
│  │  │                                                       │              │         │
│  │  │  • No anomalies detected                             │              │         │
│  │  │  • Performance patterns normal                       │              │         │
│  │  │  • Error distribution within expected range          │              │         │
│  │  │  • Resource usage stable                             │              │         │
│  │  │  • User experience metrics positive                  │              │         │
│  │  │                                                       │              │         │
│  │  │  Confidence Level: HIGH (95%)                        │              │         │
│  │  │  Recommendation: CONTINUE DEPLOYMENT                 │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Decision: DEPLOYMENT SUCCESSFUL                     │              │         │
│  │  │                                                       │              │         │
│  │  │  • All metrics within acceptable thresholds          │              │         │
│  │  │  • No degradation detected                           │              │         │
│  │  │  • All health checks passing                         │              │         │
│  │  │  • Continuous verification: PASS                     │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: DEPLOYMENT APPROVED ✓                       │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  PHASE 7: COMPLETION & NOTIFICATION                                                    │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐         │
│  │              HARNESS CD - DEPLOYMENT COMPLETION                          │         │
│  │                                                                           │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Deployment Summary:                                  │              │         │
│  │  │                                                       │              │         │
│  │  │  Pipeline: prod-vm-deployment                        │              │         │
│  │  │  Execution ID: exec-20260110-001234                  │              │         │
│  │  │  Service: myapp-vm-service                           │              │         │
│  │  │  Artifact: myapp:v1.2.3                              │              │         │
│  │  │  Environment: Production                             │              │         │
│  │  │  Servers: 10 VMs                                     │              │         │
│  │  │                                                       │              │         │
│  │  │  Start Time: 2026-01-10 14:30:00 UTC                │              │         │
│  │  │  End Time: 2026-01-10 15:45:00 UTC                  │              │         │
│  │  │  Duration: 1 hour 15 minutes                         │              │         │
│  │  │                                                       │              │         │
│  │  │  Status: SUCCESS ✓                                   │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Notifications Sent:                                  │              │         │
│  │  │                                                       │              │         │
│  │  │  📧 Email:                                            │              │         │
│  │  │     To: devops-team@company.com                      │              │         │
│  │  │     Subject: Deployment Success - myapp v1.2.3       │              │         │
│  │  │     Body: Deployment completed successfully          │              │         │
│  │  │                                                       │              │         │
│  │  │  💬 Slack:                                            │              │         │
│  │  │     Channel: #deployments                            │              │         │
│  │  │     Message: ✓ Production deployment successful      │              │         │
│  │  │              myapp v1.2.3 deployed to 10 VMs         │              │         │
│  │  │              Duration: 1h 15m                         │              │         │
│  │  │                                                       │              │         │
│  │  │  📊 Jira:                                             │              │         │
│  │  │     Ticket: DEPLOY-1234                              │              │         │
│  │  │     Status: Updated to "Deployed"                    │              │         │
│  │  │     Comment: Deployed to production successfully     │              │         │
│  │  │                                                       │              │         │
│  │  │  📈 Grafana:                                          │              │         │
│  │  │     Deployment annotation added                      │              │         │
│  │  │     Time: 2026-01-10 15:45:00 UTC                   │              │         │
│  │  │     Version: v1.2.3                                  │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  │         │                                                                 │         │
│  │         ▼                                                                 │         │
│  │  ┌──────────────────────────────────────────────────────┐              │         │
│  │  │  Audit Trail Updated:                                 │              │         │
│  │  │                                                       │              │         │
│  │  │  • Deployment recorded in audit log                  │              │         │
│  │  │  • All actions and their timestamps logged           │              │         │
│  │  │  • User identity captured: john.doe@company.com      │              │         │
│  │  │  • Approval records saved                            │              │         │
│  │  │  • Compliance report generated                       │              │         │
│  │  └──────────────────────────────────────────────────────┘              │         │
│  └───────────────────────────────────────────────────────────────────────────┘         │
│                                                                                         │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│  DEPLOYMENT COMPLETE                                                                   │
│  ════════════════════════════════════════════════════════════════════════════════════  │
│                                                                                         │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## ECS Deployment Architecture

### Detailed ECS Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              HARNESS CD CONTROL PLANE                                    │
│                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐  │
│  │                            PIPELINE EXECUTION ENGINE                              │  │
│  │                                                                                    │  │
│  │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐       │  │
│  │  │   Trigger   │ → │   Build     │ → │   Deploy    │ → │   Verify    │       │  │
│  │  │   Stage     │   │   Stage     │   │   Stage     │   │   Stage     │       │  │
│  │  └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘       │  │
│  │         │                  │                  │                  │                │  │
│  │         └──────────────────┴──────────────────┴──────────────────┘                │  │
│  │                                      │                                             │  │
│  └──────────────────────────────────────┼─────────────────────────────────────────────┘  │
│                                         │                                                │
│  ┌──────────────────────────────────────▼─────────────────────────────────────────────┐  │
│  │                         SERVICE DEFINITION (ECS)                                   │  │
│  │                                                                                    │  │
│  │  Service Name: myapp-ecs-service                                                  │  │
│  │  Type: ECS                                                                        │  │
│  │  Artifacts:                                                                       │  │
│  │    - Type: ECR (Elastic Container Registry)                                      │  │
│  │    - Repository: 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp            │  │
│  │    - Tag: <+pipeline.sequenceId>                                                 │  │
│  │  Task Definition:                                                                 │  │
│  │    - Family: myapp-task                                                          │  │
│  │    - CPU: 256 (0.25 vCPU)                                                        │  │
│  │    - Memory: 512 MB                                                              │  │
│  │    - Network Mode: awsvpc                                                        │  │
│  │    - Launch Type: FARGATE                                                        │  │
│  │  Service Configuration:                                                           │  │
│  │    - Service Name: myapp-service                                                 │  │
│  │    - Desired Count: 10                                                           │  │
│  │    - Load Balancer: Application Load Balancer                                    │  │
│  │    - Target Group: myapp-tg                                                      │  │
│  │    - Health Check: /health (HTTP)                                                │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                         │                                                │
│  ┌──────────────────────────────────────▼─────────────────────────────────────────────┐  │
│  │                    ENVIRONMENT & INFRASTRUCTURE DEFINITIONS                        │  │
│  │                                                                                    │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │  │
│  │  │     DEV      │  │      QA      │  │   STAGING    │  │  PRODUCTION  │      │  │
│  │  │              │  │              │  │              │  │              │      │  │
│  │  │ Infrastructure│  │ Infrastructure│  │ Infrastructure│  │ Infrastructure│      │  │
│  │  │ Type: ECS    │  │ Type: ECS    │  │ Type: ECS    │  │ Type: ECS    │      │  │
│  │  │ Cluster: dev │  │ Cluster: qa  │  │ Cluster: stg │  │ Cluster: prod│      │  │
│  │  │ Region:      │  │ Region:      │  │ Region:      │  │ Region:      │      │  │
│  │  │ us-east-1    │  │ us-east-1    │  │ us-east-1    │  │ us-east-1    │      │  │
│  │  │ Tasks: 2     │  │ Tasks: 3     │  │ Tasks: 5     │  │ Tasks: 10    │      │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘      │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────┬───────────────────────────────────────────────────┘
                                       │
                                       │ WebSocket over HTTPS (TLS 1.3)
                                       │ Outbound Connection Only
                                       │
┌──────────────────────────────────────▼───────────────────────────────────────────────────┐
│                                    AWS CLOUD (VPC)                                       │
│                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐  │
│  │                           DELEGATE CLUSTER (HA)                                   │  │
│  │                         Deployed in Private Subnets                               │  │
│  │                                                                                    │  │
│  │  ┌────────────────────────┐  ┌────────────────────────┐  ┌───────────────────┐ │  │
│  │  │     Delegate-1         │  │     Delegate-2         │  │    Delegate-3     │ │  │
│  │  │     (AZ-1a)            │  │     (AZ-1b)            │  │    (AZ-1c)        │ │  │
│  │  │                        │  │                        │  │                   │ │  │
│  │  │  Responsibilities:     │  │  Responsibilities:     │  │  Responsibilities: │ │  │
│  │  │  • AWS API Calls       │  │  • ECR Authentication  │  │  • Failover       │ │  │
│  │  │  • ECS Operations      │  │  • Service Updates     │  │  • Load Balancing │ │  │
│  │  │  • Task Management     │  │  • Health Monitoring   │  │                   │ │  │
│  │  │                        │  │                        │  │                   │ │  │
│  │  │  IAM Role:             │  │  IAM Role:             │  │  IAM Role:        │ │  │
│  │  │  • AmazonECSFullAccess │  │  • AmazonECSFullAccess │  │  • AmazonECS...   │ │  │
│  │  │  • AmazonEC2ReadOnly   │  │  • AmazonEC2ReadOnly   │  │  • AmazonEC2...   │ │  │
│  │  │  • CloudWatchFullAccess│  │  • CloudWatchFullAccess│  │  • CloudWatch...  │ │  │
│  │  └────────────────────────┘  └────────────────────────┘  └───────────────────┘ │  │
│  │                   │                        │                        │            │  │
│  └───────────────────┼────────────────────────┼────────────────────────┼────────────┘  │
│                      │                        │                        │               │
│                      └────────────────────────┴────────────────────────┘               │
│                                               │                                        │
│                                     AWS API Calls                                      │
│                      ┌────────────────────────┴────────────────────────┐               │
│                      │                                                 │               │
│  ┌───────────────────▼──────────────────┐       ┌────────────────────▼─────────────┐ │
│  │    ELASTIC CONTAINER REGISTRY (ECR)  │       │      ECS CLUSTERS                │ │
│  │                                      │       │                                   │ │
│  │  Repository: myapp                   │       │  ┌──────────────────────────┐   │ │
│  │  Registry: 123456789012.dkr.ecr...  │       │  │  Production Cluster       │   │ │
│  │                                      │       │  │  Name: prod-ecs-cluster   │   │ │
│  │  Images:                             │       │  │  Region: us-east-1        │   │ │
│  │  ├─ myapp:latest                     │       │  │                           │   │ │
│  │  ├─ myapp:v1.2.3                     │       │  │  ┌─────────────────────┐ │   │ │
│  │  ├─ myapp:v1.2.2                     │       │  │  │   ECS Service       │ │   │ │
│  │  ├─ myapp:v1.2.1                     │       │  │  │   Name: myapp-svc   │ │   │ │
│  │  └─ myapp:v1.2.0                     │       │  │  │   Desired: 10       │ │   │ │
│  │                                      │       │  │  │   Running: 10       │ │   │ │
│  │  Image Details (v1.2.3):             │       │  │  │   Launch: FARGATE   │ │   │ │
│  │  • Size: 350 MB                      │       │  │  └─────────────────────┘ │   │ │
│  │  • Layers: 15                        │       │  │                           │   │ │
│  │  • Digest: sha256:def789...         │       │  │  ┌─────────────────────┐ │   │ │
│  │  • Pushed: 2026-01-10 14:00 UTC     │       │  │  │   Task Definition   │ │   │ │
│  │  • Scan Status: No vulnerabilities  │       │  │  │   Family: myapp-task│ │   │ │
│  │                                      │       │  │  │   Revision: 15      │ │   │ │
│  │  Lifecycle Policy:                   │       │  │  │   CPU: 256          │ │   │ │
│  │  • Keep last 10 tagged images        │       │  │  │   Memory: 512 MB    │ │   │ │
│  │  • Expire untagged after 7 days      │       │  │  │   Network: awsvpc   │ │   │ │
│  └──────────────────────────────────────┘       │  │  └─────────────────────┘ │   │ │
│                                                  │  │                           │   │ │
│                                                  │  │  ┌─────────────────────┐ │   │ │
│  ┌──────────────────────────────────────┐       │  │  │   Running Tasks     │ │   │ │
│  │    CLOUDWATCH LOGS                   │       │  │  │                     │ │   │ │
│  │                                      │       │  │  │  Task 1 (AZ-1a)    │ │   │ │
│  │  Log Group: /ecs/myapp               │◄──────┼──┼──│  • IP: 10.0.1.10   │ │   │ │
│  │  Retention: 30 days                  │       │  │  │  • Status: RUNNING │ │   │ │
│  │                                      │       │  │  │  • Health: HEALTHY │ │   │ │
│  │  Log Streams:                        │       │  │  │                     │ │   │ │
│  │  ├─ ecs/myapp-task/task-001          │       │  │  │  Task 2 (AZ-1b)    │ │   │ │
│  │  ├─ ecs/myapp-task/task-002          │       │  │  │  • IP: 10.0.2.10   │ │   │ │
│  │  ├─ ecs/myapp-task/task-003          │       │  │  │  • Status: RUNNING │ │   │ │
│  │  └─ ... (10 tasks)                   │       │  │  │  • Health: HEALTHY │ │   │ │
│  │                                      │       │  │  │                     │ │   │ │
│  │  Recent Logs:                        │       │  │  │  Task 3 (AZ-1c)    │ │   │ │
│  │  [INFO] Application started          │       │  │  │  • IP: 10.0.3.10   │ │   │ │
│  │  [INFO] Connected to database        │       │  │  │  • Status: RUNNING │ │   │ │
│  │  [INFO] Listening on port 8080       │       │  │  │  • Health: HEALTHY │ │   │ │
│  └──────────────────────────────────────┘       │  │  │                     │ │   │ │
│                                                  │  │  │  ... (7 more)      │ │   │ │
│  ┌──────────────────────────────────────┐       │  │  └─────────────────────┘ │   │ │
│  │    CLOUDWATCH METRICS                │       │  └──────────────────────────┘   │ │
│  │                                      │       └───────────────────────────────────┘ │
│  │  ECS Service Metrics:                │                                             │
│  │  ├─ CPUUtilization                   │                                             │
│  │  ├─ MemoryUtilization                │       ┌────────────────────────────────────┐ │
│  │  ├─ TaskCount                        │       │  APPLICATION LOAD BALANCER (ALB)   │ │
│  │  └─ TargetResponseTime               │       │                                    │ │
│  │                                      │       │  Name: myapp-alb                   │ │
│  │  Task Metrics:                       │       │  DNS: myapp-alb-123.elb.aws.com    │ │
│  │  ├─ container_cpu_usage              │       │  Scheme: internet-facing           │ │
│  │  ├─ container_memory_usage           │       │  Security: HTTPS (Port 443)        │ │
│  │  └─ container_network_rx_bytes       │       │  SSL Certificate: *.example.com    │ │
│  │                                      │       │                                    │ │
│  │  Alarms:                             │       │  ┌──────────────────────────────┐ │ │
│  │  ├─ High CPU Usage (> 80%)           │       │  │   Listeners                  │ │ │
│  │  ├─ High Memory (> 85%)              │       │  │                              │ │ │
│  │  └─ Service Unhealthy                │       │  │  HTTPS:443                   │ │ │
│  └──────────────────────────────────────┘       │  │  ├─ Default: Forward to TG  │ │ │
│                                                  │  │  ├─ /api/*: Forward to TG   │ │ │
│                                                  │  │  └─ SSL Policy: ELBSec...   │ │ │
│  ┌──────────────────────────────────────┐       │  │                              │ │ │
│  │    VPC CONFIGURATION                 │       │  │  HTTP:80                     │ │ │
│  │                                      │       │  │  └─ Redirect to HTTPS:443    │ │ │
│  │  VPC: vpc-12345678                   │       │  └──────────────────────────────┘ │ │
│  │  CIDR: 10.0.0.0/16                   │       │                                    │ │
│  │                                      │       │  ┌──────────────────────────────┐ │ │
│  │  Subnets:                            │       │  │   Target Group               │ │ │
│  │  ├─ Public Subnets (ALB)             │       │  │   Name: myapp-tg             │ │ │
│  │  │  ├─ public-1a: 10.0.10.0/24       │       │  │   Protocol: HTTP             │ │ │
│  │  │  ├─ public-1b: 10.0.11.0/24       │       │  │   Port: 8080                 │ │ │
│  │  │  └─ public-1c: 10.0.12.0/24       │       │  │   VPC: vpc-12345678          │ │ │
│  │  │                                   │       │  │                              │ │ │
│  │  ├─ Private Subnets (ECS Tasks)      │       │  │  Health Check:               │ │ │
│  │  │  ├─ private-1a: 10.0.1.0/24       │◄──────┼──┼──• Path: /health            │ │ │
│  │  │  ├─ private-1b: 10.0.2.0/24       │       │  │  • Interval: 30s             │ │ │
│  │  │  └─ private-1c: 10.0.3.0/24       │       │  │  • Timeout: 5s               │ │ │
│  │  │                                   │       │  │  • Healthy threshold: 2      │ │ │
│  │  └─ Private Subnets (Delegates)      │       │  │  • Unhealthy threshold: 3    │ │ │
│  │     ├─ delegate-1a: 10.0.20.0/24     │       │  │                              │ │ │
│  │     ├─ delegate-1b: 10.0.21.0/24     │       │  │  Registered Targets: 10      │ │ │
│  │     └─ delegate-1c: 10.0.22.0/24     │       │  │  Healthy Targets: 10         │ │ │
│  │                                      │       │  │  Draining Targets: 0         │ │ │
│  │  Security Groups:                    │       │  └──────────────────────────────┘ │ │
│  │  ├─ ALB SG: Allow 80, 443 from 0/0   │       │                                    │ │
│  │  ├─ ECS Task SG: Allow 8080 from ALB │       │  Load Balancing Algorithm:         │ │
│  │  └─ Delegate SG: Allow 443 to Harness│       │  └─ Round Robin                    │ │
│  │                                      │       │                                    │ │
│  │  NAT Gateways:                       │       │  Metrics:                          │ │
│  │  ├─ nat-1a (us-east-1a)              │       │  ├─ Active Connections: 2,500      │ │
│  │  ├─ nat-1b (us-east-1b)              │       │  ├─ Request Count: 1,250 req/min   │ │
│  │  └─ nat-1c (us-east-1c)              │       │  ├─ Target Response Time: 95ms     │ │
│  │                                      │       │  └─ HTTP 5xx Errors: 0.1%          │ │
│  └──────────────────────────────────────┘       └────────────────────────────────────┘ │
│                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐  │
│  │                           MONITORING & OBSERVABILITY                              │  │
│  │                                                                                    │  │
│  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐     │  │
│  │  │   Prometheus        │  │   Datadog APM       │  │   X-Ray Tracing     │     │  │
│  │  │   • Container metrics│  │   • Application     │  │   • Distributed     │     │  │
│  │  │   • Custom metrics  │  │     Performance     │  │     Tracing         │     │  │
│  │  │   • Alerting        │  │   • Error tracking  │  │   • Service Map     │     │  │
│  │  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘     │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

I'll continue creating the comprehensive documentation in the next part. Let me save this first part and then create additional detailed sections for ECS deployment flows, network architecture, security architecture, and more.
