# Harness CI Setup Guide

## What is Harness CI?

Harness CI is a modern Continuous Integration platform that automates building, testing, and validating your code changes. It's part of the Harness Software Delivery Platform.

## Prerequisites for Using Harness CI

1. **Harness Account**: Sign up at https://app.harness.io (Free tier available)
2. **Source Code Repository**: GitHub, GitLab, or Bitbucket
3. **Build Environment**: Docker, Kubernetes, or VM-based runners

## Key Features of Harness CI

- **AI-Powered Test Intelligence**: Automatically selects relevant tests
- **Cloud-Native**: Built-in autoscaling and cloud support
- **Multi-Platform**: Supports Docker, Kubernetes, VMs
- **Security**: Built-in secrets management
- **Visual Pipeline Builder**: Easy-to-use UI for creating pipelines

## How Harness CI Works

1. **Connect Repository**: Link your Git repository (GitHub/GitLab/Bitbucket)
2. **Create Pipeline**: Define build, test, and deploy stages
3. **Configure Builds**: Set up build steps for your application
4. **Run Tests**: Execute automated tests
5. **Deploy**: Optionally deploy to staging/production

## Harness CI Configuration

Harness CI uses YAML-based pipeline configurations. Here's the structure:

```yaml
pipeline:
  name: Your Pipeline Name
  identifier: your_pipeline_id
  projectIdentifier: your_project
  orgIdentifier: your_org
  tags: {}
  stages:
    - stage:
        name: Build and Test
        identifier: Build_and_Test
        type: CI
        spec:
          cloneCodebase: true
          execution:
            steps:
              - step:
                  type: Run
                  name: Install Dependencies
                  identifier: Install_Dependencies
                  spec:
                    shell: Sh
                    command: npm install
              - step:
                  type: Run
                  name: Run Tests
                  identifier: Run_Tests
                  spec:
                    shell: Sh
                    command: npm test
```

## Getting Started Steps

### 1. Create Harness Account
- Visit https://app.harness.io
- Sign up for free account
- Create an organization and project

### 2. Connect Your Repository
- Go to Connectors → Git Connectors
- Add your GitHub/GitLab/Bitbucket repository
- Authorize Harness to access your repo

### 3. Create CI Pipeline
- Navigate to CI → Pipelines
- Click "Create Pipeline"
- Select "Start from Scratch" or use a template
- Configure your build steps

### 4. Configure Build Infrastructure
- Choose execution environment:
  - **Docker**: For containerized builds
  - **Kubernetes**: For K8s clusters
  - **VM**: For traditional VM-based builds

### 5. Set Up Build Steps
Common build steps:
- **Clone Code**: Automatically done with `cloneCodebase: true`
- **Install Dependencies**: npm install, pip install, etc.
- **Build**: npm run build, mvn package, etc.
- **Test**: npm test, pytest, etc.
- **Publish Artifacts**: Save build outputs

## Example Use Cases

### Node.js/React Application
```yaml
steps:
  - step:
      type: Run
      name: Install Dependencies
      spec:
        shell: Sh
        command: npm ci
  - step:
      type: Run
      name: Build Application
      spec:
        shell: Sh
        command: npm run build
  - step:
      type: Run
      name: Run Tests
      spec:
        shell: Sh
        command: npm test
```

### Python Application
```yaml
steps:
  - step:
      type: Run
      name: Install Dependencies
      spec:
        shell: Sh
        command: pip install -r requirements.txt
  - step:
      type: Run
      name: Run Tests
      spec:
        shell: Sh
        command: pytest
```

### Java Application
```yaml
steps:
  - step:
      type: Run
      name: Build with Maven
      spec:
        shell: Sh
        command: mvn clean package
  - step:
      type: Run
      name: Run Tests
      spec:
        shell: Sh
        command: mvn test
```

## Advantages Over Jenkins

1. **Low Maintenance**: No server management required
2. **Cloud-Native**: Built-in autoscaling
3. **Visual Interface**: Easy pipeline creation
4. **AI Features**: Test intelligence and optimization
5. **Security**: Built-in secrets management
6. **Modern**: Designed for modern DevOps practices

## Next Steps

1. Review the example configurations in this directory
2. Sign up for Harness account
3. Connect your repository
4. Create your first pipeline
5. Customize based on your project needs

## Resources

- Harness Documentation: https://developer.harness.io/docs/continuous-integration
- Harness Community: https://community.harness.io
- Harness YouTube: Tutorial videos available

