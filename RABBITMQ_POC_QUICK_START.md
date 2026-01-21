# RabbitMQ 4.x Cluster POC - Quick Start Guide

## 🚀 5-Minute Quick Start

### Step 1: Clone the Repository

```bash
cd /path/to/your/workspace
git clone https://github.com/your-org/rabbitmq-ansible-harness.git
cd rabbitmq-ansible-harness
```

### Step 2: Set Required Environment Variables

```bash
# Generate a secure Erlang cookie
export ERLANG_COOKIE=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
echo "Erlang Cookie: $ERLANG_COOKIE"

# Set admin password
export RABBITMQ_ADMIN_PASSWORD="YourSecurePassword123!"
```

### Step 3: Update Inventory

Edit `inventory/dev/hosts.yml` with your server IPs:

```yaml
all:
  children:
    rabbitmq_cluster:
      hosts:
        rabbitmq-dev-1:
          ansible_host: YOUR_IP_1
          rabbitmq_is_primary: true
        rabbitmq-dev-2:
          ansible_host: YOUR_IP_2
        rabbitmq-dev-3:
          ansible_host: YOUR_IP_3
```

### Step 4: Install Requirements

```bash
# Install Ansible collections
ansible-galaxy collection install -r requirements.yml
```

### Step 5: Deploy

```bash
# Deploy RabbitMQ cluster
ansible-playbook playbooks/site.yml -i inventory/dev/hosts.yml
```

### Step 6: Validate

```bash
# Validate deployment
ansible-playbook playbooks/validate.yml -i inventory/dev/hosts.yml
```

### Step 7: Access Management UI

Open browser: `http://YOUR_IP_1:15672`
- Username: `admin`
- Password: `$RABBITMQ_ADMIN_PASSWORD`

---

## 📋 Harness Pipeline Setup

### 1. Create Secrets in Harness

| Secret Name | Value |
|-------------|-------|
| `erlang_cookie` | Your Erlang cookie |
| `rabbitmq_admin_password` | Admin password |

### 2. Import Pipeline

1. Go to Harness → Pipelines → Import from YAML
2. Upload `harness-pipeline.yaml`
3. Configure connectors (Git, SSH)

### 3. Run Pipeline

1. Click "Run Pipeline"
2. Set `rabbitmq_version`: 4.0.3
3. Click "Run"

---

## 📁 Created Files Summary

| File | Purpose |
|------|---------|
| `RABBITMQ_POC_EXECUTIVE_SUMMARY.md` | Executive summary for management |
| `RABBITMQ_POC_IMPLEMENTATION_GUIDE.md` | Complete implementation guide |
| `RABBITMQ_POC_CONFLUENCE_PAGE.md` | Confluence-formatted documentation |
| `rabbitmq-ansible-harness/` | Complete Ansible project |
| `rabbitmq-ansible-harness/harness-pipeline.yaml` | Harness CD pipeline |

---

## 🆘 Need Help?

- **Implementation Guide**: `RABBITMQ_POC_IMPLEMENTATION_GUIDE.md`
- **Troubleshooting**: See "Troubleshooting" section in implementation guide
- **Contact**: DevOps Team
