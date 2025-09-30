# AWS構成図

## 1. POC環境構成図

### 1.1 全体構成（POC）

```mermaid
graph TB
    subgraph "POC用AWSアカウント（1アカウント）"
        subgraph "共有系VPC 10.0.0.0/16"
            subgraph "Public Subnet 10.0.1.0/24 (AZ-a)"
                VPN[Client VPN Endpoint]
            end

            TGW[Transit Gateway]
            TGWAttach1[TGW Attachment<br/>共有系VPC]
        end

        subgraph "アプリ系VPC 10.1.0.0/16"
            subgraph "Public Subnet 10.1.1.0/24 (AZ-a)"
                ALB[Application Load Balancer]
                NAT1[NAT Gateway]
            end

            subgraph "Public Subnet 10.1.2.0/24 (AZ-c)"
                NAT2[NAT Gateway]
            end

            subgraph "Private Subnet App 10.1.11.0/24 (AZ-a)"
                ECS1[ECS Fargate<br/>Frontend + Backend<br/>Task 1]
            end

            subgraph "Private Subnet App 10.1.12.0/24 (AZ-c)"
                ECS2[ECS Fargate<br/>Frontend + Backend<br/>Task 2]
            end

            subgraph "Private Subnet DB 10.1.21.0/24 (AZ-a)"
                RDS[(RDS PostgreSQL<br/>Single-AZ<br/>db.t3.micro)]
            end

            IGW[Internet Gateway]
            TGWAttach2[TGW Attachment<br/>アプリ系VPC]
        end

        ECR[Amazon ECR<br/>Container Registry]
        CW[CloudWatch<br/>Logs & Metrics]
        Cognito[Amazon Cognito<br/>User Pool]
        SES[Amazon SES<br/>Email送信]
        S3[Amazon S3<br/>PDF保存]
        EventBridge[EventBridge<br/>バッチスケジュール]
        ECSTask[ECS Task<br/>バッチ処理]
    end

    Developer[開発者<br/>市職員役<br/>Client VPN接続]
    BusinessUser[事業者<br/>インターネット]

    Developer -->|VPN接続| VPN
    VPN --> TGWAttach1
    TGWAttach1 --> TGW
    TGW --> TGWAttach2
    TGWAttach2 --> ECS1
    TGWAttach2 --> ECS2

    BusinessUser -->|HTTPS| IGW
    IGW --> ALB
    ALB --> ECS1
    ALB --> ECS2

    ECS1 --> RDS
    ECS2 --> RDS
    ECS1 --> S3
    ECS2 --> S3
    ECS1 --> SES
    ECS2 --> SES
    ECS1 -.-> ECR
    ECS2 -.-> ECR
    ECS1 --> CW
    ECS2 --> CW
    ECS1 --> Cognito
    ECS2 --> Cognito
    EventBridge -->|定時起動| ECSTask
    ECSTask --> RDS

    ECS1 --> NAT1
    ECS2 --> NAT2
    NAT1 --> IGW
    NAT2 --> IGW

    style Developer fill:#e1f5ff
    style BusinessUser fill:#fff4e1
```

### 1.2 POC環境の特徴

- **1アカウント、2VPC構成**: 共有系VPCとアプリ系VPCを分離
- **Transit Gateway検証**: 本番と同じTGW経由のルーティングを確認
- **2つのアクセス経路**:
  - 事業者: インターネット → ALB（本番と同じ経路）
  - 市職員役（開発者）: Client VPN → TGW → アプリVPC（本番はDirect Connectに置き換え）
- **Single-AZ構成**: コスト削減のためRDSは単一AZ
- **最小リソース**: db.t3.micro、ECS最小タスク数

---

## 2. 本番環境構成図

### 2.1 全体構成（本番）

```mermaid
graph TB
    subgraph "オンプレミス（市庁舎）"
        CityStaff[市職員PC]
    end

    subgraph "共有系AWSアカウント"
        DXG[Direct Connect<br/>Gateway]
        TGW[Transit Gateway]

        DXG -->|Private VIF| TGW
    end

    subgraph "本番用AWSアカウント"
        subgraph "VPC 10.1.0.0/16"
            subgraph "Public Subnet 10.1.1.0/24 (AZ-a)"
                ALB1[Application Load Balancer]
                NAT1[NAT Gateway]
            end

            subgraph "Public Subnet 10.1.2.0/24 (AZ-c)"
                NAT2[NAT Gateway]
            end

            subgraph "Private Subnet App 10.1.11.0/24 (AZ-a)"
                ECS1[ECS Fargate<br/>Frontend<br/>Task 2-6]
                ECS3[ECS Fargate<br/>Backend<br/>Task 2-8]
            end

            subgraph "Private Subnet App 10.1.12.0/24 (AZ-c)"
                ECS2[ECS Fargate<br/>Frontend<br/>Task 2-6]
                ECS4[ECS Fargate<br/>Backend<br/>Task 2-8]
            end

            subgraph "Private Subnet DB 10.1.21.0/24 (AZ-a)"
                RDSPrimary[(RDS PostgreSQL<br/>Primary<br/>db.m5.large)]
            end

            subgraph "Private Subnet DB 10.1.22.0/24 (AZ-c)"
                RDSStandby[(RDS PostgreSQL<br/>Standby<br/>db.m5.large)]
            end

            IGW[Internet Gateway]
            TGWA[Transit Gateway<br/>Attachment]
        end

        WAF[AWS WAF]
        ECR[Amazon ECR]
        CW[CloudWatch<br/>Logs & Metrics]
        Cognito[Amazon Cognito<br/>User Pool]
        SES[Amazon SES]
        S3[Amazon S3<br/>PDF + Backup]
        SecretsManager[Secrets Manager<br/>DB認証情報]
        GuardDuty[GuardDuty<br/>脅威検知]
        Config[AWS Config<br/>コンプライアンス]
        EventBridge[EventBridge]
        ECSTask[ECS Task<br/>バッチ処理]
        Bedrock[Amazon Bedrock<br/>AI運用支援]
    end

    subgraph "大阪リージョン (DR)"
        S3DR[S3<br/>スナップショットコピー]
    end

    BusinessUser[事業者<br/>インターネット]

    CityStaff -->|Direct Connect| DXG
    TGW --> TGWA
    TGWA --> ECS1
    TGWA --> ECS2
    TGWA --> ECS3
    TGWA --> ECS4

    BusinessUser -->|HTTPS| WAF
    WAF --> IGW
    IGW --> ALB1
    ALB1 --> ECS1
    ALB1 --> ECS2
    ALB1 --> ECS3
    ALB1 --> ECS4

    ECS1 --> RDSPrimary
    ECS2 --> RDSPrimary
    ECS3 --> RDSPrimary
    ECS4 --> RDSPrimary
    RDSPrimary -.->|レプリケーション| RDSStandby

    ECS1 --> S3
    ECS2 --> S3
    ECS3 --> S3
    ECS4 --> S3

    ECS1 --> SES
    ECS2 --> SES
    ECS3 --> SES
    ECS4 --> SES

    ECS1 -.-> ECR
    ECS2 -.-> ECR
    ECS3 -.-> ECR
    ECS4 -.-> ECR

    ECS1 --> CW
    ECS2 --> CW
    ECS3 --> CW
    ECS4 --> CW

    ECS1 --> Cognito
    ECS2 --> Cognito
    ECS3 --> Cognito
    ECS4 --> Cognito

    ECS1 --> SecretsManager
    ECS2 --> SecretsManager
    ECS3 --> SecretsManager
    ECS4 --> SecretsManager

    RDSPrimary --> SecretsManager

    EventBridge -->|定時起動| ECSTask
    ECSTask --> RDSPrimary

    S3 -->|日次コピー| S3DR

    CW --> Bedrock
    GuardDuty --> CW
    Config --> CW

    ECS1 --> NAT1
    ECS2 --> NAT2
    ECS3 --> NAT1
    ECS4 --> NAT2
    NAT1 --> IGW
    NAT2 --> IGW

    style CityStaff fill:#e1f5ff
    style BusinessUser fill:#fff4e1
```

### 2.2 本番環境の特徴

- **Multi-AZ構成**: RDS、ECSタスクが複数AZに分散
- **Direct Connect + Transit Gateway**: 市庁舎からセキュアに接続
- **WAF**: インターネットからの攻撃を防御
- **Auto Scaling**: ECSタスクが負荷に応じて自動スケール
- **DR対応**: 大阪リージョンにスナップショットコピー

---

## 3. ネットワーク詳細

### 3.1 POC環境のネットワーク構成

#### 共有系VPC (10.0.0.0/16)

| サブネット種別 | CIDR | AZ | 用途 |
|--------------|------|----|----|
| Public Subnet 1 | 10.0.1.0/24 | ap-northeast-1a | Client VPN Endpoint |

#### アプリ系VPC (10.1.0.0/16)

| サブネット種別 | CIDR | AZ | 用途 |
|--------------|------|----|----|
| Public Subnet 1 | 10.1.1.0/24 | ap-northeast-1a | ALB, NAT Gateway |
| Public Subnet 2 | 10.1.2.0/24 | ap-northeast-1c | NAT Gateway |
| Private Subnet App 1 | 10.1.11.0/24 | ap-northeast-1a | ECS Fargate |
| Private Subnet App 2 | 10.1.12.0/24 | ap-northeast-1c | ECS Fargate |
| Private Subnet DB 1 | 10.1.21.0/24 | ap-northeast-1a | RDS |

### 3.2 本番環境のネットワーク構成

| サブネット種別 | CIDR | AZ | 用途 |
|--------------|------|----|----|
| Public Subnet 1 | 10.1.1.0/24 | ap-northeast-1a | ALB, NAT Gateway |
| Public Subnet 2 | 10.1.2.0/24 | ap-northeast-1c | ALB, NAT Gateway |
| Private Subnet App 1 | 10.1.11.0/24 | ap-northeast-1a | ECS Fargate |
| Private Subnet App 2 | 10.1.12.0/24 | ap-northeast-1c | ECS Fargate |
| Private Subnet DB 1 | 10.1.21.0/24 | ap-northeast-1a | RDS Primary |
| Private Subnet DB 2 | 10.1.22.0/24 | ap-northeast-1c | RDS Standby |

---

## 4. セキュリティグループ構成

### 4.1 ALB Security Group

| 方向 | プロトコル | ポート | ソース | 用途 |
|-----|----------|-------|--------|-----|
| Inbound | TCP | 443 | 0.0.0.0/0 | HTTPS（事業者） |
| Inbound | TCP | 443 | VPC CIDR | HTTPS（市職員） |
| Outbound | TCP | 3000 | ECS SG | Frontend |
| Outbound | TCP | 5000 | ECS SG | Backend API |

### 4.2 ECS Security Group

| 方向 | プロトコル | ポート | ソース | 用途 |
|-----|----------|-------|--------|-----|
| Inbound | TCP | 3000 | ALB SG | Frontend |
| Inbound | TCP | 5000 | ALB SG | Backend API |
| Inbound | TCP | 3000 | VPN CIDR | Frontend（POC開発者） |
| Inbound | TCP | 5000 | VPN CIDR | Backend API（POC開発者） |
| Outbound | TCP | 5432 | RDS SG | PostgreSQL |
| Outbound | TCP | 443 | 0.0.0.0/0 | AWS API, SES, S3 |

### 4.3 RDS Security Group

| 方向 | プロトコル | ポート | ソース | 用途 |
|-----|----------|-------|--------|-----|
| Inbound | TCP | 5432 | ECS SG | PostgreSQL |
| Outbound | - | - | - | なし |

---

## 5. コンポーネント詳細

### 5.1 ECS Fargate

#### POC環境
- **Frontend**:
  - CPU: 256 (.25 vCPU)
  - Memory: 512 MB
  - タスク数: 1-2
  - コンテナポート: 3000
- **Backend**:
  - CPU: 256 (.25 vCPU)
  - Memory: 512 MB
  - タスク数: 1-2
  - コンテナポート: 5000

#### 本番環境
- **Frontend**:
  - CPU: 512 (.5 vCPU)
  - Memory: 1024 MB
  - タスク数: 2-6（Auto Scaling）
  - コンテナポート: 3000
- **Backend**:
  - CPU: 1024 (1 vCPU)
  - Memory: 2048 MB
  - タスク数: 2-8（Auto Scaling）
  - コンテナポート: 5000

### 5.2 RDS PostgreSQL

#### POC環境
- **エンジン**: PostgreSQL 15
- **インスタンスクラス**: db.t3.micro
- **ストレージ**: 20 GB GP3
- **構成**: Single-AZ
- **バックアップ**: 7日間
- **暗号化**: 無効（コスト削減）

####本番環境
- **エンジン**: PostgreSQL 15
- **インスタンスクラス**: db.m5.large
- **ストレージ**: 100 GB GP3（Auto Scaling有効）
- **構成**: Multi-AZ
- **バックアップ**: 30日間
- **暗号化**: 有効（KMS）
- **Performance Insights**: 有効

### 5.3 Amazon Cognito

- **User Pool**: 1つ
- **User Groups**:
  - Administrators（市職員）
  - BusinessUsers（事業者）
- **MFA**: オプション
- **パスワードポリシー**:
  - 最小長: 8文字
  - 大文字・小文字・数字・記号必須
- **Lambda Triggers**:
  - Pre Sign-up（自己登録防止）
  - Post Authentication（ログイン記録）

### 5.4 Application Load Balancer

#### POC環境
- **スキーム**: Internet-facing
- **リスナー**:
  - HTTP:80 → HTTPS:443リダイレクト
  - HTTPS:443 → Target Group
- **ターゲットグループ**:
  - Frontend: /
  - Backend: /api/*
- **ヘルスチェック**:
  - パス: /health
  - 間隔: 30秒
  - タイムアウト: 5秒

####本番環境（POCと同じ + WAF）
- **WAF Rules**:
  - SQLインジェクション防止
  - XSS防止
  - レート制限（100 req/5min/IP）
  - 地域制限（日本のみ許可）

### 5.5 EventBridge + Batch処理

- **スケジュール**:
  - 日次集計: cron(0 2 * * ? *) 毎日2:00
  - 月次締め: cron(0 3 1 * ? *) 毎月1日3:00
- **ECS Task**:
  - CPU: 512
  - Memory: 1024 MB
  - タイムアウト: 6時間

---

## 6. CI/CDパイプライン構成

```mermaid
graph LR
    subgraph "GitHub"
        Repo[リポジトリ]
        Dev[developブランチ]
        Main[mainブランチ]
    end

    subgraph "GitHub Actions"
        Build[ビルド<br/>テスト]
        Push[ECR Push]
        Deploy[ECS Deploy]
    end

    subgraph "開発環境"
        ECRDev[ECR]
        ECSDev[ECS Fargate]
    end

    subgraph "本番環境"
        ECRProd[ECR]
        ECSProd[ECS Fargate]
        Approval[承認待ち]
    end

    Dev -->|push| Build
    Build --> Push
    Push --> ECRDev
    Push --> Deploy
    Deploy --> ECSDev

    Main -->|push| Build
    Build --> Approval
    Approval -->|承認後| Push
    Push --> ECRProd
    Push --> Deploy
    Deploy --> ECSProd
```

---

## 7. 監視・アラート構成

```mermaid
graph TB
    subgraph "監視対象"
        ECS[ECS Fargate]
        RDS[RDS]
        ALB[ALB]
        WAF[WAF]
    end

    subgraph "CloudWatch"
        Metrics[Metrics]
        Logs[Logs]
        Alarms[Alarms]
    end

    subgraph "通知"
        SNS[SNS Topic]
        Email[Email]
        Slack[Slack<br/>将来対応]
    end

    subgraph "AI運用支援"
        Bedrock[Amazon Bedrock<br/>異常検知・原因分析]
    end

    ECS --> Metrics
    RDS --> Metrics
    ALB --> Metrics
    WAF --> Logs

    ECS --> Logs

    Metrics --> Alarms
    Logs --> Bedrock
    Alarms --> SNS
    SNS --> Email
    SNS --> Slack

    Bedrock --> SNS
```

---

## 8. DR（災害復旧）構成

```mermaid
graph LR
    subgraph "東京リージョン（Primary）"
        RDSTokyo[(RDS Primary)]
        S3Tokyo[S3 Backup]
    end

    subgraph "大阪リージョン（DR）"
        S3Osaka[S3<br/>スナップショットコピー]
        RDSOsaka[(RDS復元用<br/>※災害時のみ作成)]
    end

    RDSTokyo -->|自動バックアップ| S3Tokyo
    S3Tokyo -->|日次コピー| S3Osaka
    S3Osaka -.->|災害時に復元| RDSOsaka

    style RDSOsaka stroke-dasharray: 5 5
```

---

## 9. POC → 本番移行時の変更点

| 項目 | POC | 本番 |
|-----|-----|-----|
| AWSアカウント | 1アカウント（2VPC） | 共有系 + 本番用（2アカウント） |
| 共有系VPC | 10.0.0.0/16 | 共有系アカウントに移行 |
| アプリ系VPC | 10.1.0.0/16 | 本番アカウントに移行 |
| ネットワーク接続（市職員） | Client VPN | Direct Connect + TGW |
| Transit Gateway | POCで検証済み | アカウント分離 |
| RDS構成 | Single-AZ | Multi-AZ |
| RDSインスタンス | db.t3.micro | db.m5.large |
| ECS Auto Scaling | 無効 | 有効 |
| WAF | なし | あり |
| GuardDuty | なし | あり |
| Config | なし | あり |
| DR対応 | なし | 大阪リージョンコピー |
| 暗号化 | 無効 | 有効 |

---

**作成日**: 2025-09-30
**承認者**: （承認後に記入）
**承認日**: （承認後に記入）