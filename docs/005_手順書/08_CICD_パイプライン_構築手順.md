# CI/CDパイプライン構築手順書

## 目的
本ドキュメントでは、ECSForgateプロジェクトのCI/CDパイプラインを構築する手順を説明します。GitHubとAWS連携による継続的インテグレーション/継続的デリバリー環境を構築し、自動的なビルド、テスト、デプロイを実現します。

## 前提条件
- WSL環境でプロジェクトディレクトリ（`/mnt/c/dev2/ECSForgate/`）にアクセス可能
- AWS CLIが設定済み（AWS認証情報が利用可能）
- GitHub連携が完了している（[07_GitHub_リポジトリ_連携設定手順.md](./07_GitHub_リポジトリ_連携設定手順.md)を実行済み）
- Secrets Managerに「github/token」が登録済み

## 関連設計書
- [CI/CD詳細設計書](/docs/002_設計/components/cicd-design.md)

## 1. 環境変数の設定

```bash
# WSL環境で実行
# AWS情報とGitHub情報の設定
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
GITHUB_OWNER="k-tanaka-522"  # 実際のGitHubアカウント名に変更
GITHUB_REPO="AWS-ECS-Forgate"  # 実際のリポジトリ名に変更

# 確認出力
echo "使用する設定:"
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "AWS Region: ${AWS_REGION}"
echo "GitHub Owner: ${GITHUB_OWNER}"
echo "GitHub Repository: ${GITHUB_REPO}"
```

## 2. buildspecファイルの確認

```bash
# WSL環境で実行
cd /mnt/c/dev2/ECSForgate

# buildspecファイルの確認
ls -la buildspec-dev.yml buildspec-stg.yml buildspec-prd.yml

# buildspecファイルの内容確認（開発環境の例）
cat buildspec-dev.yml | grep -A 5 "BASE_IMAGE_TAG"

# 【確認ポイント】
# - BASE_IMAGE_TAG: "base-2025-Q2-frozen" が設定されていること
# - 適切な環境変数が設定されていること
```

## 3. CI/CDテンプレートの検証

```bash
# WSL環境で実行
# CloudFormationテンプレートの検証
./iac/cloudformation/scripts/validate.sh iac/cloudformation/templates/cicd-github.yaml
```

## 4. 開発環境(dev)パイプラインのデプロイ

```bash
# WSL環境で実行
# デプロイスクリプトに実行権限付与
chmod +x ./iac/cloudformation/scripts/deploy-cicd-github.sh

# 開発環境パイプラインのデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "develop" \
  --environment "dev"

# デプロイ状況の確認
aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-dev" \
  --query "Stacks[0].StackStatus" --output text
```

## 5. デプロイ結果の確認

```bash
# WSL環境で実行
# スタックの出力情報取得
aws cloudformation describe-stacks --stack-name "ecsforgate-cicd-dev" \
  --query "Stacks[0].Outputs[]" --output table

# パイプライン名の取得
PIPELINE_NAME=$(aws cloudformation describe-stacks \
  --stack-name "ecsforgate-cicd-dev" \
  --query "Stacks[0].Outputs[?OutputKey=='CodePipelineName'].OutputValue" \
  --output text)

echo "パイプライン名: ${PIPELINE_NAME}"

# パイプライン状態の確認
aws codepipeline get-pipeline-state --name "${PIPELINE_NAME}" \
  --query "stageStates[*].[stageName,latestExecution.status]" --output table
```

## 6. パイプラインのテスト

パイプラインをテストするには、GitHub上のdevelopブランチに変更をコミットします：

```bash
# WSL環境で実行
# GitHubリポジトリのクローン先に移動
cd /mnt/c/dev2/ECSForgate-GitHub

# developブランチへの切り替え（または作成）
git checkout develop 2>/dev/null || git checkout -b develop

# テスト用の変更
echo "# CI/CDパイプラインテスト - $(date)" >> README.md
git add README.md
git commit -m "CI/CDパイプラインのテスト"
git push origin develop

# パイプラインの実行状況を確認
aws codepipeline get-pipeline-state --name "${PIPELINE_NAME}" \
  --query "stageStates[*].[stageName,latestExecution.status]" --output table
```

## 7. トラブルシューティング

### パイプラインが起動しない場合
- GitHubウェブフックの設定を確認（GitHubリポジトリの「Settings」→「Webhooks」）
- Secrets Managerの「github/token」が正しく設定されているか確認
- 手動でパイプラインを実行してテスト：
  ```bash
  aws codepipeline start-pipeline-execution --name "${PIPELINE_NAME}"
  ```

### ビルド失敗の確認
```bash
# WSL環境で実行
# ビルドプロジェクト名の取得
BUILD_PROJECT=$(aws cloudformation describe-stacks \
  --stack-name "ecsforgate-cicd-dev" \
  --query "Stacks[0].Outputs[?OutputKey=='CodeBuildProjectName'].OutputValue" \
  --output text)

# 最新のビルドIDを取得
BUILD_ID=$(aws codebuild list-builds-for-project \
  --project-name "${BUILD_PROJECT}" \
  --sort-order DESCENDING \
  --max-items 1 \
  --query "ids[0]" \
  --output text)

# ビルドの詳細を確認
aws codebuild batch-get-builds --ids "${BUILD_ID}" \
  --query "builds[0].[buildStatus,phases[*].phaseStatus]" --output table
```

## 便利なコマンド集

### パイプラインの状態監視
```bash
# WSL環境で実行
# パイプラインの状態をリアルタイムで監視（Ctrl+Cで終了）
watch -n 10 "aws codepipeline get-pipeline-state --name ${PIPELINE_NAME} \
  --query \"stageStates[*].[stageName,latestExecution.status]\" --output table"
```

### ステージング・本番環境パイプラインの構築（オプション）
```bash
# WSL環境で実行
# ステージング環境用パイプライン
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "release/*" \
  --environment "stg"

# 本番環境用パイプライン
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "${GITHUB_OWNER}" \
  --github-repo "${GITHUB_REPO}" \
  --github-branch "main" \
  --environment "prd"
```
