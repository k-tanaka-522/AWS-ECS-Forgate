# CI/CDパイプライン構築手順書


## 実行環境の前提条件

この手順書は以下の環境を前提としています：

### 実行環境
- ホストOS: Windows 10/11
- WSL: Ubuntu 22.04 LTS
- コマンドライン環境:
  - AWS CLI コマンド: WSL環境
  - Git コマンド: WSL環境
  - bashスクリプト (.sh): WSL環境
  - Docker コマンド: Windows環境（Docker Desktop）

### ツールのバージョン要件
- AWS CLI: バージョン2.x以上（WSL上にインストール済み）
- Git: バージョン2.x以上（WSL上にインストール済み）
- Docker: Docker Desktop for Windows 4.x以上（WSL2統合有効）

### 環境設定の確認

**WSL上でのAWS CLI確認:**
```bash
# WSL環境で実行
# WSLターミナルで実行
aws --version
aws sts get-caller-identity
```

**WSL上でのGit確認:**
```bash
# WSL環境で実行
# WSLターミナルで実行
git --version
```

**Windows上でのDocker確認:**
```bash
# WSL環境で実行
# Windows PowerShellまたはCMDで実行
docker --version
docker run --rm hello-world
```

### ファイルパスの注意事項

コマンドの実行環境に応じてパスの表記が異なります：
- WSL環境でのプロジェクトパス: `/mnt/c/dev2/ECSForgate/`
- Windows環境でのプロジェクトパス: `C:\dev2\ECSForgate\`

この手順書のコマンド例はすべてWSL環境のパス表記を前提としています。Windows環境で実行する場合は適宜パスを変換してください。

### 操作環境の切り替え

各コマンドを実行する際は、適切な環境（WSLまたはWindows）に切り替えてください。

- WSL環境への切り替え: Windows PowerShellから `wsl` コマンドを実行
- Windows環境への切り替え: WSLで `exit` コマンドを実行してWSLを終了
## 目次

1. [概要と目的](#1-概要と目的)
2. [前提条件](#2-前提条件)
3. [構築手順](#3-構築手順)
   1. [環境変数の設定](#31-環境変数の設定)
   2. [buildspecファイルの準備](#32-buildspecファイルの準備)
   3. [CI/CDテンプレートの検証](#33-cicdテンプレートの検証)
   4. [開発環境(dev)パイプラインのデプロイ](#34-開発環境devパイプラインのデプロイ)
   5. [ステージング環境(stg)パイプラインのデプロイ](#35-ステージング環境stgパイプラインのデプロイ)
   6. [本番環境(prd)パイプラインのデプロイ](#36-本番環境prdパイプラインのデプロイ)
4. [デプロイ結果の確認方法](#4-デプロイ結果の確認方法)
5. [パイプラインのテスト方法](#5-パイプラインのテスト方法)
6. [トラブルシューティング](#6-トラブルシューティング)
7. [よくある質問と回答](#7-よくある質問と回答)
8. [付録：便利なコマンド集](#8-付録便利なコマンド集)

## 1. 概要と目的

本ドキュメントでは、ECSForgateプロジェクトのCI/CDパイプラインを構築するための手順を説明します。このCI/CDパイプラインは、GitHubリポジトリとAWS CodePipelineを連携させ、コードの変更からビルド、テスト、デプロイまでを自動化します。

**主な機能：**
- GitHubリポジトリからのコード取得
- ブランチごとに異なる環境へのデプロイ設定
- AWS CodeBuildによるアプリケーションのビルドとテスト
- ECRへのDockerイメージのプッシュ
- ECS Fargateへの自動デプロイ

## 2. 前提条件

以下の前提条件を全て満たしていることを確認してください：

- [x] AWS CLIがインストールされ、適切に設定されている（バージョン2.0以上）
```bash
# WSL環境で実行
  # インストール確認
  aws --version
  
  # 認証情報確認
  aws sts get-caller-identity
  
  # 【確認ポイント】
  # - バージョンが2.0以上であること
  # - 有効なAWSアカウントIDとARNが表示されること
  ```

- [x] 必要なIAM権限が付与されている
  - CloudFormation権限: `cloudformation:*`
  - CodePipeline権限: `codepipeline:*`
  - CodeBuild権限: `codebuild:*`
  - IAM権限: `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PassRole`
  - ECR権限: `ecr:*`
  - Secrets Manager権限: `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret`

- [x] Secrets ManagerにGitHubトークンが登録済み
```bash
# WSL環境で実行
  # シークレット確認
  aws secretsmanager describe-secret --secret-id github/token

  # 【確認ポイント】
  # - エラーが表示されなければOK
  # - エラーが表示される場合は「06_Secrets_Manager_シークレット_設定手順.md」を実行
  ```

- [x] ECRリポジトリが作成済み
```bash
# WSL環境で実行
  # リポジトリ確認
  aws ecr describe-repositories --repository-names ecsforgate-base ecsforgate-api

  # 【確認ポイント】
  # - ecsforgate-baseとecsforgate-apiリポジトリがリストされればOK
  # - 存在しない場合は「05_ECR_ベースイメージ_作成手順.md」を実行
  ```

- [x] プロジェクトディレクトリの準備
```bash
# WSL環境で実行
  # ディレクトリに移動
  cd /mnt/c/dev2/ECSForgate
  
  # ファイル構造確認
  ls -la iac/cloudformation/templates/cicd-github.yaml
  ls -la iac/cloudformation/scripts/deploy-cicd-github.sh
  
  # 【確認ポイント】
  # - ファイルが存在すればOK
  # - ファイルが存在しない場合はリポジトリを正しくクローンしていることを確認
  ```

## 3. 構築手順

### 【実行環境: WSL】
### 3.1 環境変数の設定

必要な環境変数を設定します。

```bash
# WSL環境で実行
# AWS情報の取得
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)

# GitHub情報の設定
GITHUB_OWNER="k-tanaka-522"  # ⚠️ 実際のGitHubアカウント名に変更
GITHUB_REPO="AWS-ECS-Forgate"  # ⚠️ 実際のリポジトリ名に変更

# 【確認ポイント】
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "AWS Region: ${AWS_REGION}"
echo "GitHub Owner: ${GITHUB_OWNER}"
echo "GitHub Repository: ${GITHUB_REPO}"

# すべての変数が正しく設定されていることを確認
```

### 【実行環境: WSL】
### 3.2 buildspecファイルの準備

各環境用のbuildspecファイルを準備します。buildspecファイルは、コードのビルド、テスト、およびデプロイの手順を定義します。

#### 3.2.1 プロジェクトルートディレクトリに移動

```bash
# WSL環境で実行
cd /mnt/c/dev2/ECSForgate
```

#### 3.2.2 各環境のbuildspecファイルの存在確認

```bash
# WSL環境で実行
# buildspecファイルの存在確認
ls -la buildspec-dev.yml buildspec-stg.yml buildspec-prd.yml

# 【確認ポイント】
# - 3つのファイルが全て存在すればOK
# - 存在しない場合は次のステップで作成
```

#### 3.2.3 必要に応じてbuildspecファイルを作成

開発環境(dev)用buildspecファイルの例：

```bash
# WSL環境で実行
# buildspec-dev.yml
cat > buildspec-dev.yml << 'EOF'
version: 0.2

env:
  variables:
    BASE_IMAGE_REPO: "ecsforgate-base"
    BASE_IMAGE_TAG: "base-2025-Q2-frozen"
    APP_IMAGE_REPO: "ecsforgate-api"
    ENVIRONMENT: "dev"
  parameter-store:
    # パラメータストアから取得する変数（必要に応じて設定）
  secrets-manager:
    # Secrets Managerから取得する変数（必要に応じて設定）
    DB_USERNAME: "dev/db/ecsforgate:username"
    DB_PASSWORD: "dev/db/ecsforgate:password"
    DB_HOST: "dev/db/ecsforgate:host"
    DB_PORT: "dev/db/ecsforgate:port"
    DB_NAME: "dev/db/ecsforgate:dbname"

phases:
  install:
    runtime-versions:
      java: corretto11
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - BUILD_DATE=$(date +%Y%m%d)
      - IMAGE_TAG=dev-${COMMIT_HASH}-${BUILD_DATE}
      - BASE_IMAGE_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$BASE_IMAGE_REPO:$BASE_IMAGE_TAG
      - APP_REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$APP_IMAGE_REPO
      - echo Set up build env...
      - echo BASE_IMAGE=$BASE_IMAGE_URI
      - echo APP_REPOSITORY_URI=$APP_REPOSITORY_URI
      - echo IMAGE_TAG=$IMAGE_TAG
  build:
    commands:
      - echo Build started on `date`
      - cd app/api
      - ./gradlew clean build
      - cd ../..
      - echo Building the Docker image...
      - docker build -t $APP_REPOSITORY_URI:$IMAGE_TAG --build-arg BASE_IMAGE=$BASE_IMAGE_URI app/api/.
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push $APP_REPOSITORY_URI:$IMAGE_TAG
      - echo Writing artifacts...
      - aws cloudformation describe-stacks --stack-name ecsforgate-${ENVIRONMENT} --query "Stacks[0].Outputs[?OutputKey=='ECSTaskDefinitionArn'].OutputValue" --output text
      - echo $IMAGE_TAG > image-tag.txt
      - echo "build completed"

artifacts:
  files:
    - image-tag.txt
    - appspec.yml
    - taskdef.json
    - iac/cloudformation/config/$ENVIRONMENT/parameters.json
EOF

# その他の環境用buildspecも同様に作成
# 必要に応じてbuildspec-stg.ymlとbuildspec-prd.ymlを作成
```

#### 3.2.4 buildspecファイルの内容を確認

```bash
# WSL環境で実行
# buildspecファイルの内容確認
cat buildspec-dev.yml

# 【確認ポイント】
# - 正しいベースイメージ名とタグが設定されていること: BASE_IMAGE_TAG: "base-2025-Q2-frozen"
# - 環境変数が適切に設定されていること: ENVIRONMENT: "dev"
# - 正しいビルドコマンドが含まれていること
# - アーティファクト設定が適切に行われていること
```

### 【実行環境: WSL】
### 3.3 CI/CDテンプレートの検証

CI/CDパイプラインを構築するCloudFormationテンプレートを検証します。

```bash
# WSL環境で実行
# プロジェクトルートディレクトリにいることを確認
cd /mnt/c/dev2/ECSForgate

# テンプレートの検証
./iac/cloudformation/scripts/validate.sh iac/cloudformation/templates/cicd-github.yaml

# 【確認ポイント】
# - エラーメッセージが表示されなければテンプレートは有効
# - エラーが表示される場合は、テンプレートを修正する必要あり
# - よくあるエラー: パラメータの参照ミス、リソース定義の構文エラーなど
```

### 【実行環境: WSL】
### 3.4 開発環境(dev)パイプラインのデプロイ

開発環境用のCI/CDパイプラインをデプロイします。

```bash
# WSL環境で実行
# スクリプトに実行権限を付与（必要に応じて）
chmod +x ./iac/cloudformation/scripts/deploy-cicd-github.sh

# 開発環境用パイプラインのデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "develop" \
  --environment "dev"

# 【確認ポイント】
# - スクリプトが正常に実行されること
# - "CI/CDパイプラインのデプロイに成功しました！"というメッセージが表示されること
# - スタックの出力情報が表示されること
#
# 【エラー対応】
# - エラーメッセージが表示される場合は、メッセージの内容を確認
# - IAM権限が不足している場合は、必要な権限を追加
# - GitHub Tokenがない場合は、Secrets Manager設定を確認
```

### 【実行環境: WSL】
### 3.5 ステージング環境(stg)パイプラインのデプロイ

開発環境と同様の手順でステージング環境用のパイプラインをデプロイします。

```bash
# WSL環境で実行
# ステージング環境用パイプラインのデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "release/*" \
  --environment "stg"

# 【確認ポイント】
# - スクリプトが正常に実行されること
# - スタックの出力情報が表示されること
```

### 【実行環境: WSL】
### 3.6 本番環境(prd)パイプラインのデプロイ

同様に本番環境用のパイプラインをデプロイします。

```bash
# WSL環境で実行
# 本番環境用パイプラインのデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "main" \
  --environment "prd"

# 【確認ポイント】
# - スクリプトが正常に実行されること
# - スタックの出力情報が表示されること
# - 本番環境であるため、特に慎重に確認すること
```

## 【実行環境: WSL + Windows（ブラウザ）】
## 4. デプロイ結果の確認方法

デプロイしたCI/CDパイプラインが正しく構築されたか確認します。

### 4.1 CloudFormationスタックの確認

```bash
# WSL環境で実行
# 各環境のスタック状態を確認
for env in dev stg prd; do
  echo "==== ${env}環境のスタック情報 ===="
  aws cloudformation describe-stacks \
    --stack-name "ecsforgate-cicd-${env}" \
    --query "Stacks[0].[StackName,StackStatus,CreationTime,LastUpdatedTime]" \
    --output table
  
  # スタックの出力を確認
  echo "==== ${env}環境のスタック出力 ===="
  aws cloudformation describe-stacks \
    --stack-name "ecsforgate-cicd-${env}" \
    --query "Stacks[0].Outputs[]" \
    --output table
done

# 【確認ポイント】
# - 全ての環境でスタックステータスが「CREATE_COMPLETE」または「UPDATE_COMPLETE」であること
# - スタックの出力に「CodePipelineName」「CodeBuildProjectName」などが含まれていること
```

### 4.2 CodePipelineの確認

```bash
# WSL環境で実行
# 各環境のパイプライン状態を確認
for env in dev stg prd; do
  # パイプライン名を取得
  PIPELINE_NAME=$(aws cloudformation describe-stacks \
    --stack-name "ecsforgate-cicd-${env}" \
    --query "Stacks[0].Outputs[?OutputKey=='CodePipelineName'].OutputValue" \
    --output text)
  
  if [ -n "$PIPELINE_NAME" ]; then
    echo "==== ${env}環境のパイプライン状態 ===="
    aws codepipeline get-pipeline-state \
      --name "$PIPELINE_NAME" \
      --query "stageStates[*].[stageName,latestExecution.status]" \
      --output table
  else
    echo "警告: ${env}環境のパイプライン名が取得できませんでした。"
  fi
done

# 【確認ポイント】
# - 各環境のパイプラインが存在すること
# - パイプラインのステージ（Source, Build, Deploy）が表示されること
# - ステータスが「InProgress」または「Succeeded」であること（または初回実行前は空の場合も）
```

### 4.3 CodeBuildプロジェクトの確認

```bash
# WSL環境で実行
# 各環境のビルドプロジェクトを確認
for env in dev stg prd; do
  # CodeBuildプロジェクト名
  BUILD_PROJECT_NAME="ecsforgate-build-${env}"
  
  echo "==== ${env}環境のCodeBuildプロジェクト情報 ===="
  aws codebuild batch-get-projects \
    --names "$BUILD_PROJECT_NAME" \
    --query "projects[0].[name,environment.type,environment.image,serviceRole]" \
    --output text
  
  # 環境変数の確認
  echo "==== ${env}環境のCodeBuild環境変数 ===="
  aws codebuild batch-get-projects \
    --names "$BUILD_PROJECT_NAME" \
    --query "projects[0].environment.environmentVariables[*].[name,value,type]" \
    --output table
done

# 【確認ポイント】
# - 各環境のCodeBuildプロジェクトが存在すること
# - サービスロールが正しく設定されていること
# - 環境変数が適切に設定されていること
```

### 4.4 GitHubウェブフックの確認

GitHubウェブフックが正しく設定されているか確認するには、GitHubのWebUIを使用します。

1. GitHubのリポジトリにブラウザでアクセス（例：https://github.com/k-tanaka-522/AWS-ECS-Forgate）
2. リポジトリの「Settings」タブをクリック
3. 左側のメニューから「Webhooks」を選択
4. AWS CodePipelineのウェブフックが存在することを確認

**確認ポイント：**
- ウェブフックのURLが「https://hooks.amazonaws.com/...」で始まること
- 最新の配信が成功している（緑色のチェックマーク）こと
- エラーがないこと

## 【実行環境: WSL】
## 5. パイプラインのテスト方法

構築したCI/CDパイプラインが正しく機能するか、実際にコードをプッシュしてテストします。

### 5.1 GitHubリポジトリの準備

```bash
# WSL環境で実行
# GitHubリポジトリに移動（実際のクローン先パスに変更）
cd /mnt/c/dev2/ECSForgate-GitHub

# 現在のブランチを確認
git branch
```

### 5.2 開発環境への変更のプッシュ

```bash
# WSL環境で実行
# developブランチにチェックアウト（存在しない場合は作成）
git checkout develop 2>/dev/null || git checkout -b develop

# テスト用の変更
echo "# CI/CDパイプラインテスト - $(date)" >> README.md

# 変更をコミット
git add README.md
git commit -m "CI/CDパイプラインのテスト"

# リモートリポジトリにプッシュ
git push origin develop

# 【確認ポイント】
# - プッシュが成功すること
# - GitHubのWebUIでコミットが見えること
```

### 5.3 パイプラインの実行確認

```bash
# WSL環境で実行
# 開発環境のパイプライン名を取得
PIPELINE_NAME=$(aws cloudformation describe-stacks \
  --stack-name "ecsforgate-cicd-dev" \
  --query "Stacks[0].Outputs[?OutputKey=='CodePipelineName'].OutputValue" \
  --output text)

# パイプラインの実行状態を定期的に確認（10秒ごと、Ctrl+Cで終了）
echo "パイプラインの実行を監視しています（Ctrl+Cで終了）..."
while true; do
  clear
  echo "==== $(date) ===="
  echo "パイプライン: ${PIPELINE_NAME}"
  aws codepipeline get-pipeline-state \
    --name "${PIPELINE_NAME}" \
    --query "stageStates[*].[stageName,latestExecution.status]" \
    --output table
  sleep 10
done

# 【確認ポイント】
# - Sourceステージが「InProgress」→「Succeeded」に変わること
# - Buildステージが「InProgress」→「Succeeded」に変わること
# - Deployステージがある場合は「InProgress」→「Succeeded」に変わること
```

### 5.4 ビルドログの確認

```bash
# WSL環境で実行
# CodeBuildプロジェクト名
BUILD_PROJECT_NAME="ecsforgate-build-dev"

# 最新のビルドIDを取得
BUILD_ID=$(aws codebuild list-builds-for-project \
  --project-name "${BUILD_PROJECT_NAME}" \
  --sort-order DESCENDING \
  --max-items 1 \
  --query "ids[0]" \
  --output text)

# ビルドの情報を取得
if [ -n "$BUILD_ID" ]; then
  echo "ビルド ID: ${BUILD_ID}"
  
  # ビルドステータスとフェーズの確認
  aws codebuild batch-get-builds \
    --ids "${BUILD_ID}" \
    --query "builds[0].[buildStatus,currentPhase,logs.deepLink]" \
    --output text
  
  # CloudWatch Logsグループとストリーム名を取得
  LOG_GROUP=$(aws codebuild batch-get-builds \
    --ids "${BUILD_ID}" \
    --query "builds[0].logs.groupName" \
    --output text)
  
  LOG_STREAM=$(aws codebuild batch-get-builds \
    --ids "${BUILD_ID}" \
    --query "builds[0].logs.streamName" \
    --output text)
  
  # ログイベントの取得
  if [ -n "$LOG_GROUP" ] && [ -n "$LOG_STREAM" ]; then
    echo "ログの最新10行:"
    aws logs get-log-events \
      --log-group-name "${LOG_GROUP}" \
      --log-stream-name "${LOG_STREAM}" \
      --limit 10 \
      --query "events[*].message" \
      --output text
  fi
else
  echo "ビルドが見つかりません。"
fi

# 【確認ポイント】
# - ビルドステータスが「SUCCEEDED」であること
# - ログに重大なエラーがないこと
```

## 【実行環境: WSL】
## 6. トラブルシューティング

CI/CDパイプラインの構築や実行中に問題が発生した場合の対処方法を説明します。

### 6.1 CloudFormationスタックのデプロイエラー

**問題**: CloudFormationスタックのデプロイまたは更新に失敗する

**解決方法**:
```bash
# WSL環境で実行
# エラーが発生した環境
ENVIRONMENT="dev"  # 問題の発生した環境に変更
STACK_NAME="ecsforgate-cicd-${ENVIRONMENT}"

# エラーの詳細を確認
aws cloudformation describe-stack-events \
  --stack-name "${STACK_NAME}" \
  --query "StackEvents[?ResourceStatus=='CREATE_FAILED' || ResourceStatus=='UPDATE_FAILED'].[LogicalResourceId,ResourceStatusReason]" \
  --output table

# 【よくあるエラーと対処法】
# 1. IAM関連エラー: 必要なIAM権限を確認・追加
# 2. リソース名の重複: スタック名やリソース名の重複を確認
# 3. ROLLBACK_COMPLETE状態: スタックを削除して再作成
```

ROLLBACK_COMPLETE状態のスタックを処理する方法:
```bash
# WSL環境で実行
# スタックのステータスを確認
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].StackStatus" \
  --output text 2>/dev/null || echo "DOES_NOT_EXIST")

if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]; then
  # スタックを削除
  aws cloudformation delete-stack --stack-name "${STACK_NAME}"
  
  # 削除が完了するまで待機
  echo "スタックの削除を待機しています..."
  aws cloudformation wait stack-delete-complete --stack-name "${STACK_NAME}"
  
  # スタックを再作成
  ./iac/cloudformation/scripts/deploy-cicd-github.sh \
    --github-owner "${GITHUB_OWNER}" \
    --github-repo "${GITHUB_REPO}" \
    --github-branch "develop" \
    --environment "${ENVIRONMENT}"
fi
```

### 6.2 パイプラインの実行エラー

**問題**: パイプラインの実行が失敗する

**解決方法**:
```bash
# WSL環境で実行
# 環境を設定
ENVIRONMENT="dev"  # 問題の発生した環境に変更
PIPELINE_NAME="ecsforgate-pipeline-${ENVIRONMENT}"

# パイプラインのステージ状態を確認
aws codepipeline get-pipeline-state \
  --name "${PIPELINE_NAME}" \
  --query "stageStates[*].[stageName,latestExecution.status,latestExecution.errorDetails.message]" \
  --output table

# 【よくあるエラーと対処法】
# 1. Sourceステージのエラー:
#    - GitHubトークンの有効期限切れ → 新しいトークンを生成しSecrets Managerに更新
#    - ウェブフックの問題 → GitHubのウェブフック設定を確認
#
# 2. Buildステージのエラー:
#    - buildspec.ymlの問題 → 構文や環境変数を確認
#    - ビルドコマンドの失敗 → ビルドログを確認
#    - ECRリポジトリアクセス権限の問題 → IAMロールの権限を確認
#
# 3. Deployステージのエラー:
#    - ECSサービスやタスク定義の問題 → ECSの設定を確認
#    - IAM権限の問題 → デプロイロールの権限を確認
```

ビルドログの確認方法:
```bash
# WSL環境で実行
# CodeBuildプロジェクト名
BUILD_PROJECT_NAME="ecsforgate-build-${ENVIRONMENT}"

# 最新のビルドIDを取得
BUILD_ID=$(aws codebuild list-builds-for-project \
  --project-name "${BUILD_PROJECT_NAME}" \
  --sort-order DESCENDING \
  --max-items 1 \
  --query "ids[0]" \
  --output text)

# ビルドログのリンクを取得
if [ -n "$BUILD_ID" ]; then
  LOG_URL=$(aws codebuild batch-get-builds \
    --ids "${BUILD_ID}" \
    --query "builds[0].logs.deepLink" \
    --output text)
  
  echo "ビルドログURL: ${LOG_URL}"
  echo "AWSマネジメントコンソールでこのURLを開いてログを確認してください。"
fi
```

### 6.3 GitHubウェブフックの問題

**問題**: GitHubウェブフックが正しく機能していない

**解決方法**:

1. GitHubリポジトリのウェブフック設定を確認:
   - GitHubリポジトリの「Settings」→「Webhooks」で確認
   - ウェブフックのURL、シークレット、イベントが正しく設定されているか確認
   - 最新の配信ステータスを確認（成功/失敗）

2. GitHub Personal Access Tokenの更新:
```bash
# WSL環境で実行
# 新しいTokenをSecrets Managerに更新（GitHubで新しいトークンを生成後）
# 注意: このコマンドは安全な環境でのみ実行
read -s -p "新しいGitHubトークンを入力: " NEW_GITHUB_TOKEN
echo

# Secrets Managerを更新
aws secretsmanager update-secret \
  --secret-id github/token \
  --secret-string "{\"token\":\"${NEW_GITHUB_TOKEN}\"}"

# 環境変数からトークンを削除（セキュリティ対策）
unset NEW_GITHUB_TOKEN

# CI/CDスタックを更新して新しいウェブフックを作成
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "develop" \
  --environment "${ENVIRONMENT}"
```

## 7. よくある質問と回答

### Q1: 複数の環境に同時にデプロイすることはできますか？

**A**: 同時でなく順次デプロイすることを推奨します。各環境ごとに個別のパイプラインを構築し、それぞれを検証してから次の環境に進むことで、問題の特定と解決が容易になります。

### Q2: GitHubトークンの有効期限が切れた場合はどうすればよいですか？

**A**: 以下の手順で更新します。

1. GitHubで新しいPersonal Access Tokenを生成
2. Secrets Managerのシークレットを更新
3. CI/CDスタックを更新（ウェブフックを再作成）

### Q3: ビルド時に「ECRリポジトリへのアクセスが拒否された」というエラーが出る場合は？

**A**: CodeBuildサービスロールに適切なECR権限が付与されているか確認してください。特に以下の権限が必要です。

- ecr:GetAuthorizationToken
- ecr:BatchCheckLayerAvailability
- ecr:PutImage
- ecr:InitiateLayerUpload
- ecr:UploadLayerPart
- ecr:CompleteLayerUpload

### Q4: デプロイパイプラインで特定のブランチパターンを使用できますか？

**A**: はい、`release/*`のようなワイルドカードパターンを使用できます。これにより、「release/v1.0.0」や「release/v2.0.0」などのブランチをすべて捕捉できます。

### Q5: パイプラインを手動で実行するにはどうすればよいですか？

**A**: 以下のコマンドで手動実行できます。

```bash
# WSL環境で実行
aws codepipeline start-pipeline-execution --name "ecsforgate-pipeline-dev"
```

## 8. 付録：便利なコマンド集

### パイプライン情報の取得

```bash
# WSL環境で実行
# パイプラインの詳細を取得
aws codepipeline get-pipeline --name "ecsforgate-pipeline-dev"

# パイプラインの実行履歴を取得
aws codepipeline list-pipeline-executions --pipeline-name "ecsforgate-pipeline-dev"
```

### CodeBuild情報の取得

```bash
# WSL環境で実行
# ビルドプロジェクトの詳細を取得
aws codebuild batch-get-projects --names "ecsforgate-build-dev"

# ビルド履歴を取得
aws codebuild list-builds-for-project --project-name "ecsforgate-build-dev"
```

### CloudFormationスタック情報の取得

```bash
# WSL環境で実行
# スタックの詳細情報を取得
aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-dev"

# スタックのリソース一覧を取得
aws cloudformation list-stack-resources --stack-name "ecsforgate-cicd-dev"
```

### ECRリポジトリ情報の取得

```bash
# WSL環境で実行
# リポジトリの一覧を取得
aws ecr describe-repositories

# イメージの一覧を取得
aws ecr describe-images --repository-name "ecsforgate-api"
```

### IAMロールとポリシーの確認

```bash
# WSL環境で実行
# ロールに付与されたポリシーを確認
aws iam list-attached-role-policies --role-name "ecsforgate-codebuild-service-role-dev"

# ポリシーの詳細を確認
aws iam get-policy --policy-arn "arn:aws:iam::123456789012:policy/ECSForgateSecretsManagerAccess"
```

**注意**：これらのコマンドは、適切なアクセス権限がある状態で実行してください。また、実際のリソース名やARNは環境によって異なる場合があります。
