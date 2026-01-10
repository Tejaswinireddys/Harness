# Harness CD - Additional Architecture Diagrams

> **Comprehensive Visual Reference for Architects and Engineers**
> **Includes: Sequence Diagrams, Component Diagrams, Dataflow Diagrams, and More**

---

## Table of Contents

1. [VM Deployment Sequence Diagrams](#1-vm-deployment-sequence-diagrams)
2. [ECS Deployment Sequence Diagrams](#2-ecs-deployment-sequence-diagrams)
3. [Component Architecture Diagrams](#3-component-architecture-diagrams)
4. [Data Flow Diagrams](#4-data-flow-diagrams)
5. [Network Topology Diagrams](#5-network-topology-diagrams)
6. [Security Architecture Diagrams](#6-security-architecture-diagrams)
7. [Integration Diagrams](#7-integration-diagrams)
8. [State Machine Diagrams](#8-state-machine-diagrams)

---

## 1. VM Deployment Sequence Diagrams

### 1.1 VM Rolling Deployment - Detailed Sequence

```
Developer    Git Repo    CI Pipeline    Harness CD    Delegate    Target VMs    Monitoring
    |            |            |             |             |            |             |
    |--commit--->|            |             |             |            |             |
    |            |--webhook-->|             |             |            |             |
    |            |            |             |             |            |             |
    |            |            |--build----->|             |            |             |
    |            |            |--test------>|             |            |             |
    |            |            |--package--->|             |            |             |
    |            |            |             |             |            |             |
    |            |            |             |             |            |             |
    |            |            |--artifact-->|             |            |             |
    |            |            |    upload   |             |            |             |
    |            |            |             |             |            |             |
    |            |            |             |             |            |             |
    |<-----------notification---------------|             |            |             |
    |            |            |             |             |            |             |
    |            |            |             |--trigger--->|            |             |
    |            |            |             |  pipeline   |            |             |
    |            |            |             |             |            |             |
    |            |            |             |--fetch----->|            |             |
    |            |            |             |  artifact   |            |             |
    |            |            |             |<--artifact--|            |             |
    |            |            |             |             |            |             |
    |            |            |             |             |            |             |
    |            |            |             |--deploy---->|            |             |
    |            |            |             |  command    |            |             |
    |            |            |             |             |            |             |
    |            |            |             |             |--SSH----->|             |
    |            |            |             |             | connect   |             |
    |            |            |             |             |            |             |
    |            |            |             |             |--backup-->|             |
    |            |            |             |             | current   |             |
    |            |            |             |             |            |             |
    |            |            |             |             |--stop---->|             |
    |            |            |             |             | service   |             |
    |            |            |             |             |            |             |
    |            |            |             |             |--transfer>|             |
    |            |            |             |             | artifact  |             |
    |            |            |             |             |            |             |
    |            |            |             |             |--extract->|             |
    |            |            |             |             |           |             |
    |            |            |             |             |--start--->|             |
    |            |            |             |             | service   |             |
    |            |            |             |             |            |             |
    |            |            |             |             |--health-->|             |
    |            |            |             |             | check     |             |
    |            |            |             |             |<--OK------|             |
    |            |            |             |             |            |             |
    |            |            |             |             |            |--metrics-->|
    |            |            |             |             |            |            |
    |            |            |             |<--success---|            |            |
    |            |            |             |             |            |            |
    |            |            |             |--verify-----|------------|---------->|
    |            |            |             |  metrics    |            |            |
    |            |            |             |<--baseline--|------------|------------|
    |            |            |             |  analysis   |            |            |
    |            |            |             |             |            |            |
    |<-----------notification---------------|             |            |            |
    |   deployment complete                 |             |            |            |

Timeline: ~75 minutes for 10 VMs (rolling)
```

### 1.2 VM Deployment with Rollback Scenario

```
Harness CD    Delegate    VM Instance    Health Check    Monitoring
    |             |            |               |              |
    |--deploy---->|            |               |              |
    |             |--SSH------>|               |              |
    |             |--stop----->|               |              |
    |             | service    |               |              |
    |             |--deploy--->|               |              |
    |             | artifact   |               |              |
    |             |--start---->|               |              |
    |             | service    |               |              |
    |             |            |               |              |
    |             |--health----|-------------->|              |
    |             |  check     |               |              |
    |             |<-----------|------FAIL-----|              |
    |             |            |               |              |
    |<--ROLLBACK--|            |               |              |
    | TRIGGERED   |            |               |              |
    |             |            |               |              |
    |--rollback-->|            |               |              |
    |             |--stop----->|               |              |
    |             | service    |               |              |
    |             |--restore-->|               |              |
    |             | backup     |               |              |
    |             |--start---->|               |              |
    |             | service    |               |              |
    |             |            |               |              |
    |             |--health----|-------------->|              |
    |             |  check     |               |              |
    |             |<-----------|------OK-------|              |
    |             |            |               |              |
    |<--success---|            |               |--verify----->|
    | rollback    |            |               |  metrics     |
    |  complete   |            |               |              |

Rollback Time: 5-10 minutes
```

---

## 2. ECS Deployment Sequence Diagrams

### 2.1 ECS Blue-Green Deployment - Detailed Sequence

```
Developer   ECR     Harness CD   Delegate   ECS API   ALB    Blue Tasks   Green Tasks   CloudWatch
    |        |          |            |         |        |         |            |             |
    |--push-->|          |            |         |        |         |            |             |
    | image   |          |            |         |        |         |            |             |
    |         |          |            |         |        |         |            |             |
    |         |--webhook>|            |         |        |         |            |             |
    |         |          |            |         |        |         |            |             |
    |         |          |--trigger-->|         |        |         |            |             |
    |         |          |  pipeline  |         |        |         |            |             |
    |         |          |            |         |        |         |            |             |
    |         |          |            |--auth-->|        |         |            |             |
    |         |          |            | verify  |        |         |            |             |
    |         |          |            |<--ok----|        |         |            |             |
    |         |          |            |         |        |         |            |             |
    |         |          |            |--create>|        |         |            |             |
    |         |          |            |  task   |        |         |            |             |
    |         |          |            | definition       |         |            |             |
    |         |          |            |<--rev#--|        |         |            |             |
    |         |          |            |         |        |         |            |             |
    |         |          |            |--create>|        |         |            |             |
    |         |          |            | green   |        |         |---create-->|             |
    |         |          |            | service |        |         |            |             |
    |         |          |            |         |        |         |<--running--|             |
    |         |          |            |         |        |         |            |             |
    |         |          |            |--health>|        |         |----check-->|             |
    |         |          |            | check   |        |         |            |             |
    |         |          |            |         |        |         |<---OK------|             |
    |         |          |            |         |        |         |            |             |
    |         |          |            |--config>|        |         |            |             |
    |         |          |            |  ALB    |------->|         |            |             |
    |         |          |            | listener|        |         |            |             |
    |         |          |            |         |        |         |            |             |
    |         |          |            |         |        |--10%--->|----------->|             |
    |         |          |            |         |        | traffic |            |             |
    |         |          |            |         |        |         |            |             |
    |         |          |            |         |        |         |            |--metrics--->|
    |         |          |            |         |        |         |            |             |
    |         |          |            |<--------|--------|---------|-------verify-------------|
    |         |          |            |         |        |         |            |             |
    |         |          |            |         |        |--50%--->|----------->|             |
    |         |          |            |         |        | traffic |            |             |
    |         |          |            |         |        |         |            |--metrics--->|
    |         |          |            |<--------|--------|---------|-------verify-------------|
    |         |          |            |         |        |         |            |             |
    |         |          |            |         |        |-100%--->|----------->|             |
    |         |          |            |         |        | traffic |            |             |
    |         |          |            |         |        |         |            |             |
    |         |          |            |         |        |         |            |--metrics--->|
    |         |          |            |<--------|--------|---------|-------verify-------------|
    |         |          |            |         |        |         |            |             |
    |         |          |            |--delete>|        |         |            |             |
    |         |          |            |  blue   |--------|-terminate            |             |
    |         |          |            | service |        |         |            |             |
    |         |          |<--success--|         |        |         |            |             |
    |         |          |            |         |        |         |            |             |
    |<--------notification-----------|         |        |         |            |             |
    | deployment complete             |         |        |         |            |             |

Timeline: ~55 minutes including verification
Traffic Shift: 10% → 50% → 100% over 20 minutes
```

### 2.2 ECS Canary Deployment Sequence

```
Harness CD   Delegate   ECS Cluster   ALB Traffic   Monitoring   Decision
    |            |            |            |             |            |
    |--deploy--->|            |            |             |            |
    |            |--create--->|            |             |            |
    |            | canary     |            |             |            |
    |            | version    |            |             |            |
    |            |            |            |             |            |
    |            |            |<--10%------|             |            |
    |            |            | traffic    |             |            |
    |            |            |            |--metrics--->|            |
    |            |            |            |             |            |
    |            |            |            |             |--analyze-->|
    |            |            |            |             |            |
    |            |            |            |             |<--PASS-----|
    |            |            |            |             |            |
    |            |            |<--25%------|             |            |
    |            |            | traffic    |             |            |
    |            |            |            |--metrics--->|            |
    |            |            |            |             |            |
    |            |            |            |             |--analyze-->|
    |            |            |            |             |            |
    |            |            |            |             |<--PASS-----|
    |            |            |            |             |            |
    |            |            |<--50%------|             |            |
    |            |            | traffic    |             |            |
    |            |            |            |--metrics--->|            |
    |            |            |            |             |            |
    |            |            |            |             |--analyze-->|
    |            |            |            |             |            |
    |            |            |            |             |<--PASS-----|
    |            |            |            |             |            |
    |            |            |<-100%------|             |            |
    |            |            | traffic    |             |            |
    |            |            |            |             |            |
    |<--success--|            |            |             |            |

Progressive Rollout: 10% → 25% → 50% → 100%
Analysis at each stage: 5-10 minutes
Total Time: ~35-45 minutes
```

---

## 3. Component Architecture Diagrams

### 3.1 Harness CD Platform Components

```
┌─────────────────────────────────────────────────────────────────────┐
│                     HARNESS CD PLATFORM (SaaS)                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐      │
│  │   Pipeline     │  │   Service      │  │  Environment   │      │
│  │   Manager      │  │   Registry     │  │  Manager       │      │
│  │                │  │                │  │                │      │
│  │ • Orchestration│  │ • Definitions  │  │ • Infra Defs   │      │
│  │ • Execution    │  │ • Artifacts    │  │ • Variables    │      │
│  │ • Scheduling   │  │ • Manifests    │  │ • Overrides    │      │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘      │
│           │                   │                   │               │
│  ┌────────┴───────────────────┴───────────────────┴────────┐     │
│  │              Harness Manager (Control Plane)             │     │
│  │                                                           │     │
│  │  • User Management & RBAC                                │     │
│  │  • API Gateway                                           │     │
│  │  • Audit & Compliance                                    │     │
│  │  • Secrets Management Integration                        │     │
│  │  • Continuous Verification Engine (AI/ML)                │     │
│  └─────────────────────────┬─────────────────────────────────┘     │
│                            │                                       │
└────────────────────────────┼───────────────────────────────────────┘
                             │ (Encrypted Channel - TLS 1.3)
                             │
                ┌────────────┴────────────┐
                │                         │
    ┌───────────▼───────────┐ ┌───────────▼───────────┐
    │   Delegate - VM       │ │   Delegate - K8s      │
    │   (Customer Network)  │ │   (Customer Network)  │
    ├───────────────────────┤ ├───────────────────────┤
    │                       │ │                       │
    │ • SSH Client          │ │ • kubectl CLI         │
    │ • SCP/SFTP            │ │ • Helm                │
    │ • Script Executor     │ │ • AWS CLI             │
    │ • Health Checker      │ │ • ECS CLI             │
    │ • Log Collector       │ │ • Docker Client       │
    │ • Metric Collector    │ │ • Terraform           │
    │                       │ │                       │
    └───────────┬───────────┘ └───────────┬───────────┘
                │                         │
    ┌───────────▼───────────┐ ┌───────────▼───────────┐
    │   Target VMs          │ │   ECS Cluster         │
    │   (10+ instances)     │ │   (Fargate Tasks)     │
    └───────────────────────┘ └───────────────────────┘
```

### 3.2 VM Deployment Component Breakdown

```
┌─────────────────────────────────────────────────────────────────┐
│                    VM DEPLOYMENT ARCHITECTURE                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────┐
│ Source Control  │
│                 │
│ • Git           │──┐
│ • GitHub        │  │
│ • GitLab        │  │
│ • Bitbucket     │  │
└─────────────────┘  │
                     │   Webhook
                     │
                     ▼
┌─────────────────┐        ┌─────────────────┐
│ CI Pipeline     │        │ Artifact Store  │
│                 │        │                 │
│ • Jenkins       │───────>│ • Artifactory   │
│ • GitLab CI     │ Build  │ • Nexus         │
│ • GitHub Actions│ Artifact│ • S3            │
│ • CircleCI      │        │ • Docker Hub    │
└─────────────────┘        └────────┬────────┘
                                    │
                                    │ Pull Artifact
                                    │
                                    ▼
                          ┌─────────────────┐
                          │ Harness Manager │
                          │                 │
                          │ • Pipeline Eng. │
                          │ • Verification  │
                          └────────┬────────┘
                                   │
                                   │ Deploy Command
                                   │
                                   ▼
                          ┌─────────────────┐
                          │ Harness Delegate│
                          │ (VM or Container)│
                          │                 │
                          │ Components:     │
                          │ • Task Executor │
                          │ • SSH Manager   │
                          │ • File Transfer │
                          │ • Health Monitor│
                          └────────┬────────┘
                                   │
                     SSH Connection (Port 22)
                                   │
            ┌──────────────────────┼──────────────────────┐
            │                      │                      │
            ▼                      ▼                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ VM Instance 1   │    │ VM Instance 2   │    │ VM Instance N   │
│                 │    │                 │    │                 │
│ Components:     │    │ Components:     │    │ Components:     │
│ • App Runtime   │    │ • App Runtime   │    │ • App Runtime   │
│ • System Service│    │ • System Service│    │ • System Service│
│ • Health Endpoint    │ • Health Endpoint    │ • Health Endpoint│
│ • Log Files     │    │ • Log Files     │    │ • Log Files     │
│ • Metrics       │    │ • Metrics       │    │ • Metrics       │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                                 │ Metrics & Logs
                                 │
                                 ▼
                    ┌─────────────────────┐
                    │ Monitoring System   │
                    │                     │
                    │ • CloudWatch        │
                    │ • Prometheus        │
                    │ • Datadog           │
                    │ • ELK Stack         │
                    └─────────────────────┘
```

### 3.3 ECS Deployment Component Breakdown

```
┌─────────────────────────────────────────────────────────────────┐
│                   ECS DEPLOYMENT ARCHITECTURE                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────┐
│ Developer       │
│ Workstation     │
│                 │
│ • Docker Build  │──┐
│ • Image Tag     │  │ Push
└─────────────────┘  │
                     ▼
              ┌─────────────────┐
              │ ECR (Registry)  │
              │                 │
              │ • Image Storage │
              │ • Versioning    │
              │ • Scanning      │
              └────────┬────────┘
                       │
                       │ Webhook / Poll
                       │
                       ▼
              ┌─────────────────┐
              │ Harness Manager │
              │                 │
              │ Pipeline:       │
              │ • Blue-Green    │
              │ • Canary        │
              │ • Verification  │
              └────────┬────────┘
                       │
                       │ Deploy Command
                       │
                       ▼
              ┌─────────────────┐
              │ Harness Delegate│
              │ (in VPC)        │
              │                 │
              │ Components:     │
              │ • AWS SDK       │
              │ • ECS Client    │
              │ • ALB Manager   │
              │ • CloudWatch API│
              └────────┬────────┘
                       │
                       │ API Calls
                       │
                       ▼
           ┌───────────────────────┐
           │    AWS ECS Service    │
           │                       │
           │ • Task Definitions    │
           │ • Service Config      │
           │ • Scaling Policies    │
           └───────────┬───────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│Blue Target  │ │Green Target │ │  Fargate    │
│   Group     │ │   Group     │ │  Capacity   │
│             │ │             │ │             │
│ • Port 8080 │ │ • Port 8080 │ │ • CPU/Mem   │
│ • Health    │ │ • Health    │ │ • Network   │
└──────┬──────┘ └──────┬──────┘ └──────┬──────┘
       │               │               │
       └───────────────┼───────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  Application    │
              │  Load Balancer  │
              │                 │
              │ • Listener Rules│
              │ • Traffic Split │
              │ • Health Checks │
              └────────┬────────┘
                       │
                       │ HTTP/HTTPS
                       │
                       ▼
              ┌─────────────────┐
              │   End Users     │
              └─────────────────┘

┌─────────────────────────────────────────┐
│     Supporting Components               │
├─────────────────────────────────────────┤
│                                         │
│  CloudWatch:                            │
│  • Container Insights                   │
│  • Metrics & Logs                       │
│  • Alarms                               │
│                                         │
│  IAM:                                   │
│  • Task Execution Role                  │
│  • Task Role                            │
│  • Delegate Role                        │
│                                         │
│  VPC:                                   │
│  • Private Subnets (Tasks)              │
│  • Public Subnets (ALB)                 │
│  • Security Groups                      │
│  • NAT Gateway                          │
│                                         │
│  Secrets Manager:                       │
│  • DB Credentials                       │
│  • API Keys                             │
│  • Certificates                         │
└─────────────────────────────────────────┘
```

---

## 4. Data Flow Diagrams

### 4.1 VM Deployment Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                   VM DEPLOYMENT DATA FLOW                        │
└─────────────────────────────────────────────────────────────────┘

   PHASE 1: ARTIFACT PREPARATION
   ═════════════════════════════

   Code Changes ──> Git Repository ──> CI Pipeline
        │                                    │
        │                                    ▼
        │                          [ Build & Test ]
        │                                    │
        │                                    ▼
        │                          [ Create Artifact ]
        │                          (app-v1.2.3.tar.gz)
        │                                    │
        │                                    ▼
        └─────────────────────────> Artifact Repository
                                    (Artifactory/S3)


   PHASE 2: PIPELINE TRIGGER & INITIALIZATION
   ══════════════════════════════════════════

   Manual Trigger / Webhook ──> Harness Manager
                                       │
                                       ▼
                           [ Validate Pipeline Config ]
                                       │
                                       ▼
                           [ Load Service Definition ]
                                       │
                                       ▼
                           [ Load Infrastructure Def ]
                                       │
                                       ▼
                           [ Initialize Execution ]
                           (Execution ID: exec-12345)


   PHASE 3: ARTIFACT DOWNLOAD
   ══════════════════════════

   Harness Manager ──> Delegate: "Fetch artifact"
                           │
                           ▼
                   [ Connect to Repository ]
                           │
                           ▼
                   [ Download app-v1.2.3.tar.gz ]
                           │
                           ▼
                   [ Verify Checksum ]
                           │
                           ▼
                   [ Cache Locally ]
                   (/opt/harness/artifacts/)


   PHASE 4: PRE-DEPLOYMENT
   ═══════════════════════

   Delegate ──SSH──> Target VM
                         │
                         ▼
                [ Create Backup Directory ]
                /opt/myapp.backup/
                         │
                         ▼
                [ Copy Current Version ]
                cp -r /opt/myapp/* /opt/myapp.backup/
                         │
                         ▼
                [ Stop Application Service ]
                systemctl stop myapp
                         │
                         ▼
                [ Verify Service Stopped ]


   PHASE 5: DEPLOYMENT EXECUTION
   ═════════════════════════════

   Delegate ──SCP──> Target VM
       │                 │
       │                 ▼
       │         [ Transfer Artifact ]
       │         app-v1.2.3.tar.gz → /tmp/
       │                 │
       │                 ▼
       │         [ Extract Archive ]
       │         tar -xzf app-v1.2.3.tar.gz
       │                 │
       │                 ▼
       │         [ Move Files ]
       │         mv /tmp/app/* /opt/myapp/
       │                 │
       │                 ▼
       │         [ Set Permissions ]
       │         chmod +x /opt/myapp/bin/*
       │                 │
       │                 ▼
       │         [ Update Configuration ]
       │         (Environment-specific configs)


   PHASE 6: POST-DEPLOYMENT
   ════════════════════════

   Target VM:
         │
         ▼
   [ Start Application Service ]
   systemctl start myapp
         │
         ▼
   [ Wait for Startup ]
   (sleep 10)
         │
         ▼
   [ Health Check ]
   curl http://localhost:8080/health
         │
         ▼
   [ Verify Response: HTTP 200 ]
         │
         ▼
   [ Run Smoke Tests ]
   curl http://localhost:8080/api/version
         │
         ▼
   [ Success ] ──> Report to Delegate


   PHASE 7: CONTINUOUS VERIFICATION
   ════════════════════════════════

   Monitoring System ──> Harness CV Engine
   (CloudWatch/Prometheus)       │
         │                       ▼
         │              [ Collect Metrics ]
         │              • CPU Usage
         │              • Memory Usage
         │              • Error Rate
         │              • Response Time
         │                       │
         │                       ▼
         │              [ Compare Baseline ]
         │              (ML-based Analysis)
         │                       │
         │                       ▼
         │              [ Risk Assessment ]
         │              Low / Medium / High
         │                       │
         │                       ▼
         └─────────────[ Decision Point ]
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
              [ Continue ]            [ Rollback ]
              (Risk: Low)             (Risk: High)


   PHASE 8: ROLLBACK (IF NEEDED)
   ═════════════════════════════

   Harness Manager ──> Delegate ──SSH──> Target VM
                                             │
                                             ▼
                                   [ Stop Current Service ]
                                   systemctl stop myapp
                                             │
                                             ▼
                                   [ Remove New Version ]
                                   rm -rf /opt/myapp/*
                                             │
                                             ▼
                                   [ Restore Backup ]
                                   cp -r /opt/myapp.backup/* /opt/myapp/
                                             │
                                             ▼
                                   [ Start Service ]
                                   systemctl start myapp
                                             │
                                             ▼
                                   [ Verify Health ]
                                   curl http://localhost:8080/health
```

### 4.2 ECS Blue-Green Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              ECS BLUE-GREEN DEPLOYMENT DATA FLOW                 │
└─────────────────────────────────────────────────────────────────┘

   PHASE 1: IMAGE BUILD & PUSH
   ═══════════════════════════

   Developer Workstation:
         │
         ▼
   [ Docker Build ]
   docker build -t myapp:v1.2.3 .
         │
         ▼
   [ Docker Tag ]
   docker tag myapp:v1.2.3 123456.dkr.ecr.us-east-1.amazonaws.com/myapp:v1.2.3
         │
         ▼
   [ ECR Authentication ]
   aws ecr get-login-password | docker login ...
         │
         ▼
   [ Push to ECR ]
   docker push 123456.dkr.ecr.us-east-1.amazonaws.com/myapp:v1.2.3
         │
         ▼
   [ ECR Webhook ] ──> Harness Manager


   PHASE 2: TASK DEFINITION CREATION
   ═════════════════════════════════

   Harness Manager ──> Delegate (AWS VPC)
                           │
                           ▼
                   [ Get Current Task Definition ]
                   aws ecs describe-task-definition \
                     --task-definition myapp-prod
                           │
                           ▼
                   [ Create New Revision ]
                   {
                     "family": "myapp-prod",
                     "revision": 456,
                     "containerDefinitions": [{
                       "name": "myapp",
                       "image": "123456.dkr...myapp:v1.2.3",
                       "cpu": 1024,
                       "memory": 2048,
                       ...
                     }]
                   }
                           │
                           ▼
                   [ Register Task Definition ]
                   aws ecs register-task-definition ...
                           │
                           ▼
                   [ Return: myapp-prod:456 ]


   PHASE 3: GREEN SERVICE CREATION
   ═══════════════════════════════

   Delegate ──> AWS ECS API
                    │
                    ▼
            [ Create Green Service ]
            aws ecs create-service \
              --cluster prod-cluster \
              --service-name myapp-green \
              --task-definition myapp-prod:456 \
              --desired-count 10 \
              --launch-type FARGATE
                    │
                    ▼
            [ Provision Fargate Tasks ]
            (10 tasks starting)
                    │
                    ▼
            [ Wait for Running State ]
            (Poll every 10 seconds)
                    │
                    ▼
            [ All Tasks Running ]


   PHASE 4: HEALTH CHECK VERIFICATION
   ══════════════════════════════════

   Green Service ──> ALB Target Group (Green)
                            │
                            ▼
                  [ Register Targets ]
                  (10 Fargate tasks)
                            │
                            ▼
                  [ ALB Health Checks ]
                  GET /health (Port 8080)
                  Interval: 30s
                  Timeout: 5s
                  Healthy threshold: 2
                            │
                            ▼
                  [ All Targets Healthy ]
                            │
                            ▼
                  Report to Delegate ──> Harness Manager


   PHASE 5: TRAFFIC SHIFT - Stage 1 (10%)
   ══════════════════════════════════════

   Harness Manager ──> Delegate ──> AWS ECS/ALB API
                                         │
                                         ▼
                              [ Update ALB Listener Rule ]
                              aws elbv2 modify-rule \
                                --rule-arn ... \
                                --actions Type=forward,ForwardConfig={
                                  TargetGroups=[
                                    {TargetGroupArn=blue-tg,Weight=90},
                                    {TargetGroupArn=green-tg,Weight=10}
                                  ]
                                }
                                         │
                                         ▼
                              [ Traffic Distribution ]
                              Blue: 90% (1,125 req/min)
                              Green: 10% (125 req/min)


   PHASE 6: MONITORING - Stage 1
   ════════════════════════════

   Green Tasks ──> CloudWatch Metrics
                         │
                         ▼
                 [ Collect Metrics ]
                 • CPU Utilization: 45%
                 • Memory Usage: 60%
                 • Request Count: 125/min
                 • Error Rate: 0.1%
                 • Response Time: 120ms
                         │
                         ▼
                 [ Send to Harness CV ]
                         │
                         ▼
   Harness CV Engine:
                 [ Compare vs Blue Baseline ]
                 • Error Rate: 0.1% vs 0.15% ✓
                 • Response Time: 120ms vs 125ms ✓
                 • No Anomalies Detected ✓
                         │
                         ▼
                 [ Decision: PASS ]
                 Proceed to 50% traffic


   PHASE 7: TRAFFIC SHIFT - Stage 2 (50%)
   ══════════════════════════════════════

   [ Update ALB Listener Rule ]
   Blue: 50% (625 req/min)
   Green: 50% (625 req/min)
         │
         ▼
   [ Monitor for 10 minutes ]
         │
         ▼
   [ Metrics Analysis ]
   All metrics within threshold ✓
         │
         ▼
   [ Decision: PASS ]
   Proceed to 100% traffic


   PHASE 8: TRAFFIC SHIFT - Stage 3 (100%)
   ═══════════════════════════════════════

   [ Update ALB Listener Rule ]
   Blue: 0%
   Green: 100% (1,250 req/min)
         │
         ▼
   [ Monitor for 15 minutes ]
         │
         ▼
   [ Final Verification ]
   All metrics stable ✓
         │
         ▼
   [ Mark Deployment Successful ]


   PHASE 9: CLEANUP
   ═══════════════

   Harness Manager ──> Delegate
                         │
                         ▼
                 [ Delete Blue Service ]
                 aws ecs delete-service \
                   --cluster prod-cluster \
                   --service myapp-blue \
                   --force
                         │
                         ▼
                 [ Terminate Blue Tasks ]
                 (10 tasks stopping)
                         │
                         ▼
                 [ Cleanup Complete ]


   ROLLBACK SCENARIO (IF NEEDED)
   ════════════════════════════

   [ Anomaly Detected ] (e.g., Error Rate > 5%)
         │
         ▼
   [ Immediate Traffic Revert ]
   Blue: 100%
   Green: 0%
         │
         ▼
   [ Delete Green Service ]
         │
         ▼
   [ Rollback Complete ]
   (< 1 minute total time)


   DATA FLOW SUMMARY
   ════════════════

   Total Data Transferred:
   • Docker Image: ~500 MB (ECR push)
   • Task Definition: ~5 KB (JSON)
   • Health Check Data: ~100 KB (monitoring)
   • Metrics Data: ~10 MB (30 min verification)
   • API Calls: ~200 requests (AWS APIs)

   Network Bandwidth:
   • Peak: ~50 Mbps (image pull to 10 tasks)
   • Average: ~5 Mbps (monitoring & logs)

   Total Deployment Time:
   • Phase 1: 5 min (image build/push)
   • Phase 2-4: 10 min (task definition & green creation)
   • Phase 5-8: 35 min (traffic shift & monitoring)
   • Phase 9: 5 min (cleanup)
   • Total: ~55 minutes
```

---

## 5. Network Topology Diagrams

### 5.1 Multi-AZ VPC Architecture for ECS

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS REGION (us-east-1)                    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  VPC: 10.0.0.0/16                         │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐│  │
│  │  │  Availability Zone A (us-east-1a)                    ││  │
│  │  │                                                       ││  │
│  │  │  ┌─────────────────────┐  ┌─────────────────────┐   ││  │
│  │  │  │ Public Subnet       │  │ Private Subnet      │   ││  │
│  │  │  │ 10.0.1.0/24         │  │ 10.0.11.0/24        │   ││  │
│  │  │  │                     │  │                     │   ││  │
│  │  │  │ ┌─────────────────┐│  │ ┌─────────────────┐ │   ││  │
│  │  │  │ │  ALB (AZ-A)     ││  │ │ ECS Tasks (3)   │ │   ││  │
│  │  │  │ │  10.0.1.10      ││  │ │ 10.0.11.20-22   │ │   ││  │
│  │  │  │ └─────────────────┘│  │ └─────────────────┘ │   ││  │
│  │  │  │                     │  │                     │   ││  │
│  │  │  │ ┌─────────────────┐│  │ ┌─────────────────┐ │   ││  │
│  │  │  │ │  NAT Gateway    ││  │ │ Harness Delegate│ │   ││  │
│  │  │  │ │  10.0.1.5       ││  │ │ 10.0.11.50      │ │   ││  │
│  │  │  │ └─────────────────┘│  │ └─────────────────┘ │   ││  │
│  │  │  └─────────────────────┘  └─────────────────────┘   ││  │
│  │  └───────────────────────────────────────────────────────┘│  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐│  │
│  │  │  Availability Zone B (us-east-1b)                    ││  │
│  │  │                                                       ││  │
│  │  │  ┌─────────────────────┐  ┌─────────────────────┐   ││  │
│  │  │  │ Public Subnet       │  │ Private Subnet      │   ││  │
│  │  │  │ 10.0.2.0/24         │  │ 10.0.12.0/24        │   ││  │
│  │  │  │                     │  │                     │   ││  │
│  │  │  │ ┌─────────────────┐│  │ ┌─────────────────┐ │   ││  │
│  │  │  │ │  ALB (AZ-B)     ││  │ │ ECS Tasks (4)   │ │   ││  │
│  │  │  │ │  10.0.2.10      ││  │ │ 10.0.12.20-23   │ │   ││  │
│  │  │  │ └─────────────────┘│  │ └─────────────────┘ │   ││  │
│  │  │  │                     │  │                     │   ││  │
│  │  │  │ ┌─────────────────┐│  │                     │   ││  │
│  │  │  │ │  NAT Gateway    ││  │                     │   ││  │
│  │  │  │ │  10.0.2.5       ││  │                     │   ││  │
│  │  │  │ └─────────────────┘│  │                     │   ││  │
│  │  │  └─────────────────────┘  └─────────────────────┘   ││  │
│  │  └───────────────────────────────────────────────────────┘│  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐│  │
│  │  │  Availability Zone C (us-east-1c)                    ││  │
│  │  │                                                       ││  │
│  │  │  ┌─────────────────────┐  ┌─────────────────────┐   ││  │
│  │  │  │ Public Subnet       │  │ Private Subnet      │   ││  │
│  │  │  │ 10.0.3.0/24         │  │ 10.0.13.0/24        │   ││  │
│  │  │  │                     │  │                     │   ││  │
│  │  │  │ ┌─────────────────┐│  │ ┌─────────────────┐ │   ││  │
│  │  │  │ │  ALB (AZ-C)     ││  │ │ ECS Tasks (3)   │ │   ││  │
│  │  │  │ │  10.0.3.10      ││  │ │ 10.0.13.20-22   │ │   ││  │
│  │  │  │ └─────────────────┘│  │ └─────────────────┘ │   ││  │
│  │  │  │                     │  │                     │   ││  │
│  │  │  │ ┌─────────────────┐│  │                     │   ││  │
│  │  │  │ │  NAT Gateway    ││  │                     │   ││  │
│  │  │  │ │  10.0.3.5       ││  │                     │   ││  │
│  │  │  │ └─────────────────┘│  │                     │   ││  │
│  │  │  └─────────────────────┘  └─────────────────────┘   ││  │
│  │  └───────────────────────────────────────────────────────┘│  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐│  │
│  │  │  VPC Endpoints (PrivateLink)                         ││  │
│  │  │                                                       ││  │
│  │  │  • com.amazonaws.us-east-1.ecr.dkr                   ││  │
│  │  │  • com.amazonaws.us-east-1.ecr.api                   ││  │
│  │  │  • com.amazonaws.us-east-1.s3                        ││  │
│  │  │  • com.amazonaws.us-east-1.logs                      ││  │
│  │  │  • com.amazonaws.us-east-1.secretsmanager            ││  │
│  │  └──────────────────────────────────────────────────────┘│  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐│  │
│  │  │  Internet Gateway                                     ││  │
│  │  │  igw-12345678                                         ││  │
│  │  └──────────────────────────────────────────────────────┘│  │
│  │                              ▲                             │  │
│  └──────────────────────────────┼─────────────────────────────┘  │
│                                 │                                │
└─────────────────────────────────┼────────────────────────────────┘
                                  │
                          ┌───────┴───────┐
                          │   Internet    │
                          │  (0.0.0.0/0)  │
                          └───────────────┘

NETWORK FLOW PATHS:

1. User Traffic:
   Internet → Internet Gateway → ALB (Public Subnets)
   → ECS Tasks (Private Subnets)

2. Outbound Traffic from Tasks:
   ECS Tasks → NAT Gateway → Internet Gateway → Internet

3. AWS Service Communication:
   ECS Tasks → VPC Endpoints → AWS Services (ECR, S3, etc.)

4. Harness Delegate Communication:
   Delegate (Private Subnet) → NAT Gateway → Internet
   → Harness SaaS Platform

SECURITY GROUPS:

ALB Security Group:
  Inbound: Port 443 (HTTPS) from 0.0.0.0/0
  Outbound: Port 8080 to ECS Tasks SG

ECS Tasks Security Group:
  Inbound: Port 8080 from ALB SG
  Outbound: Port 443 to VPC Endpoints

Delegate Security Group:
  Inbound: None
  Outbound: Port 443 to 0.0.0.0/0 (Harness platform)
```

### 5.2 VM Deployment Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                    ON-PREMISE / CLOUD VPC                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  DMZ / Public Zone                                        │  │
│  │                                                            │  │
│  │  ┌─────────────────┐       ┌─────────────────┐           │  │
│  │  │ Load Balancer   │       │  Bastion Host   │           │  │
│  │  │ 10.0.1.10       │       │  10.0.1.20      │           │  │
│  │  │ (HAProxy/Nginx) │       │  (SSH Gateway)  │           │  │
│  │  └────────┬────────┘       └────────┬────────┘           │  │
│  │           │                         │                     │  │
│  └───────────┼─────────────────────────┼─────────────────────┘  │
│              │                         │                        │
│  ┌───────────┼─────────────────────────┼─────────────────────┐  │
│  │  Application Zone (Private)         │                     │  │
│  │           │                         │                     │  │
│  │  ┌────────▼───────────┐             │                     │  │
│  │  │  App VMs (Cluster) │             │                     │  │
│  │  │                    │             │                     │  │
│  │  │  ┌──────────────┐  │             │                     │  │
│  │  │  │ VM-APP-01    │<─┼─────────────┘                     │  │
│  │  │  │ 10.0.10.11   │  │ SSH (Port 22)                     │  │
│  │  │  │              │  │                                    │  │
│  │  │  │ App: Port 8080│ │                                    │  │
│  │  │  └──────────────┘  │                                    │  │
│  │  │                    │                                    │  │
│  │  │  ┌──────────────┐  │                                    │  │
│  │  │  │ VM-APP-02    │<─┼─────────────┐                     │  │
│  │  │  │ 10.0.10.12   │  │ SSH          │                     │  │
│  │  │  │              │  │              │                     │  │
│  │  │  │ App: Port 8080│ │              │                     │  │
│  │  │  └──────────────┘  │              │                     │  │
│  │  │                    │              │                     │  │
│  │  │  ┌──────────────┐  │              │                     │  │
│  │  │  │ VM-APP-03    │<─┼──────────────┤                     │  │
│  │  │  │ 10.0.10.13   │  │ SSH          │                     │  │
│  │  │  │              │  │              │                     │  │
│  │  │  │ App: Port 8080│ │              │                     │  │
│  │  │  └──────────────┘  │              │                     │  │
│  │  │         ...        │              │                     │  │
│  │  │  ┌──────────────┐  │              │                     │  │
│  │  │  │ VM-APP-10    │<─┼──────────────┘                     │  │
│  │  │  │ 10.0.10.20   │  │                                    │  │
│  │  │  └──────────────┘  │                                    │  │
│  │  └────────────────────┘                                    │  │
│  │                                                             │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Management Zone                                          │  │
│  │                                                            │  │
│  │  ┌─────────────────┐       ┌─────────────────┐           │  │
│  │  │ Harness Delegate│       │ Artifact Store  │           │  │
│  │  │ 10.0.20.10      │       │ 10.0.20.20      │           │  │
│  │  │                 │───────│ (Artifactory)   │           │  │
│  │  │ • SSH Client    │       │                 │           │  │
│  │  │ • Kubectl       │       └─────────────────┘           │  │
│  │  │ • AWS CLI       │                                      │  │
│  │  └────────┬────────┘                                      │  │
│  │           │                                                │  │
│  │           │ HTTPS (443)                                    │  │
│  │           │ to Harness SaaS                                │  │
│  └───────────┼────────────────────────────────────────────────┘  │
│              │                                                   │
└──────────────┼───────────────────────────────────────────────────┘
               │
               ▼
       ┌───────────────┐
       │  Firewall /   │
       │  NAT Gateway  │
       └───────┬───────┘
               │
               ▼
       ┌───────────────┐
       │   Internet    │
       │               │
       └───────┬───────┘
               │
               ▼
   ┌───────────────────────┐
   │  Harness SaaS         │
   │  app.harness.io       │
   │  (Control Plane)      │
   └───────────────────────┘


NETWORK SEGMENTATION:

1. DMZ (10.0.1.0/24):
   • Load Balancer
   • Bastion Host
   • Exposed to Internet

2. Application Zone (10.0.10.0/24):
   • Application VMs
   • No direct Internet access
   • Access via SSH through Bastion

3. Management Zone (10.0.20.0/24):
   • Harness Delegate
   • Artifact Repository
   • Monitoring Tools
   • Outbound Internet access only


FIREWALL RULES:

Internet → DMZ:
  • Port 443 (HTTPS) to Load Balancer
  • Port 22 (SSH) to Bastion (restricted IPs)

DMZ → Application Zone:
  • Port 8080 from Load Balancer to App VMs
  • Port 22 from Bastion to App VMs

Management Zone → Application Zone:
  • Port 22 from Delegate to App VMs (deployment)

Management Zone → Internet:
  • Port 443 to Harness SaaS
  • Port 443 to Artifactory/ECR

Application Zone → Internet:
  • Blocked (all outbound goes via proxy if needed)
```

---

## 6. Security Architecture Diagrams

### 6.1 Security Layers Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS (Defense in Depth)            │
└─────────────────────────────────────────────────────────────────┘

  LAYER 1: PLATFORM SECURITY
  ═══════════════════════════
  ┌─────────────────────────────────────────┐
  │  Harness Platform (SaaS)                │
  │                                         │
  │  • SOC 2 Type II Certified              │
  │  • ISO 27001 Compliant                  │
  │  • GDPR/HIPAA Ready                     │
  │  • Data Encryption at Rest (AES-256)    │
  │  • TLS 1.3 for Data in Transit          │
  │  • Multi-tenant Isolation               │
  │  • DDoS Protection                      │
  │  • Web Application Firewall (WAF)       │
  └─────────────────────────────────────────┘


  LAYER 2: AUTHENTICATION & AUTHORIZATION
  ════════════════════════════════════════
  ┌─────────────────────────────────────────┐
  │  Identity & Access Management           │
  │                                         │
  │  ┌───────────────────────────────────┐  │
  │  │  Authentication                   │  │
  │  │  • SSO (SAML 2.0, OIDC)          │  │
  │  │  • LDAP/Active Directory         │  │
  │  │  • Multi-Factor Authentication   │  │
  │  │  • API Keys with Rotation        │  │
  │  └───────────────────────────────────┘  │
  │                                         │
  │  ┌───────────────────────────────────┐  │
  │  │  Authorization (RBAC)             │  │
  │  │  • Role-Based Access Control     │  │
  │  │  • Least Privilege Principle     │  │
  │  │  • Resource-Level Permissions    │  │
  │  │  • Environment-Specific Access   │  │
  │  └───────────────────────────────────┘  │
  └─────────────────────────────────────────┘


  LAYER 3: NETWORK SECURITY
  ═════════════════════════
  ┌─────────────────────────────────────────┐
  │  Network Protection                     │
  │                                         │
  │  ┌───────────────────────────────────┐  │
  │  │  VPC / Network Segmentation       │  │
  │  │  • Private Subnets for Tasks      │  │
  │  │  • Public Subnets for ALB only    │  │
  │  │  • NACLs (Network ACLs)           │  │
  │  │  • Security Groups (Stateful)     │  │
  │  └───────────────────────────────────┘  │
  │                                         │
  │  ┌───────────────────────────────────┐  │
  │  │  Encrypted Communication          │  │
  │  │  • TLS 1.3 (Harness ↔ Delegate)  │  │
  │  │  • mTLS for Service Mesh          │  │
  │  │  • SSH for VM Access              │  │
  │  │  • VPN for Corporate Access       │  │
  │  └───────────────────────────────────┘  │
  └─────────────────────────────────────────┘


  LAYER 4: SECRETS MANAGEMENT
  ═══════════════════════════
  ┌─────────────────────────────────────────┐
  │  Secrets Storage & Rotation             │
  │                                         │
  │  ┌───────────────────────────────────┐  │
  │  │  Supported Secret Managers        │  │
  │  │  • AWS Secrets Manager            │  │
  │  │  • HashiCorp Vault                │  │
  │  │  • Azure Key Vault                │  │
  │  │  • GCP Secret Manager             │  │
  │  │  • Harness Built-in (encrypted)   │  │
  │  └───────────────────────────────────┘  │
  │                                         │
  │  ┌───────────────────────────────────┐  │
  │  │  Secret Lifecycle                 │  │
  │  │  • Automatic Rotation             │  │
  │  │  • Versioning                     │  │
  │  │  • Audit Logging                  │  │
  │  │  • Just-in-Time Access            │  │
  │  └───────────────────────────────────┘  │
  └─────────────────────────────────────────┘


  LAYER 5: DEPLOYMENT SECURITY
  ════════════════════════════
  ┌─────────────────────────────────────────┐
  │  Secure Deployment Pipeline             │
  │                                         │
  │  ┌───────────────────────────────────┐  │
  │  │  Image/Artifact Security          │  │
  │  │  • Container Image Scanning       │  │
  │  │  • Vulnerability Detection        │  │
  │  │  • Signed Images (Notary)         │  │
  │  │  • Artifact Checksum Verification │  │
  │  └───────────────────────────────────┘  │
  │                                         │
  │  ┌───────────────────────────────────┐  │
  │  │  Runtime Security                 │  │
  │  │  • IAM Roles (not credentials)    │  │
  │  │  • Least Privilege for Tasks      │  │
  │  │  • Read-only Root Filesystem      │  │
  │  │  • Non-root Container Users       │  │
  │  └───────────────────────────────────┘  │
  └─────────────────────────────────────────┘


  LAYER 6: AUDIT & COMPLIANCE
  ═══════════════════════════
  ┌─────────────────────────────────────────┐
  │  Logging & Monitoring                   │
  │                                         │
  │  ┌───────────────────────────────────┐  │
  │  │  Audit Trail                      │  │
  │  │  • All API Calls Logged           │  │
  │  │  • Deployment History             │  │
  │  │  • User Activity Tracking         │  │
  │  │  • Change Management Records      │  │
  │  └───────────────────────────────────┘  │
  │                                         │
  │  ┌───────────────────────────────────┐  │
  │  │  Compliance Reporting             │  │
  │  │  • SOC 2 Reports                  │  │
  │  │  • Compliance Dashboards          │  │
  │  │  • Policy Enforcement             │  │
  │  │  • Anomaly Detection              │  │
  │  └───────────────────────────────────┘  │
  └─────────────────────────────────────────┘


  LAYER 7: INCIDENT RESPONSE
  ══════════════════════════
  ┌─────────────────────────────────────────┐
  │  Detection & Response                   │
  │                                         │
  │  • Real-time Alerting                   │
  │  • Automated Rollback on Anomalies      │
  │  • Integration with SIEM                │
  │  • Incident Management Workflow         │
  │  • Post-Incident Analysis               │
  └─────────────────────────────────────────┘
```

### 6.2 IAM Roles and Permissions

```
┌─────────────────────────────────────────────────────────────────┐
│                IAM ROLES & PERMISSIONS ARCHITECTURE              │
└─────────────────────────────────────────────────────────────────┘

  HARNESS PLATFORM ROLES (RBAC)
  ══════════════════════════════

  ┌────────────────────────────────────────┐
  │  Admin                                 │
  │  • Full platform access                │
  │  • User management                     │
  │  • Billing & subscription              │
  │  • Security settings                   │
  └────────────────────────────────────────┘

  ┌────────────────────────────────────────┐
  │  Pipeline Admin                        │
  │  • Create/edit/delete pipelines        │
  │  • Configure services & environments   │
  │  • Manage connectors                   │
  │  • Execute pipelines                   │
  └────────────────────────────────────────┘

  ┌────────────────────────────────────────┐
  │  Pipeline Executor                     │
  │  • Execute existing pipelines          │
  │  • View pipeline results               │
  │  • Approve/reject manual steps         │
  │  • View logs & metrics                 │
  └────────────────────────────────────────┘

  ┌────────────────────────────────────────┐
  │  Viewer                                │
  │  • Read-only access                    │
  │  • View pipelines & executions         │
  │  • View dashboards                     │
  │  • No execution or modification        │
  └────────────────────────────────────────┘


  AWS IAM ROLES
  ═════════════

  ┌────────────────────────────────────────┐
  │  Harness Delegate Role                 │
  │  (Attached to EC2/ECS running delegate)│
  │                                        │
  │  Permissions:                          │
  │  • ecs:*                               │
  │  • ecr:GetAuthorizationToken           │
  │  • ecr:BatchCheckLayerAvailability     │
  │  • ecr:GetDownloadUrlForLayer          │
  │  • ecr:BatchGetImage                   │
  │  • elasticloadbalancing:*              │
  │  • logs:CreateLogGroup                 │
  │  • logs:CreateLogStream                │
  │  • logs:PutLogEvents                   │
  │  • cloudwatch:PutMetricData            │
  │  • secretsmanager:GetSecretValue       │
  └────────────────────────────────────────┘

  ┌────────────────────────────────────────┐
  │  ECS Task Execution Role               │
  │  (Used by ECS to start tasks)          │
  │                                        │
  │  Permissions:                          │
  │  • ecr:GetAuthorizationToken           │
  │  • ecr:BatchCheckLayerAvailability     │
  │  • ecr:GetDownloadUrlForLayer          │
  │  • ecr:BatchGetImage                   │
  │  • logs:CreateLogGroup                 │
  │  • logs:CreateLogStream                │
  │  • logs:PutLogEvents                   │
  │  • secretsmanager:GetSecretValue       │
  └────────────────────────────────────────┘

  ┌────────────────────────────────────────┐
  │  ECS Task Role                         │
  │  (Used by application running in task) │
  │                                        │
  │  Permissions (App-specific):           │
  │  • s3:GetObject (specific buckets)     │
  │  • dynamodb:GetItem                    │
  │  • sqs:SendMessage                     │
  │  • sns:Publish                         │
  │  • secretsmanager:GetSecretValue       │
  │  (Only what app needs - least privilege│
  └────────────────────────────────────────┘


  TRUST RELATIONSHIPS
  ═══════════════════

  Delegate Role Trust Policy:
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  }

  ECS Task Execution Role Trust Policy:
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


  SECURITY BEST PRACTICES
  ═══════════════════════

  ✓ Use IAM Roles (not access keys)
  ✓ Implement least privilege
  ✓ Regular permission audits
  ✓ Enable CloudTrail logging
  ✓ Use AWS Organizations for multi-account
  ✓ Implement SCPs (Service Control Policies)
  ✓ Regular credential rotation
  ✓ MFA for console access
```

---

## 7. Integration Diagrams

### 7.1 Full CI/CD Integration Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                 COMPLETE CI/CD INTEGRATION                       │
└─────────────────────────────────────────────────────────────────┘

  ┌──────────────┐
  │  Developer   │
  │  Workstation │
  └──────┬───────┘
         │ git push
         ▼
  ┌──────────────┐
  │    GitHub    │
  │   /GitLab    │
  │  /Bitbucket  │
  └──────┬───────┘
         │ webhook
         ▼
  ┌──────────────────────────────────────┐
  │      CI Pipeline (Build)             │
  │                                      │
  │  ┌────────────────────────────────┐  │
  │  │  Stage 1: Code Quality         │  │
  │  │  • Linting (ESLint, Pylint)    │  │
  │  │  • Code Formatting (Prettier)  │  │
  │  │  • Static Analysis (SonarQube) │  │
  │  └────────────────────────────────┘  │
  │                │                     │
  │                ▼                     │
  │  ┌────────────────────────────────┐  │
  │  │  Stage 2: Build & Test         │  │
  │  │  • Compile/Build               │  │
  │  │  • Unit Tests (Jest, PyTest)   │  │
  │  │  • Integration Tests           │  │
  │  │  • Coverage Report (>80%)      │  │
  │  └────────────────────────────────┘  │
  │                │                     │
  │                ▼                     │
  │  ┌────────────────────────────────┐  │
  │  │  Stage 3: Security Scan        │  │
  │  │  • Dependency Check (Snyk)     │  │
  │  │  • Container Scan (Trivy)      │  │
  │  │  • Secrets Detection           │  │
  │  │  • License Compliance          │  │
  │  └────────────────────────────────┘  │
  │                │                     │
  │                ▼                     │
  │  ┌────────────────────────────────┐  │
  │  │  Stage 4: Artifact Creation    │  │
  │  │  • Docker Build                │  │
  │  │  • Image Tagging               │  │
  │  │  • Sign Image (Notary)         │  │
  │  └────────────────────────────────┘  │
  └────────────────┬─────────────────────┘
                   │
                   ▼
  ┌──────────────────────────────────────┐
  │   Artifact Registry                  │
  │                                      │
  │   • Docker Hub / ECR / Artifactory   │
  │   • Version: app:1.2.3-abc123def     │
  │   • Metadata: build info, tests      │
  └────────────────┬─────────────────────┘
                   │ webhook/trigger
                   ▼
  ┌──────────────────────────────────────┐
  │      HARNESS CD PLATFORM             │
  │                                      │
  │  ┌────────────────────────────────┐  │
  │  │  Pipeline Orchestration        │  │
  │  │                                │  │
  │  │  Environments:                 │  │
  │  │  • Dev → QA → Staging → Prod  │  │
  │  │                                │  │
  │  │  Approval Gates:               │  │
  │  │  • QA Team (before Staging)    │  │
  │  │  • Manager (before Prod)       │  │
  │  └────────────────────────────────┘  │
  └────────────────┬─────────────────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
         ▼                   ▼
  ┌─────────────┐    ┌─────────────┐
  │  VM Deploy  │    │ ECS Deploy  │
  │  (Staging)  │    │  (Prod)     │
  └──────┬──────┘    └──────┬──────┘
         │                   │
         ▼                   ▼
  ┌─────────────┐    ┌─────────────┐
  │  Delegate   │    │  Delegate   │
  └──────┬──────┘    └──────┬──────┘
         │                   │
         ▼                   ▼
  ┌─────────────┐    ┌─────────────┐
  │ VM Cluster  │    │ ECS Cluster │
  └──────┬──────┘    └──────┬──────┘
         │                   │
         └───────┬───────────┘
                 │
                 ▼
  ┌──────────────────────────────────────┐
  │      Monitoring & Observability      │
  │                                      │
  │  ┌────────────────────────────────┐  │
  │  │  Metrics (Prometheus/DataDog)  │  │
  │  │  • CPU, Memory, Disk           │  │
  │  │  • Request Rate, Error Rate    │  │
  │  │  • Response Time, Throughput   │  │
  │  └────────────────────────────────┘  │
  │                                      │
  │  ┌────────────────────────────────┐  │
  │  │  Logs (ELK/Splunk)             │  │
  │  │  • Application Logs            │  │
  │  │  • Access Logs                 │  │
  │  │  • Error Logs                  │  │
  │  └────────────────────────────────┘  │
  │                                      │
  │  ┌────────────────────────────────┐  │
  │  │  Traces (Jaeger/DataDog APM)   │  │
  │  │  • Distributed Tracing         │  │
  │  │  • Performance Bottlenecks     │  │
  │  └────────────────────────────────┘  │
  └────────────────┬─────────────────────┘
                   │
                   ▼
  ┌──────────────────────────────────────┐
  │   Continuous Verification (Harness)  │
  │                                      │
  │   • Compare metrics vs baseline      │
  │   • AI/ML anomaly detection          │
  │   • Automatic rollback if risk high  │
  └────────────────┬─────────────────────┘
                   │
                   ▼
  ┌──────────────────────────────────────┐
  │         Notifications                │
  │                                      │
  │  • Slack: Deployment status          │
  │  • Email: Approval requests          │
  │  • PagerDuty: Incident alerts        │
  │  • Jira: Create tickets on failure   │
  └──────────────────────────────────────┘


  INTEGRATION POINTS
  ═══════════════════

  1. Source Control Integration:
     • Webhook on push/merge
     • Branch protection rules
     • Code review requirements

  2. CI Pipeline Integration:
     • Trigger on SCM events
     • Artifact versioning
     • Test result publishing

  3. Artifact Registry Integration:
     • Automated uploads
     • Version tagging
     • Security scanning

  4. Harness CD Integration:
     • Artifact triggers
     • Environment promotion
     • Approval workflows

  5. Monitoring Integration:
     • Metrics collection
     • Log aggregation
     • APM tracing

  6. Notification Integration:
     • Slack/Teams webhooks
     • Email SMTP
     • PagerDuty API
     • Jira API


  DATA FLOW TIMELINE
  ══════════════════

  00:00 - Code Push (Developer)
  00:01 - CI Pipeline Triggered
  00:15 - Build & Tests Complete
  00:20 - Security Scans Complete
  00:25 - Artifact Published
  00:26 - Harness Pipeline Triggered
  00:30 - Dev Deployment Complete
  01:00 - QA Deployment (auto)
  01:30 - QA Tests Pass
  01:31 - Staging Approval Requested
  02:00 - Staging Approved & Deployed
  02:45 - Staging Verification Complete
  02:46 - Prod Approval Requested
  03:00 - Prod Approved & Deployed
  04:00 - Prod Deployment Complete
  04:30 - Continuous Verification (30 min)
  05:00 - Deployment Successful ✓
```

---

## 8. State Machine Diagrams

### 8.1 Pipeline Execution State Machine

```
┌─────────────────────────────────────────────────────────────────┐
│           HARNESS PIPELINE EXECUTION STATE MACHINE               │
└─────────────────────────────────────────────────────────────────┘

                    ┌──────────────┐
                    │   PENDING    │
                    │  (Queued)    │
                    └──────┬───────┘
                           │
                           │ Trigger Event
                           │
                           ▼
                    ┌──────────────┐
                    │  RUNNING     │◄───────────┐
                    │  (Executing) │            │
                    └──────┬───────┘            │
                           │                    │
         ┌─────────────────┼────────────────┐   │
         │                 │                │   │
         ▼                 ▼                ▼   │
  ┌─────────────┐   ┌─────────────┐   ┌───────────┐
  │   FAILED    │   │  PAUSED     │   │ APPROVAL  │
  │             │   │ (Manual     │   │ REQUIRED  │
  └─────────────┘   │  Interv.)   │   └─────┬─────┘
         │          └──────┬──────┘          │
         │                 │                 │
         │                 │ Resume          │ Approve
         │                 └─────────────────┤
         │                                   │
         │                                   ▼
         │                            ┌──────────────┐
         │                            │  APPROVED    │
         │                            │              │
         │                            └──────┬───────┘
         │                                   │
         │                                   │ Continue
         │                                   │
         │                                   └────────┘
         │
         │ Rollback Triggered
         │
         ▼
  ┌─────────────┐
  │ ROLLING     │
  │   BACK      │
  └──────┬──────┘
         │
         │
         ▼
  ┌─────────────┐
  │ ABORTED     │
  │             │
  └─────────────┘


                    SUCCESSFUL PATH:

                    ┌──────────────┐
                    │  RUNNING     │
                    └──────┬───────┘
                           │
                           │ All Steps
                           │ Successful
                           ▼
                    ┌──────────────┐
                    │  VERIFYING   │
                    │ (CV Running) │
                    └──────┬───────┘
                           │
                           │ Verification
                           │ Passed
                           ▼
                    ┌──────────────┐
                    │  SUCCESS     │
                    │  (Complete)  │
                    └──────────────┘


STATE DESCRIPTIONS:
═══════════════════

PENDING:
  • Pipeline queued for execution
  • Waiting for delegate availability
  • Artifact verification in progress
  • Exit conditions: Start execution, Timeout, Cancel

RUNNING:
  • Pipeline actively executing
  • Steps running sequentially/parallel
  • Logs being generated
  • Exit conditions: Success, Failure, Pause, Approval needed

PAUSED:
  • Manual intervention requested
  • Waiting for user action
  • Can inspect logs/state
  • Exit conditions: Resume, Abort

APPROVAL REQUIRED:
  • Waiting for manual approval
  • Notification sent to approvers
  • Timeout configured (e.g., 24 hours)
  • Exit conditions: Approved, Rejected, Timeout

APPROVED:
  • Approval granted
  • Continuing execution
  • Brief transition state
  • Exit conditions: Resume execution

FAILED:
  • Step/stage failure occurred
  • Error logged and reported
  • Rollback may be triggered
  • Exit conditions: Manual retry, Rollback

ROLLING BACK:
  • Reverting changes
  • Restoring previous state
  • Can be automatic or manual
  • Exit conditions: Rollback complete, Rollback failed

ABORTED:
  • Execution terminated
  • User-initiated or timeout
  • Changes may be partially applied
  • Exit conditions: None (terminal state)

VERIFYING:
  • Continuous verification running
  • Metrics being analyzed
  • AI/ML comparison against baseline
  • Exit conditions: Pass, Fail (triggers rollback)

SUCCESS:
  • All steps completed successfully
  • Verification passed
  • Audit trail recorded
  • Exit conditions: None (terminal state)


STATE TRANSITIONS MATRIX:
═════════════════════════

From → To:
PENDING → RUNNING, ABORTED
RUNNING → FAILED, PAUSED, APPROVAL_REQUIRED, VERIFYING
PAUSED → RUNNING, ABORTED
APPROVAL_REQUIRED → APPROVED, ABORTED
APPROVED → RUNNING
FAILED → ROLLING_BACK, ABORTED
ROLLING_BACK → SUCCESS, ABORTED
VERIFYING → SUCCESS, ROLLING_BACK
ABORTED → [terminal]
SUCCESS → [terminal]
```

### 8.2 ECS Service State Machine

```
┌─────────────────────────────────────────────────────────────────┐
│              ECS SERVICE DEPLOYMENT STATE MACHINE                │
└─────────────────────────────────────────────────────────────────┘

  BLUE-GREEN DEPLOYMENT STATES:
  ══════════════════════════════

           ┌────────────────┐
           │  STABLE_BLUE   │
           │  (Current Prod)│
           └────────┬───────┘
                    │ Deployment Triggered
                    ▼
           ┌────────────────┐
           │ CREATING_GREEN │
           │  (New Version) │
           └────────┬───────┘
                    │ Tasks Created
                    ▼
           ┌────────────────┐
           │ PROVISIONING   │
           │  (Starting)    │
           └────────┬───────┘
                    │ Tasks Running
                    ▼
           ┌────────────────┐
           │ HEALTH_CHECK   │
           │  (Verifying)   │
           └────────┬───────┘
                    │
          ┌─────────┴─────────┐
          │                   │
    FAIL  │                   │ PASS
          ▼                   ▼
  ┌───────────────┐   ┌────────────────┐
  │  UNHEALTHY    │   │  HEALTHY_GREEN │
  │  (Rollback)   │   │  (Ready)       │
  └───────┬───────┘   └────────┬───────┘
          │                    │
          │                    │ Start Traffic Shift
          │                    ▼
          │           ┌────────────────┐
          │           │ TRAFFIC_SHIFT  │
          │           │   10% Green    │
          │           └────────┬───────┘
          │                    │
          │                    │ Monitor (5 min)
          │                    ▼
          │           ┌────────────────┐
          │           │ MONITORING_10  │
          │           └────────┬───────┘
          │                    │
          │          ┌─────────┴─────────┐
          │    FAIL  │                   │ PASS
          │          ▼                   ▼
          │   ┌───────────────┐  ┌────────────────┐
          │   │  ANOMALY_10   │  │ TRAFFIC_SHIFT  │
          │   │  (Rollback)   │  │   50% Green    │
          │   └───────┬───────┘  └────────┬───────┘
          │           │                   │
          │           │                   │ Monitor (10 min)
          │           │                   ▼
          │           │          ┌────────────────┐
          │           │          │ MONITORING_50  │
          │           │          └────────┬───────┘
          │           │                   │
          │           │         ┌─────────┴─────────┐
          │           │   FAIL  │                   │ PASS
          │           │         ▼                   ▼
          │           │  ┌───────────────┐  ┌────────────────┐
          │           │  │  ANOMALY_50   │  │ TRAFFIC_SHIFT  │
          │           │  │  (Rollback)   │  │  100% Green    │
          │           │  └───────┬───────┘  └────────┬───────┘
          │           │          │                   │
          │           │          │                   │ Monitor (15 min)
          │           │          │                   ▼
          │           │          │          ┌────────────────┐
          │           │          │          │ MONITORING_100 │
          │           │          │          └────────┬───────┘
          │           │          │                   │
          │           │          │         ┌─────────┴─────────┐
          │           │          │   FAIL  │                   │ PASS
          │           │          │         ▼                   ▼
          │           │          │  ┌───────────────┐  ┌────────────────┐
          │           │          │  │  ANOMALY_100  │  │ STABLE_GREEN   │
          │           │          │  │  (Rollback)   │  │ (Success)      │
          │           │          │  └───────┬───────┘  └────────┬───────┘
          │           │          │          │                   │
          │           │          │          │                   │ Cleanup
          │           │          │          │                   ▼
          │           │          │          │          ┌────────────────┐
          │           │          │          │          │ DELETING_BLUE  │
          │           │          │          │          └────────┬───────┘
          │           │          │          │                   │
          │           │          │          │                   │ Complete
          │           │          │          │                   ▼
          │           │          │          │          ┌────────────────┐
          │           │          │          │          │    COMPLETE    │
          │           │          │          │          │   (Terminal)   │
          │           │          │          │          └────────────────┘
          │           │          │          │
          └───────────┴──────────┴──────────┘
                      │
                      │ Rollback Action
                      ▼
             ┌────────────────┐
             │ ROLLING_BACK   │
             │  (Reverting)   │
             └────────┬───────┘
                      │ Revert Traffic
                      ▼
             ┌────────────────┐
             │ STABLE_BLUE    │
             │  (Restored)    │
             └────────────────┘


  STATE DURATIONS:
  ════════════════

  CREATING_GREEN: ~2-3 minutes
  PROVISIONING: ~3-5 minutes
  HEALTH_CHECK: ~2-3 minutes
  TRAFFIC_SHIFT (10%): ~30 seconds
  MONITORING_10: ~5 minutes
  TRAFFIC_SHIFT (50%): ~30 seconds
  MONITORING_50: ~10 minutes
  TRAFFIC_SHIFT (100%): ~30 seconds
  MONITORING_100: ~15 minutes
  DELETING_BLUE: ~2-3 minutes
  ROLLING_BACK: ~1-2 minutes

  Total Success Path: ~40-45 minutes
  Total Rollback Time: ~1-2 minutes
```

---

## Conclusion

This comprehensive diagram document provides multiple visualization perspectives of the Harness CD architecture, including:

- **Sequence Diagrams**: Step-by-step execution flows
- **Component Diagrams**: System architecture breakdown
- **Data Flow Diagrams**: Information movement through the system
- **Network Topology**: Infrastructure and connectivity
- **Security Architecture**: Multi-layer security approach
- **Integration Diagrams**: External system connections
- **State Machines**: Execution state transitions

These diagrams complement the architecture guides and presentation materials, providing technical teams with detailed visual references for understanding, implementing, and troubleshooting Harness CD deployments.

---

**Document Version**: 1.0
**Last Updated**: January 10, 2026
**Classification**: Customer-Sharable
**Format**: Markdown with ASCII diagrams

For high-resolution graphical versions of these diagrams, consider using:
- **Lucidchart** or **Draw.io** for architecture diagrams
- **Mermaid** for sequence and state diagrams
- **PlantUML** for component diagrams

---

**END OF ADDITIONAL DIAGRAMS DOCUMENT**
