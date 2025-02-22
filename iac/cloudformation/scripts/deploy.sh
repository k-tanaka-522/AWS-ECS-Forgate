#!/bin/bash

# エラーハンドリング
set -e

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ログ出力関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 環境変数チェック
if [ -z "$ENV" ]; then
    log_error "ENV環境変数が設定されていません"
    log_info "使用例: ENV=dev ./deploy.sh"
    exit 1
fi

# パラメータファイルの存在チェック
PARAMS_FILE="../env/${ENV}/parameters-${ENV}.json"
if [ ! -f "$PARAMS_FILE" ]; then
    log_error "パラメータファイルが見つかりません: $PARAMS_FILE"
    exit 1
fi

# スタックの存在確認
check_stack_exists() {
    local stack_name=$1
    if aws cloudformation describe-stacks --stack-name $stack_name >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# スタックのデプロイ
deploy_stack() {
    local stack_name="${ENV}-escforgate-$1"
    local template_file="../modules/$1/$1.yaml"
    local operation="update"

    log_info "スタック ${stack_name} のデプロイを開始"

    if ! check_stack_exists $stack_name; then
        operation="create"
        log_info "新規スタックを作成します"
    else
        log_info "既存スタックを更新します"
    fi

    if [ "$operation" = "create" ]; then
        aws cloudformation create-stack \
            --stack-name $stack_name \
            --template-body file://$template_file \
            --parameters file://$PARAMS_FILE \
            --capabilities CAPABILITY_NAMED_IAM

        log_info "スタックの作成完了を待機中..."
        aws cloudformation wait stack-create-complete --stack-name $stack_name
    else
        if aws cloudformation update-stack \
            --stack-name $stack_name \
            --template-body file://$template_file \
            --parameters file://$PARAMS_FILE \
            --capabilities CAPABILITY_NAMED_IAM 2>/dev/null; then
            
            log_info "スタックの更新完了を待機中..."
            aws cloudformation wait stack-update-complete --stack-name $stack_name
        else
            log_warn "スタックに変更はありません"
        fi
    fi

    log_info "スタック ${stack_name} のデプロイが完了"
}

# メイン処理
main() {
    log_info "${ENV}環境へのデプロイを開始"

    # ネットワークスタック
    log_info "ネットワークスタックのデプロイ"
    deploy_stack "network"

    # データベーススタック
    log_info "データベーススタックのデプロイ"
    deploy_stack "database"

    # 認証スタック
    log_info "認証スタックのデプロイ"
    deploy_stack "auth"

    # コンピュートスタック
    log_info "コンピュートスタックのデプロイ"
    deploy_stack "compute"

    log_info "全てのスタックのデプロイが完了"
}

# スクリプトの実行
main
