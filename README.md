# AWS Multi-Account サンプルアプリケーション

AWS上で動作するエンタープライズ向けマルチアカウント構成のサンプルインフラストラクチャとアプリケーションです。

## 概要

このプロジェクトは、**AWS技術の学習・検証用**および**社内向け技術デモ・PoC**を目的としたサンプルアプリケーションです。Multi-Account構成、Transit Gateway、ECS Fargate、RDS等の主要なAWSサービスを組み合わせた実践的な構成を提供します。

### システム構成

- **Platform Account（共通基盤）**: Shared VPC、Transit Gateway、Client VPN/Direct Connect
- **Service Account（アプリケーション）**: 3サービス構成
  - **Public Service**: 一般ユーザー向けWebアプリケーション（インターネット公開）
  - **Admin Service**: 管理者向けダッシュボード（VPN/Direct Connect経由）
  - **Batch Service**: データ処理・集計バッチ

### 技術スタック

- **インフラ**: AWS CloudFormation（Multi-Account構成）
- **コンピューティング**: ECS Fargate（3サービス）
- **データベース**: RDS PostgreSQL（Multi-AZ本番）
- **監視**: CloudWatch（Alarms + Dashboard + SNS）
- **アプリケーション**: Node.js 20、Monorepo（npm workspaces）

---

## プロジェクト構成

```
.
├── .claude/              # AI開発ファシリテーター設定
│   ├── commands/         # カスタムコマンド (/status, /next等)
│   └── docs/             # 原則・ガイド・標準
├── .claude-state/        # プロジェクト状態 (Git管理外)
├── docs/                 # プロジェクトドキュメント
│   ├── 01_企画書.md
│   ├── 02_要件定義書.md
│   └── 03_設計書.md
├── infra/                # AWS Infrastructure (CloudFormation)
│   ├── platform/         # Platform Account - 共通基盤
│   │   ├── network.yaml  # Shared VPC, Transit Gateway, Client VPN
│   │   ├── parameters-poc.json
│   │   └── deploy.ps1
│   └── service/          # Service Account - 業務アプリケーション
│       ├── 01-network.yaml       # Service VPC, Subnets, Security Groups
│       ├── 02-database.yaml      # RDS PostgreSQL (Multi-AZ)
│       ├── 03-compute.yaml       # ECS Fargate, ALB
│       ├── 04-monitoring.yaml    # CloudWatch Alarms & Dashboard
│       ├── monitoring/           # 監視ネストスタック (将来拡張用)
│       ├── parameters-network-poc.json
│       ├── parameters-database-poc.json
│       ├── parameters-compute-poc.json
│       ├── parameters-monitoring-poc.json
│       └── deploy.ps1            # デプロイスクリプト (dry-run対応)
└── app/                  # アプリケーション Monorepo (npm workspaces)
    ├── public/           # 一般ユーザー向けWebアプリケーション
    │   ├── src/          # Node.js アプリ (Hello ECS デモ)
    │   ├── db/           # DB初期化スクリプト
    │   ├── package.json
    │   └── Dockerfile
    ├── admin/            # 管理者向けダッシュボード (VPN/Direct Connect経由)
    │   ├── package.json
    │   ├── Dockerfile
    │   └── README.md
    ├── batch/            # データ処理・集計バッチ
    │   ├── package.json
    │   ├── Dockerfile
    │   └── README.md
    ├── shared/           # 共通ライブラリ (DB接続、ユーティリティ等)
    │   ├── package.json
    │   └── README.md
    └── package.json      # Monorepo root設定
```

---

## クイックスタート

### 前提条件

- AWS CLI v2以上
- PowerShell 7+（Windows）または Bash（macOS/Linux）
- Docker v20以上
- Git

### デプロイ手順

詳細は [DEPLOYMENT.md](DEPLOYMENT.md) を参照してください。

```powershell
# 1. リポジトリのクローン
git clone <repository-url>
cd sampleAWS

# 2. パラメータファイルの編集
cd infra/service
# parameters-*.json を環境に合わせて編集

# 3. インフラのデプロイ（dry-run）
.\deploy.ps1 -DryRun

# 4. インフラのデプロイ（本番）
.\deploy.ps1

# 5. アプリケーションのビルド＆デプロイ
cd ..\..\app\public
docker build -t careapp/public:latest .
# ECRへpush（詳細はDEPLOYMENT.mdを参照）
```

---

## 実装済み機能

### インフラストラクチャ
- ✅ **Platform Account**: Shared VPC（Client VPN、Transit Gateway）
- ✅ **Service Account**: Service VPC（マルチAZ構成）
- ✅ **インフラ分割構成**:
  - 01-network.yaml（VPC、サブネット、セキュリティグループ）
  - 02-database.yaml（RDS PostgreSQL Multi-AZ）
  - 03-compute.yaml（ECS Fargate、ALB）
  - 04-monitoring.yaml（CloudWatch監視）
- ✅ **CloudWatch統合監視**:
  - 11種類のAlarms（ECS/RDS/ALB）
  - SNS Topics（Critical/Warning）
  - CloudWatch Dashboard
- ✅ **dry-run対応デプロイスクリプト**

### アプリケーション
- ✅ **Monorepoアプリケーション構成**:
  - public: 一般ユーザー向けWebアプリ（Hello ECSデモアプリ実装済み）
  - admin: 管理者向けダッシュボード（VPN/Direct Connect経由、準備中）
  - batch: データ処理・集計バッチ（準備中）
  - shared: 共通ライブラリ（準備中）

### ドキュメント
- ✅ デプロイ手順書（[DEPLOYMENT.md](DEPLOYMENT.md)）
- ✅ リファクタリングレポート（[REFACTORING.md](REFACTORING.md)）
- ✅ 企画書・要件定義書・設計書（[docs/](docs/)）

---

## アーキテクチャ

### Multi-Account構成

```
┌─────────────────────────────────────────────┐
│ Platform Account（共通基盤）                  │
│  - Shared VPC (10.0.0.0/16)                │
│  - Transit Gateway                          │
│  - Client VPN / Direct Connect             │
└────────────┬────────────────────────────────┘
             │ Transit Gateway
┌────────────▼────────────────────────────────┐
│ Service Account（アプリケーション）           │
│  - Service VPC (10.1.0.0/16)               │
│  - 3 ECS Services (Public/Admin/Batch)     │
│  - RDS PostgreSQL (Multi-AZ)               │
│  - CloudWatch監視                           │
└─────────────────────────────────────────────┘
```

### CloudFormationスタック構成

**デプロイ順序:**
```
Platform Account:
  └─ Platform-Network

Service Account:
  └─ 01-Network → 02-Database → 03-Compute → 04-Monitoring
```

### 技術的ポイント

このサンプルの**最も重要な要素**は、**Transit Gatewayによる拠点間閉域接続**です：

- **オンプレミス拠点** → Direct Connect → **Platform Account**
- **Platform Account** → Transit Gateway → **Service Account**
- VPN経由での安全な拠点間通信を実現

詳細は [docs/03_設計書.md](docs/03_設計書.md) を参照してください。

---

## 監視

### CloudWatch Alarms

- **ECS監視**: CPU使用率、メモリ使用率、タスク数
- **RDS監視**: CPU使用率、接続数、ストレージ容量、レプリケーションラグ
- **ALB監視**: ターゲット異常、5xxエラー率、レスポンスタイム

### SNS通知

- **Critical**: 即時対応が必要なアラート
- **Warning**: 監視が必要なアラート

### CloudWatch Dashboard

統合ダッシュボードで全サービスのメトリクスを一覧表示。

---

## 開発

### Monorepo構成

このプロジェクトは npm workspaces を使用したMonorepo構成です。

```bash
# 全サービスの依存関係をインストール
npm install

# 全サービスをビルド
npm run build:all

# 特定のサービスで作業
cd app/public
npm run dev
```

### 共通ライブラリの使用

```javascript
// app/public/src/index.js
import { connectDB } from '@sample/shared';

const db = await connectDB();
```

---

## コスト見積もり

### POC環境（最小構成）
- Platform Account: 約8,000円/月
- Service Account: 約9,500円/月
- **合計**: 約17,500円/月

### 本番環境（大規模構成）
- Platform Account: 約25,000円/月
- Service Account: 約65,500円/月
- **合計**: 約90,500円/月

詳細は [docs/02_要件定義書.md](docs/02_要件定義書.md) を参照してください。

---

## セキュリティ

### 機密情報管理

**⚠️ 重要:**
- パラメータファイル（`parameters-*.json`）はGitにコミットしない
- DBパスワード等は AWS Secrets Manager を使用
- 本番環境では必ずHTTPS（ACM証明書）を使用

### アクセス制御

- **Public Service**: インターネット公開（HTTPS）
- **Admin Service**: VPN経由のみアクセス可能
- **Batch Service**: 内部ネットワークのみ

---

## トラブルシューティング

### デプロイが失敗する

```powershell
# テンプレート検証
.\deploy.ps1 -DryRun

# CloudFormationイベントログを確認
aws cloudformation describe-stack-events `
  --stack-name CareApp-POC-Network `
  --max-items 20
```

### ECSタスクが起動しない

```powershell
# ECS Serviceのイベントログを確認
aws ecs describe-services `
  --cluster CareApp-POC-ECSCluster-Main `
  --services CareApp-POC-PublicService `
  --query 'services[0].events[0:5]'

# CloudWatch Logsを確認
aws logs tail /ecs/careapp-public --follow
```

### ALBヘルスチェックが失敗する

- `/health` エンドポイントが正常に応答するか確認
- セキュリティグループの設定を確認（ALB → ECS の通信許可）

---

## ドキュメント

- [DEPLOYMENT.md](DEPLOYMENT.md) - デプロイ手順書
- [REFACTORING.md](REFACTORING.md) - リファクタリングレポート
- [docs/01_企画書.md](docs/01_企画書.md) - プロジェクト概要
- [docs/02_要件定義書.md](docs/02_要件定義書.md) - 要件定義
- [docs/03_設計書.md](docs/03_設計書.md) - 設計書

---

## ライセンス

（ライセンス情報を記載）

---

## 貢献

（コントリビューションガイドラインを記載）

---

**作成日**: 2025-09-30
**最終更新**: 2025-10-09（汎用サンプルアプリケーション表記に変更）
