#!/bin/bash
# create-changeset.sh - CloudFormation Change Set 作成スクリプト
# Usage: ./create-changeset.sh <stack-name> [environment] [template-file]

set -e

# 引数チェック
if [ $# -lt 1 ]; then
  echo "❌ Usage: $0 <stack-name> [environment] [template-file]"
  echo "   Example: $0 platform-network dev"
  exit 1
fi

STACK_NAME=$1
ENVIRONMENT=${2:-dev}
TEMPLATE_FILE=${3:-infra/cloudformation/${STACK_NAME}.yaml}

# バリデーション
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "❌ Template file not found: $TEMPLATE_FILE"
  exit 1
fi

# Change Set 名生成 (タイムスタンプ付き)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CHANGESET_NAME="${STACK_NAME}-changeset-${TIMESTAMP}"

# Parameters ファイル
PARAMS_FILE="infra/cloudformation/parameters/${STACK_NAME}-${ENVIRONMENT}.json"

echo "📋 Creating Change Set for ${STACK_NAME}..."
echo "   Environment: ${ENVIRONMENT}"
echo "   Template: ${TEMPLATE_FILE}"
echo "   Change Set Name: ${CHANGESET_NAME}"

# Parameters ファイルが存在する場合のみ使用
PARAMS_OPTION=""
if [ -f "$PARAMS_FILE" ]; then
  echo "   Parameters: ${PARAMS_FILE}"
  PARAMS_OPTION="--parameters file://${PARAMS_FILE}"
fi

# スタックが存在するかチェック
if aws cloudformation describe-stacks --stack-name "${STACK_NAME}" &>/dev/null; then
  CHANGESET_TYPE="UPDATE"
  echo "   Change Set Type: UPDATE (existing stack)"
else
  CHANGESET_TYPE="CREATE"
  echo "   Change Set Type: CREATE (new stack)"
fi

# Change Set 作成
echo ""
echo "🚀 Creating Change Set..."
aws cloudformation create-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --template-body "file://${TEMPLATE_FILE}" \
  ${PARAMS_OPTION} \
  --capabilities CAPABILITY_NAMED_IAM \
  --change-set-type "${CHANGESET_TYPE}"

# Change Set ID を保存
echo "${CHANGESET_NAME}" > ".changeset-id-${STACK_NAME}"

echo ""
echo "⏳ Waiting for Change Set to be created..."
aws cloudformation wait change-set-create-complete \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}"

echo ""
echo "✅ Change Set created: ${CHANGESET_NAME}"
echo ""
echo "📌 Next steps:"
echo "   1. Review changes: ./describe-changeset.sh ${STACK_NAME}"
echo "   2. Execute changes: ./execute-changeset.sh ${STACK_NAME}"
echo "   3. Rollback (if needed): ./rollback.sh ${STACK_NAME}"
