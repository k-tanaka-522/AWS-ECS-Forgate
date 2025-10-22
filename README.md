# AWS Multi-Account Sample Application

AWS Multi-Account構成のサンプルアプリケーションです。Transit Gatewayによる拠点間閉域接続、ECS Fargate、RDS PostgreSQL Multi-AZなど、AWS技術の学習・検証・社内デモ用に設計されています。

## プロジェクト概要

### 目的

- AWS Multi-Account構成の技術検証
- Transit Gatewayによる拠点間閉域接続の実装
- ECS Fargate + RDS PostgreSQL構成の実践
- CloudFormation による Infrastructure as Code

### 主要技術

- **Infrastructure**: AWS Multi-Account (Platform + Service), CloudFormation
- **Compute**: ECS Fargate
- **Database**: RDS PostgreSQL 14.10 (Multi-AZ)
- **Network**: Transit Gateway, Client VPN, VPC
- **Application**: Node.js 20, Express.js
- **Monitoring**: CloudWatch (Alarms, Dashboard, Logs)

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
│  └─────────────────┘   │ - Admin        │ │
│                        └────────────────┘ │
└─────────────────────────────────────────────┘
```

### 3サービス構成

1. **Public Web Service**
   - 一般ユーザー向けWebアプリケーション
   - インターネット公開（ALB経由）
   - REST API提供

2. **Admin Dashboard Service**
   - 管理者向けダッシュボード
   - VPN経由のみアクセス可能
   - Internal ALB

3. **Batch Processing Service**
   - データ処理・集計バッチ
   - 定期実行（1時間ごと）
   - 統計レポート生成

## ディレクトリ構造

```
.
├── docs/                           # ドキュメント
│   ├── 01_企画書.md
│   ├── 02_要件定義書.md
│   ├── 03_基本設計書/              # 基本設計（8分割）
│   │   ├── 00_目次.md
│   │   ├── 01_システム概要.md
│   │   ├── 02_アーキテクチャ設計.md
│   │   ├── 03_インフラ設計.md
│   │   ├── 04_アプリケーション設計.md
│   │   ├── 05_セキュリティ設計.md
│   │   ├── 06_監視・運用設計.md
│   │   └── 07_非機能要件対応.md
│   ├── 04_詳細設計書/              # 詳細設計
│   │   ├── 01_CloudFormation詳細設計.md
│   │   ├── 02_データベース詳細設計.md
│   │   ├── 03_アプリケーション詳細設計.md
│   │   └── 04_監視詳細設計.md
│   ├── 05_テスト/                  # テストドキュメント
│   │   ├── 01_テスト計画書.md
│   │   ├── 02_単体テスト仕様書.md
│   │   ├── 03_インテグレーションテスト仕様書.md
│   │   └── 04_E2Eテスト仕様書.md
│   └── 06_納品物/                  # 納品ドキュメント
│       ├── 00_納品物一覧.md
│       ├── 01_セットアップガイド.md
│       ├── 02_運用マニュアル.md
│       └── 03_トラブルシューティング.md
├── infra/                          # インフラストラクチャコード
│   └── cloudformation/
│       ├── platform/               # Platform Account
│       │   ├── stack.yaml
│       │   ├── deploy.sh           # デプロイスクリプト
│       │   ├── rollback.sh         # ロールバックスクリプト
│       │   ├── parameters-dev.json
│       │   └── parameters-prod.json
│       └── service/                # Service Account
│           ├── 01-network.yaml
│           ├── 02-database.yaml
│           ├── 03-compute.yaml
│           ├── 04-monitoring.yaml
│           ├── deploy.sh           # デプロイスクリプト
│           ├── rollback.sh         # ロールバックスクリプト
│           ├── parameters-dev.json
│           └── parameters-prod.json
├── app/                            # アプリケーションコード
│   ├── public/                     # Public Web Service
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── package.json
│   ├── admin/                      # Admin Dashboard Service
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── package.json
│   ├── batch/                      # Batch Processing Service
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── package.json
│   └── shared/                     # 共通ライブラリ
│       ├── db/                     # DB接続・マイグレーション
│       └── package.json
└── README.md                       # このファイル
```

## クイックスタート

### 前提条件

- AWS アカウント 2つ（Platform Account + Service Account）
- AWS CLI 2.x以上インストール済み
- Node.js 20.x インストール済み
- Docker 24.x以上インストール済み

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd sampleAWS
```

### 2. Platform Account デプロイ

```bash
cd infra/cloudformation/platform

# AWS CLI プロファイル設定
export AWS_PROFILE=platform

# デプロイ実行（約10-15分）
./deploy.sh dev
```

### 3. Service Account デプロイ

Platform Account の **Transit Gateway ID** を `parameters-dev.json` に設定後：

```bash
cd ../service

# AWS CLI プロファイル設定
export AWS_PROFILE=service

# デプロイ実行（約20-30分）
./deploy.sh dev
```

### 4. データベースマイグレーション

```bash
cd ../../../app/shared

# 依存関係インストール
npm install

# RDS接続情報を環境変数に設定
export DB_HOST=<RDS_ENDPOINT>
export DB_PORT=5432
export DB_NAME=myapp_db
export DB_USER=appuser
export DB_PASSWORD=<PASSWORD_FROM_SECRETS_MANAGER>

# マイグレーション実行
npm run migrate:latest
```

### 5. Dockerイメージビルド＆デプロイ

詳細は [docs/06_納品物/01_セットアップガイド.md](docs/06_納品物/01_セットアップガイド.md) を参照してください。

### 6. 動作確認

```bash
# Public Web Service
curl http://<PUBLIC_ALB_DNS>/health
# Expected: {"status":"ok"}

# Admin Dashboard Service（VPN経由）
curl http://<ADMIN_ALB_DNS>/health
# Expected: {"status":"ok"}
```

## ドキュメント

### 企画・設計書

| ドキュメント | 説明 |
|------------|------|
| [企画書](docs/01_企画書.md) | プロジェクト概要、目的、スコープ |
| [要件定義書](docs/02_要件定義書.md) | 機能要件、非機能要件 |
| [基本設計書](docs/03_基本設計書/00_目次.md) | システムアーキテクチャ設計（8分割） |
| [詳細設計書](docs/04_詳細設計書/) | CloudFormation、DB、アプリ、監視の詳細設計 |

### テスト・運用

| ドキュメント | 説明 |
|------------|------|
| [テスト計画書](docs/05_テスト/01_テスト計画書.md) | テスト戦略、スケジュール |
| [単体テスト仕様書](docs/05_テスト/02_単体テスト仕様書.md) | 単体テストケース |
| [インテグレーションテスト仕様書](docs/05_テスト/03_インテグレーションテスト仕様書.md) | API統合テスト |
| [E2Eテスト仕様書](docs/05_テスト/04_E2Eテスト仕様書.md) | システム全体テスト |

### 納品物

| ドキュメント | 説明 |
|------------|------|
| [納品物一覧](docs/06_納品物/00_納品物一覧.md) | 全納品物のリスト |
| [セットアップガイド](docs/06_納品物/01_セットアップガイド.md) | 環境構築手順（詳細版） |
| [運用マニュアル](docs/06_納品物/02_運用マニュアル.md) | 日常運用、デプロイ、スケーリング |
| [トラブルシューティング](docs/06_納品物/03_トラブルシューティング.md) | 障害対応手順、FAQ |

## コスト見積もり

### 開発環境（dev）の月額概算

| サービス | 仕様 | 月額（USD） |
|---------|------|------------|
| ECS Fargate | 0.5 vCPU, 1GB x 3サービス | $25 |
| RDS PostgreSQL | db.t3.medium Multi-AZ | $100 |
| Application Load Balancer | 2台（Public + Admin） | $25 |
| Client VPN | エンドポイント時間課金 | $75 |
| CloudWatch Logs | 10GB | 含む |
| **合計** | | **約 $225/月** |

### 本番環境（prod）の月額概算

約 $530/月（Auto Scaling、Read Replica等含む）

## セキュリティ

- **暗号化**: RDS（KMS）、Secrets Manager、EBS、S3すべて暗号化
- **ネットワーク分離**: Admin DashboardはVPN経由のみ
- **最小権限の原則**: IAMロールで厳密な権限管理
- **監査ログ**: CloudWatch Logs、VPC Flow Logs
- **シークレット管理**: Secrets Managerで自動ローテーション

## モニタリング

- CloudWatch Alarms（CPU、メモリ、エラー率）
- CloudWatch Dashboard（統合ビュー）
- RDS Enhanced Monitoring
- VPC Flow Logs
- SNS通知（Critical/Warning）

詳細は [docs/03_基本設計書/06_監視・運用設計.md](docs/03_基本設計書/06_監視・運用設計.md) を参照してください。

## デプロイスクリプト

### Platform Account

```bash
cd infra/cloudformation/platform

# デプロイ
./deploy.sh dev

# ロールバック（削除）
./rollback.sh dev
```

### Service Account

```bash
cd infra/cloudformation/service

# デプロイ（4スタック順次）
./deploy.sh dev

# ロールバック（削除）
./rollback.sh dev
```

## トラブルシューティング

詳細は [docs/06_納品物/03_トラブルシューティング.md](docs/06_納品物/03_トラブルシューティング.md) を参照してください。

### よくある問題

#### Transit Gateway接続が確立しない

**原因**: RAM Resource Shareの承認が必要

**解決策**:
```bash
aws ram get-resource-share-invitations --region ap-northeast-1
aws ram accept-resource-share-invitation --resource-share-invitation-arn <ARN>
```

#### ECS タスクが起動しない

**原因**: Secrets Managerが取得できない

**解決策**:
1. Secrets Managerに値が設定されているか確認
2. IAM Task Execution Roleの権限を確認
3. CloudWatch Logsでエラー確認

```bash
aws logs tail /ecs/sample-app-dev/public-web --follow
```

## 技術スタック詳細

| カテゴリ | 技術 | バージョン |
|---------|------|----------|
| IaC | CloudFormation | Latest |
| Compute | ECS Fargate | Latest |
| Container | Docker | 24.x |
| Database | PostgreSQL | 14.10 |
| Runtime | Node.js | 20.x |
| Framework | Express.js | 4.18.x |
| ORM | Knex.js | 3.1.x |
| Monitoring | CloudWatch | Latest |

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
