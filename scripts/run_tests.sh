#!/bin/bash
set -e

echo "Starting AfterAllowTestTraffic hook"

# デプロイ環境の特定
ENVIRONMENT=$(echo $DEPLOYMENT_GROUP_NAME | grep -oP 'ecsforgate-\K(dev|stg|prd)')
echo "Detected environment: $ENVIRONMENT"

# ALBのDNS名を取得
ALB_DNS=$(aws elbv2 describe-load-balancers --names ecsforgate-$ENVIRONMENT-alb --query "LoadBalancers[0].DNSName" --output text)
if [ -z "$ALB_DNS" ]; then
  echo "Failed to get ALB DNS name"
  exit 1
fi

echo "ALB DNS: $ALB_DNS"

# APIのヘルスチェック
echo "Running health check test"
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/api/health)
echo "Health check status: $HEALTH_STATUS"

if [ "$HEALTH_STATUS" != "200" ]; then
  echo "Health check failed with status $HEALTH_STATUS"
  exit 1
fi

# 基本的な機能テスト
echo "Running basic functionality test"
RECORDS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/api/records)
echo "Records API status: $RECORDS_STATUS"

if [ "$RECORDS_STATUS" != "200" ]; then
  echo "Records API check failed with status $RECORDS_STATUS"
  exit 1
fi

echo "AfterAllowTestTraffic hook completed successfully"
exit 0
