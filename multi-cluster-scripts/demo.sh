#!/bin/bash
# demo.sh
# Interactive demo script for multi-cluster deployment

set -e

# Configuration
PROD_CLUSTER="${PROD_CLUSTER:-prod-cluster}"
PROD_REGION="${PROD_REGION:-us-east-1}"
ANALYTICS_CLUSTER="${ANALYTICS_CLUSTER:-analytics-cluster}"
ANALYTICS_REGION="${ANALYTICS_REGION:-us-west-2}"
SERVICE_NAME="notification-service"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Functions
print_header() {
    echo -e "\n${CYAN}${BOLD}========================================${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}${BOLD}========================================${NC}\n"
}

print_step() {
    echo -e "\n${BLUE}${BOLD}>>> $1${NC}\n"
}

press_enter() {
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Main demo flow
main() {
    clear
    print_header "MULTI-CLUSTER ECS DEPLOYMENT DEMO"
    echo -e "This demo shows deploying ${BOLD}${SERVICE_NAME}${NC} to two ECS clusters:"
    echo -e "  1. ${BOLD}${PROD_CLUSTER}${NC} (${PROD_REGION}) - Production"
    echo -e "  2. ${BOLD}${ANALYTICS_CLUSTER}${NC} (${ANALYTICS_REGION}) - Analytics"
    echo ""
    echo -e "The same container runs in both clusters with different configurations."

    press_enter

    # Step 1: Show Current State
    print_header "STEP 1: CURRENT DEPLOYMENT STATE"

    print_step "Checking Production Cluster (${PROD_CLUSTER})..."
    echo -e "${BLUE}Cluster: ${PROD_CLUSTER}${NC}"
    echo -e "${BLUE}Region: ${PROD_REGION}${NC}"
    echo ""

    if aws ecs describe-clusters --clusters ${PROD_CLUSTER} --region ${PROD_REGION} &>/dev/null; then
        # Get current version
        PROD_TASK_DEF=$(aws ecs describe-services \
          --cluster ${PROD_CLUSTER} \
          --services ${SERVICE_NAME} \
          --region ${PROD_REGION} \
          --query 'services[0].taskDefinition' \
          --output text 2>/dev/null || echo "Not Found")

        if [ "$PROD_TASK_DEF" != "Not Found" ]; then
            PROD_IMAGE=$(aws ecs describe-task-definition \
              --task-definition ${PROD_TASK_DEF} \
              --region ${PROD_REGION} \
              --query 'taskDefinition.containerDefinitions[0].image' \
              --output text)

            PROD_RUNNING=$(aws ecs describe-services \
              --cluster ${PROD_CLUSTER} \
              --services ${SERVICE_NAME} \
              --region ${PROD_REGION} \
              --query 'services[0].runningCount' \
              --output text)

            echo -e "  Task Definition: ${GREEN}${PROD_TASK_DEF}${NC}"
            echo -e "  Container Image: ${GREEN}${PROD_IMAGE}${NC}"
            echo -e "  Running Tasks: ${GREEN}${PROD_RUNNING}${NC}"
        else
            echo -e "  ${YELLOW}Service not found (will be created)${NC}"
        fi
    else
        echo -e "  ${YELLOW}Cluster not found (demo mode)${NC}"
    fi

    echo ""
    print_step "Checking Analytics Cluster (${ANALYTICS_CLUSTER})..."
    echo -e "${BLUE}Cluster: ${ANALYTICS_CLUSTER}${NC}"
    echo -e "${BLUE}Region: ${ANALYTICS_REGION}${NC}"
    echo ""

    if aws ecs describe-clusters --clusters ${ANALYTICS_CLUSTER} --region ${ANALYTICS_REGION} &>/dev/null; then
        # Get current version
        ANALYTICS_TASK_DEF=$(aws ecs describe-services \
          --cluster ${ANALYTICS_CLUSTER} \
          --services ${SERVICE_NAME} \
          --region ${ANALYTICS_REGION} \
          --query 'services[0].taskDefinition' \
          --output text 2>/dev/null || echo "Not Found")

        if [ "$ANALYTICS_TASK_DEF" != "Not Found" ]; then
            ANALYTICS_IMAGE=$(aws ecs describe-task-definition \
              --task-definition ${ANALYTICS_TASK_DEF} \
              --region ${ANALYTICS_REGION} \
              --query 'taskDefinition.containerDefinitions[0].image' \
              --output text)

            ANALYTICS_RUNNING=$(aws ecs describe-services \
              --cluster ${ANALYTICS_CLUSTER} \
              --services ${SERVICE_NAME} \
              --region ${ANALYTICS_REGION} \
              --query 'services[0].runningCount' \
              --output text)

            echo -e "  Task Definition: ${GREEN}${ANALYTICS_TASK_DEF}${NC}"
            echo -e "  Container Image: ${GREEN}${ANALYTICS_IMAGE}${NC}"
            echo -e "  Running Tasks: ${GREEN}${ANALYTICS_RUNNING}${NC}"
        else
            echo -e "  ${YELLOW}Service not found (will be created)${NC}"
        fi
    else
        echo -e "  ${YELLOW}Cluster not found (demo mode)${NC}"
    fi

    press_enter

    # Step 2: Build and Push
    print_header "STEP 2: BUILD AND PUSH NEW VERSION"

    echo -e "Now we'll build a new version of the ${BOLD}${SERVICE_NAME}${NC} container"
    echo -e "and push it to Amazon ECR."
    echo ""
    echo -e "This image will be deployed to ${BOLD}both${NC} clusters."

    press_enter

    print_step "Building and pushing container image..."

    # Ask for version
    echo -e "Enter version tag (or press ENTER for 'demo-v1.0'):"
    read VERSION
    VERSION=${VERSION:-demo-v1.0}

    echo -e "\nBuilding version: ${BOLD}${VERSION}${NC}\n"

    if [ -f "${SCRIPT_DIR}/build-and-push.sh" ]; then
        bash "${SCRIPT_DIR}/build-and-push.sh" ${VERSION}
    else
        echo -e "${YELLOW}Build script not found. Skipping build (demo mode).${NC}"
        echo -e "In a real scenario, this would:"
        echo -e "  1. Build Docker image from Dockerfile"
        echo -e "  2. Tag image as: <ecr-repo>:${VERSION}"
        echo -e "  3. Push to ECR"
        echo -e "  4. Image is replicated to us-west-2"
    fi

    press_enter

    # Step 3: Harness Pipeline
    print_header "STEP 3: TRIGGER HARNESS CD PIPELINE"

    echo -e "The Harness pipeline will:"
    echo -e "  1. ${BLUE}Validate${NC} both clusters (parallel)"
    echo -e "  2. ${BLUE}Deploy${NC} to Production cluster"
    echo -e "     • Create green service"
    echo -e "     • Shift traffic to green"
    echo -e "     • Run continuous verification"
    echo -e "  3. ${BLUE}Deploy${NC} to Analytics cluster"
    echo -e "     • Create green service"
    echo -e "     • Shift traffic to green"
    echo -e "     • Run continuous verification"
    echo -e "  4. ${BLUE}Verify${NC} both clusters (parallel)"
    echo ""
    echo -e "Total time: ~20-25 minutes"

    press_enter

    print_step "Opening Harness UI..."
    echo -e "Navigate to:"
    echo -e "  ${CYAN}https://app.harness.io${NC}"
    echo ""
    echo -e "Pipeline:"
    echo -e "  ${BOLD}Multi-Cluster Notification Service Deployment${NC}"
    echo ""
    echo -e "When prompted, enter image tag:"
    echo -e "  ${BOLD}${VERSION}${NC}"
    echo ""
    echo -e "${YELLOW}Monitor the pipeline execution in Harness UI...${NC}"

    press_enter

    # Step 4: Verify Deployment
    print_header "STEP 4: VERIFY DEPLOYMENT"

    echo -e "Once the pipeline completes, we'll verify both clusters."

    press_enter

    print_step "Verifying Production Cluster..."
    if [ -f "${SCRIPT_DIR}/health-check.sh" ]; then
        bash "${SCRIPT_DIR}/health-check.sh" ${PROD_CLUSTER} ${PROD_REGION} || true
    else
        echo -e "${YELLOW}Health check script not found${NC}"
    fi

    press_enter

    print_step "Verifying Analytics Cluster..."
    if [ -f "${SCRIPT_DIR}/health-check.sh" ]; then
        bash "${SCRIPT_DIR}/health-check.sh" ${ANALYTICS_CLUSTER} ${ANALYTICS_REGION} || true
    else
        echo -e "${YELLOW}Health check script not found${NC}"
    fi

    press_enter

    # Step 5: Show Final State
    print_header "STEP 5: DEPLOYMENT COMPLETE"

    echo -e "${GREEN}${BOLD}✓ Multi-cluster deployment successful!${NC}"
    echo ""

    print_step "Final State Summary:"

    echo -e "${BLUE}Production Cluster (${PROD_CLUSTER}):${NC}"
    if aws ecs describe-clusters --clusters ${PROD_CLUSTER} --region ${PROD_REGION} &>/dev/null; then
        PROD_FINAL_IMAGE=$(aws ecs describe-services \
          --cluster ${PROD_CLUSTER} \
          --services ${SERVICE_NAME} \
          --region ${PROD_REGION} \
          --query 'services[0].taskDefinition' \
          --output text 2>/dev/null | xargs aws ecs describe-task-definition \
          --task-definition - \
          --region ${PROD_REGION} \
          --query 'taskDefinition.containerDefinitions[0].image' \
          --output text 2>/dev/null || echo "Not available")

        echo -e "  Image: ${GREEN}${PROD_FINAL_IMAGE}${NC}"
    else
        echo -e "  ${YELLOW}Demo mode - cluster not found${NC}"
    fi

    echo ""
    echo -e "${BLUE}Analytics Cluster (${ANALYTICS_CLUSTER}):${NC}"
    if aws ecs describe-clusters --clusters ${ANALYTICS_CLUSTER} --region ${ANALYTICS_REGION} &>/dev/null; then
        ANALYTICS_FINAL_IMAGE=$(aws ecs describe-services \
          --cluster ${ANALYTICS_CLUSTER} \
          --services ${SERVICE_NAME} \
          --region ${ANALYTICS_REGION} \
          --query 'services[0].taskDefinition' \
          --output text 2>/dev/null | xargs aws ecs describe-task-definition \
          --task-definition - \
          --region ${ANALYTICS_REGION} \
          --query 'taskDefinition.containerDefinitions[0].image' \
          --output text 2>/dev/null || echo "Not available")

        echo -e "  Image: ${GREEN}${ANALYTICS_FINAL_IMAGE}${NC}"
    else
        echo -e "  ${YELLOW}Demo mode - cluster not found${NC}"
    fi

    echo ""
    print_header "KEY BENEFITS DEMONSTRATED"
    echo -e "  ${GREEN}✓${NC} Single pipeline for multi-cluster deployment"
    echo -e "  ${GREEN}✓${NC} Zero-downtime Blue-Green deployment"
    echo -e "  ${GREEN}✓${NC} Parallel validation and verification"
    echo -e "  ${GREEN}✓${NC} Automatic rollback on failure"
    echo -e "  ${GREEN}✓${NC} Consistent deployment across regions"
    echo -e "  ${GREEN}✓${NC} Complete audit trail"

    # Optional: Rollback Demo
    echo ""
    echo -e "${YELLOW}Would you like to demo rollback? (yes/no)${NC}"
    read ROLLBACK_DEMO

    if [ "$ROLLBACK_DEMO" = "yes" ]; then
        print_header "BONUS: ROLLBACK DEMONSTRATION"

        echo -e "We'll now demonstrate rolling back to the previous version."
        press_enter

        print_step "Rolling back Production Cluster..."
        if [ -f "${SCRIPT_DIR}/rollback.sh" ]; then
            bash "${SCRIPT_DIR}/rollback.sh" ${PROD_CLUSTER} ${PROD_REGION} || true
        fi

        press_enter

        print_step "Rolling back Analytics Cluster..."
        if [ -f "${SCRIPT_DIR}/rollback.sh" ]; then
            bash "${SCRIPT_DIR}/rollback.sh" ${ANALYTICS_CLUSTER} ${ANALYTICS_REGION} || true
        fi

        echo -e "\n${GREEN}✓ Rollback demonstration complete${NC}"
    fi

    print_header "DEMO COMPLETE"
    echo -e "Thank you for watching the multi-cluster deployment demo!"
    echo ""
    echo -e "Key Scripts:"
    echo -e "  • ${SCRIPT_DIR}/build-and-push.sh - Build and push images"
    echo -e "  • ${SCRIPT_DIR}/health-check.sh - Verify cluster health"
    echo -e "  • ${SCRIPT_DIR}/rollback.sh - Rollback deployments"
    echo ""
    echo -e "For questions or support, contact the DevOps team."
    echo ""
}

# Run main function
main "$@"
