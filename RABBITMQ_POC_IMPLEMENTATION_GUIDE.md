# RabbitMQ 4.x Cluster POC - Complete Implementation Guide
## Harness CD with Ansible Automation

---

# Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Harness Platform Setup](#2-harness-platform-setup)
3. [Delegate Installation](#3-delegate-installation)
4. [Connector Configuration](#4-connector-configuration)
5. [Secret Management](#5-secret-management)
6. [Ansible Playbook Structure](#6-ansible-playbook-structure)
7. [Service Configuration](#7-service-configuration)
8. [Environment Setup](#8-environment-setup)
9. [Pipeline Creation](#9-pipeline-creation)
10. [Deployment Execution](#10-deployment-execution)
11. [Validation & Testing](#11-validation--testing)
12. [Monitoring & Observability](#12-monitoring--observability)
13. [Rollback Procedures](#13-rollback-procedures)
14. [Troubleshooting Guide](#14-troubleshooting-guide)

---

# 1. Prerequisites

## 1.1 Infrastructure Requirements

### Target Servers (Minimum 3 Nodes) - RHEL 8 VMs

| Component | Specification | Notes |
|-----------|---------------|-------|
| **OS** | **RHEL 8.x** | Red Hat Enterprise Linux 8 VMs |
| **CPU** | 4+ vCPUs | Erlang/RabbitMQ are CPU-intensive |
| **Memory** | 8 GB RAM minimum | 16 GB recommended for production |
| **Storage** | 100 GB SSD | IOPS > 3000 recommended |
| **Network** | 1 Gbps | Low latency between nodes (<2ms) |
| **SELinux** | Enforcing (supported) | Configured by Ansible playbook |
| **Firewall** | firewalld | Configured by Ansible playbook |
| **Time Sync** | chronyd | Required for cluster |

### Network Requirements

| Port | Protocol | Purpose | Source |
|------|----------|---------|--------|
| 4369 | TCP | EPMD (Erlang Port Mapper) | Cluster nodes |
| 5672 | TCP | AMQP 0-9-1 and 1.0 | Application clients |
| 5671 | TCP | AMQP over TLS | Secure clients |
| 15672 | TCP | Management UI & HTTP API | Admin access |
| 25672 | TCP | Erlang distribution | Cluster nodes |
| 35672-35682 | TCP | CLI tools (dynamic) | Admin hosts |
| 15692 | TCP | Prometheus metrics | Monitoring |

### DNS/Hostnames

```bash
# All nodes must resolve each other by hostname
# Example /etc/hosts entries (if no DNS)
192.168.1.101  rabbitmq-node-1.example.com  rabbitmq-node-1
192.168.1.102  rabbitmq-node-2.example.com  rabbitmq-node-2
192.168.1.103  rabbitmq-node-3.example.com  rabbitmq-node-3
```

## 1.2 Harness Account Requirements

| Requirement | Details |
|-------------|---------|
| **Harness Account** | Team plan or higher (CD module required) |
| **License** | Harness CD Enterprise or Community |
| **User Permissions** | Account Admin or Project Admin |
| **Delegates** | Minimum 1 Delegate with Ansible installed |

## 1.3 Source Control Repository

Create a Git repository with the following structure:

```
rabbitmq-ansible-harness/
├── README.md
├── ansible.cfg
├── requirements.yml
├── inventory/
│   ├── dev/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   │       └── all.yml
│   ├── staging/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   │       └── all.yml
│   └── production/
│       ├── hosts.yml
│       └── group_vars/
│           └── all.yml
├── playbooks/
│   ├── site.yml
│   ├── deploy.yml
│   ├── configure.yml
│   ├── cluster.yml
│   ├── validate.yml
│   └── rollback.yml
├── roles/
│   ├── common/
│   ├── erlang/
│   ├── rabbitmq/
│   └── monitoring/
├── templates/
│   └── rabbitmq/
│       ├── rabbitmq.conf.j2
│       ├── advanced.config.j2
│       └── enabled_plugins.j2
└── files/
    └── rabbitmq/
        └── definitions.json
```

---

# 2. Harness Platform Setup

## 2.1 Create Organization

1. **Navigate to Account Settings**
   - Login to Harness → Account Settings → Organizations
   
2. **Create New Organization**
   ```
   Name: Infrastructure
   Description: Infrastructure Automation Projects
   Tags: infra, automation
   ```

3. **Configure Organization Settings**
   - Enable CD Module
   - Set default resource limits
   - Configure notification channels

## 2.2 Create Project

1. **Navigate to Organization**
   - Select "Infrastructure" organization
   
2. **Create Project**
   ```yaml
   Name: RabbitMQ-Deployment
   Identifier: rabbitmq_deployment
   Description: RabbitMQ 4.x Cluster Deployment using Ansible
   Color: #FF6B35  # Orange for infrastructure
   Modules Enabled:
     - Continuous Delivery
     - Continuous Verification (optional)
   ```

3. **Project Structure**
   ```
   Organization: Infrastructure
   └── Project: RabbitMQ-Deployment
       ├── Pipelines
       ├── Services
       ├── Environments
       ├── Infrastructure Definitions
       ├── Connectors
       └── Secrets
   ```

## 2.3 Configure Project Settings

### Resource Groups
```yaml
Name: RabbitMQ-Resources
Resources:
  - All Pipelines
  - All Services
  - All Environments
  - All Connectors
  - All Secrets
Permissions:
  - View
  - Create/Edit
  - Delete
  - Execute
```

### User Roles
| Role | Permissions | Users/Groups |
|------|-------------|--------------|
| Project Admin | Full access | DevOps Team Lead |
| Pipeline Executor | Execute, View | DevOps Engineers |
| Viewer | View only | Development Team |
| Approver | Approve deployments | Team Leads, Managers |

---

# 3. Delegate Installation

## 3.1 Delegate Overview

The Harness Delegate is a worker process that executes tasks on your infrastructure. For Ansible automation, the Delegate needs:

- Python 3.9+
- Ansible 2.15+
- SSH access to target servers
- Required Ansible collections

## 3.2 Kubernetes Delegate Installation (Recommended)

### Step 1: Generate Delegate YAML

1. Navigate to **Project Settings → Delegates → New Delegate**
2. Select **Kubernetes** as infrastructure
3. Configure:
   ```yaml
   Name: rabbitmq-ansible-delegate
   Description: Delegate for RabbitMQ Ansible deployments
   Size: Small (0.5 CPU, 768MB Memory)
   Replicas: 2  # For high availability
   Tags: ansible, rabbitmq, infra
   ```

### Step 2: Customize Delegate Image

Create a custom Dockerfile with Ansible pre-installed:

```dockerfile
# Dockerfile for Custom Harness Delegate with Ansible
FROM harness/delegate:24.01.82308

USER root

# Install Python and pip
RUN microdnf install -y python3 python3-pip openssh-clients sshpass && \
    microdnf clean all

# Install Ansible and required collections
RUN pip3 install --no-cache-dir \
    ansible==8.7.0 \
    ansible-core==2.15.8 \
    jmespath \
    netaddr

# Install Ansible collections
RUN ansible-galaxy collection install \
    community.rabbitmq \
    community.general \
    ansible.posix

# Set working directory
WORKDIR /harness-delegate

USER 1001

# Verify installation
RUN ansible --version
```

### Step 3: Build and Push Custom Image

```bash
# Build the custom delegate image
docker build -t your-registry.com/harness-delegate-ansible:24.01 .

# Push to your container registry
docker push your-registry.com/harness-delegate-ansible:24.01
```

### Step 4: Deploy Delegate

```yaml
# harness-delegate.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: harness-delegate-ng
---
apiVersion: v1
kind: Secret
metadata:
  name: rabbitmq-ansible-delegate-token
  namespace: harness-delegate-ng
type: Opaque
stringData:
  DELEGATE_TOKEN: "<YOUR_DELEGATE_TOKEN>"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq-ansible-delegate
  namespace: harness-delegate-ng
  labels:
    app: rabbitmq-ansible-delegate
spec:
  replicas: 2
  selector:
    matchLabels:
      app: rabbitmq-ansible-delegate
  template:
    metadata:
      labels:
        app: rabbitmq-ansible-delegate
    spec:
      serviceAccountName: default
      containers:
        - name: delegate
          image: your-registry.com/harness-delegate-ansible:24.01
          imagePullPolicy: Always
          resources:
            requests:
              cpu: "0.5"
              memory: "768Mi"
            limits:
              cpu: "1"
              memory: "2Gi"
          env:
            - name: DELEGATE_NAME
              value: rabbitmq-ansible-delegate
            - name: NEXT_GEN
              value: "true"
            - name: DELEGATE_TYPE
              value: "KUBERNETES"
            - name: ACCOUNT_ID
              value: "<YOUR_ACCOUNT_ID>"
            - name: MANAGER_HOST_AND_PORT
              value: "https://app.harness.io"
            - name: DELEGATE_TOKEN
              valueFrom:
                secretKeyRef:
                  name: rabbitmq-ansible-delegate-token
                  key: DELEGATE_TOKEN
            - name: DELEGATE_TAGS
              value: "ansible,rabbitmq,infrastructure"
            - name: INIT_SCRIPT
              value: |
                # Additional setup if needed
                echo "Delegate initialized with Ansible support"
          volumeMounts:
            - name: ssh-keys
              mountPath: /root/.ssh
              readOnly: true
      volumes:
        - name: ssh-keys
          secret:
            secretName: ssh-private-key
            defaultMode: 0600
```

### Step 5: Verify Delegate

```bash
# Apply the delegate manifest
kubectl apply -f harness-delegate.yaml

# Verify delegate is running
kubectl get pods -n harness-delegate-ng

# Check delegate logs
kubectl logs -f deployment/rabbitmq-ansible-delegate -n harness-delegate-ng

# Verify Ansible installation
kubectl exec -it deployment/rabbitmq-ansible-delegate -n harness-delegate-ng -- ansible --version
```

## 3.3 Docker Delegate Installation (Alternative)

```bash
# Run Harness Delegate with Ansible
docker run -d --name rabbitmq-ansible-delegate \
  -e DELEGATE_NAME=rabbitmq-ansible-delegate \
  -e NEXT_GEN=true \
  -e DELEGATE_TYPE=DOCKER \
  -e ACCOUNT_ID=<YOUR_ACCOUNT_ID> \
  -e DELEGATE_TOKEN=<YOUR_DELEGATE_TOKEN> \
  -e MANAGER_HOST_AND_PORT=https://app.harness.io \
  -e DELEGATE_TAGS=ansible,rabbitmq,infrastructure \
  -v /path/to/ssh/keys:/root/.ssh:ro \
  -v /path/to/ansible/inventory:/ansible/inventory:ro \
  your-registry.com/harness-delegate-ansible:24.01
```

---

# 4. Connector Configuration

## 4.1 Git Connector (Source Code)

### Create GitHub/GitLab Connector

1. Navigate to **Project Settings → Connectors → New Connector**
2. Select **Code Repositories → GitHub** (or GitLab)

```yaml
Name: rabbitmq-ansible-repo
Identifier: rabbitmq_ansible_repo
Description: Repository containing RabbitMQ Ansible playbooks

URL Type: Repository
Connection Type: HTTP
Repository URL: https://github.com/your-org/rabbitmq-ansible-harness.git

Authentication:
  Type: Username and Token
  Username: <github-username>
  Personal Access Token: <account.github_token>  # Reference to secret

Enable API Access: Yes
API Authentication: Same as Repository

Delegate Selector: ansible
```

### Test Connection
Click "Test Connection" to verify:
- ✅ Git fetch works
- ✅ API access works
- ✅ Delegate can reach repository

## 4.2 SSH Connector (Target Servers)

### Create SSH Credential

1. Navigate to **Project Settings → Connectors → New Connector**
2. Select **Secret Managers → SSH Key**

```yaml
Name: rabbitmq-servers-ssh
Identifier: rabbitmq_servers_ssh
Description: SSH access to RabbitMQ servers

Credential Type: SSH Key
SSH Key Authentication:
  Username: ansible
  SSH Key: <account.ssh_private_key>  # Reference to secret
  Passphrase: (optional)

Port: 22

Delegate Selector: ansible
```

## 4.3 Artifact Connector (Optional)

If using custom RabbitMQ packages or configurations:

```yaml
Name: artifact-repository
Identifier: artifact_repository
Description: Nexus/Artifactory for custom packages

Type: Nexus 3
URL: https://nexus.your-company.com
Version: 3.x
Authentication:
  Username: <service-account>
  Password: <account.nexus_password>

Delegate Selector: ansible
```

---

# 5. Secret Management

## 5.1 Required Secrets

Create the following secrets in Harness:

### SSH Private Key
```yaml
Secret Type: SSH Key
Name: ssh-private-key
Identifier: ssh_private_key
Description: SSH key for accessing RabbitMQ servers
Secret Manager: Harness Built-in
SSH Key Type: PEM
Value: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ... your private key ...
  -----END OPENSSH PRIVATE KEY-----
```

### RabbitMQ Admin Password
```yaml
Secret Type: Text
Name: rabbitmq-admin-password
Identifier: rabbitmq_admin_password
Description: Password for RabbitMQ admin user
Secret Manager: Harness Built-in
Value: <encrypted-password>
```

### Erlang Cookie
```yaml
Secret Type: Text
Name: erlang-cookie
Identifier: erlang_cookie
Description: Erlang cookie for cluster communication
Secret Manager: Harness Built-in
Value: <random-secret-string>
```

### GitHub Token
```yaml
Secret Type: Text
Name: github-token
Identifier: github_token
Description: GitHub Personal Access Token
Secret Manager: Harness Built-in
Value: ghp_xxxxxxxxxxxxxxxxxxxx
```

## 5.2 Secret References in Pipeline

```yaml
# Reference secrets in pipeline variables
variables:
  - name: rabbitmq_password
    type: Secret
    value: <+secrets.getValue("rabbitmq_admin_password")>
  
  - name: erlang_cookie
    type: Secret
    value: <+secrets.getValue("erlang_cookie")>
```

---

# 6. Ansible Playbook Structure

## 6.1 Repository Structure

Create the following files in your Git repository:

### `ansible.cfg`
```ini
# ansible.cfg
[defaults]
inventory = inventory/
roles_path = roles/
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
callback_whitelist = timer, profile_tasks
forks = 10
timeout = 30

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
pipelining = True
```

### `requirements.yml`
```yaml
# requirements.yml - Ansible Galaxy requirements
---
collections:
  - name: community.rabbitmq
    version: ">=1.2.0"
  - name: community.general
    version: ">=7.0.0"
  - name: ansible.posix
    version: ">=1.5.0"

roles:
  - name: geerlingguy.erlang
    version: "2.2.0"
```

### `inventory/dev/hosts.yml`
```yaml
# inventory/dev/hosts.yml
---
all:
  children:
    rabbitmq_cluster:
      hosts:
        rabbitmq-dev-1:
          ansible_host: 192.168.10.101
          rabbitmq_node_type: disc
          rabbitmq_is_primary: true
        rabbitmq-dev-2:
          ansible_host: 192.168.10.102
          rabbitmq_node_type: disc
          rabbitmq_is_primary: false
        rabbitmq-dev-3:
          ansible_host: 192.168.10.103
          rabbitmq_node_type: disc
          rabbitmq_is_primary: false
      vars:
        ansible_user: ansible
        ansible_become: yes
        ansible_python_interpreter: /usr/bin/python3
```

### `inventory/dev/group_vars/all.yml`
```yaml
# inventory/dev/group_vars/all.yml
---
# Environment Configuration
environment_name: development
environment_short: dev

# RabbitMQ Configuration
rabbitmq_version: "4.0.3"
rabbitmq_release_series: "4.0"

# Erlang Configuration
erlang_version: "26.2"

# Cluster Configuration
rabbitmq_cluster_name: "rabbitmq-{{ environment_short }}-cluster"
rabbitmq_primary_node: "rabbitmq-dev-1"

# User Configuration
rabbitmq_admin_user: admin
rabbitmq_admin_password: "{{ lookup('env', 'RABBITMQ_ADMIN_PASSWORD') | default('ChangeMe123!') }}"

# Virtual Hosts
rabbitmq_vhosts:
  - name: /
    state: present
  - name: /app
    state: present
  - name: /monitoring
    state: present

# Application Users
rabbitmq_users:
  - user: admin
    password: "{{ rabbitmq_admin_password }}"
    tags: administrator
    vhost: /
    configure_priv: .*
    read_priv: .*
    write_priv: .*
  - user: app_user
    password: "{{ lookup('env', 'RABBITMQ_APP_PASSWORD') | default('AppPass123!') }}"
    tags: ""
    vhost: /app
    configure_priv: .*
    read_priv: .*
    write_priv: .*
  - user: monitoring
    password: "{{ lookup('env', 'RABBITMQ_MONITORING_PASSWORD') | default('MonitorPass123!') }}"
    tags: monitoring
    vhost: /
    configure_priv: ""
    read_priv: .*
    write_priv: ""

# Plugins
rabbitmq_plugins:
  - rabbitmq_management
  - rabbitmq_management_agent
  - rabbitmq_prometheus
  - rabbitmq_shovel
  - rabbitmq_shovel_management
  - rabbitmq_federation
  - rabbitmq_federation_management

# Resource Limits
rabbitmq_vm_memory_high_watermark: 0.6
rabbitmq_disk_free_limit: "2GB"
rabbitmq_channel_max: 2047

# Networking
rabbitmq_listeners:
  - port: 5672
    ip: "::"
rabbitmq_management_listener:
  port: 15672
  ip: "::"
  ssl: false

# Logging
rabbitmq_log_level: info
rabbitmq_log_rotation:
  file: /var/log/rabbitmq/rabbitmq.log
  rotation_count: 10
  rotation_size: 10485760  # 10MB

# Quorum Queues (RabbitMQ 4.x default)
rabbitmq_default_queue_type: quorum

# Policies
rabbitmq_policies:
  - name: ha-all
    pattern: ".*"
    vhost: /
    tags:
      ha-mode: all
      ha-sync-mode: automatic
  - name: quorum-default
    pattern: "^quorum\\."
    vhost: /
    tags:
      queue-mode: lazy
```

### `playbooks/site.yml` (Main Playbook)
```yaml
# playbooks/site.yml
---
- name: RabbitMQ 4.x Cluster Deployment
  hosts: rabbitmq_cluster
  become: yes
  gather_facts: yes
  
  vars:
    deployment_timestamp: "{{ ansible_date_time.iso8601 }}"
    
  pre_tasks:
    - name: Display deployment information
      ansible.builtin.debug:
        msg: |
          ═══════════════════════════════════════════════════════════
          RabbitMQ Cluster Deployment
          ═══════════════════════════════════════════════════════════
          Environment: {{ environment_name }}
          Cluster Name: {{ rabbitmq_cluster_name }}
          RabbitMQ Version: {{ rabbitmq_version }}
          Timestamp: {{ deployment_timestamp }}
          Target Nodes: {{ groups['rabbitmq_cluster'] | join(', ') }}
          ═══════════════════════════════════════════════════════════
      run_once: true

    - name: Validate minimum node count
      ansible.builtin.assert:
        that:
          - groups['rabbitmq_cluster'] | length >= 3
        fail_msg: "Cluster requires minimum 3 nodes for quorum"
        success_msg: "Node count validation passed"
      run_once: true

    - name: Verify network connectivity between nodes
      ansible.builtin.command: "ping -c 3 {{ hostvars[item]['ansible_host'] }}"
      loop: "{{ groups['rabbitmq_cluster'] }}"
      register: ping_results
      changed_when: false
      failed_when: ping_results.rc != 0

  roles:
    - role: common
      tags: [common, always]
    - role: erlang
      tags: [erlang, runtime]
    - role: rabbitmq
      tags: [rabbitmq, application]
    - role: monitoring
      tags: [monitoring, observability]
      
  post_tasks:
    - name: Deployment summary
      ansible.builtin.debug:
        msg: |
          ═══════════════════════════════════════════════════════════
          Deployment Complete!
          ═══════════════════════════════════════════════════════════
          Management UI: http://{{ ansible_host }}:15672
          AMQP Endpoint: amqp://{{ ansible_host }}:5672
          Prometheus Metrics: http://{{ ansible_host }}:15692/metrics
          ═══════════════════════════════════════════════════════════
```

### `roles/common/tasks/main.yml`
```yaml
# roles/common/tasks/main.yml
---
- name: Update package cache
  ansible.builtin.apt:
    update_cache: yes
    cache_valid_time: 3600
  when: ansible_os_family == 'Debian'

- name: Update package cache (RHEL)
  ansible.builtin.dnf:
    update_cache: yes
  when: ansible_os_family == 'RedHat'

- name: Install common packages
  ansible.builtin.package:
    name:
      - curl
      - wget
      - vim
      - htop
      - net-tools
      - gnupg
      - apt-transport-https
      - ca-certificates
      - python3-pip
    state: present

- name: Set hostname
  ansible.builtin.hostname:
    name: "{{ inventory_hostname }}"

- name: Configure /etc/hosts
  ansible.builtin.lineinfile:
    path: /etc/hosts
    line: "{{ hostvars[item]['ansible_host'] }} {{ item }}"
    state: present
  loop: "{{ groups['rabbitmq_cluster'] }}"

- name: Configure system limits
  ansible.builtin.template:
    src: limits.conf.j2
    dest: /etc/security/limits.d/99-rabbitmq.conf
    mode: '0644'

- name: Set sysctl parameters
  ansible.posix.sysctl:
    name: "{{ item.name }}"
    value: "{{ item.value }}"
    sysctl_set: yes
    state: present
    reload: yes
  loop:
    - { name: 'net.core.somaxconn', value: '4096' }
    - { name: 'net.ipv4.tcp_max_syn_backlog', value: '4096' }
    - { name: 'net.ipv4.tcp_fin_timeout', value: '30' }
    - { name: 'vm.swappiness', value: '1' }

- name: Configure firewall (RHEL/CentOS)
  ansible.posix.firewalld:
    port: "{{ item }}"
    permanent: yes
    state: enabled
    immediate: yes
  loop:
    - 4369/tcp   # EPMD
    - 5672/tcp   # AMQP
    - 15672/tcp  # Management
    - 25672/tcp  # Erlang distribution
    - 15692/tcp  # Prometheus
  when: ansible_os_family == 'RedHat'
  ignore_errors: yes
```

### `roles/erlang/tasks/main.yml`
```yaml
# roles/erlang/tasks/main.yml
---
- name: Check if Erlang is already installed
  ansible.builtin.command: erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell
  register: erlang_check
  changed_when: false
  failed_when: false

- name: Display current Erlang version
  ansible.builtin.debug:
    msg: "Current Erlang version: {{ erlang_check.stdout | default('Not installed') }}"

- name: Add RabbitMQ signing key (Debian/Ubuntu)
  ansible.builtin.apt_key:
    url: https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA
    state: present
  when: ansible_os_family == 'Debian'

- name: Add Cloudsmith Erlang repository (Debian/Ubuntu)
  ansible.builtin.apt_repository:
    repo: "deb https://ppa1.novemberain.com/rabbitmq/rabbitmq-erlang/deb/{{ ansible_distribution | lower }} {{ ansible_distribution_release }} main"
    state: present
    filename: rabbitmq-erlang
  when: ansible_os_family == 'Debian'

- name: Install Erlang (Debian/Ubuntu)
  ansible.builtin.apt:
    name:
      - erlang-base
      - erlang-asn1
      - erlang-crypto
      - erlang-eldap
      - erlang-ftp
      - erlang-inets
      - erlang-mnesia
      - erlang-os-mon
      - erlang-parsetools
      - erlang-public-key
      - erlang-runtime-tools
      - erlang-snmp
      - erlang-ssl
      - erlang-syntax-tools
      - erlang-tftp
      - erlang-tools
      - erlang-xmerl
    state: present
    update_cache: yes
  when: ansible_os_family == 'Debian'

- name: Add RHEL Erlang repository
  ansible.builtin.yum_repository:
    name: rabbitmq-erlang
    description: RabbitMQ Erlang Repository
    baseurl: "https://packagecloud.io/rabbitmq/erlang/el/{{ ansible_distribution_major_version }}/$basearch"
    gpgcheck: yes
    gpgkey: https://packagecloud.io/rabbitmq/erlang/gpgkey
    enabled: yes
  when: ansible_os_family == 'RedHat'

- name: Install Erlang (RHEL)
  ansible.builtin.dnf:
    name: erlang
    state: present
  when: ansible_os_family == 'RedHat'

- name: Verify Erlang installation
  ansible.builtin.command: erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell
  register: erlang_version_check
  changed_when: false

- name: Display installed Erlang version
  ansible.builtin.debug:
    msg: "Erlang OTP version: {{ erlang_version_check.stdout }}"
```

### `roles/rabbitmq/tasks/main.yml`
```yaml
# roles/rabbitmq/tasks/main.yml
---
- name: Include installation tasks
  ansible.builtin.include_tasks: install.yml

- name: Include configuration tasks
  ansible.builtin.include_tasks: configure.yml

- name: Include clustering tasks
  ansible.builtin.include_tasks: cluster.yml

- name: Include user management tasks
  ansible.builtin.include_tasks: users.yml

- name: Include policy tasks
  ansible.builtin.include_tasks: policies.yml
```

### `roles/rabbitmq/tasks/install.yml`
```yaml
# roles/rabbitmq/tasks/install.yml
---
- name: Add RabbitMQ repository key (Debian/Ubuntu)
  ansible.builtin.apt_key:
    url: https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA
    state: present
  when: ansible_os_family == 'Debian'

- name: Add RabbitMQ repository (Debian/Ubuntu)
  ansible.builtin.apt_repository:
    repo: "deb https://ppa1.novemberain.com/rabbitmq/rabbitmq-server/deb/{{ ansible_distribution | lower }} {{ ansible_distribution_release }} main"
    state: present
    filename: rabbitmq-server
  when: ansible_os_family == 'Debian'

- name: Install RabbitMQ (Debian/Ubuntu)
  ansible.builtin.apt:
    name: "rabbitmq-server={{ rabbitmq_version }}*"
    state: present
    update_cache: yes
  when: ansible_os_family == 'Debian'

- name: Add RabbitMQ repository (RHEL)
  ansible.builtin.yum_repository:
    name: rabbitmq-server
    description: RabbitMQ Server Repository
    baseurl: "https://packagecloud.io/rabbitmq/rabbitmq-server/el/{{ ansible_distribution_major_version }}/$basearch"
    gpgcheck: yes
    gpgkey: https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey
    enabled: yes
  when: ansible_os_family == 'RedHat'

- name: Install RabbitMQ (RHEL)
  ansible.builtin.dnf:
    name: "rabbitmq-server-{{ rabbitmq_version }}"
    state: present
  when: ansible_os_family == 'RedHat'

- name: Create RabbitMQ directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: rabbitmq
    group: rabbitmq
    mode: '0755'
  loop:
    - /var/lib/rabbitmq
    - /var/log/rabbitmq
    - /etc/rabbitmq

- name: Set Erlang cookie
  ansible.builtin.copy:
    content: "{{ erlang_cookie }}"
    dest: /var/lib/rabbitmq/.erlang.cookie
    owner: rabbitmq
    group: rabbitmq
    mode: '0400'
  notify: restart rabbitmq
```

### `roles/rabbitmq/tasks/configure.yml`
```yaml
# roles/rabbitmq/tasks/configure.yml
---
- name: Deploy RabbitMQ configuration
  ansible.builtin.template:
    src: rabbitmq.conf.j2
    dest: /etc/rabbitmq/rabbitmq.conf
    owner: rabbitmq
    group: rabbitmq
    mode: '0644'
  notify: restart rabbitmq

- name: Deploy advanced configuration
  ansible.builtin.template:
    src: advanced.config.j2
    dest: /etc/rabbitmq/advanced.config
    owner: rabbitmq
    group: rabbitmq
    mode: '0644'
  notify: restart rabbitmq

- name: Enable RabbitMQ plugins
  community.rabbitmq.rabbitmq_plugin:
    names: "{{ rabbitmq_plugins | join(',') }}"
    state: enabled
  notify: restart rabbitmq

- name: Deploy enabled_plugins file
  ansible.builtin.template:
    src: enabled_plugins.j2
    dest: /etc/rabbitmq/enabled_plugins
    owner: rabbitmq
    group: rabbitmq
    mode: '0644'
  notify: restart rabbitmq

- name: Enable and start RabbitMQ service
  ansible.builtin.systemd:
    name: rabbitmq-server
    enabled: yes
    state: started

- name: Wait for RabbitMQ to be ready
  ansible.builtin.wait_for:
    port: 5672
    host: "{{ ansible_host }}"
    delay: 5
    timeout: 120
```

### `roles/rabbitmq/tasks/cluster.yml`
```yaml
# roles/rabbitmq/tasks/cluster.yml
---
- name: Get cluster status
  ansible.builtin.command: rabbitmqctl cluster_status
  register: cluster_status
  changed_when: false
  run_once: true
  delegate_to: "{{ rabbitmq_primary_node }}"

- name: Display cluster status
  ansible.builtin.debug:
    msg: "{{ cluster_status.stdout_lines }}"
  run_once: true

# Join cluster on non-primary nodes
- name: Stop RabbitMQ app (secondary nodes)
  ansible.builtin.command: rabbitmqctl stop_app
  when: 
    - not rabbitmq_is_primary | default(false)
    - rabbitmq_primary_node not in cluster_status.stdout
  
- name: Reset RabbitMQ node (secondary nodes)
  ansible.builtin.command: rabbitmqctl reset
  when:
    - not rabbitmq_is_primary | default(false)
    - rabbitmq_primary_node not in cluster_status.stdout

- name: Join cluster (secondary nodes)
  ansible.builtin.command: "rabbitmqctl join_cluster rabbit@{{ rabbitmq_primary_node }}"
  when:
    - not rabbitmq_is_primary | default(false)
    - rabbitmq_primary_node not in cluster_status.stdout

- name: Start RabbitMQ app (secondary nodes)
  ansible.builtin.command: rabbitmqctl start_app
  when:
    - not rabbitmq_is_primary | default(false)
    - rabbitmq_primary_node not in cluster_status.stdout

- name: Set cluster name
  ansible.builtin.command: "rabbitmqctl set_cluster_name {{ rabbitmq_cluster_name }}"
  run_once: true
  delegate_to: "{{ rabbitmq_primary_node }}"
  changed_when: false

- name: Verify cluster formation
  ansible.builtin.command: rabbitmqctl cluster_status
  register: final_cluster_status
  changed_when: false
  run_once: true
  delegate_to: "{{ rabbitmq_primary_node }}"

- name: Display final cluster status
  ansible.builtin.debug:
    msg: "{{ final_cluster_status.stdout_lines }}"
  run_once: true
```

### `roles/rabbitmq/tasks/users.yml`
```yaml
# roles/rabbitmq/tasks/users.yml
---
- name: Create virtual hosts
  community.rabbitmq.rabbitmq_vhost:
    name: "{{ item.name }}"
    state: "{{ item.state | default('present') }}"
  loop: "{{ rabbitmq_vhosts }}"
  run_once: true
  delegate_to: "{{ rabbitmq_primary_node }}"

- name: Create RabbitMQ users
  community.rabbitmq.rabbitmq_user:
    user: "{{ item.user }}"
    password: "{{ item.password }}"
    tags: "{{ item.tags }}"
    vhost: "{{ item.vhost }}"
    configure_priv: "{{ item.configure_priv }}"
    read_priv: "{{ item.read_priv }}"
    write_priv: "{{ item.write_priv }}"
    state: present
  loop: "{{ rabbitmq_users }}"
  run_once: true
  delegate_to: "{{ rabbitmq_primary_node }}"
  no_log: true  # Hide passwords in logs

- name: Remove default guest user
  community.rabbitmq.rabbitmq_user:
    user: guest
    state: absent
  run_once: true
  delegate_to: "{{ rabbitmq_primary_node }}"
```

### `roles/rabbitmq/tasks/policies.yml`
```yaml
# roles/rabbitmq/tasks/policies.yml
---
- name: Configure RabbitMQ policies
  community.rabbitmq.rabbitmq_policy:
    name: "{{ item.name }}"
    pattern: "{{ item.pattern }}"
    vhost: "{{ item.vhost }}"
    tags: "{{ item.tags }}"
    state: present
  loop: "{{ rabbitmq_policies }}"
  run_once: true
  delegate_to: "{{ rabbitmq_primary_node }}"
```

### `roles/rabbitmq/handlers/main.yml`
```yaml
# roles/rabbitmq/handlers/main.yml
---
- name: restart rabbitmq
  ansible.builtin.systemd:
    name: rabbitmq-server
    state: restarted
```

### `roles/rabbitmq/templates/rabbitmq.conf.j2`
```ini
# roles/rabbitmq/templates/rabbitmq.conf.j2
# RabbitMQ 4.x Configuration
# Generated by Harness CD Pipeline - {{ ansible_date_time.iso8601 }}

## Cluster Configuration
cluster_name = {{ rabbitmq_cluster_name }}
cluster_formation.peer_discovery_backend = rabbit_peer_discovery_classic_config
cluster_formation.classic_config.nodes.1 = rabbit@{{ groups['rabbitmq_cluster'][0] }}
cluster_formation.classic_config.nodes.2 = rabbit@{{ groups['rabbitmq_cluster'][1] }}
cluster_formation.classic_config.nodes.3 = rabbit@{{ groups['rabbitmq_cluster'][2] }}

## Networking
listeners.tcp.default = {{ rabbitmq_listeners[0].port }}
management.tcp.port = {{ rabbitmq_management_listener.port }}
management.tcp.ip = {{ rabbitmq_management_listener.ip }}

## Resource Limits
vm_memory_high_watermark.relative = {{ rabbitmq_vm_memory_high_watermark }}
disk_free_limit.absolute = {{ rabbitmq_disk_free_limit }}
channel_max = {{ rabbitmq_channel_max }}

## Logging
log.file.level = {{ rabbitmq_log_level }}
log.console = true
log.console.level = {{ rabbitmq_log_level }}

## Default Queue Type (RabbitMQ 4.x)
default_queue_type = {{ rabbitmq_default_queue_type }}

## Consumer Timeout (RabbitMQ 4.x)
consumer_timeout = 1800000

## Message TTL
message_ttl = 86400000

## Prometheus Metrics
prometheus.tcp.port = 15692

## Connections
tcp_listen_options.backlog = 4096
tcp_listen_options.nodelay = true
tcp_listen_options.linger.on = true
tcp_listen_options.linger.timeout = 0
tcp_listen_options.sndbuf = 196608
tcp_listen_options.recbuf = 196608
```

### `playbooks/validate.yml`
```yaml
# playbooks/validate.yml
---
- name: Validate RabbitMQ Cluster
  hosts: rabbitmq_cluster
  become: yes
  gather_facts: no
  
  tasks:
    - name: Check RabbitMQ service status
      ansible.builtin.systemd:
        name: rabbitmq-server
      register: rabbitmq_service
      
    - name: Assert RabbitMQ is running
      ansible.builtin.assert:
        that:
          - rabbitmq_service.status.ActiveState == 'active'
        fail_msg: "RabbitMQ service is not running on {{ inventory_hostname }}"
        success_msg: "RabbitMQ service is active on {{ inventory_hostname }}"

    - name: Check cluster status
      ansible.builtin.command: rabbitmqctl cluster_status --formatter json
      register: cluster_status
      changed_when: false
      run_once: true
      delegate_to: "{{ groups['rabbitmq_cluster'][0] }}"

    - name: Parse cluster status
      ansible.builtin.set_fact:
        cluster_info: "{{ cluster_status.stdout | from_json }}"
      run_once: true

    - name: Assert all nodes are in cluster
      ansible.builtin.assert:
        that:
          - cluster_info.running_nodes | length >= 3
        fail_msg: "Not all nodes joined the cluster. Running nodes: {{ cluster_info.running_nodes }}"
        success_msg: "All {{ cluster_info.running_nodes | length }} nodes are in the cluster"
      run_once: true

    - name: Check AMQP port accessibility
      ansible.builtin.wait_for:
        port: 5672
        host: "{{ ansible_host }}"
        timeout: 10
      register: amqp_port

    - name: Check Management UI port accessibility
      ansible.builtin.wait_for:
        port: 15672
        host: "{{ ansible_host }}"
        timeout: 10
      register: mgmt_port

    - name: Test RabbitMQ API health
      ansible.builtin.uri:
        url: "http://{{ ansible_host }}:15672/api/healthchecks/node"
        user: "{{ rabbitmq_admin_user }}"
        password: "{{ rabbitmq_admin_password }}"
        method: GET
        status_code: 200
      register: health_check
      run_once: true
      delegate_to: "{{ groups['rabbitmq_cluster'][0] }}"

    - name: Display health check result
      ansible.builtin.debug:
        msg: "Health check status: {{ health_check.json.status }}"
      run_once: true

    - name: Generate validation report
      ansible.builtin.debug:
        msg: |
          ═══════════════════════════════════════════════════════════
          VALIDATION REPORT
          ═══════════════════════════════════════════════════════════
          Cluster Name: {{ cluster_info.cluster_name }}
          Running Nodes: {{ cluster_info.running_nodes | join(', ') }}
          Node Count: {{ cluster_info.running_nodes | length }}
          
          Service Status:
          {% for node in groups['rabbitmq_cluster'] %}
            - {{ node }}: ✅ Running
          {% endfor %}
          
          Port Accessibility:
            - AMQP (5672): ✅ Accessible
            - Management (15672): ✅ Accessible
          
          Health Check: {{ health_check.json.status | upper }}
          ═══════════════════════════════════════════════════════════
      run_once: true
```

### `playbooks/rollback.yml`
```yaml
# playbooks/rollback.yml
---
- name: Rollback RabbitMQ Deployment
  hosts: rabbitmq_cluster
  become: yes
  gather_facts: yes
  serial: 1  # Process one node at a time
  
  vars:
    rollback_version: "{{ previous_version | default('4.0.2') }}"
    
  tasks:
    - name: Display rollback information
      ansible.builtin.debug:
        msg: |
          ═══════════════════════════════════════════════════════════
          ROLLBACK INITIATED
          ═══════════════════════════════════════════════════════════
          Target Node: {{ inventory_hostname }}
          Rolling back to version: {{ rollback_version }}
          ═══════════════════════════════════════════════════════════

    - name: Stop RabbitMQ application
      ansible.builtin.command: rabbitmqctl stop_app
      ignore_errors: yes

    - name: Stop RabbitMQ service
      ansible.builtin.systemd:
        name: rabbitmq-server
        state: stopped

    - name: Backup current data directory
      ansible.builtin.archive:
        path: /var/lib/rabbitmq
        dest: "/tmp/rabbitmq-backup-{{ ansible_date_time.epoch }}.tar.gz"
        format: gz

    - name: Downgrade RabbitMQ package (Debian/Ubuntu)
      ansible.builtin.apt:
        name: "rabbitmq-server={{ rollback_version }}*"
        state: present
        force: yes
      when: ansible_os_family == 'Debian'

    - name: Start RabbitMQ service
      ansible.builtin.systemd:
        name: rabbitmq-server
        state: started

    - name: Wait for RabbitMQ to be ready
      ansible.builtin.wait_for:
        port: 5672
        host: "{{ ansible_host }}"
        delay: 10
        timeout: 120

    - name: Verify node rejoined cluster
      ansible.builtin.command: rabbitmqctl cluster_status
      register: cluster_status
      changed_when: false

    - name: Display rollback result
      ansible.builtin.debug:
        msg: "Rollback completed for {{ inventory_hostname }}"
```

---

# 7. Service Configuration

## 7.1 Create Harness Service

Navigate to **Project → Services → New Service**

```yaml
# Service Definition YAML
service:
  name: RabbitMQ-Cluster
  identifier: rabbitmq_cluster
  description: RabbitMQ 4.x Cluster Deployment Service
  tags:
    - rabbitmq
    - messaging
    - infrastructure
  serviceDefinition:
    type: CustomDeployment
    spec:
      customDeploymentRef:
        templateRef: Ansible_Deployment
        versionLabel: v1
      artifacts:
        primary:
          primaryArtifactRef: ansible-playbooks
          sources:
            - identifier: ansible-playbooks
              type: CustomArtifact
              spec:
                version: <+input>
                scripts:
                  fetchAllArtifacts:
                    type: Inline
                    spec:
                      source:
                        type: Inline
                        spec:
                          script: |
                            # Fetch available versions from Git tags
                            git ls-remote --tags <+serviceVariables.repo_url> | \
                              awk '{print $2}' | sed 's|refs/tags/||' | sort -V
      variables:
        - name: rabbitmq_version
          type: String
          description: RabbitMQ version to deploy
          value: "4.0.3"
        - name: erlang_version
          type: String
          description: Erlang OTP version
          value: "26.2"
        - name: cluster_size
          type: Number
          description: Number of nodes in cluster
          value: 3
        - name: repo_url
          type: String
          description: Git repository URL
          value: https://github.com/your-org/rabbitmq-ansible-harness.git
```

## 7.2 Custom Deployment Template

Create a Custom Deployment Template for Ansible:

```yaml
# Custom Deployment Template: Ansible_Deployment
template:
  name: Ansible Deployment Template
  identifier: Ansible_Deployment
  versionLabel: v1
  type: CustomDeployment
  projectIdentifier: rabbitmq_deployment
  orgIdentifier: Infrastructure
  spec:
    infrastructure:
      variables:
        - name: inventory_file
          type: String
          description: Path to Ansible inventory file
          required: true
        - name: playbook_path
          type: String
          description: Path to main playbook
          required: true
          defaultValue: playbooks/site.yml
        - name: extra_vars
          type: String
          description: Extra variables to pass to Ansible
          required: false
      fetchInstancesScript:
        store:
          type: Inline
          spec:
            content: |
              # Fetch current instance list from inventory
              cat $INVENTORY_FILE | grep -E "^\s+[a-z]" | awk '{print $1}'
      instanceAttributes:
        - name: hostname
          jsonPath: hostname
        - name: ip_address
          jsonPath: ansible_host
      instancesArrayPath: instances
    execution:
      stepTemplateRefs:
        - ansible_playbook_step
```

---

# 8. Environment Setup

## 8.1 Create Environments

### Development Environment

```yaml
# Environment: Development
environment:
  name: Development
  identifier: development
  description: Development environment for RabbitMQ cluster
  type: PreProduction
  tags:
    - dev
    - non-prod
  orgIdentifier: Infrastructure
  projectIdentifier: rabbitmq_deployment
  variables:
    - name: inventory_path
      type: String
      value: inventory/dev/hosts.yml
    - name: environment_name
      type: String
      value: development
```

### Staging Environment

```yaml
# Environment: Staging
environment:
  name: Staging
  identifier: staging
  description: Staging environment for RabbitMQ cluster
  type: PreProduction
  tags:
    - staging
    - non-prod
  orgIdentifier: Infrastructure
  projectIdentifier: rabbitmq_deployment
  variables:
    - name: inventory_path
      type: String
      value: inventory/staging/hosts.yml
    - name: environment_name
      type: String
      value: staging
```

### Production Environment

```yaml
# Environment: Production
environment:
  name: Production
  identifier: production
  description: Production environment for RabbitMQ cluster
  type: Production
  tags:
    - production
    - prod
  orgIdentifier: Infrastructure
  projectIdentifier: rabbitmq_deployment
  variables:
    - name: inventory_path
      type: String
      value: inventory/production/hosts.yml
    - name: environment_name
      type: String
      value: production
```

## 8.2 Infrastructure Definitions

### Development Infrastructure

```yaml
# Infrastructure Definition: Dev
infrastructureDefinition:
  name: RabbitMQ-Dev-Infra
  identifier: rabbitmq_dev_infra
  description: Development infrastructure for RabbitMQ
  orgIdentifier: Infrastructure
  projectIdentifier: rabbitmq_deployment
  environmentRef: development
  deploymentType: CustomDeployment
  type: CustomDeployment
  spec:
    customDeploymentRef:
      templateRef: Ansible_Deployment
      versionLabel: v1
    variables:
      - name: inventory_file
        type: String
        value: inventory/dev/hosts.yml
      - name: playbook_path
        type: String
        value: playbooks/site.yml
      - name: ansible_user
        type: String
        value: ansible
    allowSimultaneousDeployments: false
```

---

# 9. Pipeline Creation

## 9.1 Complete Pipeline YAML

```yaml
# pipeline.yaml - RabbitMQ Cluster Deployment Pipeline
pipeline:
  name: RabbitMQ-Cluster-Deployment
  identifier: rabbitmq_cluster_deployment
  description: Deploy RabbitMQ 4.x cluster using Ansible automation
  projectIdentifier: rabbitmq_deployment
  orgIdentifier: Infrastructure
  tags:
    - rabbitmq
    - ansible
    - infrastructure
    - cd
  
  properties:
    ci:
      codebase:
        connectorRef: rabbitmq_ansible_repo
        repoName: rabbitmq-ansible-harness
        build: <+input>

  variables:
    - name: rabbitmq_version
      type: String
      description: RabbitMQ version to deploy
      required: true
      default: "4.0.3"
    - name: erlang_cookie
      type: Secret
      description: Erlang cluster cookie
      required: true
      value: <+secrets.getValue("erlang_cookie")>
    - name: rabbitmq_admin_password
      type: Secret
      description: RabbitMQ admin password
      required: true
      value: <+secrets.getValue("rabbitmq_admin_password")>
    - name: deploy_all_environments
      type: Boolean
      description: Deploy to all environments
      default: false

  stages:
    # ═══════════════════════════════════════════════════════════
    # STAGE 1: Pre-Flight Checks
    # ═══════════════════════════════════════════════════════════
    - stage:
        name: Pre-Flight-Checks
        identifier: preflight_checks
        description: Validate prerequisites before deployment
        type: Custom
        spec:
          execution:
            steps:
              - step:
                  name: Clone Repository
                  identifier: clone_repo
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "═══════════════════════════════════════════════════════════"
                      echo "Cloning Ansible Repository"
                      echo "═══════════════════════════════════════════════════════════"
                      
                      git clone <+pipeline.variables.repo_url> ansible-playbooks
                      cd ansible-playbooks
                      git checkout <+pipeline.variables.git_branch>
                      
                      echo "Repository cloned successfully"
                      ls -la
                    
              - step:
                  name: Validate Ansible Playbooks
                  identifier: validate_playbooks
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "═══════════════════════════════════════════════════════════"
                      echo "Validating Ansible Playbooks"
                      echo "═══════════════════════════════════════════════════════════"
                      
                      cd ansible-playbooks
                      
                      # Install required collections
                      ansible-galaxy collection install -r requirements.yml
                      
                      # Syntax check
                      ansible-playbook playbooks/site.yml --syntax-check
                      
                      # Lint check (optional)
                      # ansible-lint playbooks/
                      
                      echo "✅ Playbook validation passed"

              - step:
                  name: Verify Target Connectivity
                  identifier: verify_connectivity
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "═══════════════════════════════════════════════════════════"
                      echo "Verifying Target Server Connectivity"
                      echo "═══════════════════════════════════════════════════════════"
                      
                      cd ansible-playbooks
                      
                      # Ping all hosts
                      ansible all -i <+env.variables.inventory_path> -m ping
                      
                      # Gather facts to verify connection
                      ansible all -i <+env.variables.inventory_path> -m setup -a 'filter=ansible_distribution*'
                      
                      echo "✅ All target servers are reachable"
        tags:
          - preflight
          - validation

    # ═══════════════════════════════════════════════════════════
    # STAGE 2: Development Deployment
    # ═══════════════════════════════════════════════════════════
    - stage:
        name: Deploy-to-Development
        identifier: deploy_dev
        description: Deploy RabbitMQ cluster to Development environment
        type: Deployment
        spec:
          deploymentType: CustomDeployment
          service:
            serviceRef: rabbitmq_cluster
          environment:
            environmentRef: development
            infrastructureDefinitions:
              - identifier: rabbitmq_dev_infra
          execution:
            steps:
              - step:
                  name: Pre-Deployment Backup
                  identifier: pre_deploy_backup
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "═══════════════════════════════════════════════════════════"
                      echo "Creating Pre-Deployment Backup"
                      echo "═══════════════════════════════════════════════════════════"
                      
                      cd ansible-playbooks
                      
                      # Run backup playbook
                      ansible-playbook playbooks/backup.yml \
                        -i inventory/dev/hosts.yml \
                        -e "backup_timestamp=$(date +%Y%m%d_%H%M%S)"
                      
                      echo "✅ Backup completed"
                  timeout: 10m

              - step:
                  name: Deploy RabbitMQ Cluster
                  identifier: deploy_rabbitmq
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "═══════════════════════════════════════════════════════════"
                      echo "Deploying RabbitMQ <+pipeline.variables.rabbitmq_version>"
                      echo "Environment: Development"
                      echo "═══════════════════════════════════════════════════════════"
                      
                      cd ansible-playbooks
                      
                      # Set environment variables for secrets
                      export ERLANG_COOKIE='<+pipeline.variables.erlang_cookie>'
                      export RABBITMQ_ADMIN_PASSWORD='<+pipeline.variables.rabbitmq_admin_password>'
                      
                      # Run main playbook
                      ansible-playbook playbooks/site.yml \
                        -i inventory/dev/hosts.yml \
                        -e "rabbitmq_version=<+pipeline.variables.rabbitmq_version>" \
                        -e "erlang_cookie=${ERLANG_COOKIE}" \
                        -e "rabbitmq_admin_password=${RABBITMQ_ADMIN_PASSWORD}" \
                        -e "environment_name=development" \
                        -v
                      
                      echo "✅ Deployment completed successfully"
                  timeout: 30m
                  failureStrategies:
                    - onFailure:
                        errors:
                          - AllErrors
                        action:
                          type: StageRollback

              - step:
                  name: Validate Deployment
                  identifier: validate_deployment
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "═══════════════════════════════════════════════════════════"
                      echo "Validating RabbitMQ Cluster Deployment"
                      echo "═══════════════════════════════════════════════════════════"
                      
                      cd ansible-playbooks
                      
                      export RABBITMQ_ADMIN_PASSWORD='<+pipeline.variables.rabbitmq_admin_password>'
                      
                      # Run validation playbook
                      ansible-playbook playbooks/validate.yml \
                        -i inventory/dev/hosts.yml \
                        -e "rabbitmq_admin_password=${RABBITMQ_ADMIN_PASSWORD}"
                      
                      echo "✅ Validation passed"
                  timeout: 10m

              - step:
                  name: Smoke Tests
                  identifier: smoke_tests
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "═══════════════════════════════════════════════════════════"
                      echo "Running Smoke Tests"
                      echo "═══════════════════════════════════════════════════════════"
                      
                      # Get first node IP
                      RABBITMQ_HOST=$(grep -A1 'rabbitmq-dev-1:' ansible-playbooks/inventory/dev/hosts.yml | grep ansible_host | awk '{print $2}')
                      
                      # Test Management API
                      curl -s -u admin:<+pipeline.variables.rabbitmq_admin_password> \
                        http://${RABBITMQ_HOST}:15672/api/overview | jq '.cluster_name'
                      
                      # Test AMQP connectivity
                      python3 << 'EOF'
                      import pika
                      import sys
                      
                      credentials = pika.PlainCredentials('admin', '<+pipeline.variables.rabbitmq_admin_password>')
                      parameters = pika.ConnectionParameters(
                          host='${RABBITMQ_HOST}',
                          port=5672,
                          credentials=credentials
                      )
                      
                      try:
                          connection = pika.BlockingConnection(parameters)
                          channel = connection.channel()
                          
                          # Declare a test queue
                          channel.queue_declare(queue='harness_smoke_test', durable=False)
                          
                          # Publish a message
                          channel.basic_publish(
                              exchange='',
                              routing_key='harness_smoke_test',
                              body='Smoke test message from Harness'
                          )
                          
                          # Consume the message
                          method, properties, body = channel.basic_get('harness_smoke_test')
                          if body:
                              print(f"✅ Message received: {body.decode()}")
                          
                          # Cleanup
                          channel.queue_delete(queue='harness_smoke_test')
                          connection.close()
                          
                          print("✅ All smoke tests passed!")
                          sys.exit(0)
                      except Exception as e:
                          print(f"❌ Smoke test failed: {e}")
                          sys.exit(1)
                      EOF
                  timeout: 5m

            rollbackSteps:
              - step:
                  name: Rollback Deployment
                  identifier: rollback_deployment
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "═══════════════════════════════════════════════════════════"
                      echo "ROLLING BACK DEPLOYMENT"
                      echo "═══════════════════════════════════════════════════════════"
                      
                      cd ansible-playbooks
                      
                      export ERLANG_COOKIE='<+pipeline.variables.erlang_cookie>'
                      
                      ansible-playbook playbooks/rollback.yml \
                        -i inventory/dev/hosts.yml \
                        -e "previous_version=<+pipeline.variables.rollback_version>" \
                        -e "erlang_cookie=${ERLANG_COOKIE}"
                      
                      echo "⚠️ Rollback completed"
                  timeout: 30m
        tags:
          - dev
          - deployment

    # ═══════════════════════════════════════════════════════════
    # STAGE 3: Staging Deployment
    # ═══════════════════════════════════════════════════════════
    - stage:
        name: Deploy-to-Staging
        identifier: deploy_staging
        description: Deploy RabbitMQ cluster to Staging environment
        type: Deployment
        spec:
          deploymentType: CustomDeployment
          service:
            serviceRef: rabbitmq_cluster
          environment:
            environmentRef: staging
            infrastructureDefinitions:
              - identifier: rabbitmq_staging_infra
          execution:
            steps:
              - step:
                  name: Approval Gate
                  identifier: staging_approval
                  type: HarnessApproval
                  spec:
                    approvalMessage: |
                      Development deployment successful.
                      
                      Please review and approve deployment to STAGING:
                      - RabbitMQ Version: <+pipeline.variables.rabbitmq_version>
                      - Environment: Staging
                      
                      Development Metrics:
                      - Deployment Status: Success
                      - Cluster Health: Healthy
                    includePipelineExecutionHistory: true
                    approvers:
                      userGroups:
                        - account._account_all_users
                      minimumCount: 1
                    approverInputs: []
                  timeout: 4h

              - step:
                  name: Deploy RabbitMQ Cluster
                  identifier: deploy_rabbitmq_staging
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "═══════════════════════════════════════════════════════════"
                      echo "Deploying RabbitMQ <+pipeline.variables.rabbitmq_version>"
                      echo "Environment: Staging"
                      echo "═══════════════════════════════════════════════════════════"
                      
                      cd ansible-playbooks
                      
                      export ERLANG_COOKIE='<+pipeline.variables.erlang_cookie>'
                      export RABBITMQ_ADMIN_PASSWORD='<+pipeline.variables.rabbitmq_admin_password>'
                      
                      ansible-playbook playbooks/site.yml \
                        -i inventory/staging/hosts.yml \
                        -e "rabbitmq_version=<+pipeline.variables.rabbitmq_version>" \
                        -e "erlang_cookie=${ERLANG_COOKIE}" \
                        -e "rabbitmq_admin_password=${RABBITMQ_ADMIN_PASSWORD}" \
                        -e "environment_name=staging" \
                        -v
                      
                      echo "✅ Staging deployment completed"
                  timeout: 30m
                  failureStrategies:
                    - onFailure:
                        errors:
                          - AllErrors
                        action:
                          type: StageRollback

              - step:
                  name: Validate Staging Deployment
                  identifier: validate_staging
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      cd ansible-playbooks
                      
                      export RABBITMQ_ADMIN_PASSWORD='<+pipeline.variables.rabbitmq_admin_password>'
                      
                      ansible-playbook playbooks/validate.yml \
                        -i inventory/staging/hosts.yml \
                        -e "rabbitmq_admin_password=${RABBITMQ_ADMIN_PASSWORD}"
                  timeout: 10m

            rollbackSteps:
              - step:
                  name: Rollback Staging
                  identifier: rollback_staging
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      cd ansible-playbooks
                      
                      ansible-playbook playbooks/rollback.yml \
                        -i inventory/staging/hosts.yml
                  timeout: 30m
        when:
          pipelineStatus: Success
        tags:
          - staging
          - deployment

    # ═══════════════════════════════════════════════════════════
    # STAGE 4: Production Deployment
    # ═══════════════════════════════════════════════════════════
    - stage:
        name: Deploy-to-Production
        identifier: deploy_production
        description: Deploy RabbitMQ cluster to Production environment
        type: Deployment
        spec:
          deploymentType: CustomDeployment
          service:
            serviceRef: rabbitmq_cluster
          environment:
            environmentRef: production
            infrastructureDefinitions:
              - identifier: rabbitmq_prod_infra
          execution:
            steps:
              - step:
                  name: Production Approval
                  identifier: production_approval
                  type: HarnessApproval
                  spec:
                    approvalMessage: |
                      ⚠️ PRODUCTION DEPLOYMENT APPROVAL REQUIRED ⚠️
                      
                      Staging deployment completed successfully.
                      
                      Deployment Details:
                      - RabbitMQ Version: <+pipeline.variables.rabbitmq_version>
                      - Environment: PRODUCTION
                      - Cluster Size: 3 nodes
                      
                      Staging Metrics:
                      - Deployment Status: Success
                      - Cluster Health: Healthy
                      - All validations passed
                      
                      Please verify staging environment before approving.
                    includePipelineExecutionHistory: true
                    approvers:
                      userGroups:
                        - _project_all_users
                      minimumCount: 2
                    approverInputs:
                      - name: change_ticket
                        defaultValue: ""
                      - name: approval_notes
                        defaultValue: ""
                  timeout: 24h

              - step:
                  name: Create Change Record
                  identifier: create_change_record
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "═══════════════════════════════════════════════════════════"
                      echo "Recording Deployment in Change Management"
                      echo "═══════════════════════════════════════════════════════════"
                      
                      # Integration with ServiceNow/ITSM (example)
                      # curl -X POST https://your-servicenow-instance.com/api/now/table/change_request \
                      #   -H "Authorization: Bearer $SERVICENOW_TOKEN" \
                      #   -d '{
                      #     "short_description": "RabbitMQ Production Deployment",
                      #     "description": "Deploy RabbitMQ <+pipeline.variables.rabbitmq_version> to production",
                      #     "type": "standard",
                      #     "risk": "moderate"
                      #   }'
                      
                      echo "Change record created"

              - step:
                  name: Deploy RabbitMQ Production
                  identifier: deploy_rabbitmq_prod
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "═══════════════════════════════════════════════════════════"
                      echo "🚀 PRODUCTION DEPLOYMENT"
                      echo "═══════════════════════════════════════════════════════════"
                      echo "RabbitMQ Version: <+pipeline.variables.rabbitmq_version>"
                      echo "Deployment Strategy: Rolling (one node at a time)"
                      echo "═══════════════════════════════════════════════════════════"
                      
                      cd ansible-playbooks
                      
                      export ERLANG_COOKIE='<+pipeline.variables.erlang_cookie>'
                      export RABBITMQ_ADMIN_PASSWORD='<+pipeline.variables.rabbitmq_admin_password>'
                      
                      # Production deployment with rolling strategy
                      ansible-playbook playbooks/site.yml \
                        -i inventory/production/hosts.yml \
                        -e "rabbitmq_version=<+pipeline.variables.rabbitmq_version>" \
                        -e "erlang_cookie=${ERLANG_COOKIE}" \
                        -e "rabbitmq_admin_password=${RABBITMQ_ADMIN_PASSWORD}" \
                        -e "environment_name=production" \
                        --serial 1 \
                        -v
                      
                      echo "✅ Production deployment completed"
                  timeout: 60m
                  failureStrategies:
                    - onFailure:
                        errors:
                          - AllErrors
                        action:
                          type: StageRollback

              - step:
                  name: Production Validation
                  identifier: validate_production
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      cd ansible-playbooks
                      
                      export RABBITMQ_ADMIN_PASSWORD='<+pipeline.variables.rabbitmq_admin_password>'
                      
                      ansible-playbook playbooks/validate.yml \
                        -i inventory/production/hosts.yml \
                        -e "rabbitmq_admin_password=${RABBITMQ_ADMIN_PASSWORD}"
                  timeout: 15m

              - step:
                  name: Post-Deployment Notification
                  identifier: post_deploy_notification
                  type: Email
                  spec:
                    to: devops-team@company.com,platform-team@company.com
                    cc: management@company.com
                    subject: "✅ RabbitMQ Production Deployment Complete"
                    body: |
                      RabbitMQ Cluster has been successfully deployed to Production.
                      
                      Deployment Details:
                      - Version: <+pipeline.variables.rabbitmq_version>
                      - Cluster: rabbitmq-prod-cluster
                      - Nodes: 3
                      - Status: Healthy
                      
                      Pipeline: <+pipeline.name>
                      Execution ID: <+pipeline.executionId>
                      
                      Management UI: https://rabbitmq-prod.company.com:15672

            rollbackSteps:
              - step:
                  name: Production Rollback
                  identifier: rollback_production
                  type: Run
                  spec:
                    shell: Bash
                    command: |
                      echo "⚠️ PRODUCTION ROLLBACK INITIATED"
                      
                      cd ansible-playbooks
                      
                      ansible-playbook playbooks/rollback.yml \
                        -i inventory/production/hosts.yml \
                        --serial 1
                  timeout: 60m

              - step:
                  name: Rollback Notification
                  identifier: rollback_notification
                  type: Email
                  spec:
                    to: devops-team@company.com,platform-team@company.com
                    cc: management@company.com
                    subject: "⚠️ RabbitMQ Production Deployment ROLLED BACK"
                    body: |
                      RabbitMQ Production deployment has been rolled back due to failure.
                      
                      Please investigate immediately.
                      
                      Pipeline: <+pipeline.name>
                      Execution ID: <+pipeline.executionId>
        when:
          pipelineStatus: Success
          condition: <+pipeline.variables.deploy_all_environments> == true
        tags:
          - production
          - deployment

  notificationRules:
    - name: Pipeline Notifications
      identifier: pipeline_notifications
      pipelineEvents:
        - type: PipelineSuccess
        - type: PipelineFailed
        - type: StageSuccess
        - type: StageFailed
      notificationMethod:
        type: Slack
        spec:
          webhookUrl: <+variable.slack_webhook_url>
      enabled: true
```

---

# 10. Deployment Execution

## 10.1 Manual Pipeline Execution

1. Navigate to **Pipelines → RabbitMQ-Cluster-Deployment**
2. Click **Run Pipeline**
3. Provide input parameters:
   - `rabbitmq_version`: 4.0.3
   - `deploy_all_environments`: false (for dev only)
4. Click **Run Pipeline**

## 10.2 Trigger-Based Execution

### Git Push Trigger

```yaml
trigger:
  name: On-Commit-Trigger
  identifier: on_commit_trigger
  enabled: true
  orgIdentifier: Infrastructure
  projectIdentifier: rabbitmq_deployment
  pipelineIdentifier: rabbitmq_cluster_deployment
  source:
    type: Webhook
    spec:
      type: Github
      spec:
        type: Push
        spec:
          connectorRef: rabbitmq_ansible_repo
          autoAbortPreviousExecutions: true
          payloadConditions:
            - key: targetBranch
              operator: Equals
              value: main
          headerConditions: []
          actions: []
  inputYaml: |
    pipeline:
      identifier: rabbitmq_cluster_deployment
      variables:
        - name: rabbitmq_version
          type: String
          value: "4.0.3"
```

### Scheduled Trigger

```yaml
trigger:
  name: Nightly-Deployment
  identifier: nightly_deployment
  enabled: true
  orgIdentifier: Infrastructure
  projectIdentifier: rabbitmq_deployment
  pipelineIdentifier: rabbitmq_cluster_deployment
  source:
    type: Scheduled
    spec:
      type: Cron
      spec:
        expression: "0 2 * * *"  # Daily at 2 AM
        timezone: America/New_York
  inputYaml: |
    pipeline:
      identifier: rabbitmq_cluster_deployment
      variables:
        - name: rabbitmq_version
          type: String
          value: "4.0.3"
        - name: deploy_all_environments
          type: Boolean
          value: false
```

---

# 11. Validation & Testing

## 11.1 Cluster Health Checks

```bash
# Check cluster status
rabbitmqctl cluster_status

# Check node health
rabbitmqctl node_health_check

# List cluster members
rabbitmqctl cluster_info

# Check quorum queue status
rabbitmqctl list_quorum_queue_replicas
```

## 11.2 Performance Testing

```python
#!/usr/bin/env python3
# performance_test.py
import pika
import time
import threading
from concurrent.futures import ThreadPoolExecutor

def publish_messages(host, count):
    credentials = pika.PlainCredentials('admin', 'password')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(host=host, credentials=credentials)
    )
    channel = connection.channel()
    channel.queue_declare(queue='perf_test', durable=True)
    
    start = time.time()
    for i in range(count):
        channel.basic_publish(
            exchange='',
            routing_key='perf_test',
            body=f'Message {i}',
            properties=pika.BasicProperties(delivery_mode=2)
        )
    elapsed = time.time() - start
    
    print(f"Published {count} messages in {elapsed:.2f}s ({count/elapsed:.0f} msg/s)")
    connection.close()

if __name__ == '__main__':
    publish_messages('rabbitmq-node-1', 10000)
```

---

# 12. Monitoring & Observability

## 12.1 Prometheus Integration

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'rabbitmq'
    static_configs:
      - targets:
          - 'rabbitmq-node-1:15692'
          - 'rabbitmq-node-2:15692'
          - 'rabbitmq-node-3:15692'
    metrics_path: /metrics
```

## 12.2 Grafana Dashboard

Import RabbitMQ dashboard ID: `10991` from Grafana Dashboard repository.

## 12.3 Alerting Rules

```yaml
# alerting_rules.yml
groups:
  - name: rabbitmq
    rules:
      - alert: RabbitMQNodeDown
        expr: up{job="rabbitmq"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "RabbitMQ node {{ $labels.instance }} is down"

      - alert: RabbitMQHighMemory
        expr: rabbitmq_process_resident_memory_bytes / rabbitmq_resident_memory_limit_bytes > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "RabbitMQ memory usage above 80%"

      - alert: RabbitMQQueueGrowing
        expr: rate(rabbitmq_queue_messages_total[5m]) > 100
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Queue {{ $labels.queue }} is growing rapidly"
```

---

# 13. Rollback Procedures

## 13.1 Automatic Rollback

Harness automatically triggers rollback when:
- Deployment step fails
- Validation step fails
- Health check fails

## 13.2 Manual Rollback

1. Navigate to **Pipeline Execution**
2. Click on failed deployment
3. Select **Rollback** option
4. Confirm rollback

## 13.3 Rollback Checklist

- [ ] Verify current cluster state
- [ ] Identify rollback version
- [ ] Notify stakeholders
- [ ] Execute rollback playbook
- [ ] Validate cluster health post-rollback
- [ ] Update incident record
- [ ] Conduct post-mortem

---

# 14. Troubleshooting Guide

## 14.1 Common Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| Nodes won't cluster | Erlang cookie mismatch | Verify `.erlang.cookie` is identical on all nodes |
| Connection refused | Firewall blocking ports | Open ports 4369, 5672, 25672 |
| Memory alarm | High watermark reached | Increase RAM or adjust watermark |
| Disk alarm | Disk free limit reached | Free disk space or adjust limit |

## 14.2 Diagnostic Commands

```bash
# Check RabbitMQ logs
journalctl -u rabbitmq-server -f

# Check Erlang distribution
epmd -names

# Test cluster connectivity
rabbitmqctl eval 'net_adm:ping(rabbit@node2).'

# Export definitions (backup)
rabbitmqctl export_definitions /tmp/definitions.json
```

## 14.3 Support Escalation

| Level | Responsibility | Contact |
|-------|---------------|---------|
| L1 | Initial triage | DevOps Team |
| L2 | Advanced troubleshooting | Platform Team |
| L3 | Vendor escalation | RabbitMQ Support |

---

*Document Version: 1.0*  
*Author: Infrastructure Architecture Team*  
*Last Updated: January 2026*
