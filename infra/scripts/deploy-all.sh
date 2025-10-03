#!/bin/bash
set -e

# ========================================
# CareApp 全スタック一括デプロイスクリプト
# ========================================
# 使用方法: ./deploy-all.sh [--dry-run]
# 説明: 4つのCloudFormationスタックを順番にデプロイします
# - CareApp-POC-SharedNetwork
# - CareApp-POC-AppNetwork
# - CareApp-POC-Database
# - CareApp-POC-AppPlatform

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

# dry-runフラグ
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
  log_warning "Dry-run mode: 変更セットのみ作成します"
fi

# 環境設定
ENVIRONMENT="POC"
REGION="ap-northeast-1"

# スタック名
STACK_SHARED_NETWORK="CareApp-${ENVIRONMENT}-SharedNetwork"
STACK_APP_NETWORK="CareApp-${ENVIRONMENT}-AppNetwork"
STACK_DATABASE="CareApp-${ENVIRONMENT}-Database"
STACK_APP_PLATFORM="CareApp-${ENVIRONMENT}-AppPlatform"

# ========================================
# スタック作成/更新関数
# ========================================
deploy_stack() {
  local stack_name=$1
  local template_file=$2
  local parameters_file=$3

  log_info "========================================="
  log_info "スタック: ${stack_name}"
  log_info "========================================="

  # スタック存在確認
  if aws cloudformation describe-stacks --stack-name "${stack_name}" --region "${REGION}" &>/dev/null; then
    log_info "${stack_name} は既に存在します。更新します..."
    operation="update"
  else
    log_info "${stack_name} は存在しません。新規作成します..."
    operation="create"
  fi

  if [ "$DRY_RUN" = true ]; then
    # Dry-run: 変更セット作成のみ
    change_set_name="dry-run-$(date +%Y%m%d-%H%M%S)"
    log_info "変更セット作成中: ${change_set_name}"

    aws cloudformation create-change-set \
      --stack-name "${stack_name}" \
      --change-set-name "${change_set_name}" \
      --template-body "file://${template_file}" \
      --parameters "file://${parameters_file}" \
      --capabilities CAPABILITY_NAMED_IAM \
      --region "${REGION}"

    log_info "変更セットを作成しました。以下のコマンドで詳細を確認してください:"
    echo "  aws cloudformation describe-change-set --stack-name ${stack_name} --change-set-name ${change_set_name} --region ${REGION}"
    echo ""
  else
    # 本番実行
    if [ "$operation" = "create" ]; then
      log_info "スタック作成中..."
      aws cloudformation create-stack \
        --stack-name "${stack_name}" \
        --template-body "file://${template_file}" \
        --parameters "file://${parameters_file}" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "${REGION}"

      log_info "スタック作成完了を待機中..."
      aws cloudformation wait stack-create-complete \
        --stack-name "${stack_name}" \
        --region "${REGION}"

      log_info "✅ ${stack_name} の作成が完了しました"
    else
      log_info "スタック更新中..."
      aws cloudformation update-stack \
        --stack-name "${stack_name}" \
        --template-body "file://${template_file}" \
        --parameters "file://${parameters_file}" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "${REGION}" || {
          # "No updates are to be performed" エラーは無視
          if [[ $? -eq 254 ]]; then
            log_warning "変更はありません。スキップします。"
          else
            log_error "スタック更新に失敗しました"
            exit 1
          fi
        }

      if [[ $? -ne 254 ]]; then
        log_info "スタック更新完了を待機中..."
        aws cloudformation wait stack-update-complete \
          --stack-name "${stack_name}" \
          --region "${REGION}"

        log_info "✅ ${stack_name} の更新が完了しました"
      fi
    fi
  fi

  echo ""
}

# ========================================
# メイン処理
# ========================================
log_info "CareApp インフラデプロイ開始"
log_info "環境: ${ENVIRONMENT}"
log_info "リージョン: ${REGION}"
echo ""

# 1. 共有系ネットワークスタック
deploy_stack \
  "${STACK_SHARED_NETWORK}" \
  "../shared/network.yaml" \
  "../shared/parameters-poc.json"

# 2. アプリ系ネットワークスタック
deploy_stack \
  "${STACK_APP_NETWORK}" \
  "../app/network.yaml" \
  "../app/parameters-poc.json"

# 3. データベーススタック
deploy_stack \
  "${STACK_DATABASE}" \
  "../app/database.yaml" \
  "../app/parameters-poc.json"

# 4. アプリ基盤スタック
deploy_stack \
  "${STACK_APP_PLATFORM}" \
  "../app/platform.yaml" \
  "../app/parameters-poc.json"

# ========================================
# 完了メッセージ
# ========================================
echo ""
log_info "========================================="
log_info "✅ すべてのスタックのデプロイが完了しました"
log_info "========================================="
echo ""

if [ "$DRY_RUN" = false ]; then
  log_info "デプロイされたスタック:"
  echo "  - ${STACK_SHARED_NETWORK}"
  echo "  - ${STACK_APP_NETWORK}"
  echo "  - ${STACK_DATABASE}"
  echo "  - ${STACK_APP_PLATFORM}"
  echo ""

  log_info "次のステップ:"
  echo "  1. ALB DNS名を確認:"
  echo "     aws cloudformation describe-stacks --stack-name ${STACK_APP_NETWORK} --query 'Stacks[0].Outputs[?OutputKey==\`ALBDNSName\`].OutputValue' --output text --region ${REGION}"
  echo ""
  echo "  2. RDS Endpointを確認:"
  echo "     aws cloudformation describe-stacks --stack-name ${STACK_DATABASE} --query 'Stacks[0].Outputs[?OutputKey==\`DBEndpoint\`].OutputValue' --output text --region ${REGION}"
  echo ""
  echo "  3. Cognito User Pool IDを確認:"
  echo "     aws cloudformation describe-stacks --stack-name ${STACK_APP_PLATFORM} --query 'Stacks[0].Outputs[?OutputKey==\`CognitoUserPoolId\`].OutputValue' --output text --region ${REGION}"
fi
