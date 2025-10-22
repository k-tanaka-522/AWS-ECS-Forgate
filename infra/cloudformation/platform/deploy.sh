#!/bin/bash
################################################################################
# Platform Account - CloudFormation Deploy Script
#
# このスクリプトは Platform Account のインフラをデプロイします。
# - Shared VPC (10.0.0.0/16)
# - Transit Gateway
# - Client VPN Endpoint
#
# 前提条件:
# - AWS CLI設定済み（Platform Accountのクレデンシャル）
# - 必要なIAM権限
#
# 実行方法:
#   ./deploy.sh dev   # 開発環境
#   ./deploy.sh prod  # 本番環境
################################################################################

set -e  # エラー時に即座に終了

# ==============================================================================
# パラメータチェック
# ==============================================================================
ENVIRONMENT=$1

if [ -z "$ENVIRONMENT" ]; then
  echo "Error: Environment parameter is required"
  echo "Usage: ./deploy.sh {dev|prod}"
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
TEMPLATE_FILE="stack.yaml"
PARAMETERS_FILE="parameters-${ENVIRONMENT}.json"
REGION="ap-northeast-1"

echo "========================================"
echo "Platform Account Deployment"
echo "========================================"
echo "Project:     ${PROJECT_NAME}"
echo "Environment: ${ENVIRONMENT}"
echo "Stack Name:  ${STACK_NAME}"
echo "Region:      ${REGION}"
echo "========================================"

# ==============================================================================
# パラメータファイル確認
# ==============================================================================
if [ ! -f "$PARAMETERS_FILE" ]; then
  echo "Error: Parameters file not found: $PARAMETERS_FILE"
  exit 1
fi

# ==============================================================================
# テンプレート検証
# ==============================================================================
echo ""
echo "[Step 1/4] Validating CloudFormation template..."
aws cloudformation validate-template \
  --template-body file://${TEMPLATE_FILE} \
  --region ${REGION} > /dev/null

if [ $? -eq 0 ]; then
  echo "✓ Template validation passed"
else
  echo "✗ Template validation failed"
  exit 1
fi

# ==============================================================================
# Change Set作成
# ==============================================================================
echo ""
echo "[Step 2/4] Creating Change Set..."

# スタックが存在するか確認
STACK_EXISTS=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --region ${REGION} 2>&1 | grep -c "ValidationError" || true)

if [ $STACK_EXISTS -eq 1 ]; then
  # スタック新規作成
  CHANGE_SET_TYPE="CREATE"
  echo "Creating new stack: ${STACK_NAME}"
else
  # スタック更新
  CHANGE_SET_TYPE="UPDATE"
  echo "Updating existing stack: ${STACK_NAME}"
fi

CHANGE_SET_NAME="${STACK_NAME}-changeset-$(date +%Y%m%d-%H%M%S)"

aws cloudformation create-change-set \
  --stack-name ${STACK_NAME} \
  --change-set-name ${CHANGE_SET_NAME} \
  --change-set-type ${CHANGE_SET_TYPE} \
  --template-body file://${TEMPLATE_FILE} \
  --parameters file://${PARAMETERS_FILE} \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --region ${REGION}

echo "✓ Change Set created: ${CHANGE_SET_NAME}"

# Change Set作成完了待ち
echo ""
echo "Waiting for Change Set creation to complete..."
aws cloudformation wait change-set-create-complete \
  --stack-name ${STACK_NAME} \
  --change-set-name ${CHANGE_SET_NAME} \
  --region ${REGION}

# ==============================================================================
# Change Set内容表示
# ==============================================================================
echo ""
echo "[Step 3/4] Reviewing Change Set..."
aws cloudformation describe-change-set \
  --stack-name ${STACK_NAME} \
  --change-set-name ${CHANGE_SET_NAME} \
  --region ${REGION} \
  --query 'Changes[*].[ResourceChange.Action, ResourceChange.LogicalResourceId, ResourceChange.ResourceType]' \
  --output table

echo ""
echo "Change Set Details:"
aws cloudformation describe-change-set \
  --stack-name ${STACK_NAME} \
  --change-set-name ${CHANGE_SET_NAME} \
  --region ${REGION} \
  --query '[Status, StatusReason]' \
  --output table

# ==============================================================================
# Change Set実行確認
# ==============================================================================
echo ""
read -p "Do you want to execute this Change Set? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Deployment cancelled by user."
  echo "Deleting Change Set: ${CHANGE_SET_NAME}"
  aws cloudformation delete-change-set \
    --stack-name ${STACK_NAME} \
    --change-set-name ${CHANGE_SET_NAME} \
    --region ${REGION}
  exit 0
fi

# ==============================================================================
# Change Set実行
# ==============================================================================
echo ""
echo "[Step 4/4] Executing Change Set..."
aws cloudformation execute-change-set \
  --stack-name ${STACK_NAME} \
  --change-set-name ${CHANGE_SET_NAME} \
  --region ${REGION}

echo "✓ Change Set execution started"

# スタック作成/更新完了待ち
echo ""
echo "Waiting for stack operation to complete..."
echo "(This may take 10-15 minutes for initial deployment)"

if [ $CHANGE_SET_TYPE == "CREATE" ]; then
  aws cloudformation wait stack-create-complete \
    --stack-name ${STACK_NAME} \
    --region ${REGION}
else
  aws cloudformation wait stack-update-complete \
    --stack-name ${STACK_NAME} \
    --region ${REGION}
fi

# ==============================================================================
# デプロイ結果確認
# ==============================================================================
echo ""
echo "========================================"
echo "Deployment Completed Successfully!"
echo "========================================"

# Stack出力値を表示
echo ""
echo "Stack Outputs:"
aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --region ${REGION} \
  --query 'Stacks[0].Outputs[*].[OutputKey, OutputValue, Description]' \
  --output table

echo ""
echo "========================================"
echo "Next Steps:"
echo "========================================"
echo "1. Verify Transit Gateway is active:"
echo "   aws ec2 describe-transit-gateways --region ${REGION}"
echo ""
echo "2. Verify Client VPN Endpoint:"
echo "   aws ec2 describe-client-vpn-endpoints --region ${REGION}"
echo ""
echo "3. Proceed to Service Account deployment:"
echo "   cd ../service"
echo "   ./deploy.sh ${ENVIRONMENT}"
echo "========================================"
