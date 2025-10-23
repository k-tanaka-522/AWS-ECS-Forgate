# CloudFormation インフラデプロイガイド

## 📁 ディレクトリ構成

```
infra/cloudformation/
├── platform/              # Platform Account (共有インフラ)
│   ├── stacks/main/
│   │   └── stack.yaml     # 親スタック
│   ├── nested/
│   │   ├── network.yaml   # VPC, Subnets, NAT Gateway
│   │   └── connectivity.yaml  # Transit Gateway, Client VPN
│   ├── parameters/
│   │   └── dev.json       # 環境別パラメータ
│   ├── deploy.sh          # デプロイスクリプト (Linux/Mac)
│   └── deploy.ps1         # デプロイスクリプト (Windows)
│
└── service/               # Service Account (アプリケーションインフラ)
    ├── stacks/
    │   ├── network/main.yaml    # VPC, Transit Gateway Attachment
    │   ├── database/main.yaml   # RDS PostgreSQL
    │   ├── compute/main.yaml    # ECS, ALB, Task Definitions
    │   └── monitoring/main.yaml # CloudWatch Alarms, Dashboard
    ├── parameters/
    │   └── dev.json       # 環境別パラメータ (スタック別)
    ├── deploy.sh          # デプロイスクリプト (Linux/Mac)
    └── deploy.ps1         # デプロイスクリプト (Windows)
```

## 🚀 クイックスタート

### 前提条件
- AWS CLI インストール済み
- AWS認証情報が設定済み (Platform AccountとService Account)
- Docker インストール済み (アプリケーションデプロイ時)
- jq インストール済み (Linuxの場合)

### デプロイ順序

#### 1. Platform Account のデプロイ

**Linux/Mac:**
```bash
cd infra/cloudformation/platform
./deploy.sh dev
```

**Windows:**
```powershell
cd infra\cloudformation\platform
.\deploy.ps1 -Environment dev
```

**出力されるTransit Gateway IDをメモしてください。**

---

#### 2. Service Account のデプロイ

**パラメータファイルを編集:**
```bash
cd infra/cloudformation/service
vi parameters/dev.json
```

`TransitGatewayId` を実際の値に置き換えます。

**ネットワークスタックをデプロイ:**

**Linux/Mac:**
```bash
./deploy.sh dev network
```

**Windows:**
```powershell
.\deploy.ps1 -Environment dev -Stack network
```

**データベーススタックをデプロイ:**

**Linux/Mac:**
```bash
./deploy.sh dev database
```

**Windows:**
```powershell
.\deploy.ps1 -Environment dev -Stack database
```

---

#### 3. データベース初期化

RDSインスタンスに接続してテーブルを作成します:

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(100) NOT NULL UNIQUE,
  email VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE stats (
  id SERIAL PRIMARY KEY,
  metric_name VARCHAR(100) NOT NULL,
  metric_value NUMERIC NOT NULL,
  recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_stats_metric_name ON stats(metric_name);
CREATE INDEX idx_stats_recorded_at ON stats(recorded_at);
CREATE INDEX idx_users_created_at ON users(created_at);
```

---

#### 4. Dockerイメージのビルドとプッシュ

**Linux/Mac:**
```bash
cd ../../../app
./build-and-push.sh dev
```

**Windows:**
```powershell
cd ..\..\..\app
.\build-and-push.ps1 -Environment dev
```

---

#### 5. コンピュートスタックのデプロイ

**Linux/Mac:**
```bash
cd ../infra/cloudformation/service
./deploy.sh dev compute
```

**Windows:**
```powershell
cd ..\infra\cloudformation\service
.\deploy.ps1 -Environment dev -Stack compute
```

---

#### 6. モニタリングスタックのデプロイ

**Linux/Mac:**
```bash
./deploy.sh dev monitoring
```

**Windows:**
```powershell
.\deploy.ps1 -Environment dev -Stack monitoring
```

---

#### 7. 動作確認

ALB DNSにアクセスして動作確認:

```bash
# Health Check
curl http://<ALB_DNS>/health

# ユーザー作成
curl -X POST http://<ALB_DNS>/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com"}'

# ユーザー一覧
curl http://<ALB_DNS>/api/users
```

---

## 🔧 個別スタックのデプロイ

### ネットワークスタックのみ

**Linux/Mac:**
```bash
cd service
./deploy.sh dev network
```

**Windows:**
```powershell
cd service
.\deploy.ps1 -Environment dev -Stack network
```

### データベーススタックのみ

**Linux/Mac:**
```bash
./deploy.sh dev database
```

**Windows:**
```powershell
.\deploy.ps1 -Environment dev -Stack database
```

### コンピュートスタックのみ

**Linux/Mac:**
```bash
./deploy.sh dev compute
```

**Windows:**
```powershell
.\deploy.ps1 -Environment dev -Stack compute
```

### モニタリングスタックのみ

**Linux/Mac:**
```bash
./deploy.sh dev monitoring
```

**Windows:**
```powershell
.\deploy.ps1 -Environment dev -Stack monitoring
```

---

## 🔄 アプリケーションの更新

コードを変更した後、以下の手順で更新:

### 1. Dockerイメージの再ビルド

**特定のサービスのみ:**

**Linux/Mac:**
```bash
cd app
./build-and-push.sh dev public   # Public Web Service
./build-and-push.sh dev admin    # Admin Service
./build-and-push.sh dev batch    # Batch Service
```

**Windows:**
```powershell
cd app
.\build-and-push.ps1 -Environment dev -Service public
.\build-and-push.ps1 -Environment dev -Service admin
.\build-and-push.ps1 -Environment dev -Service batch
```

### 2. ECSサービスの更新

イメージをプッシュ後、ECSサービスを強制的に再デプロイ:

```bash
aws ecs update-service \
  --cluster sample-app-dev-cluster \
  --service sample-app-dev-public-web \
  --force-new-deployment

aws ecs update-service \
  --cluster sample-app-dev-cluster \
  --service sample-app-dev-admin \
  --force-new-deployment
```

または、コンピュートスタックを再デプロイ:

**Linux/Mac:**
```bash
cd infra/cloudformation/service
./deploy.sh dev compute
```

**Windows:**
```powershell
cd infra\cloudformation\service
.\deploy.ps1 -Environment dev -Stack compute
```

---

## 🗑️ スタックの削除

**注意: データが削除されます！本番環境では実行しないでください。**

### 削除順序 (逆順)

```bash
# 1. Monitoring
aws cloudformation delete-stack --stack-name sample-app-dev-service-monitoring

# 2. Compute
aws cloudformation delete-stack --stack-name sample-app-dev-service-compute

# 3. Database
aws cloudformation delete-stack --stack-name sample-app-dev-service-database

# 4. Network
aws cloudformation delete-stack --stack-name sample-app-dev-service-network

# 5. Platform
aws cloudformation delete-stack --stack-name sample-app-dev-platform
```

---

## 📊 モニタリング

### CloudWatch Dashboard

AWS Console → CloudWatch → Dashboards → `sample-app-dev-dashboard`

### CloudWatch Alarms

AWS Console → CloudWatch → Alarms

主要なアラーム:
- ECS CPU/メモリ使用率
- RDS接続数、レイテンシ
- ALB 5xxエラー、レスポンスタイム

### CloudWatch Logs

AWS Console → CloudWatch → Log groups

- `/ecs/sample-app/dev/public-web` - Public Web Service
- `/ecs/sample-app/dev/admin` - Admin Service
- `/ecs/sample-app/dev/batch` - Batch Service

---

## 🔍 トラブルシューティング

### スタック作成が失敗する

```bash
# スタックイベントを確認
aws cloudformation describe-stack-events \
  --stack-name sample-app-dev-service-network \
  --max-items 20
```

### ECSタスクが起動しない

```bash
# タスク定義を確認
aws ecs describe-task-definition \
  --task-definition sample-app-dev-public-web

# 実行中のタスクを確認
aws ecs list-tasks \
  --cluster sample-app-dev-cluster \
  --service-name sample-app-dev-public-web

# タスクの詳細を確認
aws ecs describe-tasks \
  --cluster sample-app-dev-cluster \
  --tasks <task-arn>
```

### データベース接続エラー

```bash
# RDSエンドポイントを確認
aws cloudformation describe-stacks \
  --stack-name sample-app-dev-service-database \
  --query 'Stacks[0].Outputs'

# Secrets Managerの値を確認
aws secretsmanager get-secret-value \
  --secret-id <secret-arn>
```

---

## 📚 参考資料

- [基本設計書](../../docs/03_基本設計書/)
- [デプロイ手順書](../../docs/05_デプロイ手順書.md)
- [アプリケーションREADME](../../app/README.md)
