# Multi-Cluster Deployment - Quick Start Guide

> **Demo-Ready Solution**: Deploy common container to multiple ECS clusters with Harness CD

---

## 🎯 What You Get

✅ **Complete Harness Pipeline** - Copy-paste ready YAML configuration
✅ **All Scripts Included** - Build, deploy, health-check, rollback
✅ **Demo Walkthrough** - Interactive demo script for presentations
✅ **Infrastructure Setup** - AWS resource creation scripts
✅ **Verification Tools** - Pre-flight checks and health monitoring

---

## ⚡ 5-Minute Quick Start

### Prerequisites
```bash
# Required
✓ AWS CLI configured with credentials
✓ Docker installed and running
✓ Harness account with delegates

# Optional (for demo)
✓ kubectl (for delegate verification)
✓ jq (for JSON parsing)
```

### Step 1: Verify Infrastructure (2 minutes)

```bash
cd multi-cluster-scripts/
./verify-infrastructure.sh
```

**Expected Output:**
```
========================================
VERIFICATION SUMMARY
========================================
Total checks: 15
Passed: 13
Failed: 0
Warnings: 2

✓ Infrastructure ready for demo!
```

### Step 2: Run Interactive Demo (30 minutes)

```bash
./demo.sh
```

The demo will guide you through:
1. 📊 Current deployment state
2. 🔨 Build and push new version
3. 🚀 Trigger Harness pipeline
4. ✅ Verify both clusters
5. 🔄 (Optional) Rollback demonstration

### Step 3: Manual Deployment (Alternative)

If you prefer manual control:

```bash
# Build and push
./build-and-push.sh v1.0.0

# Trigger Harness pipeline (via UI or API)
# Use image tag: v1.0.0

# Verify after deployment
./health-check.sh prod-cluster us-east-1
./health-check.sh analytics-cluster us-west-2
```

---

## 📁 File Structure

```
.
├── MULTI_CLUSTER_DEPLOYMENT_GUIDE.md  # Complete documentation (80+ pages)
├── MULTI_CLUSTER_QUICK_START.md       # This file
└── multi-cluster-scripts/
    ├── README.md                       # Scripts documentation
    ├── demo.sh                         # Interactive demo (⭐ START HERE)
    ├── verify-infrastructure.sh        # Pre-flight checks
    ├── build-and-push.sh               # Build and push Docker image
    ├── health-check.sh                 # Service health verification
    └── rollback.sh                     # Emergency rollback
```

---

## 🎬 Demo Scenarios

### Scenario 1: Executive Presentation (15 minutes)

Perfect for showing business value:

```bash
# Run interactive demo with pre-built image
cd multi-cluster-scripts/
./demo.sh

# Highlight these talking points:
✓ Single pipeline for multi-cluster deployment
✓ Zero-downtime Blue-Green strategy
✓ Automatic rollback on failure
✓ Complete audit trail and compliance
```

### Scenario 2: Technical Deep-Dive (45 minutes)

Perfect for engineering teams:

```bash
# 1. Show infrastructure verification
./verify-infrastructure.sh

# 2. Build from source
./build-and-push.sh demo-$(date +%s)

# 3. Show Harness pipeline YAML
# Open MULTI_CLUSTER_DEPLOYMENT_GUIDE.md
# Section 5: Pipeline Implementation

# 4. Trigger pipeline and explain each stage

# 5. Show health checks
./health-check.sh prod-cluster us-east-1
./health-check.sh analytics-cluster us-west-2

# 6. Demonstrate rollback
./rollback.sh prod-cluster us-east-1
```

### Scenario 3: Disaster Recovery Drill (10 minutes)

Perfect for showing resilience:

```bash
# Simulate failure and rollback
./rollback.sh prod-cluster us-east-1
./rollback.sh analytics-cluster us-west-2

# Verify services recovered
./health-check.sh prod-cluster us-east-1
./health-check.sh analytics-cluster us-west-2
```

---

## 🏗️ Architecture At A Glance

```
┌─────────────────────────────────────────────┐
│         HARNESS CD PLATFORM                 │
│         (Single Pipeline)                   │
└────────────┬──────────────┬─────────────────┘
             │              │
    ┌────────▼──────┐  ┌───▼──────────┐
    │ CLUSTER 1     │  │ CLUSTER 2    │
    │ us-east-1     │  │ us-west-2    │
    │               │  │              │
    │ 5 Services:   │  │ 3 Services:  │
    │ • frontend    │  │ • analytics  │
    │ • backend     │  │ • reporting  │
    │ • auth        │  │ • notification ◄─┐
    │ • payment     │  │              │   │
    │ • notification├──┼──────────────┘   │
    └───────────────┘  └──────────────────┘
                              │
                       SAME CONTAINER
                   (Different configs)
```

**Key Features:**
- ✅ Notification service deployed to BOTH clusters
- ✅ Blue-Green deployment with 0 downtime
- ✅ Independent scaling per cluster
- ✅ Parallel validation and verification
- ✅ Automatic rollback on failure

---

## 📊 Deployment Timeline

```
00:00 ─ Start Pipeline
00:02 ─ Validate Both Clusters (parallel)
00:02 ─ Deploy to Production
00:12 ─ Production Verification Complete ✓
00:12 ─ Deploy to Analytics
00:20 ─ Analytics Verification Complete ✓
00:22 ─ Final Verification (parallel)
00:23 ─ Deployment Success! 🎉

Total: ~23 minutes
```

---

## 🔧 Configuration

### Customize for Your Environment

Edit these variables in scripts:

```bash
# In each script or set as environment variables
export AWS_ACCOUNT_ID="123456789012"          # Your AWS account
export PROD_CLUSTER="prod-cluster"            # Your prod cluster name
export PROD_REGION="us-east-1"                # Your prod region
export ANALYTICS_CLUSTER="analytics-cluster"  # Your analytics cluster
export ANALYTICS_REGION="us-west-2"           # Your analytics region
export SERVICE_NAME="notification-service"    # Your service name
```

---

## 📈 Success Metrics

After running the demo, you should see:

### Production Cluster (us-east-1)
- ✅ 3+ tasks running
- ✅ All targets healthy
- ✅ HTTP health check: 200 OK
- ✅ Same image tag as deployed

### Analytics Cluster (us-west-2)
- ✅ 2+ tasks running
- ✅ All targets healthy
- ✅ HTTP health check: 200 OK
- ✅ Same image tag as deployed

### Pipeline Metrics
- ⏱️ Total time: 20-25 minutes
- 🔄 Rollback time: < 2 minutes
- 📉 Downtime: 0 minutes
- ✅ Success rate: 100%

---

## 🆘 Quick Troubleshooting

### Issue: Scripts not executable
```bash
chmod +x multi-cluster-scripts/*.sh
```

### Issue: AWS credentials not found
```bash
aws configure
# Or
export AWS_PROFILE=your-profile
```

### Issue: ECR authentication failed
```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com
```

### Issue: Cluster not found
```bash
# Check if cluster exists
aws ecs list-clusters --region us-east-1

# Create if needed
aws ecs create-cluster --cluster-name prod-cluster --region us-east-1
```

### Issue: Health check fails
```bash
# Check service logs
aws logs tail /ecs/notification-service-prod --follow

# Check task status
aws ecs describe-tasks \
  --cluster prod-cluster \
  --tasks <task-id> \
  --region us-east-1
```

---

## 📚 Next Steps

### For Demo Preparation
1. ✅ Run `./verify-infrastructure.sh` to ensure everything is ready
2. ✅ Do a practice run with `./demo.sh`
3. ✅ Prepare talking points from architecture guide
4. ✅ Have rollback scenario ready as backup
5. ✅ Test health check endpoints beforehand

### For Production Implementation
1. 📖 Read [Complete Deployment Guide](MULTI_CLUSTER_DEPLOYMENT_GUIDE.md)
2. 🏗️ Set up AWS infrastructure (Section 3)
3. ⚙️ Configure Harness (Section 4)
4. 🚀 Create pipeline (Section 5)
5. ✅ Test in non-production first
6. 📊 Set up monitoring and alerts

### For Customization
1. Modify pipeline YAML for your needs
2. Adjust task definitions (CPU, memory, environment variables)
3. Update health check endpoints
4. Configure notification rules
5. Add additional verification steps

---

## 🎓 Learning Resources

### Hands-On Practice
- Run the demo multiple times
- Try different deployment scenarios
- Practice rollback procedures
- Experiment with pipeline modifications

### Documentation
- **Complete Guide**: `MULTI_CLUSTER_DEPLOYMENT_GUIDE.md`
- **Script Docs**: `multi-cluster-scripts/README.md`
- **Harness Docs**: https://developer.harness.io
- **AWS ECS Docs**: https://docs.aws.amazon.com/ecs/

### Videos and Tutorials
- Harness University: https://university.harness.io
- AWS ECS Workshop: https://ecsworkshop.com
- Docker Documentation: https://docs.docker.com

---

## ✅ Pre-Demo Checklist

Before presenting:

- [ ] AWS CLI configured and tested
- [ ] Docker daemon running
- [ ] ECR repository exists with at least one image
- [ ] Both ECS clusters exist and are ACTIVE
- [ ] Harness delegates running and connected
- [ ] Services exist in both clusters
- [ ] Health endpoints responding
- [ ] Ran `verify-infrastructure.sh` successfully
- [ ] Did practice run of `demo.sh`
- [ ] Prepared answers for common questions

---

## 💡 Demo Tips

### For Success
1. **Start with verification**: Show infrastructure is healthy
2. **Explain the architecture**: Use the diagram in the guide
3. **Highlight parallelism**: Show validation and verification running in parallel
4. **Emphasize safety**: Automatic rollback, health checks, zero downtime
5. **Show real logs**: Live ECS console, Harness execution logs
6. **Have backup plan**: Pre-recorded demo or screenshots as fallback

### Common Questions to Prepare For
1. "What happens if production fails?" → Show rollback
2. "How long does it take?" → 20-25 minutes for both clusters
3. "Can we deploy to just one cluster?" → Yes, modify pipeline
4. "What about database migrations?" → Pre-deployment step
5. "How do we monitor?" → CloudWatch, Datadog, Prometheus integration
6. "What's the cost?" → Harness licensing + AWS resources (minimal)

---

## 📞 Support

**For Issues:**
- Check troubleshooting section above
- Review complete deployment guide
- Check Harness community forums
- Contact DevOps team

**For Questions:**
- Architecture: See complete guide Section 1
- Pipeline: See complete guide Section 5
- Scripts: See `multi-cluster-scripts/README.md`
- Troubleshooting: See complete guide Section 9

---

## 🎉 Summary

You now have everything needed for a successful multi-cluster deployment demo:

✅ **Complete Documentation** - 80+ page guide with every detail
✅ **Ready-to-Use Scripts** - All automation included
✅ **Interactive Demo** - Professional walkthrough
✅ **Harness Pipeline** - Production-ready YAML
✅ **Verification Tools** - Health checks and validation
✅ **Rollback Procedures** - Emergency recovery

**Start Here:** Run `./multi-cluster-scripts/demo.sh` for an interactive demo experience!

---

**Version**: 1.0
**Last Updated**: January 10, 2026
**Estimated Demo Time**: 30-45 minutes
**Difficulty**: Intermediate
**Prerequisites**: AWS + Harness basic knowledge

**Good luck with your demo! 🚀**
