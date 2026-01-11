#!/bin/bash
# verify-infrastructure.sh
# Verify all AWS infrastructure is ready for multi-cluster deployment demo

set -e

# Configuration
PROD_CLUSTER="${PROD_CLUSTER:-prod-cluster}"
PROD_REGION="${PROD_REGION:-us-east-1}"
ANALYTICS_CLUSTER="${ANALYTICS_CLUSTER:-analytics-cluster}"
ANALYTICS_REGION="${ANALYTICS_REGION:-us-west-2}"
SERVICE_NAME="notification-service"
ECR_REPO_NAME="notification-service"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_TOTAL=0

# Functions
print_header() {
    echo -e "\n${BLUE}${BOLD}========================================${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}========================================${NC}\n"
}

check_pass() {
    echo -e "${GREEN}✓ $1${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
}

check_fail() {
    echo -e "${RED}✗ $1${NC}"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
    CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
}

# Main verification
main() {
    print_header "INFRASTRUCTURE VERIFICATION"
    echo -e "Checking AWS resources for multi-cluster deployment demo..."

    # Check 1: AWS CLI
    print_header "1. AWS CLI Configuration"
    if command -v aws &> /dev/null; then
        check_pass "AWS CLI installed"

        # Check credentials
        if aws sts get-caller-identity &> /dev/null; then
            ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
            USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text)
            check_pass "AWS credentials valid"
            echo -e "    Account: ${ACCOUNT_ID}"
            echo -e "    Identity: ${USER_ARN}"
        else
            check_fail "AWS credentials not configured"
        fi
    else
        check_fail "AWS CLI not installed"
    fi

    # Check 2: ECR Repository
    print_header "2. ECR Repository"
    if aws ecr describe-repositories \
        --repository-names ${ECR_REPO_NAME} \
        --region ${PROD_REGION} &> /dev/null; then
        check_pass "ECR repository exists: ${ECR_REPO_NAME}"

        ECR_URI=$(aws ecr describe-repositories \
            --repository-names ${ECR_REPO_NAME} \
            --region ${PROD_REGION} \
            --query 'repositories[0].repositoryUri' \
            --output text)
        echo -e "    URI: ${ECR_URI}"

        # Check images
        IMAGE_COUNT=$(aws ecr list-images \
            --repository-name ${ECR_REPO_NAME} \
            --region ${PROD_REGION} \
            --query 'length(imageIds)' \
            --output text)

        if [ "$IMAGE_COUNT" -gt 0 ]; then
            check_pass "Repository has ${IMAGE_COUNT} images"
        else
            check_warn "Repository is empty"
        fi
    else
        check_fail "ECR repository not found: ${ECR_REPO_NAME}"
        echo -e "    ${YELLOW}Create with: aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${PROD_REGION}${NC}"
    fi

    # Check 3: Production Cluster
    print_header "3. Production ECS Cluster (${PROD_REGION})"
    if aws ecs describe-clusters \
        --clusters ${PROD_CLUSTER} \
        --region ${PROD_REGION} \
        --query 'clusters[0]' &> /dev/null; then

        CLUSTER_STATUS=$(aws ecs describe-clusters \
            --clusters ${PROD_CLUSTER} \
            --region ${PROD_REGION} \
            --query 'clusters[0].status' \
            --output text)

        if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
            check_pass "Cluster exists and is ACTIVE"

            # Check service count
            SERVICE_COUNT=$(aws ecs list-services \
                --cluster ${PROD_CLUSTER} \
                --region ${PROD_REGION} \
                --query 'length(serviceArns)' \
                --output text)
            echo -e "    Services: ${SERVICE_COUNT}"

            # Check for notification service
            if aws ecs describe-services \
                --cluster ${PROD_CLUSTER} \
                --services ${SERVICE_NAME} \
                --region ${PROD_REGION} \
                --query 'services[0]' &> /dev/null; then

                SERVICE_STATUS=$(aws ecs describe-services \
                    --cluster ${PROD_CLUSTER} \
                    --services ${SERVICE_NAME} \
                    --region ${PROD_REGION} \
                    --query 'services[0].status' \
                    --output text)

                if [ "$SERVICE_STATUS" = "ACTIVE" ]; then
                    check_pass "Service ${SERVICE_NAME} is ACTIVE"

                    RUNNING_COUNT=$(aws ecs describe-services \
                        --cluster ${PROD_CLUSTER} \
                        --services ${SERVICE_NAME} \
                        --region ${PROD_REGION} \
                        --query 'services[0].runningCount' \
                        --output text)
                    echo -e "    Running tasks: ${RUNNING_COUNT}"
                else
                    check_warn "Service ${SERVICE_NAME} status: ${SERVICE_STATUS}"
                fi
            else
                check_warn "Service ${SERVICE_NAME} not found (will be created)"
            fi
        else
            check_fail "Cluster status: ${CLUSTER_STATUS}"
        fi
    else
        check_fail "Production cluster not found: ${PROD_CLUSTER}"
        echo -e "    ${YELLOW}Create with: aws ecs create-cluster --cluster-name ${PROD_CLUSTER} --region ${PROD_REGION}${NC}"
    fi

    # Check 4: Analytics Cluster
    print_header "4. Analytics ECS Cluster (${ANALYTICS_REGION})"
    if aws ecs describe-clusters \
        --clusters ${ANALYTICS_CLUSTER} \
        --region ${ANALYTICS_REGION} \
        --query 'clusters[0]' &> /dev/null; then

        CLUSTER_STATUS=$(aws ecs describe-clusters \
            --clusters ${ANALYTICS_CLUSTER} \
            --region ${ANALYTICS_REGION} \
            --query 'clusters[0].status' \
            --output text)

        if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
            check_pass "Cluster exists and is ACTIVE"

            # Check service count
            SERVICE_COUNT=$(aws ecs list-services \
                --cluster ${ANALYTICS_CLUSTER} \
                --region ${ANALYTICS_REGION} \
                --query 'length(serviceArns)' \
                --output text)
            echo -e "    Services: ${SERVICE_COUNT}"

            # Check for notification service
            if aws ecs describe-services \
                --cluster ${ANALYTICS_CLUSTER} \
                --services ${SERVICE_NAME} \
                --region ${ANALYTICS_REGION} \
                --query 'services[0]' &> /dev/null; then

                SERVICE_STATUS=$(aws ecs describe-services \
                    --cluster ${ANALYTICS_CLUSTER} \
                    --services ${SERVICE_NAME} \
                    --region ${ANALYTICS_REGION} \
                    --query 'services[0].status' \
                    --output text)

                if [ "$SERVICE_STATUS" = "ACTIVE" ]; then
                    check_pass "Service ${SERVICE_NAME} is ACTIVE"

                    RUNNING_COUNT=$(aws ecs describe-services \
                        --cluster ${ANALYTICS_CLUSTER} \
                        --services ${SERVICE_NAME} \
                        --region ${ANALYTICS_REGION} \
                        --query 'services[0].runningCount' \
                        --output text)
                    echo -e "    Running tasks: ${RUNNING_COUNT}"
                else
                    check_warn "Service ${SERVICE_NAME} status: ${SERVICE_STATUS}"
                fi
            else
                check_warn "Service ${SERVICE_NAME} not found (will be created)"
            fi
        else
            check_fail "Cluster status: ${CLUSTER_STATUS}"
        fi
    else
        check_fail "Analytics cluster not found: ${ANALYTICS_CLUSTER}"
        echo -e "    ${YELLOW}Create with: aws ecs create-cluster --cluster-name ${ANALYTICS_CLUSTER} --region ${ANALYTICS_REGION}${NC}"
    fi

    # Check 5: IAM Roles
    print_header "5. IAM Roles"

    # Task Execution Role
    if aws iam get-role --role-name notification-service-execution-role &> /dev/null; then
        check_pass "Task execution role exists"
    else
        check_warn "Task execution role not found"
    fi

    # Task Role
    if aws iam get-role --role-name notification-service-task-role &> /dev/null; then
        check_pass "Task role exists"
    else
        check_warn "Task role not found"
    fi

    # Check 6: Harness Delegates (optional - check via kubectl if available)
    print_header "6. Harness Delegates (Optional)"
    if command -v kubectl &> /dev/null; then
        check_pass "kubectl installed"

        if kubectl get namespace harness-delegate-ng &> /dev/null; then
            DELEGATE_COUNT=$(kubectl get pods -n harness-delegate-ng --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')

            if [ "$DELEGATE_COUNT" -gt 0 ]; then
                check_pass "Harness delegates running: ${DELEGATE_COUNT}"
            else
                check_warn "No running Harness delegates found"
            fi
        else
            check_warn "Harness delegate namespace not found"
        fi
    else
        check_warn "kubectl not installed (skipping delegate check)"
    fi

    # Check 7: Docker
    print_header "7. Docker"
    if command -v docker &> /dev/null; then
        check_pass "Docker installed"

        if docker info &> /dev/null; then
            check_pass "Docker daemon running"
        else
            check_fail "Docker daemon not running"
        fi
    else
        check_warn "Docker not installed (needed for build-and-push)"
    fi

    # Check 8: Additional Tools
    print_header "8. Additional Tools"

    if command -v jq &> /dev/null; then
        check_pass "jq installed"
    else
        check_warn "jq not installed (recommended for JSON parsing)"
    fi

    if command -v curl &> /dev/null; then
        check_pass "curl installed"
    else
        check_warn "curl not installed (needed for health checks)"
    fi

    # Summary
    print_header "VERIFICATION SUMMARY"
    echo -e "Total checks: ${CHECKS_TOTAL}"
    echo -e "${GREEN}Passed: ${CHECKS_PASSED}${NC}"
    echo -e "${RED}Failed: ${CHECKS_FAILED}${NC}"
    echo -e "${YELLOW}Warnings: $((CHECKS_TOTAL - CHECKS_PASSED - CHECKS_FAILED))${NC}"

    echo ""
    if [ "$CHECKS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✓ Infrastructure ready for demo!${NC}"
        echo ""
        echo -e "Next steps:"
        echo -e "  1. Run ${BOLD}./demo.sh${NC} for interactive demo"
        echo -e "  2. Or run ${BOLD}./build-and-push.sh <version>${NC} to build and push"
        echo -e "  3. Then trigger Harness pipeline"
        exit 0
    else
        echo -e "${RED}${BOLD}✗ Infrastructure verification failed${NC}"
        echo ""
        echo -e "Please resolve the failed checks above before running the demo."
        exit 1
    fi
}

# Run main function
main "$@"
