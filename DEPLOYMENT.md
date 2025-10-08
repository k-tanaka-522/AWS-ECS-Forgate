# CareApp - Deployment Guide

## 概要

このガイドでは、CareApp の POC 環境をAWSにデプロイする手順を説明します。

**アーキテクチャ:**
- **Platform Account**: 共通基盤（Shared VPC、Transit Gateway、Client VPN）
- **Service Account**: 業務システム（3サービス: Public/Admin/Batch）

**デプロイ対象:**
- 4つのCloudFormationスタック（Network, Database, Compute, Monitoring）
- 3つのECSサービス（Public, Admin, Batch）

---

## 前提条件

### 必要なツール
- [x] AWS CLI（v2以上）
- [x] PowerShell 7+（Windows）または Bash（macOS/Linux）
- [x] Docker（v20以上）
- [x] Git
- [x] psql（PostgreSQL クライアント）

### AWS環境
- [x] **Platform Account**: Shared VPC と Transit Gateway が構築済み
- [x] **Service Account**: 適切なIAM権限（CloudFormation、ECS、RDS、VPC等の作成権限）
- [x] Transit Gateway IDの確認済み

---

## デプロイ手順

### ステップ1: リポジトリのクローン

```bash
git clone <repository-url>
cd sampleAWS
```

### ステップ2: Transit Gateway ID の確認

Shared VPCで作成したTransit Gateway IDを確認します。

```bash
aws ec2 describe-transit-gateways \
  --filters "Name=tag:Name,Values=careapp-*-tgw" \
  --query 'TransitGateways[0].TransitGatewayId' \
  --output text
```

出力例: `tgw-0123456789abcdef0`

このIDを `infra/service/parameters-network-poc.json` の `TransitGatewayId` に設定します。

### ステップ3: パラメータファイルの編集

**Service Accountの各パラメータファイルを確認・編集:**

```bash
cd infra/service
```

#### 3-1. Network Parameters

`parameters-network-poc.json`:
```json
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "POC"
  },
  {
    "ParameterKey": "TransitGatewayId",
    "ParameterValue": "tgw-0565abf9ad052b402"  // ← 実際のTGW IDに置き換え
  },
  {
    "ParameterKey": "SharedVpcCIDR",
    "ParameterValue": "10.0.0.0/16"
  }
]
```

#### 3-2. Database Parameters

`parameters-database-poc.json`:
```json
[
  {
    "ParameterKey": "DBMasterUsername",
    "ParameterValue": "postgres"
  },
  {
    "ParameterKey": "DBMasterPassword",
    "ParameterValue": "YourSecurePassword123!"  // ← 安全なパスワードに変更
  }
]
```

**⚠️ 重要**: `DBMasterPassword` は必ず変更してください（最低8文字、大文字・小文字・数字を含む）

#### 3-3. Compute Parameters

`parameters-compute-poc.json`:
```json
[
  {
    "ParameterKey": "ContainerImage",
    "ParameterValue": "public.ecr.aws/docker/library/node:20-alpine"  // 後でECRイメージに変更
  }
]
```

#### 3-4. Monitoring Parameters

`parameters-monitoring-poc.json`:
```json
[
  {
    "ParameterKey": "EmailAddress",
    "ParameterValue": "your-email@example.com"  // ← アラート通知先メールアドレス
  }
]
```

### ステップ4: CloudFormation スタックのデプロイ

**推奨: PowerShellデプロイスクリプトを使用（dry-run対応）**

#### 4-1. Dry-run（変更内容の確認）

```powershell
cd infra/service
.\deploy.ps1 -DryRun
```

このコマンドは全てのテンプレートを検証しますが、実際のデプロイは行いません。

**期待される出力:**
```
========================================
CareApp Service Infrastructure Deployment
========================================

[DRY RUN MODE] Validating templates only

Step 1: Validating Templates
Validating: CareApp-POC-Network
✓ Template valid: CareApp-POC-Network

Validating: CareApp-POC-Database
✓ Template valid: CareApp-POC-Database

Validating: CareApp-POC-Compute
✓ Template valid: CareApp-POC-Compute

Validating: CareApp-POC-Monitoring
✓ Template valid: CareApp-POC-Monitoring

DRY RUN COMPLETED - All templates valid
```

#### 4-2. スタック作成（本番デプロイ）

Dry-runで問題がなければ、実際にデプロイします:

```powershell
.\deploy.ps1
```

**デプロイ順序（自動）:**
1. Network Stack（約3分）
2. Database Stack（約15分）
3. Compute Stack（約5分）
4. Monitoring Stack（約2分）

**合計約25分**

#### 4-3. デプロイ進捗の確認（オプション）

別のPowerShellウィンドウで進捗を確認:

```powershell
aws cloudformation describe-stacks `
  --stack-name CareApp-POC-Network `
  --query 'Stacks[0].StackStatus' `
  --output text
```

#### 4-4. (オプション) 個別スタックのデプロイ

必要に応じて個別スタックのみデプロイ可能:

```powershell
# Network スタックのみ
aws cloudformation deploy `
  --template-file 01-network.yaml `
  --stack-name CareApp-POC-Network `
  --parameter-overrides file://parameters-network-poc.json `
  --region ap-northeast-1

# Database スタックのみ（Networkスタック完了後）
aws cloudformation deploy `
  --template-file 02-database.yaml `
  --stack-name CareApp-POC-Database `
  --parameter-overrides file://parameters-database-poc.json `
  --capabilities CAPABILITY_NAMED_IAM `
  --region ap-northeast-1
```

### ステップ5: デプロイ完了確認とエンドポイント取得

デプロイスクリプトが正常に完了すると、ALB DNS Nameが表示されます:

```
========================================
Deployment Complete!
========================================
Access URL: http://careapp-poc-alb-xxxxxxxxx.ap-northeast-1.elb.amazonaws.com
```

#### 5-1. RDS Endpoint の取得（手動確認）

```powershell
aws cloudformation describe-stacks `
  --stack-name CareApp-POC-Database `
  --query 'Stacks[0].Outputs[?OutputKey==``DBEndpoint``].OutputValue' `
  --output text
```

出力例: `careapp-poc-db.abcdefg.ap-northeast-1.rds.amazonaws.com`

### ステップ6: RDS データベースの初期化

#### 6-1. Client VPN経由で接続（またはECS Execを使用）

**オプションA: psqlクライアントから直接接続**

```bash
# RDS Endpoint, Username, Password を環境変数に設定
export DB_HOST="careapp-poc-db.abcdefg.ap-northeast-1.rds.amazonaws.com"
export DB_USER="postgres"
export DB_PASSWORD="YourSecurePassword123!"
export DB_NAME="careapp"

# データベース接続テスト
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT version();"
```

**オプションB: ECS Execを使用（推奨）**

まず、ECS Execを有効化してから:

```bash
# ECS Task IDを取得
TASK_ARN=$(aws ecs list-tasks \
  --cluster careapp-poc-cluster \
  --service-name careapp-poc-service \
  --query 'taskArns[0]' \
  --output text)

# ECS Execでコンテナに接続
aws ecs execute-command \
  --cluster careapp-poc-cluster \
  --task $TASK_ARN \
  --container app \
  --interactive \
  --command "/bin/sh"
```

#### 6-2. 初期化スクリプトの実行

```bash
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f app/db/init.sql
```

または、手動でSQLを実行:

```sql
CREATE TABLE IF NOT EXISTS messages (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO messages (message) VALUES ('Hello ECS Service');

SELECT * FROM messages;
```

### ステップ7: Dockerイメージのビルドとプッシュ

**注意**: ECRリポジトリは Compute Stack で自動作成されます。

#### 7-1. ECR ログイン

```powershell
$AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$ECR_REGISTRY = "$AWS_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com"

aws ecr get-login-password --region ap-northeast-1 | `
  docker login --username AWS --password-stdin $ECR_REGISTRY
```

#### 7-2. Public Service（Hello ECS）のビルド

```powershell
cd ..\..\app\public

docker build -t careapp/public:latest .

$PUBLIC_ECR_URI = "$ECR_REGISTRY/careapp-public"
docker tag careapp/public:latest ${PUBLIC_ECR_URI}:latest
docker push ${PUBLIC_ECR_URI}:latest
```

#### 7-3. (将来) Admin Service のビルド

```powershell
cd ..\admin

docker build -t careapp/admin:latest .

$ADMIN_ECR_URI = "$ECR_REGISTRY/careapp-admin"
docker tag careapp/admin:latest ${ADMIN_ECR_URI}:latest
docker push ${ADMIN_ECR_URI}:latest
```

#### 7-4. (将来) Batch Service のビルド

```powershell
cd ..\batch

docker build -t careapp/batch:latest .

$BATCH_ECR_URI = "$ECR_REGISTRY/careapp-batch"
docker tag careapp/batch:latest ${BATCH_ECR_URI}:latest
docker push ${BATCH_ECR_URI}:latest
```

### ステップ8: ECS サービスの更新（新しいイメージのデプロイ）

#### 8-1. CloudFormation スタックを更新

ECRにイメージをプッシュした後、Compute Stackを更新:

```powershell
cd ..\..\infra\service

# parameters-compute-poc.json の ContainerImage を ECR URI に変更
# 例: "ParameterValue": "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/careapp-public:latest"

# Compute Stack を更新
aws cloudformation update-stack `
  --stack-name CareApp-POC-Compute `
  --template-body file://03-compute.yaml `
  --parameters file://parameters-compute-poc.json `
  --capabilities CAPABILITY_NAMED_IAM `
  --region ap-northeast-1
```

#### 8-2. ECS サービスの強制再デプロイ

```powershell
aws ecs update-service `
  --cluster CareApp-POC-ECSCluster-Main `
  --service CareApp-POC-PublicService `
  --force-new-deployment `
  --region ap-northeast-1
```

### ステップ9: アプリケーションの確認

#### 9-1. ALB DNS Name の取得

```powershell
aws cloudformation describe-stacks `
  --stack-name CareApp-POC-Compute `
  --query 'Stacks[0].Outputs[?OutputKey==``ALBDNSName``].OutputValue' `
  --output text
```

出力例: `careapp-poc-alb-1234567890.ap-northeast-1.elb.amazonaws.com`

#### 9-2. ブラウザでアクセス

```
http://<ALB-DNS-Name>/
```

**期待される表示:**
```
Hello ECS Service
🚀 Running on AWS ECS Fargate
📦 PostgreSQL RDS Database
```

#### 9-3. API エンドポイントの確認

```bash
curl http://<ALB-DNS-Name>/api/messages
```

**期待されるレスポンス:**
```json
[
  {
    "id": 1,
    "message": "Hello ECS Service",
    "created_at": "2025-10-03T...",
    "updated_at": "2025-10-03T..."
  }
]
```

---

## トラブルシューティング

### ECS タスクが起動しない

```bash
# ECS Service のイベントログを確認
aws ecs describe-services \
  --cluster careapp-poc-cluster \
  --services careapp-poc-service \
  --query 'services[0].events[0:5]'

# CloudWatch Logs を確認
aws logs tail /ecs/careapp-poc --follow
```

### RDS に接続できない

- セキュリティグループを確認（ECS SG → RDS SG への5432ポート許可）
- RDS Endpoint が正しいか確認
- DB パスワードが正しいか確認

### ALB ヘルスチェックが失敗する

```bash
# ターゲットグループのヘルスチェック状態を確認
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

- `/health` エンドポイントが正常に応答するか確認
- ECS タスクのログを確認

---

## クリーンアップ（削除）

### スタックの削除

```bash
# ECS サービスのタスク数を0に（RDS削除の前に必須）
aws ecs update-service \
  --cluster careapp-poc-cluster \
  --service careapp-poc-service \
  --desired-count 0

# スタック削除
aws cloudformation delete-stack \
  --stack-name careapp-poc-app

# 削除完了を確認
aws cloudformation wait stack-delete-complete \
  --stack-name careapp-poc-app
```

### ECR イメージの削除

```bash
aws ecr delete-repository \
  --repository-name careapp/hello-ecs \
  --force
```

---

## セキュリティに関する注意事項

### 機密情報の管理

**⚠️ 重要:**
- `parameters-poc.json` の `DBMasterPassword` は **絶対にGitにコミットしない**
- `.gitignore` に以下を追加:
  ```
  infra/**/parameters-*.json
  !infra/**/parameters-*.json.example
  ```

**推奨: AWS Secrets Manager を使用**

```bash
# Secrets Manager にパスワードを保存
aws secretsmanager create-secret \
  --name careapp/poc/db-password \
  --secret-string '{"password":"YourSecurePassword123!"}'

# CloudFormation から参照（今後の改善）
```

---

## 次のステップ

- [ ] GitHub Actions CI/CDパイプラインの構築
- [ ] HTTPS対応（ACM証明書 + ALB HTTPS リスナー）
- [ ] Auto Scaling の有効化
- [ ] CloudWatch Alarms の設定
- [ ] 本番環境へのプロモーション

---

## 参考: CloudWatch監視の確認

### アラームの確認

```powershell
aws cloudformation describe-stacks `
  --stack-name CareApp-POC-Monitoring `
  --query 'Stacks[0].Outputs' `
  --output table
```

### Dashboard URL

CloudWatch コンソールから `CareApp-POC-Dashboard` を開く:
```
https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards:name=CareApp-POC-Dashboard
```

### SNS Topic サブスクリプション確認

アラート通知のEmailサブスクリプションを確認:
```powershell
# 確認メールが届いているので、リンクをクリックして承認
aws sns list-subscriptions-by-topic `
  --topic-arn <CriticalAlertTopicのARN>
```

---

## 関連ドキュメント

- [REFACTORING.md](REFACTORING.md) - リファクタリングレポート（構造変更の詳細）
- [README.md](README.md) - プロジェクト概要
- [docs/02_CareApp要件定義書.md](docs/02_CareApp要件定義書.md) - 要件定義
- [docs/03_CareApp設計書.md](docs/03_CareApp設計書.md) - 設計書

---

**作成日**: 2025-10-03
**最終更新**: 2025-10-08（スタック分割、3サービス構成、監視強化を反映）
