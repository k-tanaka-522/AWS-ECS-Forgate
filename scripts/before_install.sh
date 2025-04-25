#!/bin/bash
set -e

echo "Starting BeforeInstall hook"
echo "Checking if environment variables are properly set"

# 環境変数のチェック
if [ -z "$DEPLOYMENT_GROUP_NAME" ]; then
  echo "DEPLOYMENT_GROUP_NAME is not set"
  exit 1
fi

# デプロイ環境の特定
ENVIRONMENT=$(echo $DEPLOYMENT_GROUP_NAME | grep -oP 'ecsforgate-\K(dev|stg|prd)')
echo "Detected environment: $ENVIRONMENT"

# リソース状態の確認
echo "Checking ECS service status"
aws ecs describe-services --cluster ecsforgate-$ENVIRONMENT-cluster --services ecsforgate-api-$ENVIRONMENT-service --query "services[0].status" || echo "Service not found or not running yet"

echo "BeforeInstall hook completed successfully"
exit 0
