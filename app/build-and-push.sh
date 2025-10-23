#!/bin/bash
set -e

# ==============================================================================
# Build and Push Docker Images to ECR
# ==============================================================================

# Usage: ./build-and-push.sh <environment> [service]
# Example: ./build-and-push.sh dev           # Build and push all services
# Example: ./build-and-push.sh dev public    # Build and push only public service

ENVIRONMENT=${1:-dev}
SERVICE=${2:-all}
AWS_REGION="ap-northeast-1"

echo "=========================================="
echo "Docker Build and Push to ECR"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Service: $SERVICE"
echo "Region: $AWS_REGION"
echo ""

# Check AWS CLI authentication
echo "[1/4] Checking AWS authentication..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "  AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# Login to ECR
echo "[2/4] Logging in to Amazon ECR..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

echo "  ✅ ECR login successful"
echo ""

# Function to build and push a service
build_and_push() {
  local SERVICE_NAME=$1
  local DOCKERFILE="$SERVICE_NAME/Dockerfile"
  local ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sample-app/${SERVICE_NAME}"
  local IMAGE_TAG="${GITHUB_SHA:-latest}"

  echo "=========================================="
  echo "Building and pushing: $SERVICE_NAME"
  echo "=========================================="

  # Check if Dockerfile exists
  if [ ! -f "$DOCKERFILE" ]; then
    echo "  ❌ Dockerfile not found: $DOCKERFILE"
    exit 1
  fi

  # Build Docker image
  echo "  🔨 Building Docker image..."
  docker build \
    -t sample-app-${SERVICE_NAME}:${IMAGE_TAG} \
    -t sample-app-${SERVICE_NAME}:latest \
    -f $DOCKERFILE \
    .

  echo "  ✅ Build completed"
  echo ""

  # Tag for ECR
  echo "  🏷️  Tagging image for ECR..."
  docker tag sample-app-${SERVICE_NAME}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
  docker tag sample-app-${SERVICE_NAME}:latest ${ECR_REPO}:latest

  echo "  ✅ Tagging completed"
  echo ""

  # Push to ECR
  echo "  ⬆️  Pushing to ECR..."
  docker push ${ECR_REPO}:${IMAGE_TAG}
  docker push ${ECR_REPO}:latest

  echo "  ✅ Push completed: ${ECR_REPO}:${IMAGE_TAG}"
  echo "  ✅ Push completed: ${ECR_REPO}:latest"
  echo ""
}

# Build and push services
echo "[3/4] Building and pushing Docker images..."
echo ""

if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "public" ]; then
  build_and_push "public"
fi

if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "admin" ]; then
  build_and_push "admin"
fi

if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "batch" ]; then
  build_and_push "batch"
fi

echo "[4/4] Listing ECR images..."
echo ""

# List all images in ECR
if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "public" ]; then
  echo "Public Web Service images:"
  aws ecr describe-images \
    --repository-name sample-app/public \
    --region $AWS_REGION \
    --query 'imageDetails[*].[imageTags[0],imagePushedAt]' \
    --output table 2>/dev/null || echo "  No images found"
  echo ""
fi

if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "admin" ]; then
  echo "Admin Service images:"
  aws ecr describe-images \
    --repository-name sample-app/admin \
    --region $AWS_REGION \
    --query 'imageDetails[*].[imageTags[0],imagePushedAt]' \
    --output table 2>/dev/null || echo "  No images found"
  echo ""
fi

if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "batch" ]; then
  echo "Batch Service images:"
  aws ecr describe-images \
    --repository-name sample-app/batch \
    --region $AWS_REGION \
    --query 'imageDetails[*].[imageTags[0],imagePushedAt]' \
    --output table 2>/dev/null || echo "  No images found"
  echo ""
fi

echo "=========================================="
echo "✅ Build and push completed!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Deploy or update ECS services to use the new images"
echo "2. Run: cd ../infra/cloudformation/service && ./deploy.sh $ENVIRONMENT compute"
echo ""
