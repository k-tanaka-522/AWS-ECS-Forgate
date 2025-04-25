#!/bin/bash
set -e

# 引数の解析
ENVIRONMENT=${1:-dev}  # デフォルトは dev
STACK_NAME="ecsforgate-cicd-${ENVIRONMENT}"
TEMPLATE_FILE="$(pwd)/iac/cloudformation/templates/cicd-github.yaml"
AWS_REGION=${2:-ap-northeast-1}  # デフォルトは東京リージョン

# 引数の確認
if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "stg" ] && [ "$ENVIRONMENT" != "prd" ]; then
  echo "Error: Invalid environment. Must be one of: dev, stg, prd"
  exit 1
fi

# 環境別のブランチ設定
if [ "$ENVIRONMENT" == "dev" ]; then
  DEFAULT_BRANCH="develop"
elif [ "$ENVIRONMENT" == "stg" ]; then
  DEFAULT_BRANCH="release"
else
  DEFAULT_BRANCH="main"
fi

# パラメータの入力
read -p "GitHub Owner [default: your-github-username]: " GITHUB_OWNER
GITHUB_OWNER=${GITHUB_OWNER:-your-github-username}

read -p "GitHub Repository [default: ECSForgate]: " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-ECSForgate}

read -p "GitHub Branch [default: $DEFAULT_BRANCH]: " GITHUB_BRANCH
GITHUB_BRANCH=${GITHUB_BRANCH:-$DEFAULT_BRANCH}

read -p "Notification Email [default: example@example.com]: " NOTIFICATION_EMAIL
NOTIFICATION_EMAIL=${NOTIFICATION_EMAIL:-example@example.com}

read -s -p "GitHub Personal Access Token: " GITHUB_TOKEN
echo ""
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GitHub Token is required"
  exit 1
fi

read -p "Artifact Bucket Name [default: ecsforgate-${ENVIRONMENT}-artifacts-${AWS_REGION}-$(date +%s)]: " ARTIFACT_BUCKET_NAME
ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME:-ecsforgate-${ENVIRONMENT}-artifacts-${AWS_REGION}-$(date +%s)}

echo "Deploying CI/CD Pipeline with the following parameters:"
echo "Environment: $ENVIRONMENT"
echo "Stack Name: $STACK_NAME"
echo "Template File: $TEMPLATE_FILE"
echo "GitHub Owner: $GITHUB_OWNER"
echo "GitHub Repository: $GITHUB_REPO"
echo "GitHub Branch: $GITHUB_BRANCH"
echo "Artifact Bucket Name: $ARTIFACT_BUCKET_NAME"
echo "Notification Email: $NOTIFICATION_EMAIL"
echo "Region: $AWS_REGION"

# 確認
read -p "Continue with deployment? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Deployment cancelled"
  exit 0
fi

# スタックが既に存在するか確認
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $AWS_REGION > /dev/null 2>&1; then
  echo "Stack $STACK_NAME exists, updating..."
  ACTION="update-stack"
else
  echo "Stack $STACK_NAME does not exist, creating..."
  ACTION="create-stack"
fi

# テンプレートの検証
echo "Validating CloudFormation template..."
aws cloudformation validate-template \
  --template-body file://$TEMPLATE_FILE \
  --region $AWS_REGION

# CloudFormationスタックのデプロイ
echo "Deploying CloudFormation stack..."
aws cloudformation $ACTION \
  --stack-name $STACK_NAME \
  --template-body file://$TEMPLATE_FILE \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT \
    ParameterKey=GitHubOwner,ParameterValue=$GITHUB_OWNER \
    ParameterKey=GitHubRepo,ParameterValue=$GITHUB_REPO \
    ParameterKey=GitHubBranch,ParameterValue=$GITHUB_BRANCH \
    ParameterKey=GitHubToken,ParameterValue=$GITHUB_TOKEN \
    ParameterKey=ArtifactBucketName,ParameterValue=$ARTIFACT_BUCKET_NAME \
    ParameterKey=NotificationEmail,ParameterValue=$NOTIFICATION_EMAIL \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $AWS_REGION

echo "Waiting for stack operation to complete..."
aws cloudformation wait stack-$ACTION-complete \
  --stack-name $STACK_NAME \
  --region $AWS_REGION

if [ $? -eq 0 ]; then
  echo "CI/CD Pipeline deployed successfully!"
  
  # スタックの出力を表示
  echo "Stack outputs:"
  aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs" \
    --output table \
    --region $AWS_REGION
  
  echo ""
  echo "Instructions:"
  echo "1. Make sure your GitHub repository is set up correctly"
  echo "2. Push code to the '$GITHUB_BRANCH' branch to trigger the pipeline"
  echo "3. You will receive email notifications for pipeline successes and failures"
  echo "4. Check the AWS CodePipeline console to monitor the pipeline"
else
  echo "Deployment failed!"
  exit 1
fi

exit 0
