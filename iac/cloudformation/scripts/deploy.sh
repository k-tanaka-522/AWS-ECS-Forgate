#!/bin/bash
# deploy.sh
# ECSForgateプロジェクト用のCloudFormationスタックをデプロイするスクリプト

# 使用方法
if [ "$#" -lt 2 ]; then
  echo "使用方法: $0 <環境名> <アクション>"
  echo "環境名: dev, stg, prd"
  echo "アクション: create, update, delete, validate"
  exit 1
fi

# 引数の設定
ENVIRONMENT=$1
ACTION=$2
REGION="ap-northeast-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
S3_BUCKET="ecsforgate-cfn-templates-${ACCOUNT_ID}"
S3_PREFIX="${ENVIRONMENT}"
STACK_NAME="ecsforgate-${ENVIRONMENT}"

# 環境変数の確認
if [ -z "${ACCOUNT_ID}" ]; then
  echo "エラー: AWS アカウントIDを取得できませんでした。AWS CLIの設定を確認してください。"
  exit 1
fi

# S3バケットの確認・作成
if ! aws s3 ls "s3://${S3_BUCKET}" &> /dev/null; then
  echo "S3バケット ${S3_BUCKET} を作成します..."
  aws s3 mb "s3://${S3_BUCKET}" --region ${REGION}
  
  # バケットバージョニングを有効化（IaC管理に重要）
  echo "S3バケットのバージョニングを有効化しています..."
  aws s3api put-bucket-versioning \
    --bucket ${S3_BUCKET} \
    --versioning-configuration Status=Enabled
fi

# テンプレートの事前検証
if [ "${ACTION}" = "validate" ] || [ "${ACTION}" = "create" ] || [ "${ACTION}" = "update" ]; then
  echo "CloudFormationテンプレートを検証しています..."
  aws cloudformation validate-template \
    --template-body file://iac/cloudformation/templates/environment-main.yaml \
    --region ${REGION}
  
  if [ $? -ne 0 ]; then
    echo "テンプレート検証に失敗しました。エラーを修正してから再実行してください。"
    exit 1
  fi
  
  echo "メインテンプレートの検証が完了しました。"
  
  if [ "${ACTION}" = "validate" ]; then
    exit 0
  fi
fi

# テンプレートのアップロード
echo "ネストスタックテンプレートをS3バケットにアップロードしています..."

# ネストスタックテンプレートをアップロード
for template in iac/cloudformation/templates/nested/*.yaml; do
  if [ -f "${template}" ]; then
    template_name=$(basename "${template}")
    echo "テンプレート ${template_name} をアップロードしています..."
    aws s3 cp "${template}" "s3://${S3_BUCKET}/cloudformation/templates/nested/${template_name}" --region ${REGION}
  fi
done

# メインテンプレートをアップロード
echo "メインテンプレートをアップロードしています..."
aws s3 cp "iac/cloudformation/templates/environment-main.yaml" "s3://${S3_BUCKET}/cloudformation/templates/environment-main.yaml" --region ${REGION}

# パラメータファイルの準備
PARAMETERS_FILE="iac/cloudformation/config/${ENVIRONMENT}/parameters.json"
if [ ! -f "${PARAMETERS_FILE}" ]; then
  echo "エラー: パラメータファイル ${PARAMETERS_FILE} が見つかりません。"
  exit 1
fi

# AWSアカウントIDの置換
sed -i.bak "s/\${AWS_ACCOUNT_ID}/${ACCOUNT_ID}/g" "${PARAMETERS_FILE}"

# スタックのデプロイ
echo "${ENVIRONMENT}環境のスタックを${ACTION}しています..."
case ${ACTION} in
  create)
    aws cloudformation create-stack \
      --stack-name ${STACK_NAME} \
      --template-url "https://${S3_BUCKET}.s3.${REGION}.amazonaws.com/cloudformation/templates/environment-main.yaml" \
      --parameters file://${PARAMETERS_FILE} \
      --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
      --region ${REGION} \
      --tags Key=Environment,Value=${ENVIRONMENT} Key=Project,Value=ECSForgate Key=ManagedBy,Value=CloudFormation
    
    echo "スタック作成を開始しました。完了までお待ちください..."
    aws cloudformation wait stack-create-complete --stack-name ${STACK_NAME} --region ${REGION}
    create_status=$?
    
    if [ ${create_status} -eq 0 ]; then
      echo "スタック作成が正常に完了しました。"
    else
      echo "スタック作成が失敗しました。CloudFormationコンソールでエラーを確認してください。"
      exit 1
    fi
    ;;
  
  update)
    # 変更セットの作成（実行前にプレビュー用）
    CHANGE_SET_NAME="${STACK_NAME}-change-set-$(date +%Y%m%d%H%M%S)"
    
    echo "変更セットを作成しています: ${CHANGE_SET_NAME}"
    aws cloudformation create-change-set \
      --stack-name ${STACK_NAME} \
      --change-set-name ${CHANGE_SET_NAME} \
      --template-url "https://${S3_BUCKET}.s3.${REGION}.amazonaws.com/cloudformation/templates/environment-main.yaml" \
      --parameters file://${PARAMETERS_FILE} \
      --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
      --region ${REGION}
    
    # 変更セットが作成されるまで待機
    echo "変更セットの作成を待機しています..."
    aws cloudformation wait change-set-create-complete \
      --stack-name ${STACK_NAME} \
      --change-set-name ${CHANGE_SET_NAME} \
      --region ${REGION}
    
    # 変更セットの詳細を表示
    echo "変更セットの内容:"
    aws cloudformation describe-change-set \
      --stack-name ${STACK_NAME} \
      --change-set-name ${CHANGE_SET_NAME} \
      --region ${REGION}
    
    # ユーザーに確認
    read -p "変更内容を適用しますか？ (y/n): " CONFIRM
    if [[ ${CONFIRM} == "y" ]]; then
      echo "変更セットを実行しています..."
      aws cloudformation execute-change-set \
        --stack-name ${STACK_NAME} \
        --change-set-name ${CHANGE_SET_NAME} \
        --region ${REGION}
      
      echo "スタック更新を開始しました。完了までお待ちください..."
      aws cloudformation wait stack-update-complete --stack-name ${STACK_NAME} --region ${REGION}
      update_status=$?
      
      if [ ${update_status} -eq 0 ]; then
        echo "スタック更新が正常に完了しました。"
      else
        echo "スタック更新が失敗しました。CloudFormationコンソールでエラーを確認してください。"
        exit 1
      fi
    else
      echo "スタック更新を中止しました。"
      
      # 変更セットの削除
      echo "変更セットを削除しています..."
      aws cloudformation delete-change-set \
        --stack-name ${STACK_NAME} \
        --change-set-name ${CHANGE_SET_NAME} \
        --region ${REGION}
    fi
    ;;
  
  delete)
    echo "警告: ${ENVIRONMENT}環境のスタックを削除します。この操作は取り消せません。"
    if [ "${ENVIRONMENT}" = "prd" ]; then
      echo "本番環境の削除には特別な確認が必要です。"
      read -p "本当に本番環境を削除しますか？ 'confirm-production-delete'と入力してください: " CONFIRM_PRD
      if [ "${CONFIRM_PRD}" != "confirm-production-delete" ]; then
        echo "本番環境のスタック削除を中止しました。"
        exit 0
      fi
    else
      read -p "削除を続行しますか？ (y/n): " CONFIRM
      if [ "${CONFIRM}" != "y" ]; then
        echo "スタック削除を中止しました。"
        exit 0
      fi
    fi
    
    echo "スタックを削除しています..."
    aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${REGION}
    
    echo "スタック削除を開始しました。完了までお待ちください..."
    aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME} --region ${REGION}
    delete_status=$?
    
    if [ ${delete_status} -eq 0 ]; then
      echo "スタック削除が正常に完了しました。"
    else
      echo "スタック削除中にエラーが発生しました。CloudFormationコンソールでエラーを確認してください。"
      exit 1
    fi
    ;;
  
  *)
    echo "不明なアクション: ${ACTION}"
    echo "使用方法: $0 <環境名> <アクション>"
    echo "アクション: create, update, delete, validate"
    exit 1
    ;;
esac

# パラメータファイルを元に戻す
if [ -f "${PARAMETERS_FILE}.bak" ]; then
  mv "${PARAMETERS_FILE}.bak" "${PARAMETERS_FILE}"
fi

echo "操作が完了しました。"