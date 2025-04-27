# CI/CDパイプライン構築手順

## 関連設計書
- [CI/CD詳細設計書](/docs/002_設計/components/cicd-design.md)
- [CloudFormation詳細設計書](/docs/002_設計/components/cloudformation-design.md)
- [ECS Fargate詳細設計書](/docs/002_設計/components/ecs-design.md)

## 目的
本ドキュメントでは、ECSForgateプロジェクトのCI/CDパイプラインを構築するための手順を説明します。CI/CDパイプラインにより、コードの変更からビルド、テスト、デプロイまでの一連のプロセスを自動化します。

## 前提条件
- AWS CLIがインストールされ、適切な権限を持つIAMユーザーで設定済み
- GitHubリポジトリが作成済み
- GitHubトークンがSecrets Managerに保存済み
- ECRリポジトリが作成済み
- 基本インフラストラクチャが構築済み

## 1. CI/CD構築前準備

### 1.1 必要なCloudFormationテンプレートの確認

CI/CDパイプラインを構築するためのCloudFormationテンプレートを確認します。

```bash
# テンプレートファイルの確認
cd /mnt/c/dev2/ECSForgate
ls -l iac/cloudformation/templates/cicd-github.yaml
cat iac/cloudformation/templates/cicd-github.yaml | head -n 20
```

### 1.2 環境別パラメータファイルの確認

各環境（dev/stg/prd）のパラメータファイルを確認します。

```bash
# 各環境のパラメータファイルを確認
ls -l iac/cloudformation/config/*/parameters.json

# 開発環境のパラメータファイルを表示
cat iac/cloudformation/config/dev/parameters.json
```

### 1.3 環境別buildspec.ymlファイルの確認

各環境のビルド仕様ファイルを確認します。

```bash
# 環境別buildspecファイルの確認
ls -l buildspec-dev.yml buildspec-stg.yml buildspec-prd.yml

# 開発環境のbuildspecファイルを表示
cat buildspec-dev.yml
```

## 2. 環境別buildspec.ymlファイルの作成

各環境に対応するbuildspec.ymlファイルが存在することを確認し、必要に応じて作成または修正します。

### 2.1 開発環境（dev）のbuildspec.yml

```bash
# 開発環境のbuildspec.ymlを確認し、必要に応じて編集
cat buildspec-dev.yml

# 必要に応じて修正
# nano buildspec-dev.yml
```

重要なポイント：
- ベースイメージの参照（`BASE_IMAGE_REPO`と`BASE_IMAGE_TAG`）
- ECRリポジトリ名の設定
- アプリケーションのビルドとテストコマンド
- デプロイ設定（環境変数、IAMロール参照）
- タグ命名規則（`dev-${COMMIT_HASH}-${BUILD_DATE}`）

### 2.2 ステージング環境（stg）のbuildspec.yml

```bash
# ステージング環境のbuildspec.ymlを確認し、必要に応じて編集
cat buildspec-stg.yml

# 必要に応じて修正
# nano buildspec-stg.yml
```

ステージング環境特有の設定：
- セマンティックバージョニングタグ（`stg-rc-${VERSION}`）
- 開発環境より厳格なテスト
- 環境変数の設定

### 2.3 本番環境（prd）のbuildspec.yml

```bash
# 本番環境のbuildspec.ymlを確認し、必要に応じて編集
cat buildspec-prd.yml

# 必要に応じて修正
# nano buildspec-prd.yml
```

本番環境特有の設定：
- 凍結タグ付与（`${VERSION}-frozen`）
- 厳格なテストと検証
- 本番環境用の環境変数設定

## 3. CI/CDテンプレートの検証とデプロイ

### 3.1 CI/CDテンプレートの検証

```bash
# テンプレート構文の検証
cd /mnt/c/dev2/ECSForgate
./iac/cloudformation/scripts/validate.sh iac/cloudformation/templates/cicd-github.yaml

# または直接AWS CLIを使用
aws cloudformation validate-template --template-body file://iac/cloudformation/templates/cicd-github.yaml
```

### 3.2 開発環境(dev)へのデプロイ

```bash
# 専用スクリプトを使用
cd /mnt/c/dev2/ECSForgate
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "k-tanaka-522" \
  --github-repo "AWS-ECS-Forgate" \
  --github-branch "develop" \
  --environment dev

# デプロイ状況の確認
aws cloudformation describe-stacks --stack-name dev-ecsforgate-cicd-stack --query "Stacks[0].StackStatus"
```

### 3.3 ステージング環境(stg)へのデプロイ

```bash
# ステージング環境用のCI/CDパイプラインをデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "k-tanaka-522" \
  --github-repo "AWS-ECS-Forgate" \
  --github-branch "release/*" \
  --environment stg

# デプロイ状況の確認
aws cloudformation describe-stacks --stack-name stg-ecsforgate-cicd-stack --query "Stacks[0].StackStatus"
```

### 3.4 本番環境(prd)へのデプロイ

```bash
# 本番環境用のCI/CDパイプラインをデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "k-tanaka-522" \
  --github-repo "AWS-ECS-Forgate" \
  --github-branch "main" \
  --environment prd

# デプロイ状況の確認
aws cloudformation describe-stacks --stack-name prd-ecsforgate-cicd-stack --query "Stacks[0].StackStatus"
```

## 4. パイプラインリソースの確認

### 4.1 CodePipelineの確認

```bash
# 開発環境のパイプラインを確認
aws codepipeline get-pipeline --name ecsforgate-pipeline-dev

# ステージング環境のパイプラインを確認
aws codepipeline get-pipeline --name ecsforgate-pipeline-stg

# 本番環境のパイプラインを確認
aws codepipeline get-pipeline --name ecsforgate-pipeline-prd
```

### 4.2 CodeBuildプロジェクトの確認

```bash
# 開発環境のCodeBuildプロジェクトを確認
aws codebuild batch-get-projects --names ecsforgate-build-dev

# ステージング環境のCodeBuildプロジェクトを確認
aws codebuild batch-get-projects --names ecsforgate-build-stg

# 本番環境のCodeBuildプロジェクトを確認
aws codebuild batch-get-projects --names ecsforgate-build-prd
```

### 4.3 IAMロールとポリシーの確認

```bash
# CodeBuildサービスロールを確認
aws iam get-role --role-name ecsforgate-codebuild-service-role-dev

# CodePipelineサービスロールを確認
aws iam get-role --role-name ecsforgate-pipeline-service-role-dev
```

## 5. CI/CDパイプラインのテスト

### 5.1 テスト用のコミットプッシュ

```bash
# 開発ブランチに切り替え
git checkout -b develop
# または既存のdevelopブランチがある場合
# git checkout develop

# テスト用のファイルを変更
echo "# CI/CDパイプラインテスト - $(date)" >> README.md

# 変更をコミットしてプッシュ
git add README.md
git commit -m "CI/CDパイプラインのテスト"
git push origin develop
```

### 5.2 パイプラインの実行状態確認

```bash
# パイプラインの実行状態を確認
aws codepipeline get-pipeline-state --name ecsforgate-pipeline-dev
```

### 5.3 ビルドログの確認

```bash
# 最新のビルドを取得
BUILD_ID=$(aws codebuild list-builds-for-project --project-name ecsforgate-build-dev --query "ids[0]" --output text)

# ビルドログを取得
aws codebuild batch-get-builds --ids $BUILD_ID --query "builds[0].logs.deepLink"
```

## 6. ブランチ戦略の実装確認

### 6.1 開発環境（develop）

```bash
# developブランチにコミットすると、開発環境(dev)にデプロイされることを確認
git checkout develop
# 変更してプッシュ
git push origin develop
```

### 6.2 ステージング環境（release/*）

```bash
# リリースブランチを作成し、ステージング環境(stg)にデプロイされることを確認
git checkout -b release/v1.0.0
# 変更してプッシュ
git push origin release/v1.0.0
```

### 6.3 本番環境（main）

```bash
# mainブランチに反映し、本番環境(prd)にデプロイされることを確認
git checkout main
git merge --no-ff release/v1.0.0
git push origin main
```

## 7. トラブルシューティング

### 7.1 パイプラインの実行に失敗した場合

1. パイプラインの実行状態を確認
   ```bash
   aws codepipeline get-pipeline-state --name ecsforgate-pipeline-dev
   ```

2. 失敗したステージとアクションを特定
   ```bash
   aws codepipeline get-pipeline-execution --pipeline-name ecsforgate-pipeline-dev --pipeline-execution-id <execution-id>
   ```

3. CodeBuildのログを確認（ビルドに失敗した場合）
   ```bash
   aws codebuild batch-get-builds --ids <build-id> --query "builds[0].logs.deepLink"
   ```

### 7.2 CloudFormationデプロイに失敗した場合

```bash
# スタックの失敗イベントを確認
aws cloudformation describe-stack-events --stack-name dev-ecsforgate-cicd-stack --query "StackEvents[?ResourceStatus=='CREATE_FAILED' || ResourceStatus=='UPDATE_FAILED']"
```

### 7.3 アクセス権限の問題がある場合

```bash
# IAMロールに必要なポリシーが設定されているかを確認
aws iam list-attached-role-policies --role-name ecsforgate-codebuild-service-role-dev
aws iam list-attached-role-policies --role-name ecsforgate-pipeline-service-role-dev
```

## 8. CI/CD構成の更新・修正方法

### 8.1 buildspec.ymlの更新

```bash
# buildspec.ymlを更新
nano buildspec-dev.yml

# 変更をコミット
git add buildspec-dev.yml
git commit -m "Update buildspec for better testing"
git push origin develop
```

### 8.2 CloudFormationテンプレートの更新

```bash
# テンプレートを編集
nano iac/cloudformation/templates/cicd-github.yaml

# 変更を検証
./iac/cloudformation/scripts/validate.sh iac/cloudformation/templates/cicd-github.yaml

# 更新されたテンプレートをデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "k-tanaka-522" \
  --github-repo "AWS-ECS-Forgate" \
  --github-branch "develop" \
  --environment dev
```

## 参考情報

- [AWS CodePipeline ユーザーガイド](https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/welcome.html)
- [AWS CodeBuild ユーザーガイド](https://docs.aws.amazon.com/ja_jp/codebuild/latest/userguide/welcome.html)
- [AWS CloudFormation ユーザーガイド](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/Welcome.html)
- [buildspec.yml リファレンス](https://docs.aws.amazon.com/ja_jp/codebuild/latest/userguide/build-spec-ref.html)
- [Git ブランチ戦略ベストプラクティス](https://git-scm.com/book/ja/v2/Git-%E3%81%AE%E3%83%96%E3%83%A9%E3%83%B3%E3%83%81%E6%A9%9F%E8%83%BD-%E3%83%96%E3%83%A9%E3%83%B3%E3%83%81%E3%81%A8%E3%83%9E%E3%83%BC%E3%82%B8%E3%81%AE%E5%9F%BA%E6%9C%AC)
