#!/bin/bash
# health-check.sh
# Comprehensive health check for notification service in ECS cluster

set -e

# Usage
if [ $# -lt 2 ]; then
    echo "Usage: $0 <cluster-name> <region> [alb-dns]"
    echo "Example: $0 prod-cluster us-east-1 prod-alb-123.us-east-1.elb.amazonaws.com"
    exit 1
fi

CLUSTER=$1
REGION=$2
ALB_DNS=$3
SERVICE_NAME="notification-service"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Health Check: ${SERVICE_NAME}${NC}"
echo -e "${BLUE}Cluster: ${CLUSTER} (${REGION})${NC}"
echo -e "${BLUE}========================================${NC}"

# Check 1: Service Status
echo -e "\n${BLUE}Check 1: Service Status${NC}"
SERVICE_STATUS=$(aws ecs describe-services \
  --cluster ${CLUSTER} \
  --services ${SERVICE_NAME} \
  --region ${REGION} \
  --query 'services[0].status' \
  --output text 2>/dev/null)

if [ "$SERVICE_STATUS" != "ACTIVE" ]; then
  echo -e "${RED}✗ Service status: $SERVICE_STATUS${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Service status: ACTIVE${NC}"

# Check 2: Task Count
echo -e "\n${BLUE}Check 2: Task Count${NC}"
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

echo -e "Running tasks: ${RUNNING_COUNT}/${DESIRED_COUNT}"

if [ "$RUNNING_COUNT" != "$DESIRED_COUNT" ]; then
  echo -e "${YELLOW}⚠ Warning: Task count mismatch${NC}"
  # Don't fail immediately, might be scaling
fi

if [ "$RUNNING_COUNT" -eq 0 ]; then
  echo -e "${RED}✗ No tasks running${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Tasks running: ${RUNNING_COUNT}${NC}"

# Check 3: Task Health
echo -e "\n${BLUE}Check 3: Task Health${NC}"
TASK_ARNS=$(aws ecs list-tasks \
  --cluster ${CLUSTER} \
  --service-name ${SERVICE_NAME} \
  --region ${REGION} \
  --desired-status RUNNING \
  --query 'taskArns' \
  --output text)

if [ -z "$TASK_ARNS" ]; then
  echo -e "${RED}✗ No running tasks found${NC}"
  exit 1
fi

UNHEALTHY_TASKS=0
for TASK_ARN in $TASK_ARNS; do
  TASK_ID=$(basename $TASK_ARN)
  TASK_HEALTH=$(aws ecs describe-tasks \
    --cluster ${CLUSTER} \
    --tasks ${TASK_ARN} \
    --region ${REGION} \
    --query 'tasks[0].healthStatus' \
    --output text)

  LAST_STATUS=$(aws ecs describe-tasks \
    --cluster ${CLUSTER} \
    --tasks ${TASK_ARN} \
    --region ${REGION} \
    --query 'tasks[0].lastStatus' \
    --output text)

  if [ "$TASK_HEALTH" = "HEALTHY" ] && [ "$LAST_STATUS" = "RUNNING" ]; then
    echo -e "${GREEN}✓ Task ${TASK_ID:0:8}: ${TASK_HEALTH} / ${LAST_STATUS}${NC}"
  else
    echo -e "${YELLOW}⚠ Task ${TASK_ID:0:8}: ${TASK_HEALTH} / ${LAST_STATUS}${NC}"
    UNHEALTHY_TASKS=$((UNHEALTHY_TASKS + 1))
  fi
done

if [ "$UNHEALTHY_TASKS" -gt 0 ]; then
  echo -e "${YELLOW}⚠ Warning: ${UNHEALTHY_TASKS} unhealthy tasks${NC}"
fi

# Check 4: Task Definition
echo -e "\n${BLUE}Check 4: Current Task Definition${NC}"
CURRENT_TASK_DEF=$(aws ecs describe-services \
  --cluster ${CLUSTER} \
  --services ${SERVICE_NAME} \
  --region ${REGION} \
  --query 'services[0].taskDefinition' \
  --output text)

CURRENT_IMAGE=$(aws ecs describe-task-definition \
  --task-definition ${CURRENT_TASK_DEF} \
  --region ${REGION} \
  --query 'taskDefinition.containerDefinitions[0].image' \
  --output text)

echo -e "Task Definition: ${CURRENT_TASK_DEF}"
echo -e "Container Image: ${CURRENT_IMAGE}"
echo -e "${GREEN}✓ Task definition retrieved${NC}"

# Check 5: Target Group Health (if ALB provided)
if [ -n "$ALB_DNS" ]; then
  echo -e "\n${BLUE}Check 5: ALB Target Group Health${NC}"

  # Get target group ARN from service
  TG_ARN=$(aws ecs describe-services \
    --cluster ${CLUSTER} \
    --services ${SERVICE_NAME} \
    --region ${REGION} \
    --query 'services[0].loadBalancers[0].targetGroupArn' \
    --output text 2>/dev/null)

  if [ "$TG_ARN" = "None" ] || [ -z "$TG_ARN" ]; then
    echo -e "${YELLOW}⚠ No target group configured${NC}"
  else
    HEALTHY_TARGETS=$(aws elbv2 describe-target-health \
      --target-group-arn ${TG_ARN} \
      --region ${REGION} \
      --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
      --output text)

    TOTAL_TARGETS=$(aws elbv2 describe-target-health \
      --target-group-arn ${TG_ARN} \
      --region ${REGION} \
      --query 'length(TargetHealthDescriptions)' \
      --output text)

    echo -e "Healthy ALB targets: ${HEALTHY_TARGETS}/${TOTAL_TARGETS}"

    if [ "$HEALTHY_TARGETS" -eq 0 ]; then
      echo -e "${RED}✗ No healthy ALB targets${NC}"
      exit 1
    fi

    echo -e "${GREEN}✓ ALB targets healthy: ${HEALTHY_TARGETS}/${TOTAL_TARGETS}${NC}"
  fi

  # Check 6: HTTP Health Endpoint
  echo -e "\n${BLUE}Check 6: HTTP Health Endpoint${NC}"
  HEALTH_URL="http://${ALB_DNS}/health"

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 ${HEALTH_URL} 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    HEALTH_RESPONSE=$(curl -s ${HEALTH_URL} 2>/dev/null)
    echo -e "Health URL: ${HEALTH_URL}"
    echo -e "Response: ${HEALTH_RESPONSE}"
    echo -e "${GREEN}✓ HTTP health check passed (200 OK)${NC}"
  else
    echo -e "${YELLOW}⚠ Health endpoint returned: ${HTTP_CODE}${NC}"
    echo -e "  (This might be normal if ALB is not publicly accessible)"
  fi
fi

# Check 7: CloudWatch Metrics (Optional)
echo -e "\n${BLUE}Check 7: Recent Deployment Events${NC}"
DEPLOYMENTS=$(aws ecs describe-services \
  --cluster ${CLUSTER} \
  --services ${SERVICE_NAME} \
  --region ${REGION} \
  --query 'services[0].deployments' \
  --output json)

DEPLOYMENT_COUNT=$(echo "$DEPLOYMENTS" | jq 'length')
echo -e "Active deployments: ${DEPLOYMENT_COUNT}"

if [ "$DEPLOYMENT_COUNT" -gt 1 ]; then
  echo -e "${YELLOW}⚠ Multiple deployments active (deployment in progress)${NC}"
fi

PRIMARY_DEPLOYMENT=$(echo "$DEPLOYMENTS" | jq -r '.[0] | "Status: \(.status), Running: \(.runningCount), Desired: \(.desiredCount)"')
echo -e "Primary: ${PRIMARY_DEPLOYMENT}"
echo -e "${GREEN}✓ Deployment status checked${NC}"

# Summary
echo -e "\n${BLUE}========================================${NC}"
if [ "$RUNNING_COUNT" -eq "$DESIRED_COUNT" ] && [ "$UNHEALTHY_TASKS" -eq 0 ]; then
  echo -e "${GREEN}✓ ALL HEALTH CHECKS PASSED${NC}"
  echo -e "${BLUE}========================================${NC}"
  exit 0
else
  echo -e "${YELLOW}⚠ HEALTH CHECKS COMPLETED WITH WARNINGS${NC}"
  echo -e "${BLUE}========================================${NC}"
  exit 0
fi
