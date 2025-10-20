# GitHub Actions CI/CD Workflows

このディレクトリには、AWS Multi-Account構成のCI/CDパイプラインが含まれています。

## ワークフロー一覧

### 1. `deploy.yml` - アプリケーションデプロイ

**トリガー:**
- `main` ブランチへのpush
- 手動実行 (workflow_dispatch)

**処理内容:**
1. Dockerイメージのビルド（Public Web, Admin Dashboard, Batch Processing）
2. ECRへのプッシュ
3. ECS サービスの更新（強制デプロイ）
4. デプロイ検証

**使用シークレット:**
- `AWS_ACCOUNT_ID` - AWSアカウントID
- `AWS_ACCESS_KEY_ID` - Service Account用アクセスキーID
- `AWS_SECRET_ACCESS_KEY` - Service Account用シークレットアクセスキー

### 2. `infrastructure.yml` - インフラストラクチャデプロイ

**トリガー:**
- 手動実行のみ (workflow_dispatch)

**入力パラメータ:**
- `account_type` - デプロイ先アカウント (`platform` または `service`)
- `environment` - 環境 (`dev` または `prod`)
- `action` - 実行アクション (`create`, `update`, または `delete`)

**処理内容:**
1. CloudFormation Change Setの作成
2. Change Setの確認（差分表示）
3. Change Setの実行
4. スタック作成/更新/削除の完了待機

**使用シークレット:**
- `PLATFORM_AWS_ACCESS_KEY_ID` - Platform Account用アクセスキーID
- `PLATFORM_AWS_SECRET_ACCESS_KEY` - Platform Account用シークレットアクセスキー
- `SERVICE_AWS_ACCESS_KEY_ID` - Service Account用アクセスキーID
- `SERVICE_AWS_SECRET_ACCESS_KEY` - Service Account用シークレットアクセスキー

### 3. `pr-validation.yml` - Pull Request検証

**トリガー:**
- `main` または `develop` ブランチへのPull Request作成/更新

**処理内容:**
1. Lint - アプリケーションコードの静的解析
2. Test - ユニットテスト実行
3. CloudFormation Validation - テンプレートの文法チェック
4. Docker Build - イメージビルド検証（プッシュなし）

**使用シークレット:**
- `AWS_ACCESS_KEY_ID` - CloudFormation検証用
- `AWS_SECRET_ACCESS_KEY` - CloudFormation検証用

## セットアップ

### 1. GitHub Secrets の登録

リポジトリの `Settings` → `Secrets and variables` → `Actions` で以下を登録：

#### Service Account用（アプリケーションデプロイ）

```
AWS_ACCOUNT_ID=123456789012
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=xxxxx...
```

#### Platform Account用（インフラデプロイ）

```
PLATFORM_AWS_ACCESS_KEY_ID=AKIA...
PLATFORM_AWS_SECRET_ACCESS_KEY=xxxxx...
```

#### Service Account用（インフラデプロイ）

```
SERVICE_AWS_ACCESS_KEY_ID=AKIA...
SERVICE_AWS_SECRET_ACCESS_KEY=xxxxx...
```

### 2. IAMユーザー・ロールの権限

#### アプリケーションデプロイ用（Service Account）

必要な権限:
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:GetDownloadUrlForLayer`
- `ecr:BatchGetImage`
- `ecr:PutImage`
- `ecr:InitiateLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:CompleteLayerUpload`
- `ecs:UpdateService`
- `ecs:DescribeServices`

#### インフラデプロイ用（Platform Account / Service Account）

必要な権限:
- `cloudformation:*`
- `s3:*` (Nested Templates用)
- `ec2:*`
- `rds:*`
- `ecs:*`
- `elasticloadbalancing:*`
- `iam:*`
- `logs:*`
- `secretsmanager:*`
- `ssm:*`

## 使用方法

### アプリケーションのデプロイ

#### 自動デプロイ

`main` ブランチにマージすると自動的にデプロイされます：

```bash
git checkout main
git merge feature-branch
git push origin main
```

#### 手動デプロイ

1. GitHubリポジトリの `Actions` タブを開く
2. `Deploy to AWS` ワークフローを選択
3. `Run workflow` をクリック
4. `main` ブランチを選択して実行

### インフラストラクチャのデプロイ

#### Platform Accountの初回デプロイ

1. GitHubリポジトリの `Actions` タブを開く
2. `Deploy Infrastructure` ワークフローを選択
3. `Run workflow` をクリック
4. 以下のパラメータを入力：
   - Account type: `platform`
   - Environment: `dev`
   - Action: `create`
5. `Run workflow` をクリック

#### Service Accountの初回デプロイ

Platform Accountデプロイ後、以下の順番で実行：

1. **Network スタック**
   - Account type: `service`
   - Environment: `dev`
   - Action: `create`

2. **Database スタック** (Networkスタック完了後)
   - Account type: `service`
   - Environment: `dev`
   - Action: `create`

3. **Compute スタック** (Databaseスタック完了後)
   - Account type: `service`
   - Environment: `dev`
   - Action: `create`

#### インフラ更新

Action を `update` に変更して実行します。

#### インフラ削除

**注意:** 削除は逆順で実行してください。

1. Compute スタック → Database スタック → Network スタック の順で削除
2. 最後に Platform Account を削除

### Pull Request検証

PRを作成すると自動的に検証が実行されます：

```bash
git checkout -b feature-new-feature
# ... 変更を加える
git push origin feature-new-feature
# GitHubでPRを作成
```

検証項目:
- ✅ Lint チェック
- ✅ ユニットテスト
- ✅ CloudFormation テンプレート検証
- ✅ Dockerイメージビルド

## ワークフロー実行の確認

### 1. GitHub Actions UI

リポジトリの `Actions` タブで実行状況を確認できます。

### 2. AWS Console

**ECS デプロイ確認:**
```bash
aws ecs describe-services \
  --cluster myapp-dev-cluster \
  --services myapp-dev-public-web \
  --region ap-northeast-1
```

**CloudFormation デプロイ確認:**
```bash
aws cloudformation describe-stacks \
  --stack-name myapp-dev-platform \
  --region ap-northeast-1
```

## トラブルシューティング

### ECRプッシュが失敗する

**エラー:** `denied: Your authorization token has expired`

**解決策:** GitHub Secretsの `AWS_ACCESS_KEY_ID` と `AWS_SECRET_ACCESS_KEY` を確認

---

**エラー:** `repository does not exist`

**解決策:** ECRリポジトリが作成されているか確認

```bash
aws ecr create-repository --repository-name myapp/public-web --region ap-northeast-1
```

### ECS デプロイが失敗する

**エラー:** `service myapp-dev-public-web not found`

**解決策:** インフラ（Compute Stack）がデプロイされているか確認

---

**エラー:** `Task failed to start`

**解決策:**
1. ECS タスクログを確認
2. 環境変数（Secrets Manager/Parameter Store）が正しく設定されているか確認
3. IAM Task Execution Roleの権限を確認

### CloudFormation デプロイが失敗する

**エラー:** `Parameter validation failed`

**解決策:** `infra/platform/parameters-dev.json` または `infra/service/parameters-dev.json` のパラメータ値を確認

---

**エラー:** `CREATE_FAILED - Resource already exists`

**解決策:** 既存のリソースを削除するか、スタック名を変更

## ベストプラクティス

### 1. 環境ごとのブランチ戦略

- `main` ブランチ → 開発環境 (dev)
- `release` ブランチ → 本番環境 (prod)

### 2. タグ戦略

Dockerイメージには以下のタグを付与：
- `latest` - 最新ビルド
- `<commit-sha>` - コミットSHA (例: `a1b2c3d`)
- `v1.0.0` - セマンティックバージョニング（本番リリース時）

### 3. ロールバック

デプロイに失敗した場合、前のイメージタグに戻す：

```bash
aws ecs update-service \
  --cluster myapp-dev-cluster \
  --service myapp-dev-public-web \
  --task-definition myapp-dev-public-web:123 \
  --force-new-deployment \
  --region ap-northeast-1
```

### 4. Change Setsの活用

インフラ変更時は必ずChange Setで差分を確認してから実行します。

## 参考リンク

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Actions for GitHub](https://github.com/aws-actions)
- [CloudFormation Change Sets](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-updating-stacks-changesets.html)
- [Amazon ECS Deployment](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-types.html)
