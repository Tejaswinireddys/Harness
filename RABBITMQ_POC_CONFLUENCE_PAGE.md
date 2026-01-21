# RabbitMQ 4.x Cluster POC - Confluence Documentation

---

> **Document Type:** Technical Documentation  
> **Space:** Infrastructure / DevOps  
> **Status:** {status:colour=Blue|title=In Progress}  
> **Owner:** Infrastructure Architecture Team

---

{toc:maxLevel=3}

---

# Overview

{panel:title=POC Summary|borderStyle=solid|borderColor=#ccc|titleBGColor=#f0f0f0}
This Proof of Concept demonstrates automated deployment of a **RabbitMQ 4.x** cluster using **Harness CD** with **Ansible** automation. The POC validates our ability to deploy, configure, and manage RabbitMQ clusters across multiple environments with enterprise-grade controls.
{panel}

## Quick Links

| Resource | Link |
|----------|------|
| {status:colour=Green|title=Harness Project} | [RabbitMQ-Deployment Project](https://app.harness.io/ng/account/xxx/cd/orgs/Infrastructure/projects/rabbitmq_deployment) |
| {status:colour=Blue|title=Git Repository} | [rabbitmq-ansible-harness](https://github.com/your-org/rabbitmq-ansible-harness) |
| {status:colour=Yellow|title=Pipeline} | [RabbitMQ-Cluster-Deployment](https://app.harness.io/ng/account/xxx/cd/orgs/Infrastructure/projects/rabbitmq_deployment/pipelines/rabbitmq_cluster_deployment) |
| {status:colour=Purple|title=Monitoring} | [RabbitMQ Grafana Dashboard](https://grafana.company.com/d/rabbitmq) |

---

# Architecture

## High-Level Architecture Diagram

{code:language=none|title=RabbitMQ Cluster Architecture}
┌─────────────────────────────────────────────────────────────────────────────┐
│                           HARNESS PLATFORM                                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────┐      │
│  │   Project   │───▶│  Pipeline   │───▶│     Deployment Stages       │      │
│  │  RabbitMQ   │    │   CD Flow   │    │  DEV → STAGE → PRODUCTION   │      │
│  └─────────────┘    └─────────────┘    └─────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          HARNESS DELEGATE                                    │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │                    Ansible Execution Engine                       │       │
│  └──────────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
┌───────────────────────┐ ┌───────────────────────┐ ┌───────────────────────┐
│   RabbitMQ Node 1     │ │   RabbitMQ Node 2     │ │   RabbitMQ Node 3     │
│   (Primary/Disc)      │ │   (Replica/Disc)      │ │   (Replica/Disc)      │
│  • RabbitMQ 4.x       │ │  • RabbitMQ 4.x       │ │  • RabbitMQ 4.x       │
│  • Erlang 26.x        │ │  • Erlang 26.x        │ │  • Erlang 26.x        │
└───────────────────────┘ └───────────────────────┘ └───────────────────────┘
{code}

## Component Diagram

{drawio:name=RabbitMQ-Architecture|width=800}

---

# Prerequisites

## Infrastructure Requirements

{info:title=Minimum Requirements}
Each RabbitMQ node requires the following resources. These are minimums for POC; production may require more.
{info}

| Component | Specification | POC | Production |
|-----------|---------------|-----|------------|
| **CPU** | vCPUs | 4 | 8+ |
| **Memory** | RAM | 8 GB | 16 GB+ |
| **Storage** | SSD | 100 GB | 500 GB+ |
| **Network** | Bandwidth | 1 Gbps | 10 Gbps |

## Network Ports

{warning:title=Firewall Configuration Required}
Ensure these ports are open between all cluster nodes and from management networks.
{warning}

| Port | Protocol | Purpose |
|------|----------|---------|
| 4369 | TCP | EPMD (Erlang Port Mapper) |
| 5672 | TCP | AMQP 0-9-1 and 1.0 |
| 15672 | TCP | Management UI & HTTP API |
| 25672 | TCP | Erlang distribution |
| 15692 | TCP | Prometheus metrics |

## Software Prerequisites

| Software | Version | Purpose |
|----------|---------|---------|
| Harness Account | Enterprise/Team | CD Platform |
| Ansible | 2.15+ | Automation |
| Python | 3.9+ | Ansible runtime |
| Git | 2.x | Source control |

---

# Implementation Steps

## Phase 1: Harness Setup (Days 1-2)

### Step 1.1: Create Organization and Project

{expand:title=Click to expand detailed steps}

1. **Login to Harness**
   - Navigate to https://app.harness.io
   - Login with your credentials

2. **Create Organization**
   - Go to Account Settings → Organizations
   - Click "New Organization"
   - Name: `Infrastructure`
   - Description: `Infrastructure Automation Projects`

3. **Create Project**
   - Select "Infrastructure" organization
   - Click "New Project"
   - Name: `RabbitMQ-Deployment`
   - Identifier: `rabbitmq_deployment`
   - Enable: Continuous Delivery module

{expand}

### Step 1.2: Install Harness Delegate

{note:title=Delegate Requirements}
The Delegate must have Ansible installed and SSH access to target servers.
{note}

**Option A: Kubernetes Delegate (Recommended)**

{code:language=yaml|title=delegate-values.yaml}
delegateName: rabbitmq-ansible-delegate
delegateType: KUBERNETES
accountId: YOUR_ACCOUNT_ID
delegateToken: YOUR_DELEGATE_TOKEN
image: your-registry.com/harness-delegate-ansible:24.01
replicas: 2
resources:
  requests:
    cpu: 500m
    memory: 768Mi
  limits:
    cpu: 1000m
    memory: 2Gi
{code}

**Installation Command:**
{code:language=bash}
kubectl apply -f harness-delegate.yaml
{code}

**Verification:**
{code:language=bash}
kubectl get pods -n harness-delegate-ng
kubectl logs -f deployment/rabbitmq-ansible-delegate -n harness-delegate-ng
{code}

### Step 1.3: Configure Connectors

| Connector | Type | Purpose |
|-----------|------|---------|
| `rabbitmq-ansible-repo` | GitHub | Ansible playbooks repository |
| `rabbitmq-servers-ssh` | SSH Key | Access to target servers |

---

## Phase 2: Ansible Development (Days 3-5)

### Step 2.1: Repository Structure

{code:language=none|title=Repository Layout}
rabbitmq-ansible-harness/
├── ansible.cfg
├── requirements.yml
├── inventory/
│   ├── dev/
│   │   ├── hosts.yml
│   │   └── group_vars/all.yml
│   ├── staging/
│   └── production/
├── playbooks/
│   ├── site.yml
│   ├── deploy.yml
│   ├── validate.yml
│   └── rollback.yml
├── roles/
│   ├── common/
│   ├── erlang/
│   ├── rabbitmq/
│   └── monitoring/
└── templates/
    └── rabbitmq/
        └── rabbitmq.conf.j2
{code}

### Step 2.2: Key Playbook - site.yml

{code:language=yaml|title=playbooks/site.yml}
---
- name: RabbitMQ 4.x Cluster Deployment
  hosts: rabbitmq_cluster
  become: yes
  gather_facts: yes
  
  pre_tasks:
    - name: Validate minimum node count
      ansible.builtin.assert:
        that:
          - groups['rabbitmq_cluster'] | length >= 3
        fail_msg: "Cluster requires minimum 3 nodes"
      run_once: true

  roles:
    - role: common
    - role: erlang
    - role: rabbitmq
    - role: monitoring
{code}

### Step 2.3: RabbitMQ Configuration Template

{code:language=ini|title=templates/rabbitmq.conf.j2}
# RabbitMQ 4.x Configuration
cluster_name = {{ rabbitmq_cluster_name }}

# Networking
listeners.tcp.default = 5672
management.tcp.port = 15672

# Resource Limits
vm_memory_high_watermark.relative = 0.6
disk_free_limit.absolute = 2GB

# Default Queue Type (RabbitMQ 4.x)
default_queue_type = quorum

# Prometheus Metrics
prometheus.tcp.port = 15692
{code}

---

## Phase 3: Pipeline Configuration (Days 5-6)

### Step 3.1: Create Pipeline

{panel:title=Pipeline Overview|borderStyle=solid}
**Pipeline Name:** RabbitMQ-Cluster-Deployment  
**Stages:**
1. Pre-Flight Checks
2. Deploy to Development
3. Deploy to Staging (with approval)
4. Deploy to Production (with approval)
{panel}

### Step 3.2: Pipeline Variables

| Variable | Type | Description |
|----------|------|-------------|
| `rabbitmq_version` | String | RabbitMQ version (e.g., 4.0.3) |
| `erlang_cookie` | Secret | Cluster authentication |
| `rabbitmq_admin_password` | Secret | Admin user password |
| `deploy_all_environments` | Boolean | Full deployment flag |

### Step 3.3: Deployment Stage Configuration

{code:language=yaml|title=Deploy Stage - Ansible Execution}
steps:
  - step:
      name: Deploy RabbitMQ Cluster
      type: Run
      spec:
        shell: Bash
        command: |
          ansible-playbook playbooks/site.yml \
            -i inventory/dev/hosts.yml \
            -e "rabbitmq_version=<+pipeline.variables.rabbitmq_version>" \
            -e "erlang_cookie=<+pipeline.variables.erlang_cookie>" \
            -v
      timeout: 30m
      failureStrategies:
        - onFailure:
            action:
              type: StageRollback
{code}

### Step 3.4: Approval Gates

{tip:title=Approval Configuration}
Approvals are configured between stages to ensure proper review before promoting to higher environments.
{tip}

| Environment | Approvers | Minimum Count | Timeout |
|-------------|-----------|---------------|---------|
| Staging | DevOps Team | 1 | 4 hours |
| Production | Platform Team, Management | 2 | 24 hours |

---

## Phase 4: Testing & Validation (Days 6-7)

### Step 4.1: Validation Playbook

{code:language=yaml|title=playbooks/validate.yml}
---
- name: Validate RabbitMQ Cluster
  hosts: rabbitmq_cluster
  tasks:
    - name: Check cluster status
      command: rabbitmqctl cluster_status --formatter json
      register: cluster_status
      
    - name: Assert all nodes in cluster
      assert:
        that:
          - cluster_info.running_nodes | length >= 3
        success_msg: "All nodes are in the cluster"
        
    - name: Test Management API
      uri:
        url: "http://{{ ansible_host }}:15672/api/healthchecks/node"
        user: admin
        password: "{{ rabbitmq_admin_password }}"
        status_code: 200
{code}

### Step 4.2: Smoke Test Checklist

{tasklist}
* Verify cluster formation (3 nodes)
* Test AMQP connectivity on port 5672
* Access Management UI on port 15672
* Verify Prometheus metrics on port 15692
* Test message publish/consume
* Verify quorum queues work correctly
{tasklist}

---

## Phase 5: Demo & Handoff (Day 8)

### Demo Script

1. **Show Harness Dashboard**
   - Project overview
   - Pipeline definition
   - Environment configurations

2. **Execute Pipeline**
   - Run deployment to Dev
   - Show real-time logs
   - Demonstrate approval workflow

3. **Show Results**
   - Cluster status
   - Management UI
   - Metrics dashboard

4. **Demonstrate Rollback**
   - Trigger manual rollback
   - Show automatic rollback on failure

---

# Rollback Procedures

## Automatic Rollback

Harness automatically triggers rollback when:
- Deployment step fails
- Validation step fails
- Timeout exceeded

## Manual Rollback Steps

{code:language=bash|title=Manual Rollback}
# Via Ansible
ansible-playbook playbooks/rollback.yml \
  -i inventory/dev/hosts.yml \
  -e "previous_version=4.0.2"
{code}

## Rollback Checklist

{tasklist}
* Notify stakeholders
* Verify current cluster state
* Execute rollback playbook
* Validate cluster health
* Update incident ticket
* Schedule post-mortem
{tasklist}

---

# Monitoring & Alerting

## Key Metrics

| Metric | Warning | Critical |
|--------|---------|----------|
| Memory Usage | > 70% | > 85% |
| Disk Usage | > 70% | > 90% |
| Queue Depth | > 10,000 | > 50,000 |
| Connection Count | > 500 | > 1000 |

## Grafana Dashboard

{info}
RabbitMQ metrics dashboard available at: https://grafana.company.com/d/rabbitmq
{info}

---

# Troubleshooting

## Common Issues

{expand:title=Nodes won't join cluster}
**Cause:** Erlang cookie mismatch

**Resolution:**
1. Stop RabbitMQ on all nodes
2. Verify `.erlang.cookie` is identical
3. Restart RabbitMQ
{expand}

{expand:title=Connection refused}
**Cause:** Firewall blocking ports

**Resolution:**
1. Check firewall rules: `firewall-cmd --list-all`
2. Open required ports (4369, 5672, 15672, 25672)
3. Reload firewall: `firewall-cmd --reload`
{expand}

{expand:title=Memory alarm}
**Cause:** High watermark reached

**Resolution:**
1. Check memory usage: `rabbitmqctl status | grep memory`
2. Reduce load or add memory
3. Adjust watermark if appropriate
{expand}

## Diagnostic Commands

{code:language=bash}
# Cluster status
rabbitmqctl cluster_status

# Check logs
journalctl -u rabbitmq-server -f

# Node health check
rabbitmqctl node_health_check

# List queues
rabbitmqctl list_queues name messages consumers
{code}

---

# Security Considerations

## Authentication

- Default `guest` user disabled
- Admin user with strong password
- Application users with least privilege

## Network Security

- TLS encryption for production
- Network segmentation
- Firewall rules restricted to required ports

## Secrets Management

All secrets stored in Harness Secrets Manager:
- Erlang cookie
- Admin password
- SSH keys

---

# POC Timeline

{roadmap}
| Phase | Start | End | Status |
|-------|-------|-----|--------|
| Setup | Day 1 | Day 2 | {status:colour=Green|title=Complete} |
| Development | Day 3 | Day 5 | {status:colour=Blue|title=In Progress} |
| Testing | Day 6 | Day 7 | {status:colour=Yellow|title=Planned} |
| Demo | Day 8 | Day 8 | {status:colour=Yellow|title=Planned} |
{roadmap}

---

# Success Criteria

{panel:title=POC Success Metrics|borderStyle=solid|borderColor=#228B22|titleBGColor=#90EE90}

| Criteria | Target | Status |
|----------|--------|--------|
| Automated cluster deployment | 3 nodes | ⏳ |
| Deployment time | < 30 minutes | ⏳ |
| Validation automation | 100% | ⏳ |
| Rollback capability | < 10 minutes | ⏳ |
| Approval workflow | Functional | ⏳ |
| Audit trail | Complete | ⏳ |

{panel}

---

# Next Steps

After POC completion:

1. **Production Planning**
   - Capacity planning
   - HA requirements
   - DR strategy

2. **Security Hardening**
   - TLS configuration
   - Certificate management
   - Network policies

3. **Integration**
   - Application onboarding
   - Monitoring integration
   - ITSM integration

4. **Documentation**
   - Runbooks
   - Training materials
   - SOP creation

---

# Contacts

| Role | Name | Email |
|------|------|-------|
| Project Lead | TBD | lead@company.com |
| DevOps Lead | TBD | devops@company.com |
| Platform Team | TBD | platform@company.com |

---

{info:title=Document Information}
**Version:** 1.0  
**Created:** January 2026  
**Last Updated:** January 2026  
**Review Date:** Quarterly
{info}
