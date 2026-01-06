# Quick Start: Setting Up Harness CI

## Step-by-Step Guide

### 1. Create Harness Account
- Visit: https://app.harness.io
- Click "Sign Up" (Free tier available)
- Complete registration

### 2. Create Organization & Project
- After login, create an organization
- Create a project within the organization
- Note down your organization and project identifiers

### 3. Set Up Git Connector
- Go to: **Connectors** → **Git Connectors**
- Click **"New Git Connector"**
- Choose your Git provider (GitHub/GitLab/Bitbucket)
- Authorize Harness to access your repositories
- Test the connection

### 4. Set Up Build Infrastructure

#### Option A: Kubernetes (Recommended)
- Go to: **Connectors** → **Kubernetes Clusters**
- Add your Kubernetes cluster
- Install Harness Delegate in your cluster

#### Option B: Docker
- Go to: **Connectors** → **Docker Registry**
- Add Docker Hub or your container registry

### 5. Create CI Pipeline

#### Method 1: Using UI (Easiest)
1. Go to: **CI** → **Pipelines**
2. Click **"Create Pipeline"**
3. Select **"Start from Scratch"**
4. Add a new stage → Select **"CI"**
5. Configure build steps using the visual editor
6. Save and run

#### Method 2: Using YAML (Advanced)
1. Go to: **CI** → **Pipelines**
2. Click **"Create Pipeline"**
3. Select **"YAML"** view
4. Copy one of the example YAML files from this directory
5. Replace placeholders:
   - `YOUR_GIT_CONNECTOR` → Your Git connector name
   - `YOUR_REPO_NAME` → Your repository name
   - `YOUR_K8S_CONNECTOR` → Your Kubernetes connector name
   - `YOUR_DOCKER_CONNECTOR` → Your Docker connector name (if using)
6. Save and run

### 6. Configure Pipeline Variables

Replace these in your YAML:
```yaml
projectIdentifier: YOUR_PROJECT_ID
orgIdentifier: YOUR_ORG_ID
connectorRef: YOUR_CONNECTOR_NAME
repoName: YOUR_REPO_NAME
```

### 7. Run Your First Pipeline

1. Click **"Run"** on your pipeline
2. Select branch/commit to build
3. Monitor execution in real-time
4. View logs and results

## Common Pipeline Steps

### Basic Steps Available:
- **Run**: Execute shell commands
- **BuildAndPushDockerRegistry**: Build and push Docker images
- **ArtifactoryUpload**: Upload artifacts
- **Cache**: Cache dependencies for faster builds
- **Plugin**: Use Harness plugins
- **Background**: Run background processes

## Tips for Success

1. **Start Simple**: Begin with basic build and test steps
2. **Use Templates**: Harness provides templates for common scenarios
3. **Test Locally**: Test your commands locally before adding to pipeline
4. **Use Caching**: Cache dependencies to speed up builds
5. **Monitor Logs**: Check logs to debug issues
6. **Use Variables**: Store secrets and configs in Harness variables

## Troubleshooting

### Pipeline Not Running?
- Check Git connector is connected
- Verify infrastructure connector is set up
- Ensure delegate is running (for Kubernetes)

### Build Failing?
- Check logs in execution view
- Verify commands work locally
- Check image/container configuration
- Verify file paths are correct

### Need Help?
- Harness Docs: https://developer.harness.io/docs/continuous-integration
- Community: https://community.harness.io
- Support: Available in Harness UI

## Next Steps

1. ✅ Set up your Harness account
2. ✅ Connect your repository
3. ✅ Create your first pipeline
4. ✅ Run and test
5. ✅ Add more stages (deploy, verify, etc.)
6. ✅ Integrate with CD pipeline for full CI/CD

