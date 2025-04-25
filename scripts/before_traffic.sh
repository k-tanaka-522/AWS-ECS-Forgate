#!/bin/bash
set -e

echo "Starting BeforeAllowTraffic hook"

# デプロイ環境の特定
ENVIRONMENT=$(echo $DEPLOYMENT_GROUP_NAME | grep -oP 'ecsforgate-\K(dev|stg|prd)')
echo "Detected environment: $ENVIRONMENT"

# 新しいタスク定義の詳細を取得
TASK_DEFINITION_ARN=$(aws ecs describe-task-definition --task-definition ecsforgate-api-$ENVIRONMENT --query "taskDefinition.taskDefinitionArn" --output text)
echo "Current task definition: $TASK_DEFINITION_ARN"

# 実行中のタスクを確認
RUNNING_TASKS=$(aws ecs list-tasks --cluster ecsforgate-$ENVIRONMENT-cluster --service-name ecsforgate-api-$ENVIRONMENT-service --desired-status RUNNING --query "taskArns" --output text)
echo "Running tasks: $RUNNING_TASKS"

if [ -z "$RUNNING_TASKS" ]; then
  echo "Warning: No running tasks found"
else
  # タスクの詳細を確認
  echo "Checking task details"
  aws ecs describe-tasks --cluster ecsforgate-$ENVIRONMENT-cluster --tasks $RUNNING_TASKS --query "tasks[0].lastStatus" --output text
fi

echo "BeforeAllowTraffic hook completed successfully"
exit 0
