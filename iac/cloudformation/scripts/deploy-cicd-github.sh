#!/bin/bash
# ==============================================================================
# ECSForgate CI/CD パイプライン構築スクリプト
# 
# 目的：GitHub連携のCI/CDパイプラインを構築するためのCloudFormationスタックをデプロイ
# 使用方法：
#   ./deploy-cicd-github.sh --github-owner <owner> --github-repo <repo> --github-branch <branch> --environment <env>
# オプション:
#   --github-owner  : GitHubアカウント名（必須）
#   --github-repo   : GitHubリポジトリ名（必須）
#   --github-branch : 使用するブランチ名（必須）
#   --environment   : 環境名 [dev|stg|prd] （必須）
#   --region        : AWSリージョン（省略可、デフォルト: ap-northeast-1）
#   --help          : ヘルプメッセージを表示
# ==============================================================================
set -e

# デフォルト値の設定
AWS_REGION="ap-northeast-1"
NOTIFICATION_EMAIL="example@example.com"

# ヘルプメッセージの表示
function show_help {
  echo "使用方法: $0 --github-owner <owner> --github-repo <repo> --github-branch <branch> --environment <env> [--region <region>]"
  echo ""
  echo "オプション:"
  echo "  --github-owner  : GitHubアカウント名（必須）"
  echo "  --github-repo   : GitHubリポジトリ名（必須）"
  echo "  --github-branch : 使用するブランチ名（必須）"
  echo "  --environment   : 環境名 [dev|stg|prd] （必須）"
  echo "  --region        : AWSリージョン（省略可、デフォルト: ap-northeast-1）"
  echo "  --help          : このヘルプメッセージを表示"
  echo ""
  echo "例:"
  echo "  $0 --github-owner k-tanaka-522 --github-repo AWS-ECS-Forgate --github-branch develop --environment dev"
  exit 1
}

# 引数の解析
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --github-owner)
      GITHUB_OWNER="$2"
      shift 2
      ;;
    --github-repo)
      GITHUB_REPO="$2"
      shift 2
      ;;
    --github-branch)
      GITHUB_BRANCH="$2"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --region)
      AWS_REGION="$2"
      shift 2
      ;;
    --help)
      show_help
      ;;
    *)
      echo "エラー: 不明なオプション: $1"
      show_help
      ;;
  esac
done

# 必須パラメータの確認
if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ] || [ -z "$GITHUB_BRANCH" ] || [ -z "$ENVIRONMENT" ]; then
  echo "エラー: 必須パラメータが指定されていません。"
  show_help
fi

# 環境の検証
if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "stg" ] && [ "$ENVIRONMENT" != "prd" ]; then
  echo "エラー: 環境は dev, stg, prd のいずれかを指定してください。"
  exit 1
fi

# スタック名とテンプレートファイルのパスを設定
STACK_NAME="ecsforgate-cicd-${ENVIRONMENT}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEMPLATE_FILE="${PROJECT_ROOT}/iac/cloudformation/templates/cicd-github.yaml"

# テンプレートファイルの存在確認
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "エラー: テンプレートファイル $TEMPLATE_FILE が見つかりません。"
  exit 1
fi

# AWSアカウントIDの取得
echo "AWSアカウント情報を取得しています..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
  echo "エラー: AWSアカウントIDの取得に失敗しました。認証情報を確認してください。"
  exit 1
fi

# アーティファクトバケット名の設定
TIMESTAMP=$(date +%Y%m%d%H%M%S)
ARTIFACT_BUCKET_NAME="ecsforgate-${ENVIRONMENT}-artifacts-${AWS_ACCOUNT_ID}-${TIMESTAMP}"

# GitHub Tokenの存在確認とSecrets Managerからの取得
echo "GitHub Token の存在をSecrets Managerで確認しています..."
TOKEN_EXISTS=$(aws secretsmanager describe-secret --secret-id github/token 2>/dev/null && echo "yes" || echo "no")

if [ "$TOKEN_EXISTS" = "yes" ]; then
  echo "GitHub Token がSecrets Managerに存在します。この値を使用します。"
  # デプロイ時にSecrets Managerから取得するよう設計変更（トークンの値は直接使用しない）
  USE_SECRET_MANAGER=true
else
  echo "警告: GitHub Token がSecrets Managerに見つかりません。"
  echo "先に「06_Secrets_Manager_シークレット_設定手順.md」と「07_GitHub_リポジトリ_連携設定手順.md」を実行してください。"
  exit 1
fi

# デプロイする情報の表示
echo "========================================="
echo "CI/CDパイプラインデプロイ情報"
echo "========================================="
echo "環境                : $ENVIRONMENT"
echo "スタック名          : $STACK_NAME"
echo "リージョン          : $AWS_REGION"
echo "GitHub所有者        : $GITHUB_OWNER"
echo "GitHubリポジトリ    : $GITHUB_REPO"
echo "GitHubブランチ      : $GITHUB_BRANCH"
echo "アーティファクトバケット : $ARTIFACT_BUCKET_NAME"
echo "テンプレートファイル : $TEMPLATE_FILE"
echo "通知メールアドレス   : $NOTIFICATION_EMAIL"
echo "========================================="
echo ""

# 確認
read -p "デプロイを続行しますか？ (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "デプロイをキャンセルしました。"
  exit 0
fi

# テンプレートの検証
echo "CloudFormationテンプレートを検証しています..."
aws cloudformation validate-template \
  --template-body file://$TEMPLATE_FILE \
  --region $AWS_REGION

if [ $? -ne 0 ]; then
  echo "エラー: テンプレートの検証に失敗しました。テンプレート内容を確認してください。"
  exit 1
fi
echo "テンプレートの検証に成功しました。"

# スタックが既に存在するか確認
echo "スタックの存在を確認しています..."
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $AWS_REGION --query "Stacks[0].StackStatus" --output text 2>/dev/null || echo "DOES_NOT_EXIST")

if [ "$STACK_STATUS" = "DOES_NOT_EXIST" ]; then
  echo "スタック $STACK_NAME は存在しません。新規作成します..."
  ACTION="create-stack"
elif [ "$STACK_STATUS" = "ROLLBACK_COMPLETE" ]; then
  echo "スタック $STACK_NAME は ROLLBACK_COMPLETE 状態です。更新できないため、削除して再作成する必要があります。"
  read -p "スタックを削除して再作成しますか？ (y/n): " DELETE_CONFIRM
  
  if [ "$DELETE_CONFIRM" != "y" ] && [ "$DELETE_CONFIRM" != "Y" ]; then
    echo "操作をキャンセルしました。"
    exit 0
  fi
  
  echo "スタックを削除しています..."
  aws cloudformation delete-stack --stack-name $STACK_NAME --region $AWS_REGION
  
  echo "スタックの削除が完了するまで待機しています..."
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $AWS_REGION
  
  ACTION="create-stack"
else
  echo "スタック $STACK_NAME は存在し、状態は $STACK_STATUS です。更新します..."
  ACTION="update-stack"
fi

# CloudFormationスタックのデプロイ
echo "CloudFormationスタックをデプロイしています... ($ACTION)"
STACK_RESPONSE=$(aws cloudformation $ACTION \
  --stack-name $STACK_NAME \
  --template-body file://$TEMPLATE_FILE \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT \
    ParameterKey=GitHubOwner,ParameterValue=$GITHUB_OWNER \
    ParameterKey=GitHubRepo,ParameterValue=$GITHUB_REPO \
    ParameterKey=GitHubBranch,ParameterValue=$GITHUB_BRANCH \
    ParameterKey=ArtifactBucketName,ParameterValue=$ARTIFACT_BUCKET_NAME \
    ParameterKey=NotificationEmail,ParameterValue=$NOTIFICATION_EMAIL \
    ParameterKey=UseSecretsManager,ParameterValue=true \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $AWS_REGION 2>&1)

# スタックの更新に変更がない場合の処理
if [[ $STACK_RESPONSE == *"No updates are to be performed"* ]]; then
  echo "スタックに変更はありません。スキップします。"
  exit 0
fi

# デプロイ失敗時のエラーハンドリング
if [ $? -ne 0 ]; then
  echo "エラー: スタックのデプロイに失敗しました。"
  echo "エラーメッセージ: $STACK_RESPONSE"
  exit 1
fi

# スタック操作の完了を待機
echo "スタック操作が完了するまで待機しています..."
if [ "$ACTION" == "create-stack" ]; then
  WAIT_ACTION="stack-create-complete"
else
  WAIT_ACTION="stack-update-complete"
fi

aws cloudformation wait $WAIT_ACTION \
  --stack-name $STACK_NAME \
  --region $AWS_REGION

# 結果の確認と表示
if [ $? -eq 0 ]; then
  echo "========================================"
  echo "CI/CDパイプラインのデプロイに成功しました！"
  echo "========================================"
  
  # スタックの出力を表示
  echo "スタックの出力:"
  aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs" \
    --output table \
    --region $AWS_REGION
  
  # パイプラインの状態を確認
  PIPELINE_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='CodePipelineName'].OutputValue" \
    --output text \
    --region $AWS_REGION)
  
  if [ -n "$PIPELINE_NAME" ]; then
    echo ""
    echo "パイプラインの状態:"
    aws codepipeline get-pipeline-state \
      --name "$PIPELINE_NAME" \
      --query "stageStates[*].[stageName,latestExecution.status]" \
      --output table \
      --region $AWS_REGION
  fi
  
  echo ""
  echo "次のステップ:"
  echo "1. GitHubリポジトリ「$GITHUB_REPO」の「$GITHUB_BRANCH」ブランチにコードをプッシュしてパイプラインをトリガーできます"
  echo "2. パイプラインの実行状態は AWS CodePipeline コンソールで確認できます"
  echo "3. パイプラインの成功/失敗通知は「$NOTIFICATION_EMAIL」宛に送信されます"
  echo ""
  echo "デプロイスクリプトを終了します。"
else
  echo "デプロイ失敗！スタックイベントを確認してください。"
  aws cloudformation describe-stack-events \
    --stack-name $STACK_NAME \
    --query "StackEvents[?ResourceStatus=='CREATE_FAILED' || ResourceStatus=='UPDATE_FAILED'].[LogicalResourceId,ResourceStatusReason]" \
    --output table \
    --region $AWS_REGION
  exit 1
fi

exit 0