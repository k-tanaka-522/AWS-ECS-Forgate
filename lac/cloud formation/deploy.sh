#!/bin/bash

# 環境変数の設定
ENVIRONMENT="dev"
STACK_PREFIX="escforgate"
REGION="ap-northeast-1"
PROFILE="default"  # AWS CLIのプロファイル名を必要に応じて変更

# パラメータファイル
PARAMS_FILE="parameters-${ENVIRONMENT}.json"

# スタック名の定義
NETWORK_STACK="${STACK_PREFIX}-${ENVIRONMENT}-network"
DATABASE_STACK="${STACK_PREFIX}-${ENVIRONMENT}-database"
AUTH_STACK="${STACK_PREFIX}-${ENVIRONMENT}-auth"
COMPUTE_STACK="${STACK_PREFIX}-${ENVIRONMENT}-compute"

# 関数: スタックの状態を確認
check_stack() {
    aws cloudformation describe-stacks --stack-name $1 --region $REGION --profile $PROFILE 2>&1 > /dev/null
    return $?
}

# 関数: スタックの作成または更新
deploy_stack() {
    local stack_name=$1
    local template_file=$2
    local params_file=$3
    local deps=$4

    echo "Deploying stack: $stack_name"
    
    if check_stack $stack_name; then
        echo "Updating existing stack: $stack_name"
        if [ -z "$deps" ]; then
            aws cloudformation update-stack \
                --stack-name $stack_name \
                --template-body file://$template_file \
                --parameters file://$params_file \
                --capabilities CAPABILITY_NAMED_IAM \
                --region $REGION \
                --profile $PROFILE
        else
            aws cloudformation update-stack \
                --stack-name $stack_name \
                --template-body file://$template_file \
                --parameters file://$params_file \
                --capabilities CAPABILITY_NAMED_IAM \
                --region $REGION \
                --profile $PROFILE
        fi
    else
        echo "Creating new stack: $stack_name"
        if [ -z "$deps" ]; then
            aws cloudformation create-stack \
                --stack-name $stack_name \
                --template-body file://$template_file \
                --parameters file://$params_file \
                --capabilities CAPABILITY_NAMED_IAM \
                --region $REGION \
                --profile $PROFILE
        else
            aws cloudformation create-stack \
                --stack-name $stack_name \
                --template-body file://$template_file \
                --parameters file://$params_file \
                --capabilities CAPABILITY_NAMED_IAM \
                --region $REGION \
                --profile $PROFILE
        fi
    fi

    echo "Waiting for stack operation to complete..."
    aws cloudformation wait stack-create-complete --stack-name $stack_name --region $REGION --profile $PROFILE 2>/dev/null || \
    aws cloudformation wait stack-update-complete --stack-name $stack_name --region $REGION --profile $PROFILE
    
    if [ $? -eq 0 ]; then
        echo "Stack operation completed successfully"
    else
        echo "Stack operation failed"
        exit 1
    fi
}

# ネットワークスタックのデプロイ
echo "Deploying Network Stack..."
deploy_stack $NETWORK_STACK "network.yaml" $PARAMS_FILE

# データベーススタックのデプロイ
echo "Deploying Database Stack..."
deploy_stack $DATABASE_STACK "database.yaml" $PARAMS_FILE

# 認証スタックのデプロイ
echo "Deploying Auth Stack..."
deploy_stack $AUTH_STACK "auth.yaml" $PARAMS_FILE

# コンピュートスタックのデプロイ
echo "Deploying Compute Stack..."
deploy_stack $COMPUTE_STACK "compute.yaml" $PARAMS_FILE

echo "All stacks deployed successfully!"
