# AWS Multi-Account Sample Application

AWS Multi-Account構成のサンプルアプリケーションです。Transit Gatewayによる拠点間閉域接続、ECS Fargate、RDS PostgreSQL Multi-AZなど、AWS技術の学習・検証・社内デモ用に設計されています。

## プロジェクト概要

### 目的

- AWS Multi-Account構成の技術検証
- Transit Gatewayによる拠点間閉域接続の実装
- ECS Fargate + RDS PostgreSQL構成の実践
- CloudFormation + GitHub Actionsによる自動化

### 主要技術

- **Infrastructure**: AWS Multi-Account (Platform + Service), CloudFormation
- **Compute**: ECS Fargate
- **Database**: RDS PostgreSQL 15 (Multi-AZ)
- **Network**: Transit Gateway, Client VPN, VPC
- **Application**: Node.js 20, Express.js
- **CI/CD**: GitHub Actions
- **Monitoring**: CloudWatch (Container Insights, Alarms, Dashboard)

## アーキテクチャ

### Multi-Account構成

```
┌─────────────────────────────────────────────┐
│ Platform Account (共通基盤)                 │
│                                             │
│  ┌─────────────────┐   ┌────────────────┐ │
│  │ Shared VPC      │   │ Transit Gateway│ │
│  │ 10.0.0.0/16     │───│                │ │
│  └─────────────────┘   └────────────────┘ │
│                          │                  │
│  ┌─────────────────┐    │                  │
│  │ Client VPN      │    │                  │
│  │ 172.16.0.0/22   │────┘                  │
│  └─────────────────┘                       │
└─────────────────────────────────────────────┘
                  │ (Transit Gateway Sharing via RAM)
                  ▼
┌─────────────────────────────────────────────┐
│ Service Account (アプリケーション)          │
│                                             │
│  ┌─────────────────┐   ┌────────────────┐ │
│  │ Service VPC     │   │ ECS Fargate    │ │
│  │ 10.1.0.0/16     │   │ - Public Web   │ │
│  └─────────────────┘   │ - Admin        │ │
│          │             │ - Batch        │ │
│          │             └────────────────┘ │
│          ▼                                 │
│  ┌─────────────────┐   ┌────────────────┐ │
│  │ RDS PostgreSQL  │   │ ALB            │ │
│  │ Multi-AZ        │   │ - Public       │ │
│  └─────────────────┘   │ - Internal     │ │
│                        └────────────────┘ │
└─────────────────────────────────────────────┘
```

### 3サービス構成

1. **Public Web Service**
   - 一般ユーザー向けWebアプリケーション
   - インターネット公開（ALB経由）
   - ポート: 8080

2. **Admin Dashboard Service**
   - 管理者向けダッシュボード
   - VPN/Direct Connect経由のみアクセス可能
   - Internal ALB
   - ポート: 8080

3. **Batch Processing Service**
   - データ処理・集計バッチ
   - 定期実行（1時間ごと）
   - ALBなし

## ディレクトリ構造

```
.
├── docs/                           # ドキュメント
│   ├── 02_要件定義書.md
│   ├── 03_基本設計書.md
│   └── 04_詳細設計書.md
├── infra/                          # インフラストラクチャコード
│   ├── platform/                   # Platform Account
│   │   ├── stack.yaml
│   │   ├── nested/
│   │   │   ├── network.yaml
│   │   │   └── connectivity.yaml
│   │   ├── parameters-dev.json
│   │   └── parameters-prod.json
│   └── service/                    # Service Account
│       ├── 01-network.yaml
│       ├── 02-database.yaml
│       ├── 03-compute.yaml
│       ├── parameters-dev.json
│       └── parameters-prod.json
├── app/                            # アプリケーションコード
│   ├── public/                     # Public Web Service
│   ├── admin/                      # Admin Dashboard Service
│   ├── batch/                      # Batch Processing Service
│   └── shared/                     # 共通ライブラリ
├── .github/workflows/              # CI/CDパイプライン
│   ├── deploy.yml
│   ├── infrastructure.yml
│   └── pr-validation.yml
└── README.md                       # このファイル
```

## クイックスタート

### 前提条件

- AWS アカウント 2つ（Platform Account + Service Account）
- AWS CLI インストール済み
- Node.js 20 インストール済み
- Docker インストール済み
- GitHub アカウント（CI/CD使用時）

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd sampleAWS
```

### 2. インフラストラクチャのデプロイ

詳細は [infra/README.md](infra/README.md) を参照してください。

#### Platform Account

```bash
# S3バケット作成（Nested Templates用）
aws s3 mb s3://myapp-dev-cfn-templates --region ap-northeast-1

# Nested Templatesアップロード
aws s3 cp infra/platform/nested/ s3://myapp-dev-cfn-templates/nested/ --recursive

# スタックデプロイ
aws cloudformation create-change-set \
  --stack-name myapp-dev-platform \
  --change-set-name myapp-dev-platform-changeset-$(date +%Y%m%d%H%M%S) \
  --template-body file://infra/platform/stack.yaml \
  --parameters file://infra/platform/parameters-dev.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# Change Set確認・実行
aws cloudformation describe-change-set --stack-name myapp-dev-platform --change-set-name <CHANGE_SET_NAME>
aws cloudformation execute-change-set --stack-name myapp-dev-platform --change-set-name <CHANGE_SET_NAME>
```

#### Service Account

```bash
# Network スタック
aws cloudformation create-change-set \
  --stack-name myapp-dev-service-network \
  --change-set-name myapp-dev-service-network-changeset-$(date +%Y%m%d%H%M%S) \
  --template-body file://infra/service/01-network.yaml \
  --parameters file://infra/service/parameters-dev.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# Database スタック（Network完了後）
aws cloudformation create-change-set \
  --stack-name myapp-dev-service-database \
  --change-set-name myapp-dev-service-database-changeset-$(date +%Y%m%d%H%M%S) \
  --template-body file://infra/service/02-database.yaml \
  --parameters file://infra/service/parameters-dev.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# Compute スタック（Database完了後）
aws cloudformation create-change-set \
  --stack-name myapp-dev-service-compute \
  --change-set-name myapp-dev-service-compute-changeset-$(date +%Y%m%d%H%M%S) \
  --template-body file://infra/service/03-compute.yaml \
  --parameters file://infra/service/parameters-dev.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

### 3. アプリケーションのビルドとデプロイ

詳細は [app/README.md](app/README.md) を参照してください。

```bash
cd app

# 依存関係インストール
npm run install:all

# Dockerイメージビルド
npm run docker:build

# ECRプッシュ
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com

docker tag myapp-public-web:latest <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/public-web:latest
docker push <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/public-web:latest

# 同様にadmin, batchもプッシュ
```

### 4. 動作確認

```bash
# Public Web Service
curl http://<PUBLIC_ALB_DNS>/health

# Admin Dashboard Service（VPN経由）
curl http://<ADMIN_ALB_DNS>/health
```

## CI/CD

GitHub Actionsによる自動デプロイを構成しています。

詳細は [.github/workflows/README.md](.github/workflows/README.md) を参照してください。

### GitHub Secrets の設定

リポジトリの `Settings` → `Secrets and variables` → `Actions` で以下を登録：

```
AWS_ACCOUNT_ID=123456789012
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=xxxxx...
PLATFORM_AWS_ACCESS_KEY_ID=AKIA...
PLATFORM_AWS_SECRET_ACCESS_KEY=xxxxx...
SERVICE_AWS_ACCESS_KEY_ID=AKIA...
SERVICE_AWS_SECRET_ACCESS_KEY=xxxxx...
```

### 自動デプロイ

`main` ブランチへのマージで自動的にデプロイされます：

```bash
git checkout main
git merge feature-branch
git push origin main
```

## ドキュメント

- [02_要件定義書.md](docs/02_要件定義書.md) - 機能要件・非機能要件
- [03_基本設計書.md](docs/03_基本設計書.md) - システムアーキテクチャ設計
- [04_詳細設計書.md](docs/04_詳細設計書.md) - 実装レベルの詳細設計
- [infra/README.md](infra/README.md) - インフラデプロイ手順
- [app/README.md](app/README.md) - アプリケーション開発ガイド
- [.github/workflows/README.md](.github/workflows/README.md) - CI/CDガイド

## コスト見積もり

開発環境（dev）の月額概算：

| サービス | 仕様 | 月額（USD） |
|---------|------|------------|
| ECS Fargate | 0.5 vCPU, 1GB x 5タスク | $36 |
| RDS PostgreSQL | db.t3.micro Multi-AZ | $30 |
| NAT Gateway | 2台 x 730時間 | $65 |
| Transit Gateway | 1台 + データ転送 | $36 |
| Application Load Balancer | 2台 | $32 |
| CloudWatch Logs | 10GB | $5 |
| **合計** | | **約 $204/月** |

本番環境（prod）：約 $530/月

## セキュリティ

- すべてのデータは暗号化（RDS, Secrets Manager, KMS）
- 管理系サービスはVPN/Direct Connect経由のみアクセス可能
- IAMロールは最小権限の原則に基づいて設定
- Security Groupで厳密なネットワーク制御
- Secrets Managerでパスワード自動生成・管理

## モニタリング

- CloudWatch Container Insights（ECS）
- RDS Enhanced Monitoring
- CloudWatch Alarms（CPU, メモリ, エラー率）
- SNS通知（Critical/Warning）
- CloudWatch Dashboard（統合ビュー）

## トラブルシューティング

### Transit Gateway接続が確立しない

**原因:** RAM Resource Shareの承認が必要

**解決策:**
```bash
aws ram get-resource-share-invitations --region ap-northeast-1
aws ram accept-resource-share-invitation --resource-share-invitation-arn <ARN> --region ap-northeast-1
```

### ECS タスクが起動しない

**原因:** 環境変数（Secrets Manager）が取得できない

**解決策:**
1. Secrets Managerに値が設定されているか確認
2. IAM Task Execution Roleの権限を確認
3. ECS タスクログを確認

```bash
aws logs tail /ecs/myapp-dev/public-web --follow --region ap-northeast-1
```

### データベース接続エラー

**原因:** Security Groupで通信がブロックされている

**解決策:** Security Groupのインバウンドルールを確認

## 貢献

このプロジェクトは学習・検証目的のサンプルです。改善提案やバグ報告は Issue または Pull Request でお願いします。

## ライセンス

MIT License

## 参考資料

- [AWS Multi-Account Strategy](https://aws.amazon.com/jp/organizations/getting-started/best-practices/)
- [AWS Transit Gateway](https://docs.aws.amazon.com/ja_jp/vpc/latest/tgw/what-is-transit-gateway.html)
- [Amazon ECS on AWS Fargate](https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Amazon RDS for PostgreSQL](https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [AWS CloudFormation Best Practices](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/best-practices.html)

## お問い合わせ

質問や不明点がある場合は、Issue を作成してください。
