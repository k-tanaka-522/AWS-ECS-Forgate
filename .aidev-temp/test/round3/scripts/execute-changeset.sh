#!/bin/bash
# execute-changeset.sh - CloudFormation Change Set 実行スクリプト (ユーザー承認あり)
# Usage: ./execute-changeset.sh <stack-name>

set -e

# 引数チェック
if [ $# -lt 1 ]; then
  echo "❌ Usage: $0 <stack-name>"
  echo "   Example: $0 platform-network"
  exit 1
fi

STACK_NAME=$1

# Change Set ID 取得
CHANGESET_ID_FILE=".changeset-id-${STACK_NAME}"
if [ ! -f "$CHANGESET_ID_FILE" ]; then
  echo "❌ No change set found for stack: ${STACK_NAME}"
  echo "   Run create-changeset.sh first."
  exit 1
fi

CHANGESET_NAME=$(cat "$CHANGESET_ID_FILE")

echo "⚠️  Executing Change Set: ${CHANGESET_NAME}"
echo "   Stack Name: ${STACK_NAME}"
echo ""
echo "   This will modify your AWS resources."
echo "   Please review the changes before proceeding."
echo ""

# 変更内容サマリー表示
CHANGES_COUNT=$(aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --query 'length(Changes)' \
  --output text)

ADD_COUNT=$(aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --query 'length(Changes[?ResourceChange.Action==`Add`])' \
  --output text)

MODIFY_COUNT=$(aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --query 'length(Changes[?ResourceChange.Action==`Modify`])' \
  --output text)

REMOVE_COUNT=$(aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --query 'length(Changes[?ResourceChange.Action==`Remove`])' \
  --output text)

echo "📊 Change Summary:"
echo "   Total Changes: ${CHANGES_COUNT}"
echo "   - Add: ${ADD_COUNT} resources"
echo "   - Modify: ${MODIFY_COUNT} resources"
echo "   - Remove: ${REMOVE_COUNT} resources"
echo ""

# Replacement 警告
REPLACEMENT_COUNT=$(aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --query 'length(Changes[?ResourceChange.Replacement==`True`])' \
  --output text)

if [ "$REPLACEMENT_COUNT" != "0" ]; then
  echo "⚠️  WARNING: ${REPLACEMENT_COUNT} resource(s) will be REPLACED"
  echo "   This may cause downtime. Please review carefully."
  echo ""
fi

# ユーザー確認
read -p "Execute change set? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo ""
  echo "❌ Execution cancelled."
  echo "   Change set is still available for review."
  echo "   Run './describe-changeset.sh ${STACK_NAME}' to review again."
  exit 0
fi

echo ""
echo "🚀 Executing Change Set..."

# Change Set 実行
aws cloudformation execute-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}"

echo ""
echo "⏳ Waiting for stack operation to complete..."
echo "   This may take several minutes..."
echo ""

# スタック操作完了待機
# CREATE または UPDATE を検出
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "CREATE_IN_PROGRESS")

if [[ "$STACK_STATUS" == "CREATE"* ]]; then
  # 新規作成
  aws cloudformation wait stack-create-complete --stack-name "${STACK_NAME}"
  echo "✅ Stack created successfully: ${STACK_NAME}"
elif [[ "$STACK_STATUS" == "UPDATE"* ]]; then
  # 更新
  aws cloudformation wait stack-update-complete --stack-name "${STACK_NAME}"
  echo "✅ Stack updated successfully: ${STACK_NAME}"
else
  echo "⚠️  Stack status: ${STACK_STATUS}"
fi

# Change Set ID ファイル削除
rm -f "$CHANGESET_ID_FILE"

echo ""
echo "📌 Deployment completed."
echo "   Stack Name: ${STACK_NAME}"

# スタック出力表示
OUTPUTS=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs' \
  --output table 2>/dev/null || echo "")

if [ -n "$OUTPUTS" ]; then
  echo ""
  echo "📌 Stack Outputs:"
  echo "$OUTPUTS"
fi
