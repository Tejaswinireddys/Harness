#!/bin/bash
# build-and-push.sh
# Build Docker image and push to ECR for multi-cluster deployment

set -e

# Configuration
SERVICE_NAME="notification-service"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-123456789012}"
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${SERVICE_NAME}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get version from argument or git commit
VERSION=${1:-$(git rev-parse --short HEAD 2>/dev/null || echo "latest")}
IMAGE_TAG="${VERSION}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Building ${SERVICE_NAME}:${IMAGE_TAG}${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    echo -e "${YELLOW}Warning: Dockerfile not found. Using sample Dockerfile.${NC}"
    cat > Dockerfile <<EOF
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 8083
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \\
  CMD node healthcheck.js
CMD ["node", "server.js"]
EOF
fi

# Build Docker image
echo -e "${BLUE}Step 1: Building Docker image...${NC}"
docker build -t ${SERVICE_NAME}:${IMAGE_TAG} . || {
    echo -e "${YELLOW}Build failed! Check Dockerfile and try again.${NC}"
    exit 1
}

echo -e "${GREEN}✓ Build complete${NC}"

# Tag for ECR
echo -e "${BLUE}Step 2: Tagging for ECR...${NC}"
docker tag ${SERVICE_NAME}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
docker tag ${SERVICE_NAME}:${IMAGE_TAG} ${ECR_REPO}:latest

echo -e "${GREEN}✓ Tagged: ${ECR_REPO}:${IMAGE_TAG}${NC}"
echo -e "${GREEN}✓ Tagged: ${ECR_REPO}:latest${NC}"

# Login to ECR
echo -e "${BLUE}Step 3: Authenticating with ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REPO} || {
    echo -e "${YELLOW}ECR login failed! Check AWS credentials.${NC}"
    exit 1
}

echo -e "${GREEN}✓ Authenticated with ECR${NC}"

# Push to ECR
echo -e "${BLUE}Step 4: Pushing to ECR...${NC}"
docker push ${ECR_REPO}:${IMAGE_TAG}
docker push ${ECR_REPO}:latest

echo -e "${GREEN}✓ Image pushed successfully${NC}"

# Get image digest
IMAGE_DIGEST=$(aws ecr describe-images \
  --repository-name ${SERVICE_NAME} \
  --image-ids imageTag=${IMAGE_TAG} \
  --region ${AWS_REGION} \
  --query 'imageDetails[0].imageDigest' \
  --output text)

# Output summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ BUILD AND PUSH COMPLETE${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Image URI: ${ECR_REPO}:${IMAGE_TAG}"
echo -e "Latest URI: ${ECR_REPO}:latest"
echo -e "Digest: ${IMAGE_DIGEST}"
echo ""
echo -e "Use this in Harness pipeline:"
echo -e "  Tag: ${YELLOW}${IMAGE_TAG}${NC}"
echo -e "${BLUE}========================================${NC}"

# Export for CI/CD
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "IMAGE_URI=${ECR_REPO}:${IMAGE_TAG}" >> $GITHUB_OUTPUT
    echo "IMAGE_TAG=${IMAGE_TAG}" >> $GITHUB_OUTPUT
fi
