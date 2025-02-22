#!/bin/bash

# 環境変数の設定
ENVIRONMENT=${1:-dev}  # デフォルトはdev環境
REGION="ap-northeast-1"
PROFILE="default"  # AWS CLIのプロファイル名を必要に応じて変更

# 状態管理用のS3バケット名とDynamoDBテーブル名
STATE_BUCKET="tfstate-escforgate-${ENVIRONMENT}"
LOCK_TABLE="terraform-state-lock-${ENVIRONMENT}"

# 使用方法の表示
usage() {
    echo "Usage: $0 [environment] [command]"
    echo "Environment: dev (default) | stg | prd"
    echo "Commands: init | plan | apply | destroy"
    exit 1
}

# コマンドライン引数のチェック
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
fi

# 環境の検証
if [[ ! "$ENVIRONMENT" =~ ^(dev|stg|prd)$ ]]; then
    echo "Invalid environment. Must be one of: dev, stg, prd"
    exit 1
fi

# コマンドの設定
COMMAND=${2:-apply}  # デフォルトはapply

# 状態管理用のS3バケットとDynamoDBテーブルの作成
setup_remote_state() {
    # S3バケットの作成
    if ! aws s3 ls "s3://${STATE_BUCKET}" 2>&1 > /dev/null; then
        echo "Creating S3 bucket for Terraform state..."
        aws s3api create-bucket \
            --bucket ${STATE_BUCKET} \
            --region ${REGION} \
            --create-bucket-configuration LocationConstraint=${REGION} \
            --profile ${PROFILE}
        
        # バージョニングの有効化
        aws s3api put-bucket-versioning \
            --bucket ${STATE_BUCKET} \
            --versioning-configuration Status=Enabled \
            --profile ${PROFILE}
        
        # 暗号化の有効化
        aws s3api put-bucket-encryption \
            --bucket ${STATE_BUCKET} \
            --server-side-encryption-configuration '{
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }
                ]
            }' \
            --profile ${PROFILE}
    fi

    # DynamoDBテーブルの作成
    if ! aws dynamodb describe-table --table-name ${LOCK_TABLE} --region ${REGION} --profile ${PROFILE} 2>&1 > /dev/null; then
        echo "Creating DynamoDB table for state locking..."
        aws dynamodb create-table \
            --table-name ${LOCK_TABLE} \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
            --region ${REGION} \
            --profile ${PROFILE}
    fi
}

# 環境変数の設定
export TF_VAR_environment=${ENVIRONMENT}
export TF_VAR_aws_region=${REGION}

# バックエンド設定の作成
create_backend_config() {
    cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "${STATE_BUCKET}"
    key            = "${ENVIRONMENT}/terraform.tfstate"
    region         = "${REGION}"
    dynamodb_table = "${LOCK_TABLE}"
    encrypt        = true
  }
}
EOF
}

# メイン処理
echo "Setting up remote state..."
setup_remote_state

echo "Creating backend configuration..."
create_backend_config

case ${COMMAND} in
    init)
        echo "Initializing Terraform..."
        terraform init
        ;;
    plan)
        echo "Planning Terraform changes..."
        terraform plan -var-file="environments/${ENVIRONMENT}.tfvars"
        ;;
    apply)
        echo "Applying Terraform changes..."
        terraform apply -var-file="environments/${ENVIRONMENT}.tfvars" -auto-approve
        ;;
    destroy)
        echo "Destroying Terraform resources..."
        terraform destroy -var-file="environments/${ENVIRONMENT}.tfvars" -auto-approve
        ;;
    *)
        echo "Invalid command. Must be one of: init, plan, apply, destroy"
        exit 1
        ;;
esac
