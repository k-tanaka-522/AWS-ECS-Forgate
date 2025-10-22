#!/bin/bash
################################################################################
# Service Account - CloudFormation Rollback Script
#
# このスクリプトは Service Account のスタックを削除します。
# 削除は逆順で実行されます（依存関係を考慮）。
#
# 警告: このスクリプトは全てのリソースを削除します！
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
REGION="ap-northeast-1"

# スタック名リスト（削除順序 - デプロイの逆順）
STACKS=(
  "04-monitoring"
  "03-compute"
  "02-database"
  "01-network"
)

echo "========================================"
echo "Service Account Rollback"
echo "========================================"
echo "Project:     ${PROJECT_NAME}"
echo "Environment: ${ENVIRONMENT}"
echo "Region:      ${REGION}"
echo "Stacks:      ${#STACKS[@]} stacks"
echo "========================================"
echo ""
echo "⚠️  WARNING ⚠️"
echo "This will DELETE the following stacks:"
for STACK in "${STACKS[@]}"; do
  STACK_NAME="${PROJECT_NAME}-service-${ENVIRONMENT}-${STACK%-*}"
  echo "  - ${STACK_NAME}"
done
echo ""
echo "All resources including:"
echo "  - ECS Services and Tasks"
echo "  - RDS Database (with final snapshot)"
echo "  - Load Balancers"
echo "  - VPC and Networking"
echo "  - CloudWatch Alarms and Dashboards"
echo ""

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

read -p "Are you sure you want to delete all stacks? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Rollback cancelled by user."
  exit 0
fi

# ==============================================================================
# スタック削除処理
# ==============================================================================

delete_stack() {
  local STACK_FILE=$1
  local STACK_NAME="${PROJECT_NAME}-service-${ENVIRONMENT}-${STACK_FILE%-*}"

  echo ""
  echo "========================================"
  echo "Deleting: ${STACK_NAME}"
  echo "========================================"

  # スタック存在確認
  STACK_EXISTS=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${REGION} 2>&1 | grep -c "ValidationError" || true)

  if [ $STACK_EXISTS -eq 1 ]; then
    echo "✓ Stack does not exist, skipping: ${STACK_NAME}"
    return 0
  fi

  # スタック削除
  echo "Deleting stack..."
  aws cloudformation delete-stack \
    --stack-name ${STACK_NAME} \
    --region ${REGION}

  echo "✓ Stack deletion initiated: ${STACK_NAME}"

  # 削除完了待ち
  echo "Waiting for stack deletion to complete..."
  if [ "$STACK_FILE" == "02-database" ]; then
    echo "(RDS deletion may take 10-15 minutes, final snapshot will be created)"
  fi

  aws cloudformation wait stack-delete-complete \
    --stack-name ${STACK_NAME} \
    --region ${REGION}

  echo "✓ Stack deleted successfully: ${STACK_NAME}"
}

# 各スタックを逆順で削除
for STACK in "${STACKS[@]}"; do
  delete_stack "$STACK"
done

# ==============================================================================
# 削除完了
# ==============================================================================
echo ""
echo "========================================"
echo "All Stacks Deleted Successfully!"
echo "========================================"

echo ""
echo "Cleanup Notes:"
echo "1. RDS final snapshot が作成されています："
echo "   aws rds describe-db-snapshots --region ${REGION}"
echo ""
echo "2. ECR images は削除されていません（手動削除が必要）："
echo "   aws ecr list-images --repository-name ${PROJECT_NAME}/${ENVIRONMENT}/public-web --region ${REGION}"
echo ""
echo "3. CloudWatch Logs は削除されていません（保持期間に従って自動削除）："
echo "   /ecs/${PROJECT_NAME}-${ENVIRONMENT}/*"
echo ""
echo "4. Secrets Manager のシークレットは削除されていません："
echo "   aws secretsmanager list-secrets --region ${REGION}"
echo ""
echo "========================================"
