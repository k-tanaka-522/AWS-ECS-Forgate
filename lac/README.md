# ESCForgate インフラストラクチャ

このリポジトリには、ESCForgate（業務管理システム）のインフラストラクチャコードが含まれています。CloudFormationとTerraformの両方の実装を提供しています。

## 前提条件

- AWS CLI がインストールされ、適切に設定されていること
- AWS認証情報が設定されていること
- Terraform（v1.0.0以上）がインストールされていること（Terraformを使用する場合）

## ディレクトリ構造

```
.
├── cloud formation/          # CloudFormation テンプレート
│   ├── network.yaml         # VPC、サブネット、セキュリティグループ
│   ├── database.yaml        # RDS設定
│   ├── auth.yaml            # Cognito設定
│   ├── compute.yaml         # ECS、ALB設定
│   ├── parameters-dev.json  # 開発環境用パラメータ
│   └── deploy.sh            # デプロイスクリプト
│
└── terraform/               # Terraform モジュール
    ├── modules/             # 各種モジュール
    │   ├── network/        # ネットワークモジュール
    │   ├── database/       # データベースモジュール
    │   ├── auth/           # 認証モジュール
    │   └── compute/        # コンピュートモジュール
    ├── environments/       # 環境別の変数ファイル
    │   └── dev.tfvars     # 開発環境用変数
    ├── main.tf            # メインの設定ファイル
    └── deploy.sh          # デプロイスクリプト
```

## CloudFormationを使用した構築手順

1. パラメータファイルの設定
```bash
# parameters-dev.json を編集し、必要な値を設定
vi cloud\ formation/parameters-dev.json
```

2. スタックのデプロイ
```bash
cd cloud\ formation
./deploy.sh
```

このスクリプトは以下の順序でスタックをデプロイします：
1. ネットワークスタック
2. データベーススタック
3. 認証スタック
4. コンピュートスタック

## Terraformを使用した構築手順

1. 環境変数の設定
```bash
# dev.tfvars を編集し、必要な値を設定
vi terraform/environments/dev.tfvars
```

2. インフラストラクチャのデプロイ
```bash
cd terraform
./deploy.sh dev init    # 初期化
./deploy.sh dev plan    # 実行計画の確認
./deploy.sh dev apply   # リソースの作成
```

## 環境の削除

### CloudFormation
```bash
# スタックの削除（逆順）
aws cloudformation delete-stack --stack-name escforgate-dev-compute
aws cloudformation delete-stack --stack-name escforgate-dev-auth
aws cloudformation delete-stack --stack-name escforgate-dev-database
aws cloudformation delete-stack --stack-name escforgate-dev-network
```

### Terraform
```bash
cd terraform
./deploy.sh dev destroy
```

## 注意事項

- サンプル構築では、最小限のリソース（ECS、RDS、Cognito）のみを使用します
- 監視とアラートの設定は、サンプル構築では含まれていません
- 本番環境での使用前に、セキュリティ設定を十分に確認してください
- データベースのパスワードなど、機密情報は適切に管理してください

## セキュリティ

- すべての認証情報は AWS Secrets Manager で管理されます
- VPCエンドポイントを使用して、プライベートサブネットからのアクセスを確保します
- セキュリティグループで必要最小限のアクセスのみを許可します

## サポート

問題や質問がある場合は、プロジェクトの管理者に連絡してください。
