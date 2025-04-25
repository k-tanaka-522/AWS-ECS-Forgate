#!/bin/bash
set -e

echo "Starting AfterAllowTraffic hook"

# デプロイ環境の特定
ENVIRONMENT=$(echo $DEPLOYMENT_GROUP_NAME | grep -oP 'ecsforgate-\K(dev|stg|prd)')
echo "Detected environment: $ENVIRONMENT"

# ALBの健全性チェック
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names ecsforgate-$ENVIRONMENT-tg --query "TargetGroups[0].TargetGroupArn" --output text)
if [ -z "$TARGET_GROUP_ARN" ]; then
  echo "Failed to get target group ARN"
  exit 1
fi

echo "Target group ARN: $TARGET_GROUP_ARN"

# ターゲットグループのヘルス状態を確認
HEALTH_COUNT=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" --output text)
UNHEALTHY_COUNT=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --query "length(TargetHealthDescriptions[?TargetHealth.State!='healthy'])" --output text)

echo "Healthy targets: $HEALTH_COUNT"
echo "Unhealthy targets: $UNHEALTHY_COUNT"

if [ "$HEALTH_COUNT" -eq 0 ]; then
  echo "No healthy targets found"
  exit 1
fi

# メトリクス確認のためのテスト負荷（オプション）
if [ "$ENVIRONMENT" != "prd" ]; then
  echo "Running test load for metrics verification"
  for i in {1..10}; do
    curl -s -o /dev/null http://$ALB_DNS/api/health
    curl -s -o /dev/null http://$ALB_DNS/api/records
    sleep 1
  done
  echo "Test load completed"
fi

# デプロイ完了通知
echo "Deployment to $ENVIRONMENT completed successfully at $(date)"

echo "AfterAllowTraffic hook completed successfully"
exit 0
