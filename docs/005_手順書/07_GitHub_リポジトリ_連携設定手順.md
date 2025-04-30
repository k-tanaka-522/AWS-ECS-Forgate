# GitHubリポジトリ連携設定手順

## 目的
本ドキュメントでは、AWS CodePipelineとGitHubリポジトリを連携させるための設定手順を説明します。この連携により、GitHubリポジトリへのコードプッシュをトリガーとして、自動的にCI/CDパイプラインが実行されるようになります。

## 前提条件
- WSL環境でプロジェクトディレクトリ（`/mnt/c/dev2/ECSForgate/`）にアクセス可能
- AWS CLIが設定済み（AWS認証情報が利用可能）
- GitHubアカウントとリポジトリの管理権限を保有

## 関連設計書
- [CI/CD詳細設計書](/docs/002_設計/components/cicd-design.md)
- [CloudFormation詳細設計書](/docs/002_設計/components/cloudformation-design.md)

## 1. GitHubリポジトリの準備

### 1.1 GitHubリポジトリの確認

```bash
# WSL環境で実行
# GitHubユーザー名とリポジトリ名を設定
GITHUB_USER="k-tanaka-522"  # 実際のGitHubユーザー名に置き換え
REPO_NAME="AWS-ECS-Forgate"  # 実際のリポジトリ名に置き換え

# 確認のみ実行（実際にクローンはしない）
echo "連携対象のGitHubリポジトリ: https://github.com/$GITHUB_USER/$REPO_NAME"
```

## 2. GitHub Personal Access Token (PAT)の準備

AWS CodePipelineがGitHubリポジトリにアクセスするためのトークンを準備します。

### 2.1 GitHubトークンの作成（トークンがない場合）

1. GitHubアカウントにログイン
2. 右上のプロファイルアイコン → Settings → Developer settings
3. Personal access tokens → Generate new token (classic)
4. 以下の設定で生成：
   - 名前: ECSForgate-CICD
   - 有効期限: 90 days
   - スコープ: repo (全て), admin:repo_hook (write:repo_hook)
5. トークンを安全な場所に一時保存（一度しか表示されない）

## 3. AWS Secrets Managerへのトークン登録

トークンをAWS Secrets Managerに保存します。

### 3.1 スクリプトファイルの作成

```bash
# WSL環境で実行
# スクリプトファイルを作成
vi create_ASMgithubtoken.sh
```

ファイルが開いたら、以下の内容を貼り付けます：

```bash
#!/bin/bash
# 環境変数にトークンを設定（セキュリティのため表示なし）
read -s -p "GitHubトークンを入力: " GITHUB_TOKEN
echo

# シークレットの作成または更新
aws secretsmanager describe-secret --secret-id github/token > /dev/null 2>&1
if [ $? -eq 0 ]; then
  # 既存シークレットを更新
  aws secretsmanager update-secret \
    --secret-id github/token \
    --secret-string "{\"token\":\"$GITHUB_TOKEN\"}"
else
  # 新規シークレット作成
  aws secretsmanager create-secret \
    --name github/token \
    --secret-string "{\"token\":\"$GITHUB_TOKEN\"}"
  
  # タグ付け
  aws secretsmanager tag-resource \
    --secret-id github/token \
    --tags Key=Project,Value=ECSForgate
fi

# 環境変数からトークンを削除
unset GITHUB_TOKEN
```

### 3.2 スクリプトの実行と削除

```bash
# WSL環境で実行
# スクリプトに実行権限を付与
chmod +x create_ASMgithubtoken.sh

# スクリプトを実行
./create_ASMgithubtoken.sh

# 実施成功後は、スクリプトは削除してください
rm -f create_ASMgithubtoken.sh
```
## 4. CI/CDパイプラインのデプロイ

環境ごとにCI/CDパイプラインをデプロイします。

### 4.1 環境変数の設定

```bash
# WSL環境で実行
# 必要な情報を取得・設定
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
GITHUB_OWNER="k-tanaka-522"  # 実際のユーザー名に変更
GITHUB_REPO="AWS-ECS-Forgate"  # 実際のリポジトリ名に変更

# 確認出力
echo "使用する設定:"
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "AWS Region: ${AWS_REGION}"
echo "GitHub Owner: ${GITHUB_OWNER}"
echo "GitHub Repository: ${GITHUB_REPO}"
```

### 4.2 開発環境(dev)パイプラインのデプロイ

まず、CloudFormationテンプレートの検証と、デプロイスクリプトの実行権限を付与します。

```bash
# WSL環境で実行
# ECSForgateプロジェクトディレクトリに移動
cd /mnt/c/dev2/ECSForgate

# テンプレート検証
./iac/cloudformation/scripts/validate.sh iac/cloudformation/templates/cicd-github.yaml

# デプロイスクリプトに実行権限付与
chmod +x ./iac/cloudformation/scripts/deploy-cicd-github.sh
```

次に、パイプラインのデプロイを実行します。

```bash
# WSL環境で実行
# パイプラインのデプロイ（ECSForgateプロジェクトディレクトリで実行）
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "develop" \
  --environment "dev"
```

デプロイ後、スタックの状態を確認します。

```bash
# WSL環境で実行
# デプロイ状況の確認
aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-dev" \
  --query "Stacks[0].StackStatus" --output text
```

### 4.3 ステージング環境(stg)パイプラインのデプロイ（オプション）

```bash
# WSL環境で実行
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "release/*" \
  --environment "stg"
```

### 4.4 本番環境(prd)パイプラインのデプロイ（オプション）

```bash
# WSL環境で実行
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "main" \
  --environment "prd"
```

## 5. デプロイ結果の確認

### 5.1 CloudFormationスタックの確認

```bash
# WSL環境で実行
# スタックの状態と出力を確認
aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-dev" \
  --query "Stacks[0].[StackName,StackStatus]" --output table

aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-dev" \
  --query "Stacks[0].Outputs[]" --output table
```

### 5.2 GitHubウェブフックの確認

GitHubのWebUIで確認します：
1. GitHubリポジトリの「Settings」→「Webhooks」
2. AWS CodePipelineのウェブフックが存在することを確認
3. ウェブフックのURL：`https://hooks.amazonaws.com/...`

## 6. パイプラインのテスト（オプション）

パイプラインをテストする場合、GitHubリポジトリに変更をプッシュして、自動的にパイプラインが起動することを確認します。

### 6.1 パイプライン名の取得

```bash
# WSL環境で実行
# CloudFormationスタックの出力からパイプライン名を取得
PIPELINE_NAME=$(aws cloudformation describe-stacks \
  --stack-name "ecsforgate-cicd-dev" \
  --query "Stacks[0].Outputs[?OutputKey=='PipelineName'].OutputValue" \
  --output text)

echo "パイプライン名: ${PIPELINE_NAME}"
```

### 6.2 パイプラインの手動起動

GitHubの連携が完了するまで待つのではなく、パイプラインを手動で起動してテストすることもできます。

```bash
# WSL環境で実行
# パイプラインを手動で起動
aws codepipeline start-pipeline-execution --name "${PIPELINE_NAME}"

# パイプラインの実行状況を確認
aws codepipeline get-pipeline-state --name "${PIPELINE_NAME}" \
  --query "stageStates[*].[stageName,latestExecution.status]" --output table
```

## トラブルシューティング

### ウェブフックが作成されない場合

ウェブフックが正しく作成されない場合、以下の点を確認してください：

```bash
# WSL環境で実行
# 1. シークレット `github/token` の存在を確認
aws secretsmanager describe-secret --secret-id github/token

# 2. トークンの形式を確認（valueは表示されません）
aws secretsmanager get-secret-value --secret-id github/token \
  --query SecretString --output text
```

その他の確認ポイント：
- GitHubトークンの権限を確認（repo、admin:repo_hook）
- IAMロールの権限を確認
- CloudFormationスタックの作成ログでエラーを確認

### パイプラインが自動起動しない場合

パイプラインが自動起動しない場合、以下を確認してください：

1. GitHubのWebUIでウェブフックを確認：
   - GitHubリポジトリの「Settings」→「Webhooks」
   - 「Recent Deliveries」で配信状況を確認
   
2. パイプラインを手動で開始して動作確認：
```bash
# WSL環境で実行
aws codepipeline start-pipeline-execution --name "${PIPELINE_NAME}"
```

3. CloudWatchログでエラーを確認：
```bash
# WSL環境で実行
# CodePipelineのログを確認
aws logs describe-log-groups --log-group-name-prefix "/aws/codepipeline"
```

## セキュリティのベストプラクティス

### GitHub PAT管理
- トークンには有効期限を設定（90日推奨）
- 必要な権限のみを付与
- 定期的にローテーション
- トークン漏洩時は即座に無効化

## 参考情報
- [AWS CodePipeline ユーザーガイド](https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/welcome.html)
- [GitHub Webhook ドキュメント](https://docs.github.com/ja/developers/webhooks-and-events/webhooks/about-webhooks)
