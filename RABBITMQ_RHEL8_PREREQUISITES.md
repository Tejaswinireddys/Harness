# RabbitMQ 4.x Cluster POC - RHEL 8 Prerequisites

## 🎯 Target Environment

| Component | Specification |
|-----------|---------------|
| **Operating System** | Red Hat Enterprise Linux 8.x |
| **Architecture** | x86_64 |
| **Deployment Type** | Virtual Machines |
| **Cluster Size** | 3 nodes (minimum) |

---

## 📋 RHEL 8 VM Requirements

### Hardware Specifications (Per Node)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **vCPU** | 4 cores | 8 cores |
| **RAM** | 8 GB | 16 GB |
| **Root Disk** | 50 GB | 100 GB |
| **Data Disk** | 100 GB SSD | 500 GB SSD |
| **Network** | 1 Gbps | 10 Gbps |

### RHEL 8 Subscription Requirements

```bash
# Verify subscription status
sudo subscription-manager status

# Required repositories
sudo subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms
sudo subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms
sudo subscription-manager repos --enable=codeready-builder-for-rhel-8-x86_64-rpms
```

---

## 🔧 Pre-Installation Checklist

### 1. System Access

```bash
# Verify SSH access from Ansible control node
ssh ansible@rabbitmq-node-1 "hostname; cat /etc/redhat-release"

# Verify sudo access
ssh ansible@rabbitmq-node-1 "sudo whoami"
```

### 2. Network Configuration

```bash
# Verify hostname is set correctly
hostnamectl status

# Verify /etc/hosts has all cluster nodes
cat /etc/hosts

# Example entries:
# 192.168.10.101  rabbitmq-dev-1
# 192.168.10.102  rabbitmq-dev-2
# 192.168.10.103  rabbitmq-dev-3
```

### 3. Firewall Ports

```bash
# Check firewalld status
sudo systemctl status firewalld

# Required ports (will be configured by Ansible)
# 4369/tcp  - EPMD
# 5672/tcp  - AMQP
# 5671/tcp  - AMQPS (TLS)
# 15672/tcp - Management UI
# 25672/tcp - Erlang distribution
# 15692/tcp - Prometheus metrics

# Manual configuration (if needed)
sudo firewall-cmd --permanent --add-port=4369/tcp
sudo firewall-cmd --permanent --add-port=5672/tcp
sudo firewall-cmd --permanent --add-port=15672/tcp
sudo firewall-cmd --permanent --add-port=25672/tcp
sudo firewall-cmd --permanent --add-port=15692/tcp
sudo firewall-cmd --reload
```

### 4. SELinux Status

```bash
# Check SELinux status
getenforce

# If Enforcing, the Ansible playbook will configure appropriate contexts
# Alternatively, set to Permissive for POC:
# sudo setenforce 0
# sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

### 5. Time Synchronization

```bash
# Verify chrony is running
sudo systemctl status chronyd

# Check time sync status
chronyc tracking

# All nodes MUST have synchronized time for cluster to work
```

### 6. Python 3 (Required for Ansible)

```bash
# Verify Python 3 is installed
python3 --version

# Install if missing
sudo dnf install -y python3 python3-pip
```

---

## 📁 Directory Structure

The following directories will be created by the playbook:

```
/var/lib/rabbitmq/          # RabbitMQ data directory
/var/lib/rabbitmq/mnesia/   # Mnesia database
/var/log/rabbitmq/          # Log files
/etc/rabbitmq/              # Configuration files
/var/backups/rabbitmq/      # Backup location
```

---

## 🔐 Security Considerations for RHEL 8

### SELinux Configuration

The Ansible playbook configures SELinux to allow RabbitMQ operations. If you prefer to keep SELinux in Enforcing mode, ensure:

```bash
# Allow RabbitMQ to bind to ports
sudo semanage port -a -t amqp_port_t -p tcp 5672
sudo semanage port -a -t amqp_port_t -p tcp 15672
sudo semanage port -a -t amqp_port_t -p tcp 25672
```

### Firewalld Zones

For enhanced security, consider using firewalld zones:

```bash
# Create a dedicated zone for RabbitMQ cluster
sudo firewall-cmd --permanent --new-zone=rabbitmq-cluster
sudo firewall-cmd --permanent --zone=rabbitmq-cluster --add-port=4369/tcp
sudo firewall-cmd --permanent --zone=rabbitmq-cluster --add-port=5672/tcp
sudo firewall-cmd --permanent --zone=rabbitmq-cluster --add-port=15672/tcp
sudo firewall-cmd --permanent --zone=rabbitmq-cluster --add-port=25672/tcp
sudo firewall-cmd --permanent --zone=rabbitmq-cluster --add-port=15692/tcp

# Add cluster node IPs to trusted zone
sudo firewall-cmd --permanent --zone=trusted --add-source=192.168.10.101
sudo firewall-cmd --permanent --zone=trusted --add-source=192.168.10.102
sudo firewall-cmd --permanent --zone=trusted --add-source=192.168.10.103

sudo firewall-cmd --reload
```

---

## 🔄 System Tuning for RHEL 8

### Tuned Profile

```bash
# Install tuned (usually pre-installed)
sudo dnf install -y tuned

# Enable and start tuned
sudo systemctl enable tuned
sudo systemctl start tuned

# Set throughput-performance profile
sudo tuned-adm profile throughput-performance

# Verify
sudo tuned-adm active
```

### File Descriptor Limits

The Ansible playbook configures these, but for manual setup:

```bash
# /etc/security/limits.d/99-rabbitmq.conf
rabbitmq soft nofile 65536
rabbitmq hard nofile 65536
rabbitmq soft nproc 65536
rabbitmq hard nproc 65536
```

### Sysctl Parameters

```bash
# /etc/sysctl.d/99-rabbitmq.conf
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3
vm.swappiness = 1
```

---

## 📦 Package Dependencies (Installed by Ansible)

### From RHEL 8 Base Repos

- `socat`
- `logrotate`
- `net-tools`
- `lsof`
- `jq`
- `bind-utils`
- `python3`
- `python3-pip`

### From EPEL Repository

- `htop`

### From RabbitMQ Repositories

- `erlang` (from rabbitmq/erlang)
- `rabbitmq-server` (from rabbitmq/rabbitmq-server)

---

## ✅ Pre-Flight Validation Script

Run this script on each node before deployment:

```bash
#!/bin/bash
# pre-flight-check.sh

echo "═══════════════════════════════════════════════════════════"
echo "RabbitMQ POC - RHEL 8 Pre-Flight Check"
echo "═══════════════════════════════════════════════════════════"

# Check RHEL version
echo -n "RHEL Version: "
cat /etc/redhat-release

# Check CPU cores
echo -n "CPU Cores: "
nproc

# Check memory
echo -n "Memory: "
free -h | grep Mem | awk '{print $2}'

# Check disk space
echo -n "Root Disk: "
df -h / | tail -1 | awk '{print $4 " available"}'

# Check network
echo -n "Network: "
ip addr show | grep "inet " | grep -v 127.0.0.1 | head -1

# Check hostname resolution
echo "Hostname Resolution:"
for host in rabbitmq-dev-1 rabbitmq-dev-2 rabbitmq-dev-3; do
    echo -n "  $host: "
    getent hosts $host 2>/dev/null && echo "✅" || echo "❌ NOT FOUND"
done

# Check firewalld
echo -n "Firewalld: "
systemctl is-active firewalld

# Check SELinux
echo -n "SELinux: "
getenforce

# Check chronyd
echo -n "Time Sync: "
systemctl is-active chronyd

# Check Python
echo -n "Python 3: "
python3 --version 2>/dev/null || echo "❌ NOT INSTALLED"

echo "═══════════════════════════════════════════════════════════"
echo "Pre-flight check complete"
echo "═══════════════════════════════════════════════════════════"
```

---

## 🚀 Quick Start for RHEL 8

```bash
# 1. Update inventory with your RHEL 8 server IPs
vi inventory/dev/hosts.yml

# 2. Set environment variables
export ERLANG_COOKIE="your-secure-cookie-here"
export RABBITMQ_ADMIN_PASSWORD="YourSecurePassword123!"

# 3. Install Ansible requirements
ansible-galaxy collection install -r requirements.yml

# 4. Test connectivity
ansible all -i inventory/dev/hosts.yml -m ping

# 5. Run deployment
ansible-playbook playbooks/site.yml -i inventory/dev/hosts.yml
```

---

## 📞 Support

For RHEL 8 specific issues:
- Red Hat Customer Portal: https://access.redhat.com
- RabbitMQ Documentation: https://rabbitmq.com/docs

---

*Document Version: 1.0*  
*Last Updated: January 2026*  
*Target OS: RHEL 8.x*
