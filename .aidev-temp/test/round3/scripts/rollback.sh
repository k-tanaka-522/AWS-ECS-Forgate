#!/bin/bash
# rollback.sh - CloudFormation Change Set ロールバックスクリプト
# Usage: ./rollback.sh <stack-name>

set -e

# 引数チェック
if [ $# -lt 1 ]; then
  echo "❌ Usage: $0 <stack-name>"
  echo "   Example: $0 platform-network"
  exit 1
fi

STACK_NAME=$1

echo "🔄 Rollback: ${STACK_NAME}"
echo ""

# スタック状態取得
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "DOES_NOT_EXIST")

echo "📊 Current Stack Status: ${STACK_STATUS}"
echo ""

# パターン1: Change Set 実行前 (Change Set 削除)
CHANGESET_ID_FILE=".changeset-id-${STACK_NAME}"
if [ -f "$CHANGESET_ID_FILE" ]; then
  CHANGESET_NAME=$(cat "$CHANGESET_ID_FILE")
  echo "📋 Change Set found: ${CHANGESET_NAME}"
  echo "   Status: Not executed (still in pending state)"
  echo ""

  read -p "Delete change set? (yes/no): " CONFIRM

  if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Rollback cancelled."
    exit 0
  fi

  echo "🗑️  Deleting Change Set..."
  aws cloudformation delete-change-set \
    --stack-name "${STACK_NAME}" \
    --change-set-name "${CHANGESET_NAME}"

  # Change Set ID ファイル削除
  rm -f "$CHANGESET_ID_FILE"

  echo "✅ Change Set deleted: ${CHANGESET_NAME}"
  echo "   Stack remains unchanged."
  exit 0
fi

# パターン2: スタックが存在しない
if [ "$STACK_STATUS" == "DOES_NOT_EXIST" ]; then
  echo "ℹ️  Stack does not exist: ${STACK_NAME}"
  echo "   No rollback needed."
  exit 0
fi

# パターン3: スタック更新中 → cancel-update-stack
if [[ "$STACK_STATUS" == *"IN_PROGRESS"* ]]; then
  echo "⚠️  Stack update in progress."
  echo "   Current Status: ${STACK_STATUS}"
  echo ""

  read -p "Cancel stack update? (yes/no): " CONFIRM

  if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Rollback cancelled."
    exit 0
  fi

  echo "🔄 Cancelling stack update..."
  aws cloudformation cancel-update-stack --stack-name "${STACK_NAME}"

  echo "⏳ Waiting for rollback to complete..."
  aws cloudformation wait stack-update-rollback-complete --stack-name "${STACK_NAME}" || {
    # UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS の場合もある
    echo "⚠️  Rollback may still be in progress. Check AWS Console."
  }

  echo "✅ Stack update cancelled and rolled back."
  exit 0
fi

# パターン4: スタック更新失敗 → 既にロールバック済み
if [[ "$STACK_STATUS" == *"ROLLBACK"* || "$STACK_STATUS" == *"FAILED"* ]]; then
  echo "ℹ️  Stack is already in rollback or failed state: ${STACK_STATUS}"
  echo "   No further rollback needed."
  echo ""
  echo "📌 Options:"
  echo "   - Delete stack: aws cloudformation delete-stack --stack-name ${STACK_NAME}"
  echo "   - Review error: aws cloudformation describe-stack-events --stack-name ${STACK_NAME}"
  exit 0
fi

# パターン5: スタックは安定状態
if [[ "$STACK_STATUS" == "CREATE_COMPLETE" || "$STACK_STATUS" == "UPDATE_COMPLETE" ]]; then
  echo "ℹ️  Stack is in stable state: ${STACK_STATUS}"
  echo "   No rollback needed."
  echo ""
  echo "📌 Options:"
  echo "   - Delete stack: aws cloudformation delete-stack --stack-name ${STACK_NAME}"
  echo "   - Create new change set: ./create-changeset.sh ${STACK_NAME}"
  exit 0
fi

# その他の状態
echo "⚠️  Unknown stack status: ${STACK_STATUS}"
echo "   Please check AWS Console for details."
exit 1
