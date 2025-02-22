#!/bin/bash

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
    log_info "使用例: ENV=dev ./cleanup.sh"
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

# スタックの削除
delete_stack() {
    local stack_name="${ENV}-escforgate-$1"
    log_info "スタック ${stack_name} の削除を開始"
    
    if check_stack_exists $stack_name; then
        aws cloudformation delete-stack --stack-name $stack_name
        log_info "スタックの削除完了を待機中..."
        aws cloudformation wait stack-delete-complete --stack-name $stack_name
        log_info "スタック ${stack_name} の削除が完了"
    else
        log_warn "スタック ${stack_name} は存在しません"
    fi
}

# シークレットの削除
delete_secrets() {
    local secrets=(
        "db-password"
        "db-host"
        "cognito-pool-id"
        "cognito-client-id"
        "aws-access-key"
        "aws-secret-key"
    )

    for secret in "${secrets[@]}"; do
        local secret_id="${ENV}/wordpress/$secret"
        log_info "シークレット ${secret_id} の削除を開始"
        
        if aws secretsmanager describe-secret --secret-id $secret_id >/dev/null 2>&1; then
            aws secretsmanager delete-secret \
                --secret-id $secret_id \
                --force-delete-without-recovery
            log_info "シークレット ${secret_id} の削除が完了"
        else
            log_warn "シークレット ${secret_id} は存在しません"
        fi
    done
}

# メイン処理
main() {
    log_info "${ENV}環境のクリーンアップを開始"

    # 依存関係を考慮した削除順序
    log_info "コンピュートスタックの削除"
    delete_stack "compute"

    log_info "認証スタックの削除"
    delete_stack "auth"

    log_info "データベーススタックの削除"
    delete_stack "database"

    log_info "ネットワークスタックの削除"
    delete_stack "network"

    log_info "シークレットの削除"
    delete_secrets

    log_info "クリーンアップが完了"
}

# スクリプトの実行
main
