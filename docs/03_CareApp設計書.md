# CareApp 設計書

## 1. 概要

### 1.1 目的
本ドキュメントは、介護保険申請管理システム（CareApp）のPOC環境におけるAWSインフラ設計を定義します。

### 1.2 対象範囲
- **Phase 1**: POC環境のインフラ構築
- **対象**: Shared VPC、App VPC、Transit Gateway、Client VPN、ECS、RDS、Cognito等のAWSリソース

### 1.3 参照ドキュメント
- [01_CareApp企画書.md](01_CareApp企画書.md)
- [02_CareApp要件定義書.md](02_CareApp要件定義書.md)
- [standards/インフラ/01_基本設計規約.md](standards/インフラ/01_基本設計規約.md)

---

## 2. アーキテクチャ設計

### 2.1 全体構成

```
┌─────────────────────────────────────────────────────────────┐
│                    CareApp POC環境（1 AWSアカウント）          │
│                                                             │
│  ┌─────────────────────┐      ┌────────────────────────┐   │
│  │  Shared VPC         │      │  App VPC               │   │
│  │  (10.0.0.0/16)      │      │  (10.1.0.0/16)         │   │
│  │                     │      │                        │   │
│  │  ┌───────────────┐  │      │  ┌──────────────────┐  │   │
│  │  │ Client VPN    │  │      │  │ Public Subnet    │  │   │
│  │  │ Endpoint      │  │      │  │ (10.1.0.0/24)    │  │   │
│  │  └───────────────┘  │      │  │                  │  │   │
│  │         │           │      │  │  ┌───────────┐   │  │   │
│  │         │           │      │  │  │    ALB    │   │  │   │
│  │  ┌──────▼────────┐  │      │  │  └─────┬─────┘   │  │   │
│  │  │ Transit       │◄─┼──────┼──┼────────┘         │  │   │
│  │  │ Gateway       │  │      │  └──────────────────┘  │   │
│  │  └───────────────┘  │      │                        │   │
│  │                     │      │  ┌──────────────────┐  │   │
│  └─────────────────────┘      │  │ Private Subnet   │  │   │
│                               │  │ (App)            │  │   │
│                               │  │ (10.1.1.0/24)    │  │   │
│                               │  │                  │  │   │
│                               │  │  ┌───────────┐   │  │   │
│                               │  │  │ ECS Tasks │   │  │   │
│                               │  │  └───────────┘   │  │   │
│                               │  └──────────────────┘  │   │
│                               │                        │   │
│                               │  ┌──────────────────┐  │   │
│                               │  │ Private Subnet   │  │   │
│                               │  │ (DB)             │  │   │
│                               │  │ (10.1.2.0/24)    │  │   │
│                               │  │                  │  │   │
│                               │  │  ┌───────────┐   │  │   │
│                               │  │  │    RDS    │   │  │   │
│                               │  │  └───────────┘   │  │   │
│                               │  └──────────────────┘  │   │
│                               │                        │   │
│                               └────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ その他のAWSサービス                                    │   │
│  │ - Cognito User Pool（認証）                           │   │
│  │ - S3（ファイル保存）                                   │   │
│  │ - ECR（コンテナイメージ）                               │   │
│  │ - Secrets Manager（DB接続情報）                        │   │
│  │ - CloudWatch（監視・ログ）                             │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

        ▲                           ▲
        │                           │
   Client VPN                   HTTPS（インターネット）
   （市職員）                     （介護事業者）
```

### 2.2 採用アーキテクチャ

**Hub-and-Spoke型ネットワーク**

- **Hub**: Shared VPC（Transit Gateway、Client VPN配置）
- **Spoke**: App VPC（アプリケーション配置）
- **接続**: Transit Gateway経由で相互通信

**選定理由:**
- 将来的に複数のApp VPC追加が容易（スケーラブル）
- ネットワーク管理の集中化
- セキュリティ境界の明確化

---

## 3. ネットワーク設計

### 3.1 VPC設計

#### 3.1.1 Shared VPC

| 項目 | 値 |
|-----|---|
| **CIDR** | 10.0.0.0/16 |
| **用途** | Transit Gateway、Client VPN |
| **サブネット** | なし（VPC自体はAttachment用） |
| **リージョン** | ap-northeast-1 |

#### 3.1.2 App VPC

| 項目 | 値 |
|-----|---|
| **CIDR** | 10.1.0.0/16 |
| **用途** | アプリケーション本体 |
| **AZ** | ap-northeast-1a（Single-AZ） |
| **リージョン** | ap-northeast-1 |

**サブネット構成:**

| サブネット名 | CIDR | AZ | 用途 | インターネット接続 |
|------------|------|----|----|------------------|
| Public Subnet | 10.1.0.0/24 | 1a | ALB配置 | あり（IGW経由） |
| Private Subnet (App) | 10.1.1.0/24 | 1a | ECS Fargate配置 | NAT Gateway経由 |
| Private Subnet (DB) | 10.1.2.0/24 | 1a | RDS配置 | なし |

### 3.2 ルーティング設計

#### 3.2.1 Public Subnet ルートテーブル

| 宛先 | ターゲット | 用途 |
|-----|----------|-----|
| 10.1.0.0/16 | local | VPC内通信 |
| 0.0.0.0/0 | Internet Gateway | インターネット接続 |
| 10.0.0.0/16 | Transit Gateway | Shared VPCへの通信 |

#### 3.2.2 Private Subnet (App) ルートテーブル

| 宛先 | ターゲット | 用途 |
|-----|----------|-----|
| 10.1.0.0/16 | local | VPC内通信 |
| 0.0.0.0/0 | NAT Gateway | 外部API通信（ECR pull等） |
| 10.0.0.0/16 | Transit Gateway | Shared VPCへの通信 |

#### 3.2.3 Private Subnet (DB) ルートテーブル

| 宛先 | ターゲット | 用途 |
|-----|----------|-----|
| 10.1.0.0/16 | local | VPC内通信のみ |

### 3.3 セキュリティグループ設計

#### 3.3.1 ALB Security Group

**Ingress:**
| プロトコル | ポート | ソース | 説明 |
|----------|-------|-------|-----|
| TCP | 443 | 0.0.0.0/0 | インターネットからのHTTPS |

**Egress:**
| プロトコル | ポート | 宛先 | 説明 |
|----------|-------|-----|-----|
| TCP | 8080 | ECS Security Group | ECSタスクへの転送 |

#### 3.3.2 ECS Security Group

**Ingress:**
| プロトコル | ポート | ソース | 説明 |
|----------|-------|-------|-----|
| TCP | 8080 | ALB Security Group | ALBからのトラフィック |

**Egress:**
| プロトコル | ポート | 宛先 | 説明 |
|----------|-------|-----|-----|
| TCP | 443 | 0.0.0.0/0 | 外部API通信、ECR pull |
| TCP | 5432 | RDS Security Group | RDSへの接続 |

#### 3.3.3 RDS Security Group

**Ingress:**
| プロトコル | ポート | ソース | 説明 |
|----------|-------|-------|-----|
| TCP | 5432 | ECS Security Group | ECSタスクからのDB接続 |

**Egress:**
なし

### 3.4 Transit Gateway設計

| 項目 | 値 |
|-----|---|
| **名前** | CareApp-POC-TransitGateway |
| **Amazon側ASN** | 64512（デフォルト） |
| **デフォルトルートテーブル関連付け** | 有効 |
| **デフォルトルートテーブル伝播** | 有効 |

**Attachment:**
- Shared VPC Attachment
- App VPC Attachment

### 3.5 Client VPN設計（POC環境のみ）

| 項目 | 値 |
|-----|---|
| **名前** | CareApp-POC-ClientVPN |
| **クライアントCIDR** | 10.255.0.0/16 |
| **認証方式** | 相互認証（証明書ベース） |
| **ターゲットネットワーク** | Shared VPC |
| **分割トンネル** | 有効（10.0.0.0/8のみVPN経由） |

**アクセス制御:**
- Client VPN → Transit Gateway → App VPC（10.1.0.0/16）への通信を許可

---

## 4. コンピューティング設計

### 4.1 ECS Fargate

#### 4.1.1 ECS Cluster

| 項目 | 値 |
|-----|---|
| **名前** | CareApp-POC-ECSCluster-Main |
| **キャパシティプロバイダー** | FARGATE |
| **Container Insights** | 有効 |

#### 4.1.2 タスク定義（例: Backendタスク）

| 項目 | 値 |
|-----|---|
| **タスク名** | CareApp-POC-Backend-Task |
| **起動タイプ** | FARGATE |
| **CPU** | 0.25 vCPU（POC）、0.5 vCPU（本番） |
| **メモリ** | 0.5 GB（POC）、1 GB（本番） |
| **ネットワークモード** | awsvpc |

**コンテナ定義:**
- **イメージ**: {ECR URI}/careapp-backend:latest
- **ポート**: 8080
- **環境変数**: Secrets Manager参照（DB接続情報）

#### 4.1.3 ECS Service

| 項目 | 値 |
|-----|---|
| **サービス名** | CareApp-POC-Backend-Service |
| **タスク数** | 2（POC）、4-8（本番、Auto Scaling） |
| **ロードバランサー** | ALB Target Group紐付け |
| **デプロイタイプ** | Rolling Update |

**Auto Scaling（本番のみ）:**
- **最小タスク数**: 4
- **最大タスク数**: 8
- **スケールアウト条件**: CPU使用率 > 70%（5分継続）
- **スケールイン条件**: CPU使用率 < 30%（5分継続）

### 4.2 Application Load Balancer

| 項目 | 値 |
|-----|---|
| **名前** | CareApp-POC-ALB-App |
| **スキーム** | internet-facing |
| **サブネット** | Public Subnet |
| **セキュリティグループ** | ALB Security Group |
| **アクセスログ** | S3バケットに記録 |

**リスナー:**
| プロトコル | ポート | デフォルトアクション |
|----------|-------|------------------|
| HTTPS | 443 | Frontend Target Groupへ転送 |

**ターゲットグループ:**
| 名前 | プロトコル | ポート | ヘルスチェックパス |
|-----|----------|-------|----------------|
| CareApp-POC-TG-Frontend | HTTP | 8080 | /health |
| CareApp-POC-TG-Backend | HTTP | 8080 | /api/health |

---

## 5. データベース設計

### 5.1 RDS PostgreSQL

| 項目 | 値（POC） | 値（本番） |
|-----|---------|----------|
| **エンジン** | PostgreSQL 15 | PostgreSQL 15 |
| **インスタンスクラス** | db.t3.micro | db.m5.large |
| **ストレージ** | 20 GB（汎用SSD） | 100 GB（汎用SSD） |
| **Multi-AZ** | 無効 | 有効 |
| **暗号化** | 無効 | 有効（AWS KMS） |
| **自動バックアップ** | 7日保管 | 30日保管 |
| **バックアップウィンドウ** | 02:00-03:00 JST | 02:00-03:00 JST |

### 5.2 DB接続情報管理

**AWS Secrets Manager使用:**
```json
{
  "username": "admin",
  "password": "{自動生成32文字}",
  "engine": "postgres",
  "host": "{RDSエンドポイント}",
  "port": 5432,
  "dbname": "careapp"
}
```

**シークレット名:** `CareApp-POC-DB-Secret`

---

## 6. 認証設計

### 6.1 Amazon Cognito User Pool

| 項目 | 値 |
|-----|---|
| **プール名** | CareApp-POC-UserPool |
| **サインイン方法** | Email |
| **パスワードポリシー** | 最小8文字、大文字・小文字・数字・記号必須 |
| **MFA** | オプション（本番は必須推奨） |
| **パスワード有効期限** | 90日 |

### 6.2 ユーザーグループ

| グループ名 | 説明 | 権限 |
|----------|-----|-----|
| Administrators | 市職員（管理者） | 全申請閲覧・審査、マスタ管理 |
| BusinessUsers | 介護事業者 | 自社申請のみ閲覧・作成 |

---

## 7. ストレージ設計

### 7.1 S3バケット

#### 7.1.1 アプリケーションバケット

| 項目 | 値 |
|-----|---|
| **バケット名** | careapp-poc-app-{account-id} |
| **用途** | 申請書添付ファイル保存 |
| **暗号化** | SSE-S3（POC）、SSE-KMS（本番） |
| **バージョニング** | 有効 |
| **ライフサイクル** | 90日後Glacier移行 |
| **パブリックアクセス** | すべてブロック |

#### 7.1.2 ログバケット

| 項目 | 値 |
|-----|---|
| **バケット名** | careapp-poc-logs-{account-id} |
| **用途** | ALBアクセスログ、CloudTrailログ |
| **暗号化** | SSE-S3 |
| **ライフサイクル** | 90日後削除 |

### 7.2 ECR（コンテナレジストリ）

| リポジトリ名 | 用途 |
|------------|-----|
| careapp-frontend | Reactアプリコンテナイメージ |
| careapp-backend | Node.js/Pythonアプリコンテナイメージ |

**イメージスキャン:** プッシュ時に自動スキャン有効

---

## 8. 監視・ログ設計

### 8.1 CloudWatch Logs

| ロググループ名 | 保管期間 | ソース |
|-------------|---------|-------|
| /aws/ecs/careapp-frontend | 90日 | ECS Frontendタスク |
| /aws/ecs/careapp-backend | 90日 | ECS Backendタスク |
| /aws/rds/careapp-poc | 90日 | RDS PostgreSQL |
| /aws/vpc/careapp-poc-app | 90日 | VPC Flow Logs |

### 8.2 CloudWatch Alarms

| アラーム名 | メトリクス | 条件 | アクション |
|----------|----------|-----|----------|
| ECS-HighCPU | ECS CPU使用率 | > 80%（5分） | SNS通知 |
| RDS-HighCPU | RDS CPU使用率 | > 80%（5分） | SNS通知 |
| ALB-High5xxError | ALB 5xxエラー率 | > 5%（5分） | SNS通知 |
| RDS-LowStorage | RDS空きストレージ | < 20% | SNS通知 |

### 8.3 CloudTrail

**POC環境:**
- 有効化（推奨）
- S3ログバケットに保存

**本番環境:**
- 必須
- S3 + CloudWatch Logs統合
- 90日後S3 Glacier移行

---

## 9. IAM設計

### 9.1 ECS Task Execution Role

**権限:**
- ECRイメージプル
- CloudWatch Logs作成・書き込み
- Secrets Manager読み取り（環境変数注入用）

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/ecs/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:CareApp-*"
    }
  ]
}
```

### 9.2 ECS Task Role

**権限:**
- S3読み書き（申請書添付ファイル）
- SES送信（メール通知）
- Secrets Manager読み取り（DB接続情報）

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::careapp-poc-app-*/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:CareApp-POC-DB-Secret-*"
    }
  ]
}
```

---

## 10. デプロイ設計

### 10.1 CloudFormation スタック構成

**Cross-Stack References方式を採用**

```
1. CareApp-POC-SharedNetwork
   ├── Shared VPC
   ├── Transit Gateway
   └── Client VPN

2. CareApp-POC-AppNetwork（依存: SharedNetwork）
   ├── App VPC
   ├── サブネット
   ├── ALB
   └── セキュリティグループ

3. CareApp-POC-Database（依存: AppNetwork）
   ├── RDS PostgreSQL
   └── Secrets Manager

4. CareApp-POC-AppPlatform（依存: AppNetwork, Database）
   ├── ECS Cluster
   ├── ECR
   ├── Cognito
   └── S3
```

**デプロイ順序:**
```
SharedNetwork → AppNetwork → (Database & AppPlatform 並列実行可能)
```

### 10.2 CI/CD（将来対応）

**GitHub Actions:**
```
1. コードpush
2. Dockerイメージビルド
3. ECR push
4. ECS Task Definition更新
5. ECS Service更新（Rolling Update）
```

---

## 11. コスト見積もり

### 11.1 月額コスト（POC環境）

| サービス | スペック | 月額（円） |
|---------|---------|----------|
| ECS Fargate | 0.25vCPU, 0.5GB, 2タスク | 2,000 |
| RDS PostgreSQL | db.t3.micro Single-AZ | 2,000 |
| ALB | - | 2,500 |
| Client VPN | 1エンドポイント | 5,000 |
| NAT Gateway | Single-AZ | 3,500 |
| S3 | 10GB | 300 |
| CloudWatch | 標準監視 | 500 |
| その他 | Cognito, Secrets Manager等 | 700 |
| **合計** | - | **約16,500円** |

---

**作成日**: 2025-10-03
**承認者**: （承認後に記入）
**承認日**: （承認後に記入）
