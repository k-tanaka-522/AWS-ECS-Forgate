#!/bin/bash
################################################################################
# Service Account - CloudFormation Deploy Script
#
# このスクリプトは Service Account のインフラをデプロイします。
# - Service VPC (10.1.0.0/16)
# - RDS PostgreSQL
# - ECS Fargate (Public Web, Admin, Batch)
# - ALB (Public, Admin)
# - CloudWatch Monitoring
#
# 前提条件:
# - AWS CLI設定済み（Service Accountのクレデンシャル）
# - Platform Account デプロイ完了
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
REGION="ap-northeast-1"
PARAMETERS_FILE="parameters-${ENVIRONMENT}.json"

# スタック名リスト（デプロイ順序）
STACKS=(
  "01-network"
  "02-database"
  "03-compute"
  "04-monitoring"
)

echo "========================================"
echo "Service Account Deployment"
echo "========================================"
echo "Project:     ${PROJECT_NAME}"
echo "Environment: ${ENVIRONMENT}"
echo "Region:      ${REGION}"
echo "Stacks:      ${#STACKS[@]} stacks"
echo "========================================"

# ==============================================================================
# パラメータファイル確認
# ==============================================================================
if [ ! -f "$PARAMETERS_FILE" ]; then
  echo "Error: Parameters file not found: $PARAMETERS_FILE"
  exit 1
fi

# ==============================================================================
# 関数定義
# ==============================================================================

# スタックをデプロイする関数
deploy_stack() {
  local STACK_FILE=$1
  local STACK_NAME="${PROJECT_NAME}-service-${ENVIRONMENT}-${STACK_FILE%-*}"
  local TEMPLATE_FILE="${STACK_FILE}.yaml"

  echo ""
  echo "========================================"
  echo "Deploying: ${STACK_NAME}"
  echo "========================================"

  # テンプレート存在確認
  if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found: $TEMPLATE_FILE"
    exit 1
  fi

  # テンプレート検証
  echo "[1/5] Validating template..."
  aws cloudformation validate-template \
    --template-body file://${TEMPLATE_FILE} \
    --region ${REGION} > /dev/null

  if [ $? -eq 0 ]; then
    echo "✓ Template validation passed"
  else
    echo "✗ Template validation failed"
    exit 1
  fi

  # スタック存在確認
  echo "[2/5] Checking stack status..."
  STACK_EXISTS=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${REGION} 2>&1 | grep -c "ValidationError" || true)

  if [ $STACK_EXISTS -eq 1 ]; then
    CHANGE_SET_TYPE="CREATE"
    echo "✓ Stack does not exist, will create new stack"
  else
    CHANGE_SET_TYPE="UPDATE"
    echo "✓ Stack exists, will update"
  fi

  # Change Set作成
  echo "[3/5] Creating Change Set..."
  CHANGE_SET_NAME="${STACK_NAME}-changeset-$(date +%Y%m%d-%H%M%S)"

  aws cloudformation create-change-set \
    --stack-name ${STACK_NAME} \
    --change-set-name ${CHANGE_SET_NAME} \
    --change-set-type ${CHANGE_SET_TYPE} \
    --template-body file://${TEMPLATE_FILE} \
    --parameters file://${PARAMETERS_FILE} \
    --capabilities CAPABILITY_IAM \
    --region ${REGION}

  echo "✓ Change Set created: ${CHANGE_SET_NAME}"

  # Change Set作成完了待ち
  echo "Waiting for Change Set creation..."
  aws cloudformation wait change-set-create-complete \
    --stack-name ${STACK_NAME} \
    --change-set-name ${CHANGE_SET_NAME} \
    --region ${REGION} 2>&1 | grep -v "Waiter" || true

  # Change Set内容表示
  echo "[4/5] Reviewing Change Set..."
  aws cloudformation describe-change-set \
    --stack-name ${STACK_NAME} \
    --change-set-name ${CHANGE_SET_NAME} \
    --region ${REGION} \
    --query 'Changes[*].[ResourceChange.Action, ResourceChange.LogicalResourceId, ResourceChange.ResourceType]' \
    --output table

  # 実行確認
  read -p "Execute this Change Set? (yes/no): " CONFIRM

  if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled by user."
    echo "Deleting Change Set..."
    aws cloudformation delete-change-set \
      --stack-name ${STACK_NAME} \
      --change-set-name ${CHANGE_SET_NAME} \
      --region ${REGION}
    exit 0
  fi

  # Change Set実行
  echo "[5/5] Executing Change Set..."
  aws cloudformation execute-change-set \
    --stack-name ${STACK_NAME} \
    --change-set-name ${CHANGE_SET_NAME} \
    --region ${REGION}

  echo "✓ Change Set execution started"

  # 完了待ち
  echo "Waiting for stack operation to complete..."
  if [ "$STACK_FILE" == "02-database" ]; then
    echo "(RDS deployment may take 10-15 minutes)"
  elif [ "$STACK_FILE" == "03-compute" ]; then
    echo "(ECS deployment may take 5-10 minutes)"
  fi

  if [ $CHANGE_SET_TYPE == "CREATE" ]; then
    aws cloudformation wait stack-create-complete \
      --stack-name ${STACK_NAME} \
      --region ${REGION}
  else
    aws cloudformation wait stack-update-complete \
      --stack-name ${STACK_NAME} \
      --region ${REGION}
  fi

  echo "✓ Stack deployment completed: ${STACK_NAME}"

  # Stack出力値を表示
  echo ""
  echo "Stack Outputs:"
  aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${REGION} \
    --query 'Stacks[0].Outputs[*].[OutputKey, OutputValue]' \
    --output table
}

# ==============================================================================
# メインデプロイ処理
# ==============================================================================

echo ""
echo "This script will deploy ${#STACKS[@]} CloudFormation stacks in sequence:"
for i in "${!STACKS[@]}"; do
  echo "  $((i+1)). ${STACKS[$i]}.yaml"
done

echo ""
read -p "Do you want to proceed with all deployments? (yes/no): " PROCEED

if [ "$PROCEED" != "yes" ]; then
  echo "Deployment cancelled by user."
  exit 0
fi

# 各スタックを順番にデプロイ
for STACK in "${STACKS[@]}"; do
  deploy_stack "$STACK"
done

# ==============================================================================
# デプロイ完了
# ==============================================================================
echo ""
echo "========================================"
echo "All Stacks Deployed Successfully!"
echo "========================================"

# 全スタックの情報を表示
echo ""
echo "Deployed Stacks Summary:"
for STACK in "${STACKS[@]}"; do
  STACK_NAME="${PROJECT_NAME}-service-${ENVIRONMENT}-${STACK%-*}"
  echo ""
  echo "-------------------"
  echo "Stack: ${STACK_NAME}"
  echo "-------------------"
  aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${REGION} \
    --query 'Stacks[0].[StackStatus, CreationTime]' \
    --output table
done

echo ""
echo "========================================"
echo "Next Steps:"
echo "========================================"
echo "1. Verify RDS Database:"
echo "   aws rds describe-db-instances --region ${REGION}"
echo ""
echo "2. Get RDS Endpoint:"
echo "   DB_ENDPOINT=\$(aws cloudformation describe-stacks \\"
echo "     --stack-name ${PROJECT_NAME}-service-${ENVIRONMENT}-database \\"
echo "     --region ${REGION} \\"
echo "     --query 'Stacks[0].Outputs[?OutputKey==\`DBEndpoint\`].OutputValue' \\"
echo "     --output text)"
echo ""
echo "3. Build and Push Docker Images:"
echo "   cd ../../../app"
echo "   ./build.sh ${ENVIRONMENT}"
echo ""
echo "4. Run Database Migrations:"
echo "   cd app/shared/db"
echo "   npm run migrate:latest"
echo ""
echo "5. Verify ECS Services:"
echo "   aws ecs list-services --cluster ${PROJECT_NAME}-${ENVIRONMENT} --region ${REGION}"
echo ""
echo "6. Get ALB DNS Names:"
echo "   aws cloudformation describe-stacks \\"
echo "     --stack-name ${PROJECT_NAME}-service-${ENVIRONMENT}-compute \\"
echo "     --region ${REGION} \\"
echo "     --query 'Stacks[0].Outputs[?contains(OutputKey, \`ALB\`)].{Key:OutputKey, Value:OutputValue}' \\"
echo "     --output table"
echo ""
echo "7. Check CloudWatch Dashboard:"
echo "   https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#dashboards:"
echo "========================================"
