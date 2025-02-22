# ESCForgate

WordPressサイト用のインフラストラクチャコード

## プロジェクト構成

```
ESCForgate/
├── doc/                      # ドキュメント
│   ├── architecture/        # アーキテクチャ設計
│   │   ├── images/         # 構成図など
│   │   └── *.md
│   ├── operation/          # 運用手順
│   │   ├── デプロイ手順.md
│   │   └── *.md
│   └── requirements/       # 要件定義
│       ├── インフラ要件.md
│       └── 実装定義.md
│
├── iac/                     # Infrastructure as Code
│   ├── cloudformation/     # CloudFormation
│   │   ├── modules/       # 機能別モジュール
│   │   │   ├── network/   # ネットワーク
│   │   │   ├── database/  # データベース
│   │   │   ├── auth/      # 認証
│   │   │   └── compute/   # コンピュート
│   │   ├── env/          # 環境別設定
│   │   │   ├── dev/      # 開発環境
│   │   │   ├── stg/      # ステージング環境
│   │   │   └── prd/      # 本番環境
│   │   └── scripts/      # 運用スクリプト
│   │
│   └── terraform/         # Terraform
│       ├── modules/       # 機能別モジュール
│       ├── env/          # 環境別設定
│       └── scripts/      # 運用スクリプト
│
└── app/                    # アプリケーション
    ├── src/               # ソースコード
    ├── Dockerfile        # コンテナ定義
    └── docker-compose.yml # ローカル開発用
```

## 環境構成

各環境のネットワーク構成：

```
dev:  10.0.0.0/16
stg:  10.1.0.0/16
prd:  10.2.0.0/16

各環境のサブネット:
- public-1:  x.x.0.0/24
- public-2:  x.x.1.0/24
- private-1: x.x.2.0/24
- private-2: x.x.3.0/24
```

## デプロイ方法

### CloudFormationを使用する場合

1. 環境変数の設定
```bash
export ENV=dev  # dev/stg/prd
```

2. スタックのデプロイ
```bash
cd iac/cloudformation/scripts
./deploy.sh
```

### Terraformを使用する場合

1. 環境の初期化
```bash
cd iac/terraform
terraform init
terraform workspace select ${ENV}  # ENV=dev/stg/prd
```

2. デプロイ
```bash
./scripts/deploy.sh
```

## クリーンアップ

リソースの削除：

```bash
# CloudFormationの場合
cd iac/cloudformation/scripts
./cleanup.sh

# Terraformの場合
cd iac/terraform
terraform destroy
```

## 注意事項

- 環境ごとにネットワークセグメントが異なります
- シークレット情報はAWS Secrets Managerで管理
- 環境差分はパラメータファイルで管理
