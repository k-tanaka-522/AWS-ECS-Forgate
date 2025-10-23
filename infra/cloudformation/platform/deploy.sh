#!/bin/bash
set -e

# ==============================================================================
# Platform Account - CloudFormation Deployment Script
# ==============================================================================

# Usage: ./deploy.sh <environment>
# Example: ./deploy.sh dev

ENVIRONMENT=${1:-dev}
PROJECT_NAME="sample-app"
AWS_REGION="ap-northeast-1"
BUCKET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cfn-templates"
STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-platform"

echo "=========================================="
echo "Platform Account Deployment"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Stack Name: $STACK_NAME"
echo "Region: $AWS_REGION"
echo ""

# Check AWS CLI authentication
echo "[1/5] Checking AWS authentication..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "  AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# Create S3 bucket for nested templates (if not exists)
echo "[2/5] Creating S3 bucket for nested templates..."
if aws s3 ls s3://$BUCKET_NAME 2>/dev/null; then
  echo "  Bucket already exists: $BUCKET_NAME"
else
  aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION
  echo "  Bucket created: $BUCKET_NAME"
fi
echo ""

# Upload nested templates to S3
echo "[3/5] Uploading nested templates to S3..."
aws s3 cp nested/network.yaml s3://$BUCKET_NAME/platform/nested/network.yaml
echo "  Uploaded: nested/network.yaml"

aws s3 cp nested/connectivity.yaml s3://$BUCKET_NAME/platform/nested/connectivity.yaml
echo "  Uploaded: nested/connectivity.yaml"
echo ""

# Deploy CloudFormation stack
echo "[4/5] Deploying CloudFormation stack..."
aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --template-file stacks/main/stack.yaml \
  --parameter-overrides file://parameters/${ENVIRONMENT}.json \
  --capabilities CAPABILITY_IAM \
  --region $AWS_REGION \
  --no-fail-on-empty-changeset

echo ""

# Get stack outputs
echo "[5/5] Retrieving stack outputs..."
aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $AWS_REGION \
  --query 'Stacks[0].Outputs' \
  --output table

echo ""
echo "=========================================="
echo "✅ Platform Account deployment completed!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Note the Transit Gateway ID from the outputs above"
echo "2. Update Service Account parameters file with the Transit Gateway ID"
echo "3. Deploy Service Account infrastructure"
echo ""
