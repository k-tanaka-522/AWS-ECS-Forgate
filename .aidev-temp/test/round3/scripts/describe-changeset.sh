#!/bin/bash
# describe-changeset.sh - CloudFormation Change Set 内容確認スクリプト (dry-run)
# Usage: ./describe-changeset.sh <stack-name>

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

echo "🔍 Describing Change Set: ${CHANGESET_NAME}"
echo ""

# Change Set ステータス取得
CHANGESET_STATUS=$(aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --query 'Status' \
  --output text)

if [ "$CHANGESET_STATUS" != "CREATE_COMPLETE" ]; then
  echo "⚠️  Change Set Status: ${CHANGESET_STATUS}"
  if [ "$CHANGESET_STATUS" == "FAILED" ]; then
    echo "❌ Change Set creation failed."
    echo ""
    aws cloudformation describe-change-set \
      --stack-name "${STACK_NAME}" \
      --change-set-name "${CHANGESET_NAME}" \
      --query 'StatusReason' \
      --output text
    exit 1
  fi
fi

# 変更内容詳細取得
echo "📊 Change Set Details:"
echo ""
aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --query 'Changes[*].[ResourceChange.Action, ResourceChange.LogicalResourceId, ResourceChange.ResourceType, ResourceChange.Replacement]' \
  --output table

echo ""
echo "📌 Change Set Summary:"
echo "   Stack Name: ${STACK_NAME}"
echo "   Change Set Name: ${CHANGESET_NAME}"
echo "   Status: ${CHANGESET_STATUS}"

# 変更統計
CHANGES_COUNT=$(aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --query 'length(Changes)' \
  --output text)

echo "   Total Changes: ${CHANGES_COUNT}"

# Action 別集計
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

echo "   - Add: ${ADD_COUNT}"
echo "   - Modify: ${MODIFY_COUNT}"
echo "   - Remove: ${REMOVE_COUNT}"

# Replacement 警告
REPLACEMENT_COUNT=$(aws cloudformation describe-change-set \
  --stack-name "${STACK_NAME}" \
  --change-set-name "${CHANGESET_NAME}" \
  --query 'length(Changes[?ResourceChange.Replacement==`True`])' \
  --output text)

if [ "$REPLACEMENT_COUNT" != "0" ]; then
  echo ""
  echo "⚠️  WARNING: ${REPLACEMENT_COUNT} resource(s) will be REPLACED (may cause downtime)"
  aws cloudformation describe-change-set \
    --stack-name "${STACK_NAME}" \
    --change-set-name "${CHANGESET_NAME}" \
    --query 'Changes[?ResourceChange.Replacement==`True`].[ResourceChange.LogicalResourceId, ResourceChange.ResourceType]' \
    --output table
fi

echo ""
echo "✅ Review completed."
echo ""
echo "📌 Next steps:"
echo "   Execute changes: ./execute-changeset.sh ${STACK_NAME}"
echo "   Rollback (cancel): ./rollback.sh ${STACK_NAME}"
