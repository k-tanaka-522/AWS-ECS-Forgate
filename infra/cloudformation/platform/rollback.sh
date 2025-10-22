#!/bin/bash
################################################################################
# Platform Account - CloudFormation Rollback Script
#
# このスクリプトは Platform Account のスタックを削除します。
#
# 警告: このスクリプトは全てのリソースを削除します！
# 前提条件: Service Account のスタックが先に削除されていること
#
# 実行方法:
#   ./rollback.sh dev   # 開発環境の削除
#   ./rollback.sh prod  # 本番環境の削除
################################################################################

set -e  # エラー時に即座に終了

# ==============================================================================
# パラメータチェック
# ==============================================================================
ENVIRONMENT=$1

if [ -z "$ENVIRONMENT" ]; then
  echo "Error: Environment parameter is required"
  echo "Usage: ./rollback.sh {dev|prod}"
  exit 1
fi

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
  echo "Error: Environment must be 'dev' or 'prod'"
  exit 1
fi

# ==============================================================================
# 変数設定
# ==============================================================================
PROJECT_NAME="sample-app"
STACK_NAME="${PROJECT_NAME}-platform-${ENVIRONMENT}"
REGION="ap-northeast-1"

echo "========================================"
echo "Platform Account Rollback"
echo "========================================"
echo "Project:     ${PROJECT_NAME}"
echo "Environment: ${ENVIRONMENT}"
echo "Stack Name:  ${STACK_NAME}"
echo "Region:      ${REGION}"
echo "========================================"
echo ""
echo "⚠️  WARNING ⚠️"
echo "This will DELETE the following stack:"
echo "  - ${STACK_NAME}"
echo ""
echo "All resources including:"
echo "  - Transit Gateway"
echo "  - Client VPN Endpoint"
echo "  - Shared VPC and Networking"
echo "  - CloudWatch Logs"
echo ""

# Service Account削除確認
echo "⚠️  IMPORTANT ⚠️"
echo "Before deleting Platform stack, ensure Service Account stacks are deleted."
echo ""
read -p "Have you deleted all Service Account stacks? (yes/no): " SERVICE_CONFIRM

if [ "$SERVICE_CONFIRM" != "yes" ]; then
  echo "Please delete Service Account stacks first:"
  echo "  cd ../service"
  echo "  ./rollback.sh ${ENVIRONMENT}"
  exit 1
fi

# 本番環境の場合は追加確認
if [ "$ENVIRONMENT" == "prod" ]; then
  echo "🚨 YOU ARE ABOUT TO DELETE PRODUCTION ENVIRONMENT! 🚨"
  echo ""
  read -p "Type 'DELETE PRODUCTION' to confirm: " PROD_CONFIRM
  if [ "$PROD_CONFIRM" != "DELETE PRODUCTION" ]; then
    echo "Rollback cancelled."
    exit 0
  fi
fi

read -p "Are you sure you want to delete the Platform stack? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Rollback cancelled by user."
  exit 0
fi

# ==============================================================================
# スタック削除処理
# ==============================================================================

echo ""
echo "========================================"
echo "Deleting: ${STACK_NAME}"
echo "========================================"

# スタック存在確認
STACK_EXISTS=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --region ${REGION} 2>&1 | grep -c "ValidationError" || true)

if [ $STACK_EXISTS -eq 1 ]; then
  echo "✓ Stack does not exist: ${STACK_NAME}"
  exit 0
fi

# スタック削除
echo "Deleting stack..."
aws cloudformation delete-stack \
  --stack-name ${STACK_NAME} \
  --region ${REGION}

echo "✓ Stack deletion initiated: ${STACK_NAME}"

# 削除完了待ち
echo "Waiting for stack deletion to complete..."
echo "(Transit Gateway deletion may take 5-10 minutes)"

aws cloudformation wait stack-delete-complete \
  --stack-name ${STACK_NAME} \
  --region ${REGION}

echo "✓ Stack deleted successfully: ${STACK_NAME}"

# ==============================================================================
# 削除完了
# ==============================================================================
echo ""
echo "========================================"
echo "Platform Stack Deleted Successfully!"
echo "========================================"

echo ""
echo "Cleanup Notes:"
echo "1. VPN Client certificates は削除されていません（手動削除が必要）"
echo ""
echo "2. CloudWatch Logs は削除されていません（保持期間に従って自動削除）"
echo ""
echo "3. 削除されたリソースの確認："
echo "   aws ec2 describe-transit-gateways --region ${REGION}"
echo "   aws ec2 describe-client-vpn-endpoints --region ${REGION}"
echo "========================================"
