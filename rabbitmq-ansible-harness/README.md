# RabbitMQ 4.x Cluster Deployment with Harness CD

[![Harness](https://img.shields.io/badge/Harness-CD-blue)](https://harness.io)
[![RabbitMQ](https://img.shields.io/badge/RabbitMQ-4.x-orange)](https://rabbitmq.com)
[![Ansible](https://img.shields.io/badge/Ansible-2.15+-red)](https://ansible.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

Automated deployment of a production-grade **RabbitMQ 4.x** cluster using **Harness CD** with **Ansible** automation.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Validation](#validation)
- [Rollback](#rollback)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This repository contains Ansible playbooks and Harness CD pipeline configurations for deploying a highly available RabbitMQ 4.x cluster. The solution supports:

- ✅ 3-node (or more) cluster deployment
- ✅ Multi-environment support (Dev, Staging, Production)
- ✅ Quorum queues (RabbitMQ 4.x default)
- ✅ Approval gates for production
- ✅ Automatic rollback on failure
- ✅ Prometheus metrics integration
- ✅ Complete audit trail

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      HARNESS PLATFORM                           │
│  ┌─────────────┐    ┌─────────────┐    ┌───────────────────┐   │
│  │   Project   │───▶│  Pipeline   │───▶│ DEV → STG → PROD  │   │
│  └─────────────┘    └─────────────┘    └───────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     HARNESS DELEGATE                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Ansible Execution Engine                    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                               │
               ┌───────────────┼───────────────┐
               ▼               ▼               ▼
┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐
│  RabbitMQ Node 1  │ │  RabbitMQ Node 2  │ │  RabbitMQ Node 3  │
│    (Primary)      │ │    (Replica)      │ │    (Replica)      │
│  ─────────────    │ │  ─────────────    │ │  ─────────────    │
│  AMQP: 5672       │ │  AMQP: 5672       │ │  AMQP: 5672       │
│  MGMT: 15672      │ │  MGMT: 15672      │ │  MGMT: 15672      │
│  Metrics: 15692   │ │  Metrics: 15692   │ │  Metrics: 15692   │
└───────────────────┘ └───────────────────┘ └───────────────────┘
            │                   │                   │
            └───────────────────┴───────────────────┘
                        Erlang Cluster
```

## 📋 Prerequisites

### Target Environment

| Component | Specification |
|-----------|---------------|
| **Operating System** | **RHEL 8.x** (Red Hat Enterprise Linux 8) |
| **Architecture** | x86_64 |
| **Deployment** | Virtual Machines |

### Infrastructure Requirements (Per Node)

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 vCPUs | 8 vCPUs |
| Memory | 8 GB | 16 GB |
| Storage | 100 GB SSD | 500 GB SSD |
| Network | 1 Gbps | 10 Gbps |

### RHEL 8 Requirements

- Active RHEL subscription (or configured repos)
- Python 3 installed
- Firewalld (will be configured by playbook)
- SELinux (Enforcing supported, configured by playbook)
- Chrony for time sync

### Software Requirements

- Harness Account (CD module enabled)
- Harness Delegate with Ansible 2.15+
- SSH access to target RHEL 8 VMs
- Git repository access

### Network Ports

| Port | Purpose |
|------|---------|
| 4369 | EPMD (Erlang Port Mapper) |
| 5672 | AMQP |
| 5671 | AMQPS (TLS) |
| 15672 | Management UI |
| 25672 | Erlang Distribution |
| 15692 | Prometheus Metrics |

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/your-org/rabbitmq-ansible-harness.git
cd rabbitmq-ansible-harness
```

### 2. Configure Inventory

Edit `inventory/dev/hosts.yml`:

```yaml
all:
  children:
    rabbitmq_cluster:
      hosts:
        rabbitmq-node-1:
          ansible_host: 192.168.1.101
          rabbitmq_is_primary: true
        rabbitmq-node-2:
          ansible_host: 192.168.1.102
        rabbitmq-node-3:
          ansible_host: 192.168.1.103
```

### 3. Set Environment Variables

```bash
export ERLANG_COOKIE="your-secure-erlang-cookie"
export RABBITMQ_ADMIN_PASSWORD="your-admin-password"
```

### 4. Run Deployment (Local)

```bash
# Install requirements
ansible-galaxy collection install -r requirements.yml

# Deploy cluster
ansible-playbook playbooks/site.yml -i inventory/dev/hosts.yml

# Validate deployment
ansible-playbook playbooks/validate.yml -i inventory/dev/hosts.yml
```

### 5. Import to Harness

1. Import `harness-pipeline.yaml` to your Harness project
2. Configure secrets (erlang_cookie, rabbitmq_admin_password)
3. Run the pipeline

## 📁 Repository Structure

```
.
├── ansible.cfg                 # Ansible configuration
├── requirements.yml            # Galaxy requirements
├── harness-pipeline.yaml       # Harness CD pipeline
├── inventory/
│   ├── dev/
│   │   ├── hosts.yml          # Dev inventory
│   │   └── group_vars/
│   │       └── all.yml        # Dev variables
│   ├── staging/
│   └── production/
├── playbooks/
│   ├── site.yml               # Main playbook
│   ├── validate.yml           # Validation playbook
│   ├── rollback.yml           # Rollback playbook
│   └── backup.yml             # Backup playbook
├── roles/
│   ├── common/                # System preparation
│   ├── erlang/                # Erlang installation
│   ├── rabbitmq/              # RabbitMQ installation
│   └── monitoring/            # Prometheus setup
└── templates/
    └── rabbitmq/
        ├── rabbitmq.conf.j2
        └── enabled_plugins.j2
```

## ⚙️ Configuration

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `rabbitmq_version` | RabbitMQ version | `4.0.3` |
| `erlang_version` | Erlang OTP version | `26.2` |
| `rabbitmq_cluster_name` | Cluster name | `rabbitmq-{env}-cluster` |
| `rabbitmq_vm_memory_high_watermark` | Memory limit | `0.6` |
| `rabbitmq_disk_free_limit` | Disk limit | `2GB` |
| `rabbitmq_default_queue_type` | Default queue type | `quorum` |

### Secrets (Harness)

| Secret | Description |
|--------|-------------|
| `erlang_cookie` | Erlang cluster cookie |
| `rabbitmq_admin_password` | Admin user password |
| `ssh_private_key` | SSH key for deployment |

## 🚢 Deployment

### Via Harness Pipeline

1. Navigate to Pipelines → RabbitMQ-Cluster-Deployment
2. Click "Run Pipeline"
3. Set variables:
   - `rabbitmq_version`: 4.0.3
   - `deploy_to_staging`: false
   - `deploy_to_production`: false
4. Click "Run Pipeline"

### Pipeline Stages

1. **Pre-Flight Checks**: Validate playbooks, security scan
2. **Deploy to Development**: Backup, deploy, validate
3. **Deploy to Staging**: Approval → Deploy → Validate
4. **Deploy to Production**: Dual approval → Rolling deploy → Validate

## ✅ Validation

The validation playbook checks:

- ✅ RabbitMQ service status
- ✅ Port accessibility (5672, 15672, 15692)
- ✅ Cluster formation
- ✅ Node health
- ✅ Management API
- ✅ Prometheus metrics

```bash
# Run validation
ansible-playbook playbooks/validate.yml -i inventory/dev/hosts.yml
```

## ⏪ Rollback

### Automatic Rollback

The pipeline automatically triggers rollback on:
- Deployment step failure
- Validation failure
- Timeout

### Manual Rollback

```bash
# Rollback to previous version
ansible-playbook playbooks/rollback.yml \
  -i inventory/dev/hosts.yml \
  -e "previous_version=4.0.2"
```

## 📊 Monitoring

### Prometheus Metrics

Metrics available at `http://<node>:15692/metrics`

### Grafana Dashboard

Import dashboard ID `10991` from Grafana Labs.

### Key Metrics

| Metric | Alert Threshold |
|--------|-----------------|
| Memory Usage | > 80% |
| Disk Usage | > 90% |
| Queue Depth | > 10,000 |
| Connections | > 1,000 |

## 🔧 Troubleshooting

### Common Issues

#### Nodes Won't Cluster

```bash
# Verify Erlang cookie
cat /var/lib/rabbitmq/.erlang.cookie

# Check connectivity
rabbitmqctl eval 'net_adm:ping(rabbit@node2).'
```

#### Memory Alarm

```bash
# Check memory
rabbitmqctl status | grep memory

# Adjust watermark
rabbitmqctl set_vm_memory_high_watermark 0.7
```

#### Service Won't Start

```bash
# Check logs
journalctl -u rabbitmq-server -f

# Check status
systemctl status rabbitmq-server
```

## 📚 Documentation

- [Implementation Guide](../RABBITMQ_POC_IMPLEMENTATION_GUIDE.md)
- [Confluence Page](../RABBITMQ_POC_CONFLUENCE_PAGE.md)
- [Executive Summary](../RABBITMQ_POC_EXECUTIVE_SUMMARY.md)

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 👥 Contributors

- Infrastructure Architecture Team

---

**Need Help?** Contact DevOps Team at devops@company.com
