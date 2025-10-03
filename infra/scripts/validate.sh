#!/bin/bash
set -e

# ========================================
# CloudFormation テンプレート検証スクリプト
# ========================================
# 使用方法: ./validate.sh

# 色付きログ関数
log_info() {
  echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_error() {
  echo -e "\033[0;31m[ERROR]\033[0m $1"
}

log_success() {
  echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

# リージョン設定
REGION="ap-northeast-1"

# ========================================
# 検証関数
# ========================================
validate_template() {
  local template_file=$1
  local template_name=$(basename "$template_file")

  log_info "検証中: ${template_name}"

  if aws cloudformation validate-template \
    --template-body "file://${template_file}" \
    --region "${REGION}" &>/dev/null; then
    log_success "✅ ${template_name} は有効です"
  else
    log_error "❌ ${template_name} に問題があります"
    aws cloudformation validate-template \
      --template-body "file://${template_file}" \
      --region "${REGION}"
    exit 1
  fi
}

# ========================================
# メイン処理
# ========================================
log_info "CloudFormation テンプレート検証開始"
echo ""

# Shared Network
validate_template "../shared/network.yaml"

# App Network
validate_template "../app/network.yaml"

# Database
validate_template "../app/database.yaml"

# App Platform
validate_template "../app/platform.yaml"

echo ""
log_success "========================================="
log_success "✅ すべてのテンプレートが有効です"
log_success "========================================="
