# リファクタリング完了レポート

## 概要

IaCの命名規則、ネスト構造、アプリケーション構成を本番運用を見据えて全面的にリファクタリングしました。

---

## 変更内容

### 1. ディレクトリ構造の変更

#### Before（旧構造）
```
infra/
├── shared/         # 共有インフラ
└── app/            # アプリインフラ（混乱しやすい名前）

app/                # アプリケーションコード（混同）
```

#### After（新構造）
```
infra/
├── platform/       # プラットフォームアカウント（共通系AWSアカウント）
│   ├── network.yaml
│   ├── parameters-poc.json
│   └── deploy.ps1
│
└── service/        # サービスアカウント（業務アプリ系AWSアカウント）
    ├── 01-network.yaml              # VPC, Subnets, TGW Attachment, Security Groups
    ├── 02-database.yaml             # RDS PostgreSQL
    ├── 03-compute.yaml              # ECS Fargate + ALB
    ├── 04-monitoring.yaml           # CloudWatch監視（POC版：統合）
    │
    ├── monitoring/                  # 本番用：ネストスタック構成
    │   ├── sns-topics.yaml          # SNSトピック
    │   ├── alarms-ecs.yaml          # ECSアラーム
    │   ├── alarms-rds.yaml          # RDSアラーム
    │   ├── alarms-alb.yaml          # ALBアラーム
    │   └── dashboard.yaml           # CloudWatchダッシュボード
    │
    ├── parameters-network-poc.json
    ├── parameters-database-poc.json
    ├── parameters-compute-poc.json
    ├── parameters-monitoring-poc.json
    └── deploy.ps1

app/
├── public/         # パブリックサービス（住民向けWebアプリ）
├── admin/          # 業務用（自治体職員向け管理画面）
├── batch/          # データ変換・バッチ処理
├── shared/         # 共通ライブラリ
└── package.json    # モノレポ管理
```

---

### 2. 命名規則の統一

#### リソースタグ命名規則
```yaml
Name: {ProjectName}-{Environment}-{ResourceType}-{Purpose}

例:
- CareApp-POC-VPC-Service
- CareApp-POC-ECS-Cluster
- CareApp-POC-RDS-Main
- CareApp-POC-ALB
```

#### Export名の統一
```yaml
Export:
  Name: !Sub '${AWS::StackName}-{Resource}-{Type}'

例:
- CareApp-POC-Network-VPC-ID
- CareApp-POC-Database-DB-Endpoint
- CareApp-POC-Compute-ALB-DNS
```

---

### 3. CloudFormation分割

#### Before
- `infra/app/main.yaml` - 1ファイル564行（VPC, ECS, RDS, ALB全部）

#### After
- `01-network.yaml` - ネットワーク（VPC, Subnets, TGW, Security Groups）
- `02-database.yaml` - データベース（RDS）
- `03-compute.yaml` - コンピュート（ECS, ALB）
- `04-monitoring.yaml` - 監視（CloudWatch Alarms, Dashboard）

**メリット:**
- 責務が明確
- 各ファイル200-300行で見やすい
- 個別にデプロイ・テスト可能
- 変更時の影響範囲が限定

---

### 4. CloudWatch監視の構造化

#### POC版（現在）
- `04-monitoring.yaml` - 1ファイルに全アラーム統合（シンプル、S3不要）

#### 本番版（将来）
- `04-monitoring.yaml` - 親スタック
- `monitoring/sns-topics.yaml` - SNSトピック
- `monitoring/alarms-ecs.yaml` - ECSアラーム
- `monitoring/alarms-rds.yaml` - RDSアラーム
- `monitoring/alarms-alb.yaml` - ALBアラーム
- `monitoring/dashboard.yaml` - ダッシュボード

**段階的移行:**
1. POC: シンプルな統合版
2. 本番: ネストスタック版（運用性・保守性向上）

---

### 5. アプリケーション構成（モノレポ）

#### 3つのサービス
1. **public/** - パブリックサービス（住民向けWebアプリ）
2. **admin/** - 業務用（自治体職員向け管理画面）
3. **batch/** - データ変換・バッチ処理

#### 共通ライブラリ
- **shared/** - DB接続、モデル、ユーティリティ

#### npm workspaces
```json
{
  "workspaces": ["public", "admin", "batch", "shared"]
}
```

**メリット:**
- 依存関係の一元管理
- 共通コードの再利用
- 各サービス独立してビルド・デプロイ可能

---

## デプロイ方法

### 1. Platform（共通基盤）デプロイ
```powershell
cd infra/platform
.\deploy.ps1
```

### 2. Service（業務アプリ基盤）デプロイ

#### Dry-run（検証のみ）
```powershell
cd infra/service
.\deploy.ps1 -DryRun
```

#### 本番デプロイ
```powershell
.\deploy.ps1
```

#### 監視スキップ（開発時）
```powershell
.\deploy.ps1 -SkipMonitoring
```

### デプロイ順序
1. **01-network.yaml** - VPC, Subnets, Security Groups
2. **02-database.yaml** - RDS（networkに依存）
3. **03-compute.yaml** - ECS, ALB（network, databaseに依存）
4. **04-monitoring.yaml** - 監視（compute, databaseに依存）

---

## パラメータファイル

各スタック専用のパラメータファイル:
- `parameters-network-poc.json`
- `parameters-database-poc.json`
- `parameters-compute-poc.json`
- `parameters-monitoring-poc.json`

**機密情報（パスワード等）:**
- パラメータファイルに記載（`.gitignore`で除外推奨）
- 本番: AWS Secrets Manager使用を推奨

---

## 監視項目（04-monitoring.yaml）

### ECS
- CPUUtilization（閾値: 80%）
- MemoryUtilization（閾値: 80%）

### RDS
- CPUUtilization（閾値: 80%）
- FreeStorageSpace（閾値: 2GB）
- DatabaseConnections（閾値: 80）

### ALB
- UnHealthyHostCount（閾値: 1）
- TargetResponseTime（閾値: 2秒）

### 通知
- Critical: `CriticalAlertTopic` → Email
- Warning: `WarningAlertTopic` → Email

---

## 次のステップ

### POC → 本番への移行

1. **監視のネストスタック化**
   - S3バケット作成
   - `monitoring/` 配下のテンプレートをS3にアップロード
   - `04-monitoring.yaml` を親スタックに変更

2. **3サービス対応（ECS）**
   - public, admin, batch用のECSサービスを追加
   - ALBのターゲットグループ分離
   - VPN経由アクセス制御（adminのみ）

3. **CI/CD構築**
   - GitHub Actions
   - ECRへのイメージpush
   - ECSサービス自動デプロイ

4. **セキュリティ強化**
   - AWS Secrets Manager導入
   - IAMロール最小権限化
   - CloudTrail有効化

---

## 技術標準の適用

本リファクタリングは以下の技術標準に準拠:
- `.claude/docs/40_standards/41_common.md` - 共通技術標準
- `.claude/docs/40_standards/42_infrastructure.md` - インフラ標準
- `.claude/docs/40_standards/45_secrets-management.md` - シークレット管理標準

---

## まとめ

### 改善ポイント
✅ ディレクトリ名を明確化（platform / service）
✅ CloudFormationを責務ごとに分割
✅ 命名規則を統一
✅ CloudWatch監視を構造化
✅ アプリをモノレポ化（3サービス対応）
✅ デプロイスクリプト改善（Dry-run対応）

### 本番運用への準備
✅ 段階的移行パス明確化
✅ 監視項目の定義完了
✅ パラメータファイル分離
✅ セキュリティ考慮（Secrets Manager）

リファクタリング完了！🎉
