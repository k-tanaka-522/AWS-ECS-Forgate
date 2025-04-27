# GitHubリポジトリ連携設定手順


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
aws --version
aws sts get-caller-identity
```

**WSL上でのGit確認:**
```bash
# WSL環境で実行
git --version
```

**Windows上でのDocker確認:**
```bash
# WSL環境で実行
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
## 関連設計書
- [CI/CD詳細設計書](/docs/002_設計/components/cicd-design.md)
- [CloudFormation詳細設計書](/docs/002_設計/components/cloudformation-design.md)

## 目的
本ドキュメントでは、AWS CodePipelineとGitHubリポジトリを連携させるための設定手順を説明します。この連携により、GitHubリポジトリへのコードプッシュをトリガーとして、自動的にCI/CDパイプラインが実行されるようになります。

## 前提条件チェックリスト
以下の前提条件を確認してから作業を開始してください：

- [ ] AWS CLIがインストールされている（バージョン2.0以上推奨）
```bash
# WSL環境で実行
  aws --version
  # 出力例: aws-cli/2.9.19 Python/3.9.11 Linux/5.10.16.3-microsoft-standard-WSL2 exe/x86_64.ubuntu.22 prompt/off
  ```

- [ ] AWS CLIが適切な権限を持つIAMユーザーで設定済み
```bash
# WSL環境で実行
  aws sts get-caller-identity
  # 出力例：
  # {
  #     "UserId": "AIDAXXXXXXXXXXXXXX",
  #     "Account": "123456789012",
  #     "Arn": "arn:aws:iam::123456789012:user/username"
  # }
  ```

- [ ] 必要なIAM権限が付与されている
  - CloudFormation権限: `cloudformation:CreateStack`, `cloudformation:UpdateStack`, `cloudformation:DescribeStacks`
  - CodePipeline権限: `codepipeline:CreatePipeline`, `codepipeline:GetPipeline`, `codepipeline:GetPipelineState`
  - CodeBuild権限: `codebuild:CreateProject`, `codebuild:BatchGetProjects`
  - IAM権限: `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PassRole`
  - Secrets Manager権限: `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret`

- [ ] GitHubアカウントとリポジトリの管理権限を保有
```bash
# WSL環境で実行
  # GitHubアクセストークンを持っているか確認
  # 持っていない場合は後述する「GitHub Personal Access Token (PAT)の作成」セクションで作成
  ```

- [ ] Secrets Managerに「github/token」シークレットが存在する
```bash
# WSL環境で実行
  # Secrets Managerにシークレットが存在するか確認
  aws secretsmanager describe-secret --secret-id github/token
  
  # 【確認ポイント】
  # 以下のようなJSONレスポンスが返ってくれば存在します：
  # {
  #     "ARN": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:github/token-Abcdef",
  #     "Name": "github/token",
  #     ...
  # }
  
  # 【エラー対応】
  # 以下のエラーが表示される場合は、シークレットが存在しないか、アクセス権限がありません：
  # An error occurred (ResourceNotFoundException) when calling the DescribeSecret operation: Secrets Manager can't find the specified secret.
  # この場合、「06_Secrets_Manager_シークレット_設定手順.md」に従ってGitHubトークンを登録してください
  ```

- [ ] プロジェクトリポジトリのクローンがローカル環境にある
```bash
# WSL環境で実行
  # プロジェクトルートディレクトリに移動
  cd /mnt/c/dev2/ECSForgate
  # 確認
  ls -l
  # 出力例: README.md, app/, docs/, iac/ などのファイル/ディレクトリが表示される
  ```

### 【実行環境: WSL】
## 1. GitHubリポジトリの準備

### 1.1 GitHubリポジトリの存在確認

```bash
# WSL環境で実行
# GitHubリポジトリが既にあるかどうかの確認
# 以下のコマンドはGitHub APIを使用するため、GitHubトークンが必要です
# 環境変数にGitHubトークンを安全に設定（トークンが既にある場合）
echo "GitHubトークンを安全に入力してください（入力内容は表示されません）"
read -s GITHUB_TOKEN

# トークンを使ってリポジトリの存在を確認（実際のユーザー名とリポジトリ名に置き換え）
GITHUB_USER="k-tanaka-522"
REPO_NAME="AWS-ECS-Forgate"
curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME" | grep -q "\"name\": \"$REPO_NAME\"" && echo "リポジトリは存在します" || echo "リポジトリが存在しないか、アクセスできません"

# 【確認ポイント】
# 「リポジトリは存在します」と表示されれば、リポジトリは既に存在します
# 「リポジトリが存在しないか、アクセスできません」と表示される場合は、次のステップで作成が必要です

# 環境変数からトークンを削除（セキュリティ対策）
unset GITHUB_TOKEN
```

### 1.2 GitHubリポジトリの作成（既存のリポジトリがない場合）

GitHubリポジトリが存在しない場合、以下の手順で作成します。

1. GitHubにログイン
2. 右上の「+」アイコンをクリック → 「New repository」を選択
3. 以下の設定でリポジトリを作成：
   - Repository name: `AWS-ECS-Forgate`
   - Description: `Spring BootアプリケーションをECS Fargateで実行するためのプロジェクト`
   - Visibility: `Private` （必要に応じてPublicも可）
   - Initialize this repository with: `Add a README file`を選択
   - Add .gitignore: `Java`を選択
4. 「Create repository」ボタンをクリック

### 1.3 GitHubリポジトリのクローン（リポジトリが新規作成された場合）

```bash
# WSL環境で実行
# リポジトリをローカル環境にクローン
# まずプロジェクトのルートディレクトリの一つ上の階層に移動
cd /mnt/c/dev2
# リポジトリをクローン（実際のユーザー名に置き換え）
git clone https://github.com/k-tanaka-522/AWS-ECS-Forgate.git ECSForgate-GitHub
cd ECSForgate-GitHub

# 【確認ポイント】
# クローンが成功したら、.gitディレクトリと初期ファイルが存在するか確認
ls -la
# 出力例: .git/ README.md .gitignore などが表示される

# 【エラー対応】
# 認証エラーが発生する場合は、URLにGitHubユーザー名を含めるか、
# Personal Access Tokenを使用したURLでクローンを試みてください：
# git clone https://<GitHubユーザー名>:<トークン>@github.com/k-tanaka-522/AWS-ECS-Forgate.git ECSForgate-GitHub
```

### 1.4 プロジェクトファイルの準備（新規リポジトリの場合）

```bash
# WSL環境で実行
# プロジェクトファイルを新しいリポジトリにコピー
# まず、既存のプロジェクトファイルがあるディレクトリに存在するファイルを確認
ls -la /mnt/c/dev2/ECSForgate

# プロジェクトファイルをコピー（.gitディレクトリを除く）
cp -r /mnt/c/dev2/ECSForgate/* /mnt/c/dev2/ECSForgate-GitHub/
cp -r /mnt/c/dev2/ECSForgate/.* /mnt/c/dev2/ECSForgate-GitHub/ 2>/dev/null || :
# .gitディレクトリはコピーしないよう注意

# コピー後のファイルを確認
cd /mnt/c/dev2/ECSForgate-GitHub
ls -la

# 【確認ポイント】
# プロジェクトの主要ファイルとディレクトリがコピーされているか確認
# app/, docs/, iac/ などのディレクトリが存在するか
# .gitディレクトリはクローン時に作成された元のものが残っているか

# ファイルをステージングしてコミット
git add .
git commit -m "Initial commit for ECS Forgate project"

# リモートリポジトリにプッシュ
git push origin main

# 【確認ポイント】
# プッシュが成功したか確認
# GitHubのWebUIにアクセスして、ファイルがリポジトリに反映されているか確認

# 【エラー対応】
# プッシュに失敗する場合は、認証情報が正しいか確認
# 必要に応じてGitHubの認証情報を設定：
# git config credential.helper store
# git push origin main  # ここでユーザー名とパスワード（またはトークン）を入力
```

### 【実行環境: Windows（ブラウザ）+ WSL】
## 2. GitHub Personal Access Token (PAT)の作成

AWS CodePipelineがGitHubリポジトリにアクセスするためのトークンを作成します。

### 2.1 既存PAT確認と新規PAT作成手順

まず、Secrets Managerに保存されている既存のGitHubトークンを確認します。

```bash
# WSL環境で実行
# Secrets Managerに保存されているGitHubトークンが有効か確認
# （警告：このコマンドは機密情報を表示するため、安全な環境で実行してください）
# aws secretsmanager get-secret-value --secret-id github/token --query "SecretString" --output text | jq .

# より安全な確認方法（トークンの値を表示せずに）
aws secretsmanager describe-secret --secret-id github/token

# 【確認ポイント】
# シークレットが存在し、最近更新されているか確認
# LastChangedDateが90日以内かチェック（GitHubトークンの推奨有効期限）
```

既存のトークンがない場合や期限切れの場合は、新しいトークンを作成します：

1. GitHubアカウントにログイン
2. 右上のプロファイルアイコンをクリック → Settings
3. 左サイドバーの「Developer settings」をクリック
4. 「Personal access tokens」 → 「Tokens (classic)」をクリック
5. 「Generate new token」 → 「Generate new token (classic)」をクリック
6. トークンに名前を付ける（例：ECSForgate-CICD-2025-04）
7. 有効期限を設定（例：90 days）
8. 以下の権限を選択：
   - `repo` （すべてのサブ項目）
   - `admin:repo_hook` （サブ項目の `write:repo_hook` も選択）
9. 「Generate token」ボタンをクリック
10. 生成されたトークンをコピーして安全な場所に一時的に保存（表示は一度だけ）

### 2.2 トークンの有効性確認

生成したPATが正しく機能するか確認します。

```bash
# WSL環境で実行
# 環境変数にトークンを設定（トークンを直接表示しないよう注意）
read -s -p "GitHubトークンを入力してください: " GITHUB_TOKEN
echo

# トークンの形式を確認
if [[ $GITHUB_TOKEN == ghp_* ]]; then
  echo "トークン形式が正しいです: ghp_***...(最初の4文字のみ表示)"
else
  echo "警告: トークン形式が一般的な形式と異なります。GitHubのPATは通常 'ghp_' で始まります。"
fi

# トークンが有効か確認（GitHubユーザー情報取得）
GITHUB_USER="k-tanaka-522"  # 実際のGitHubユーザー名に置き換え
REPO_NAME="AWS-ECS-Forgate"  # 実際のリポジトリ名に置き換え

# APIリクエストでリポジトリにアクセスできるか確認
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME")

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "トークンは有効で、リポジトリにアクセスできます。"
else
  echo "警告: トークンでリポジトリにアクセスできません。HTTPステータス: $HTTP_STATUS"
  echo "トークンの権限とリポジトリ名が正しいか確認してください。"
fi

# 環境変数からトークンを削除（セキュリティ対策）
unset GITHUB_TOKEN
```

### 【実行環境: WSL】
## 3. AWS Secrets Managerへのトークン保存

GitHubトークンをAWS Secrets Managerに安全に保存します。トークンがSecrets Managerに既に存在する場合は更新します。

```bash
# WSL環境で実行
# 環境変数にトークンを安全に設定
echo "GitHubトークンを安全に入力してください（入力内容は表示されません）"
read -s GITHUB_TOKEN
echo

# トークンの有無を確認
aws secretsmanager describe-secret --secret-id github/token > /dev/null 2>&1
SECRET_EXISTS=$?

if [ $SECRET_EXISTS -eq 0 ]; then
  # 既存のシークレットを更新
  echo "github/tokenシークレットが存在します。更新します..."
  aws secretsmanager update-secret \
    --secret-id github/token \
    --description "GitHub Personal Access Token for ECSForgate CI/CD" \
    --secret-string "{\"token\":\"$GITHUB_TOKEN\"}"
  
  # 【確認ポイント】
  # 成功時の出力例：
  # {
  #     "ARN": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:github/token-Abcdef",
  #     "Name": "github/token",
  #     "VersionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  # }
  
  echo "シークレットが正常に更新されました。"
else
  # 新規シークレットを作成
  echo "github/tokenシークレットが存在しません。新規作成します..."
  aws secretsmanager create-secret \
    --name "github/token" \
    --description "GitHub Personal Access Token for ECSForgate CI/CD" \
    --secret-string "{\"token\":\"$GITHUB_TOKEN\"}"
  
  # 【確認ポイント】
  # 成功時の出力例：
  # {
  #     "ARN": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:github/token-Abcdef",
  #     "Name": "github/token",
  #     "VersionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  # }

  # シークレットへのタグ付け
  aws secretsmanager tag-resource \
    --secret-id "github/token" \
    --tags Key=Project,Value=ECSForgate Key=Service,Value=CICD Key=Confidentiality,Value=High
  
  echo "シークレットが正常に作成されました。"
fi

# シークレットが正しく作成/更新されたか確認
aws secretsmanager describe-secret --secret-id github/token --query "ARN"

# 【確認ポイント】
# シークレットのARNが表示されれば成功
# 例: "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:github/token-Abcdef"

# 環境変数からトークンを削除（セキュリティ対策）
unset GITHUB_TOKEN
```

### 【実行環境: WSL】
## 4. CI/CDパイプラインのデプロイ

### 4.1 AWSアカウントIDとリージョンの取得

```bash
# WSL環境で実行
# AWSアカウントIDとリージョンを変数に格納（後続のコマンドで使用）
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "AWS Region: ${AWS_REGION}"

# 【確認ポイント】
# AWSアカウントIDとリージョンが正しく表示されるか確認
# 例: AWS Account ID: 123456789012
#     AWS Region: ap-northeast-1
```

### 4.2 CI/CDテンプレートの検証

```bash
# WSL環境で実行
# プロジェクトのルートディレクトリに移動
cd /mnt/c/dev2/ECSForgate

# テンプレートの存在を確認
ls -l iac/cloudformation/templates/cicd-github.yaml
if [ $? -ne 0 ]; then
  echo "エラー: cicd-github.yamlファイルが見つかりません。"
  exit 1
fi

# テンプレート構文の検証
./iac/cloudformation/scripts/validate.sh iac/cloudformation/templates/cicd-github.yaml

# 【確認ポイント】
# 成功した場合、出力はありません（エラーがなければ検証成功）
# エラーがある場合は、具体的なエラーメッセージが表示されます

# 【エラー対応】
# テンプレートに構文エラーがある場合は、エラーメッセージを確認し、
# テンプレートを修正してから再度検証を実行してください
```

### 4.3 CI/CDパイプラインのデプロイ（開発環境）

```bash
# WSL環境で実行
# GitHubユーザー、リポジトリ、ブランチの設定
GITHUB_OWNER="k-tanaka-522"  # 実際のGitHubユーザー名に置き換え
GITHUB_REPO="AWS-ECS-Forgate"  # 実際のリポジトリ名に置き換え
GITHUB_BRANCH="develop"
ENVIRONMENT="dev"

# デプロイスクリプトが存在するか確認
ls -l ./iac/cloudformation/scripts/deploy-cicd-github.sh
if [ $? -ne 0 ]; then
  echo "エラー: deploy-cicd-github.shスクリプトが見つかりません。"
  exit 1
fi

# 実行権限を確認し、必要に応じて付与
if [ ! -x ./iac/cloudformation/scripts/deploy-cicd-github.sh ]; then
  echo "スクリプトに実行権限を付与します..."
  chmod +x ./iac/cloudformation/scripts/deploy-cicd-github.sh
fi

# 専用スクリプトを使用してデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "${GITHUB_BRANCH}" \
  --environment "${ENVIRONMENT}"

# 【確認ポイント】
# デプロイスクリプトが成功すると、以下のようなメッセージが表示されます：
# "スタックの作成が開始されました: ecsforgate-cicd-dev"
# "スタックの作成が完了しました。"

# デプロイ状況の確認
echo "スタックのステータスを確認しています..."
aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-${ENVIRONMENT}" --query "Stacks[0].StackStatus" --output text

# 【確認ポイント】
# CREATE_COMPLETE または UPDATE_COMPLETE が表示されれば成功
# CREATE_IN_PROGRESS や UPDATE_IN_PROGRESS の場合は、まだ進行中
# ROLLBACK_IN_PROGRESS や CREATE_FAILED の場合は失敗

# 【エラー対応】
# デプロイに失敗した場合は、スタックイベントを確認して失敗の原因を特定：
aws cloudformation describe-stack-events --stack-name "ecsforgate-cicd-${ENVIRONMENT}" --query "StackEvents[?ResourceStatus=='CREATE_FAILED' || ResourceStatus=='UPDATE_FAILED']"
```

### 4.4 CI/CDパイプラインのデプロイ（ステージング環境）

```bash
# WSL環境で実行
# ステージング環境用の変数設定
GITHUB_OWNER="k-tanaka-522"  # 実際のGitHubユーザー名に置き換え
GITHUB_REPO="AWS-ECS-Forgate"  # 実際のリポジトリ名に置き換え
GITHUB_BRANCH="release/*"
ENVIRONMENT="stg"

# ステージング環境用のCI/CDパイプラインをデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "${GITHUB_BRANCH}" \
  --environment "${ENVIRONMENT}"

# デプロイ状況の確認
echo "スタックのステータスを確認しています..."
aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-${ENVIRONMENT}" --query "Stacks[0].StackStatus" --output text
```

### 4.5 CI/CDパイプラインのデプロイ（本番環境）

```bash
# WSL環境で実行
# 本番環境用の変数設定
GITHUB_OWNER="k-tanaka-522"  # 実際のGitHubユーザー名に置き換え
GITHUB_REPO="AWS-ECS-Forgate"  # 実際のリポジトリ名に置き換え
GITHUB_BRANCH="main"
ENVIRONMENT="prd"

# 本番環境用のCI/CDパイプラインをデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "${GITHUB_BRANCH}" \
  --environment "${ENVIRONMENT}"

# デプロイ状況の確認
echo "スタックのステータスを確認しています..."
aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-${ENVIRONMENT}" --query "Stacks[0].StackStatus" --output text
```

### 【実行環境: WSL + Windows（ブラウザ）】
## 5. デプロイ結果の確認

### 5.1 CloudFormationスタックの詳細確認

```bash
# WSL環境で実行
# 環境変数が設定されているか確認（されていない場合は再設定）
if [ -z "$ENVIRONMENT" ]; then
  ENVIRONMENT="dev"  # デフォルトとして開発環境を使用
fi

# スタックの詳細情報を取得
aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-${ENVIRONMENT}" --query "Stacks[0].[StackName,StackStatus,CreationTime,LastUpdatedTime]" --output table

# 【確認ポイント】
# StackStatusが「CREATE_COMPLETE」または「UPDATE_COMPLETE」であることを確認
# CreationTimeとLastUpdatedTimeが最新であることを確認

# スタックの出力パラメータを確認
aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-${ENVIRONMENT}" --query "Stacks[0].Outputs[]" --output table

# 【確認ポイント】
# 出力パラメータのキーと値が表示されることを確認
# 例: CodePipelineName, CodeBuildProjectName, RepositoryUrl など
```

### 5.2 AWS CodePipelineの確認

```bash
# WSL環境で実行
# CodePipelineの名前を取得（スタックの出力から）
PIPELINE_NAME=$(aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-${ENVIRONMENT}" --query "Stacks[0].Outputs[?OutputKey=='CodePipelineName'].OutputValue" --output text)

# パイプラインの詳細を取得
if [ -n "$PIPELINE_NAME" ]; then
  echo "パイプライン名: ${PIPELINE_NAME}"
  aws codepipeline get-pipeline --name "${PIPELINE_NAME}"
else
  echo "パイプライン名を取得できませんでした。スタックの出力を確認してください。"
  # スタック出力が見つからない場合は、想定されるパイプライン名を試行
  PIPELINE_NAME="ecsforgate-pipeline-${ENVIRONMENT}"
  echo "想定されるパイプライン名 ${PIPELINE_NAME} を使用して確認します..."
  aws codepipeline get-pipeline --name "${PIPELINE_NAME}"
fi

# 【確認ポイント】
# パイプラインの設定が表示されることを確認
# 各ステージ（ソース、ビルド、デプロイ）の設定が正しいか確認

# パイプラインの状態を確認
aws codepipeline get-pipeline-state --name "${PIPELINE_NAME}"

# 【確認ポイント】
# パイプラインの各ステージの状態が表示されることを確認
# latestExecutionが表示され、ステータスが確認できること
```

### 5.3 GitHubウェブフックの確認

GitHubウェブフックが正しく設定されているか確認します。これはGitHubのWebUIで確認する必要があります。

1. GitHubリポジトリにアクセス（例：https://github.com/k-tanaka-522/AWS-ECS-Forgate）
2. 「Settings」タブをクリック
3. 左サイドバーで「Webhooks」をクリック
4. ウェブフックのリスト内にAWS CodePipelineのウェブフックが存在することを確認

以下の点を確認してください：
- ウェブフックのURL: `https://hooks.amazonaws.com/...`
- ペイロードのURLにAWSアカウントとリージョンが含まれている
- 最後の配信が成功している（緑色のチェックマーク）
- エラーがない

### 【実行環境: WSL】
## 6. パイプラインのテスト

### 6.1 ブランチ構造の準備

```bash
# WSL環境で実行
# プロジェクトディレクトリに移動
cd /mnt/c/dev2/ECSForgate-GitHub  # GitHubリポジトリのクローン先ディレクトリ

# 現在のブランチを確認
git branch
# 出力例: * main

# developブランチの作成（まだ存在しない場合）
git checkout -b develop
# または既存のdevelopブランチがある場合
# git checkout develop

# 【確認ポイント】
# ブランチが正しく切り替わったことを確認
git branch
# 出力例: * develop
#         main
```

### 6.2 テスト用の変更をプッシュ

```bash
# WSL環境で実行
# テスト用のファイルを作成またはREADME.mdを更新
echo "# CI/CDパイプラインテスト - $(date)" >> README.md

# 変更をステージング
git add README.md

# 変更をコミット
git commit -m "CI/CDパイプラインのテスト"

# 変更をプッシュ
git push origin develop

# 【確認ポイント】
# プッシュが成功したことを確認
# GitHubのWebUIでもコミットが反映されていることを確認

# 【エラー対応】
# 認証エラーが発生する場合は、GitHubの認証情報を設定：
# git config credential.helper store
# git push origin develop  # ここでユーザー名とパスワード（またはトークン）を入力
```

### 6.3 パイプラインの実行状況確認

```bash
# WSL環境で実行
# パイプライン名を設定（環境に応じて）
ENVIRONMENT="dev"
PIPELINE_NAME="ecsforgate-pipeline-${ENVIRONMENT}"

# 実行状況を確認
aws codepipeline get-pipeline-state --name "${PIPELINE_NAME}"

# 【確認ポイント】
# latestExecutionのステータスがSucceeded、InProgress、またはFailed
# ステージごとの状態とタイムスタンプが表示されること

# 最新の実行を繰り返し確認（10秒ごとに更新）
echo "パイプラインの状態を監視しています（Ctrl+Cで終了）..."
while true; do
  clear
  echo "======== $(date) ========"
  aws codepipeline get-pipeline-state --name "${PIPELINE_NAME}" --query "stageStates[*].[stageName,latestExecution.status]" --output table
  sleep 10
done
```

### 【実行環境: WSL + Windows（ブラウザ）】
## 7. トラブルシューティング

### 7.1 ウェブフックが作成されない場合

```bash
# WSL環境で実行
# ウェブフック作成に必要なリソースとアクセス権をチェック
# Secrets Managerのシークレットが存在するか確認
aws secretsmanager describe-secret --secret-id github/token

# IAMロールとポリシーが正しく設定されているか確認
# スタックにより作成されたIAMロールのリストを取得
aws cloudformation describe-stack-resources --stack-name "ecsforgate-cicd-${ENVIRONMENT}" --query "StackResources[?ResourceType=='AWS::IAM::Role'].PhysicalResourceId" --output text

# 【確認ポイント】
# githubシークレットが存在すること
# IAMロールが存在すること

# CloudFormationのイベントログを確認し、エラーメッセージを特定
aws cloudformation describe-stack-events --stack-name "ecsforgate-cicd-${ENVIRONMENT}" --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].[LogicalResourceId,ResourceStatusReason]" --output table

# 【対応策】
# エラーに応じて以下の対策を実施：
# 1. GitHub PATの権限が不足している場合は、新しいトークンを生成し直し、より広い権限を付与
# 2. Secrets Managerのシークレットが存在しない場合や形式が正しくない場合は、修正
# 3. IAMロールに必要な権限が不足している場合は、ポリシーを修正
```

### 7.2 パイプラインが自動起動しない場合

GitHubウェブフックが正しく設定されているにもかかわらず、パイプラインが自動起動しない場合：

```bash
# WSL環境で実行
# ウェブフックの状態を確認（GitHubのWebUIで）
# 1. GitHubリポジトリにアクセス
# 2. 「Settings」→「Webhooks」に移動
# 3. ウェブフックをクリック
# 4. 「Recent Deliveries」タブを確認

# CodePipelineのステータスを確認
aws codepipeline get-pipeline-state --name "${PIPELINE_NAME}"

# パイプラインを手動で開始してテスト
aws codepipeline start-pipeline-execution --name "${PIPELINE_NAME}"

# 【確認ポイント】
# 手動実行が成功するか
# 実行後のパイプラインステータスが正常に更新されるか

# CloudTrailログで問題を調査（AWSマネジメントコンソールを使用）
echo "CloudTrailでCodePipelineのAPIコールを確認してください。"
```

### 7.3 CloudFormationスタックのデプロイに失敗した場合

```bash
# WSL環境で実行
# スタックイベントを確認して失敗の原因を特定
aws cloudformation describe-stack-events --stack-name "ecsforgate-cicd-${ENVIRONMENT}" --query "StackEvents[?ResourceStatus=='CREATE_FAILED' || ResourceStatus=='UPDATE_FAILED'].[LogicalResourceId,ResourceStatusReason]" --output table

# 【対応策】
# エラーメッセージに基づいてテンプレートを修正

# テンプレートを修正した後、再検証
./iac/cloudformation/scripts/validate.sh iac/cloudformation/templates/cicd-github.yaml

# 再デプロイ前に既存のスタックがROLLBACK_COMPLETE状態の場合は削除が必要
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-${ENVIRONMENT}" --query "Stacks[0].StackStatus" --output text 2>/dev/null || echo "DOES_NOT_EXIST")

if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]; then
  echo "スタックは${STACK_STATUS}状態です。再デプロイ前に削除します..."
  aws cloudformation delete-stack --stack-name "ecsforgate-cicd-${ENVIRONMENT}"
  
  # スタックの削除が完了するまで待機
  echo "スタックの削除を待機しています..."
  aws cloudformation wait stack-delete-complete --stack-name "ecsforgate-cicd-${ENVIRONMENT}"
  echo "スタックの削除が完了しました。"
fi

# 修正したテンプレートで再デプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "${GITHUB_BRANCH}" \
  --environment "${ENVIRONMENT}"
```

### 【実行環境: WSL + Windows（ブラウザ）】
## 8. セキュリティに関する注意事項

### 8.1 GitHub PATのベストプラクティス

GitHub Personal Access Tokenを安全に管理するためのベストプラクティス：

1. **有効期限の設定**
   - トークンには常に有効期限を設定（90日間を推奨）
   - 有効期限切れ前に新しいトークンを生成し、古いトークンを無効化

2. **最小権限の原則**
   - 必要な権限のみを付与（`repo`と`admin:repo_hook`）
   - 不要な権限は付与しない（例：`delete_repo`など）

3. **定期的なローテーション**
   - 少なくとも90日ごとにトークンをローテーション
   - ローテーション手順：
```bash
# WSL環境で実行
     # 新しいトークンを生成（GitHubのWebUIで）
     # 新しいトークンをSecrets Managerに更新
     read -s -p "新しいGitHubトークンを入力: " NEW_GITHUB_TOKEN
     aws secretsmanager update-secret \
       --secret-id github/token \
       --description "GitHub Personal Access Token for ECSForgate CI/CD" \
       --secret-string "{\"token\":\"$NEW_GITHUB_TOKEN\"}"
     unset NEW_GITHUB_TOKEN
     
     # CI/CDパイプラインのウェブフックを再作成（または更新）
     # CloudFormationスタックを更新
     ./iac/cloudformation/scripts/deploy-cicd-github.sh \
       --github-owner "${GITHUB_OWNER}" \
       --github-repo "${GITHUB_REPO}" \
       --github-branch "${GITHUB_BRANCH}" \
       --environment "${ENVIRONMENT}"
     
     # 古いトークンを削除（GitHubのWebUIで）
     ```

4. **トークン漏洩時の対応**
   - トークンが漏洩した疑いがある場合は、即座に無効化
   - GitHubでトークンを削除し、新しいトークンを生成
   - 侵害されたシステムを調査し、不正アクセスの痕跡を確認

### 8.2 IAMのベストプラクティス

AWS IAMに関するセキュリティベストプラクティス：

1. **最小権限の原則**
   - CI/CDパイプラインに必要な最小限の権限のみを付与
   - 必要に応じて権限を細分化し、環境ごとにIAMロールを分離

2. **ロールとポリシーの監査**
   - 定期的に付与された権限を監査
   - AWS IAM Access Analyzerを使用して過剰な権限を特定

3. **クロスアカウントアクセスの制限**
   - 複数のAWSアカウントを使用する場合、アカウント間のアクセスを最小限に制限
   - ロール引き受け（role assumption）に条件を追加

4. **認証情報の安全な管理**
   - AWS認証情報をソースコードに埋め込まない
   - Secrets ManagerやParameter Storeを使用して認証情報を管理

## 参考情報

- [AWS CodePipeline ユーザーガイド](https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/welcome.html)
- [GitHub Webhook ドキュメント](https://docs.github.com/ja/developers/webhooks-and-events/webhooks/about-webhooks)
- [AWS CloudFormation ユーザーガイド](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/Welcome.html)
- [AWS Secrets Manager ユーザーガイド](https://docs.aws.amazon.com/ja_jp/secretsmanager/latest/userguide/intro.html)
- [GitHub Personal Access Tokens セキュリティベストプラクティス](https://docs.github.com/ja/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
