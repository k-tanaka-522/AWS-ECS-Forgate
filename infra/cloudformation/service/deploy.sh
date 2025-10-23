#!/bin/bash
set -e

# ==============================================================================
# Service Account - CloudFormation Deployment Script
# ==============================================================================

# Usage: ./deploy.sh <environment> [stack]
# Example: ./deploy.sh dev            # Deploy all stacks
# Example: ./deploy.sh dev network    # Deploy only network stack

ENVIRONMENT=${1:-dev}
STACK_TO_DEPLOY=${2:-all}
PROJECT_NAME="sample-app"
AWS_REGION="ap-northeast-1"

echo "=========================================="
echo "Service Account Deployment"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Stack to deploy: $STACK_TO_DEPLOY"
echo "Region: $AWS_REGION"
echo ""

# Check AWS CLI authentication
echo "[0/4] Checking AWS authentication..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "  AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# Function to deploy a stack
deploy_stack() {
  local STACK_TYPE=$1
  local STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-service-${STACK_TYPE}"

  echo "=========================================="
  echo "Deploying ${STACK_TYPE} stack..."
  echo "=========================================="

  # Extract parameters for this stack from JSON
  local PARAMS=$(jq -r ".${STACK_TYPE}[] | \"\\(.ParameterKey)=\\(.ParameterValue)\"" parameters/${ENVIRONMENT}.json | tr '\n' ' ')

  aws cloudformation deploy \
    --stack-name $STACK_NAME \
    --template-file stacks/${STACK_TYPE}/main.yaml \
    --parameter-overrides $PARAMS \
    --capabilities CAPABILITY_IAM \
    --region $AWS_REGION \
    --no-fail-on-empty-changeset

  echo ""
  echo "✅ ${STACK_TYPE} stack deployment completed"
  echo ""

  # Get stack outputs
  echo "Stack outputs:"
  aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $AWS_REGION \
    --query 'Stacks[0].Outputs' \
    --output table

  echo ""
}

# Deploy stacks in order
if [ "$STACK_TO_DEPLOY" = "all" ] || [ "$STACK_TO_DEPLOY" = "network" ]; then
  echo "[1/4] Deploying Network stack..."
  deploy_stack "network"
fi

if [ "$STACK_TO_DEPLOY" = "all" ] || [ "$STACK_TO_DEPLOY" = "database" ]; then
  echo "[2/4] Deploying Database stack..."
  deploy_stack "database"

  # Wait for RDS to be available
  echo "⏳ Waiting for RDS instance to be available (this may take 15-20 minutes)..."
  STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-service-database"
  aws cloudformation wait stack-create-complete \
    --stack-name $STACK_NAME \
    --region $AWS_REGION 2>/dev/null || \
  aws cloudformation wait stack-update-complete \
    --stack-name $STACK_NAME \
    --region $AWS_REGION 2>/dev/null || true

  echo ""
  echo "⚠️  IMPORTANT: Initialize the database schema before deploying compute stack!"
  echo ""
  echo "Run the following SQL on your RDS instance:"
  echo ""
  echo "CREATE TABLE users ("
  echo "  id SERIAL PRIMARY KEY,"
  echo "  username VARCHAR(100) NOT NULL UNIQUE,"
  echo "  email VARCHAR(255) NOT NULL UNIQUE,"
  echo "  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
  echo "  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
  echo ");"
  echo ""
  echo "CREATE TABLE stats ("
  echo "  id SERIAL PRIMARY KEY,"
  echo "  metric_name VARCHAR(100) NOT NULL,"
  echo "  metric_value NUMERIC NOT NULL,"
  echo "  recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
  echo ");"
  echo ""
  echo "CREATE INDEX idx_stats_metric_name ON stats(metric_name);"
  echo "CREATE INDEX idx_stats_recorded_at ON stats(recorded_at);"
  echo "CREATE INDEX idx_users_created_at ON users(created_at);"
  echo ""
  read -p "Press Enter after you have initialized the database..."
fi

if [ "$STACK_TO_DEPLOY" = "all" ] || [ "$STACK_TO_DEPLOY" = "compute" ]; then
  echo "[3/4] Deploying Compute stack..."

  # Check if Docker images are available in ECR
  echo "⚠️  Make sure Docker images are pushed to ECR before deploying compute stack!"
  echo ""
  echo "Required ECR repositories:"
  echo "  - sample-app/public:latest"
  echo "  - sample-app/admin:latest"
  echo "  - sample-app/batch:latest"
  echo ""
  read -p "Have you pushed all Docker images to ECR? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipping compute stack deployment. Please push Docker images first."
    echo ""
    echo "To push images, run:"
    echo "  cd ../../../app"
    echo "  ./build-and-push.sh $ENVIRONMENT"
    echo ""
    exit 0
  fi

  deploy_stack "compute"
fi

if [ "$STACK_TO_DEPLOY" = "all" ] || [ "$STACK_TO_DEPLOY" = "monitoring" ]; then
  echo "[4/4] Deploying Monitoring stack..."
  deploy_stack "monitoring"
fi

echo ""
echo "=========================================="
echo "✅ Service Account deployment completed!"
echo "=========================================="
echo ""

# Get ALB DNS name if compute stack was deployed
if [ "$STACK_TO_DEPLOY" = "all" ] || [ "$STACK_TO_DEPLOY" = "compute" ]; then
  STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-service-compute"
  ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $AWS_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
    --output text 2>/dev/null || echo "N/A")

  echo "Application URLs:"
  echo "  Public Web: http://$ALB_DNS"
  echo "  Health Check: http://$ALB_DNS/health"
  echo ""
fi

echo "Next steps:"
echo "1. Test application endpoints"
echo "2. Check CloudWatch Dashboard"
echo "3. Review CloudWatch Alarms"
echo ""
