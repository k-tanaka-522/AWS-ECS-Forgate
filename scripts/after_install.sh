#!/bin/bash
set -e

echo "Starting AfterInstall hook"

# デプロイ環境の特定
ENVIRONMENT=$(echo $DEPLOYMENT_GROUP_NAME | grep -oP 'ecsforgate-\K(dev|stg|prd)')
echo "Detected environment: $ENVIRONMENT"

# 新しいタスク定義の確認
TASK_DEFINITION_ARN=$(aws ecs describe-task-definition --task-definition ecsforgate-api-$ENVIRONMENT --query "taskDefinition.taskDefinitionArn" --output text)
echo "Newly registered task definition: $TASK_DEFINITION_ARN"

# タスク定義の詳細を出力
aws ecs describe-task-definition --task-definition ecsforgate-api-$ENVIRONMENT --query "taskDefinition.containerDefinitions[0].image" --output text
echo "Container image updated successfully"

echo "AfterInstall hook completed successfully"
exit 0
