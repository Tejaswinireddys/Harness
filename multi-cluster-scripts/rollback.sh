#!/bin/bash
# rollback.sh
# Manual rollback to previous task definition version

set -e

# Usage
if [ $# -lt 2 ]; then
    echo "Usage: $0 <cluster-name> <region> [revision-number]"
    echo "Example: $0 prod-cluster us-east-1"
    echo "Example: $0 prod-cluster us-east-1 145"
    exit 1
fi

CLUSTER=$1
REGION=$2
TARGET_REVISION=$3
SERVICE_NAME="notification-service"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Rollback: ${SERVICE_NAME}${NC}"
echo -e "${BLUE}Cluster: ${CLUSTER} (${REGION})${NC}"
echo -e "${BLUE}========================================${NC}"

# Get current task definition
echo -e "\n${BLUE}Step 1: Getting current deployment info...${NC}"
CURRENT_TASK_DEF=$(aws ecs describe-services \
  --cluster ${CLUSTER} \
  --services ${SERVICE_NAME} \
  --region ${REGION} \
  --query 'services[0].taskDefinition' \
  --output text)

echo -e "Current task definition: ${CURRENT_TASK_DEF}"

# Extract task family and revision
TASK_FAMILY=$(echo ${CURRENT_TASK_DEF} | sed 's/:.*//')
CURRENT_REVISION=$(echo ${CURRENT_TASK_DEF} | grep -o '[0-9]*$')

echo -e "Task family: ${TASK_FAMILY}"
echo -e "Current revision: ${CURRENT_REVISION}"

# Get current image for logging
CURRENT_IMAGE=$(aws ecs describe-task-definition \
  --task-definition ${CURRENT_TASK_DEF} \
  --region ${REGION} \
  --query 'taskDefinition.containerDefinitions[0].image' \
  --output text)

echo -e "Current image: ${CURRENT_IMAGE}"

# Determine target revision
if [ -z "$TARGET_REVISION" ]; then
  # No revision specified, roll back to previous
  TARGET_REVISION=$((CURRENT_REVISION - 1))
  echo -e "\n${YELLOW}No revision specified. Rolling back to previous revision: ${TARGET_REVISION}${NC}"
else
  echo -e "\n${BLUE}Rolling back to specified revision: ${TARGET_REVISION}${NC}"
fi

if [ "$TARGET_REVISION" -eq "$CURRENT_REVISION" ]; then
  echo -e "${RED}✗ Target revision is the same as current revision${NC}"
  exit 1
fi

if [ "$TARGET_REVISION" -lt 1 ]; then
  echo -e "${RED}✗ Invalid target revision: ${TARGET_REVISION}${NC}"
  exit 1
fi

# Build target task definition ARN
TARGET_TASK_DEF="${TASK_FAMILY}:${TARGET_REVISION}"

# Check if target revision exists
echo -e "\n${BLUE}Step 2: Validating target revision...${NC}"
aws ecs describe-task-definition \
  --task-definition ${TARGET_TASK_DEF} \
  --region ${REGION} > /dev/null 2>&1 || {
  echo -e "${RED}✗ Target task definition not found: ${TARGET_TASK_DEF}${NC}"
  echo -e "\nAvailable revisions:"
  aws ecs list-task-definitions \
    --family-prefix ${TASK_FAMILY} \
    --region ${REGION} \
    --query 'taskDefinitionArns' \
    --output text | tr '\t' '\n' | tail -10
  exit 1
}

# Get target image
TARGET_IMAGE=$(aws ecs describe-task-definition \
  --task-definition ${TARGET_TASK_DEF} \
  --region ${REGION} \
  --query 'taskDefinition.containerDefinitions[0].image' \
  --output text)

echo -e "${GREEN}✓ Target task definition exists${NC}"
echo -e "Target image: ${TARGET_IMAGE}"

# Confirmation
echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}ROLLBACK CONFIRMATION${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "Cluster: ${CLUSTER}"
echo -e "Region: ${REGION}"
echo -e "Service: ${SERVICE_NAME}"
echo -e ""
echo -e "Current: ${CURRENT_TASK_DEF}"
echo -e "  Image: ${CURRENT_IMAGE}"
echo -e ""
echo -e "Target:  ${TARGET_TASK_DEF}"
echo -e "  Image: ${TARGET_IMAGE}"
echo -e "${YELLOW}========================================${NC}"

read -p "Continue with rollback? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo -e "${YELLOW}Rollback cancelled${NC}"
  exit 0
fi

# Perform rollback
echo -e "\n${BLUE}Step 3: Updating service...${NC}"
aws ecs update-service \
  --cluster ${CLUSTER} \
  --service ${SERVICE_NAME} \
  --task-definition ${TARGET_TASK_DEF} \
  --region ${REGION} \
  --force-new-deployment > /dev/null

echo -e "${GREEN}✓ Service update initiated${NC}"

# Wait for service to stabilize
echo -e "\n${BLUE}Step 4: Waiting for deployment to stabilize...${NC}"
echo -e "(This may take 5-10 minutes)"

# Show progress
for i in {1..60}; do
  DEPLOYMENTS=$(aws ecs describe-services \
    --cluster ${CLUSTER} \
    --services ${SERVICE_NAME} \
    --region ${REGION} \
    --query 'services[0].deployments' \
    --output json)

  DEPLOYMENT_COUNT=$(echo "$DEPLOYMENTS" | jq 'length')
  RUNNING_COUNT=$(aws ecs describe-services \
    --cluster ${CLUSTER} \
    --services ${SERVICE_NAME} \
    --region ${REGION} \
    --query 'services[0].runningCount' \
    --output text)

  DESIRED_COUNT=$(aws ecs describe-services \
    --cluster ${CLUSTER} \
    --services ${SERVICE_NAME} \
    --region ${REGION} \
    --query 'services[0].desiredCount' \
    --output text)

  echo -e "  Deployment ${i}/60: ${RUNNING_COUNT}/${DESIRED_COUNT} tasks, ${DEPLOYMENT_COUNT} deployments"

  # Check if stable (only one deployment and running == desired)
  if [ "$DEPLOYMENT_COUNT" -eq 1 ] && [ "$RUNNING_COUNT" -eq "$DESIRED_COUNT" ]; then
    echo -e "${GREEN}✓ Deployment stabilized${NC}"
    break
  fi

  if [ "$i" -eq 60 ]; then
    echo -e "${RED}✗ Timeout waiting for deployment to stabilize${NC}"
    echo -e "Please check ECS console for details"
    exit 1
  fi

  sleep 10
done

# Verify rollback
echo -e "\n${BLUE}Step 5: Verifying rollback...${NC}"

FINAL_TASK_DEF=$(aws ecs describe-services \
  --cluster ${CLUSTER} \
  --services ${SERVICE_NAME} \
  --region ${REGION} \
  --query 'services[0].taskDefinition' \
  --output text)

FINAL_IMAGE=$(aws ecs describe-task-definition \
  --task-definition ${FINAL_TASK_DEF} \
  --region ${REGION} \
  --query 'taskDefinition.containerDefinitions[0].image' \
  --output text)

echo -e "Final task definition: ${FINAL_TASK_DEF}"
echo -e "Final image: ${FINAL_IMAGE}"

if [ "$FINAL_TASK_DEF" != "${TASK_FAMILY}:${TARGET_REVISION}" ]; then
  echo -e "${RED}✗ Rollback verification failed${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Rollback verified${NC}"

# Run health check
echo -e "\n${BLUE}Step 6: Running health check...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/health-check.sh" ]; then
  bash "${SCRIPT_DIR}/health-check.sh" ${CLUSTER} ${REGION}
else
  echo -e "${YELLOW}⚠ Health check script not found, skipping${NC}"
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✓ ROLLBACK COMPLETE${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Service: ${SERVICE_NAME}"
echo -e "Cluster: ${CLUSTER}"
echo -e "Region: ${REGION}"
echo -e ""
echo -e "Rolled back from:"
echo -e "  ${CURRENT_TASK_DEF}"
echo -e "  ${CURRENT_IMAGE}"
echo -e ""
echo -e "Rolled back to:"
echo -e "  ${FINAL_TASK_DEF}"
echo -e "  ${FINAL_IMAGE}"
echo -e "${BLUE}========================================${NC}"
