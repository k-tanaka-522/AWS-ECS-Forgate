#!/bin/bash
set -e

# ========================================
# CareApp 全スタック削除スクリプト
# ========================================
# 使用方法: ./delete-all.sh
# 警告: すべてのリソースが削除されます！

# 色付きログ関数
log_info() {
  echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_error() {
  echo -e "\033[0;31m[ERROR]\033[0m $1"
}

log_warning() {
  echo -e "\033[0;33m[WARNING]\033[0m $1"
}

# 環境設定
ENVIRONMENT="POC"
REGION="ap-northeast-1"

# スタック名
STACK_SHARED_NETWORK="CareApp-${ENVIRONMENT}-SharedNetwork"
STACK_APP_NETWORK="CareApp-${ENVIRONMENT}-AppNetwork"
STACK_DATABASE="CareApp-${ENVIRONMENT}-Database"
STACK_APP_PLATFORM="CareApp-${ENVIRONMENT}-AppPlatform"

# ========================================
# 確認プロンプト
# ========================================
log_warning "========================================="
log_warning "⚠️  警告: すべてのスタックを削除します"
log_warning "========================================="
echo ""
echo "削除対象:"
echo "  - ${STACK_APP_PLATFORM}"
echo "  - ${STACK_DATABASE}"
echo "  - ${STACK_APP_NETWORK}"
echo "  - ${STACK_SHARED_NETWORK}"
echo ""
log_warning "この操作は取り消せません！"
echo ""
read -p "本当に削除しますか？ (yes/no): " confirmation

if [ "$confirmation" != "yes" ]; then
  log_info "削除をキャンセルしました"
  exit 0
fi

# ========================================
# スタック削除関数
# ========================================
delete_stack() {
  local stack_name=$1

  log_info "========================================="
  log_info "スタック削除: ${stack_name}"
  log_info "========================================="

  # スタック存在確認
  if ! aws cloudformation describe-stacks --stack-name "${stack_name}" --region "${REGION}" &>/dev/null; then
    log_warning "${stack_name} は存在しません。スキップします。"
    echo ""
    return
  fi

  log_info "${stack_name} を削除中..."
  aws cloudformation delete-stack \
    --stack-name "${stack_name}" \
    --region "${REGION}"

  log_info "スタック削除完了を待機中..."
  aws cloudformation wait stack-delete-complete \
    --stack-name "${stack_name}" \
    --region "${REGION}"

  log_info "✅ ${stack_name} の削除が完了しました"
  echo ""
}

# ========================================
# メイン処理（依存関係の逆順で削除）
# ========================================
log_info "CareApp インフラ削除開始"
log_info "環境: ${ENVIRONMENT}"
log_info "リージョン: ${REGION}"
echo ""

# 4. アプリ基盤スタック
delete_stack "${STACK_APP_PLATFORM}"

# 3. データベーススタック
delete_stack "${STACK_DATABASE}"

# 2. アプリ系ネットワークスタック
delete_stack "${STACK_APP_NETWORK}"

# 1. 共有系ネットワークスタック
delete_stack "${STACK_SHARED_NETWORK}"

# ========================================
# 完了メッセージ
# ========================================
log_info "========================================="
log_info "✅ すべてのスタックの削除が完了しました"
log_info "========================================="
