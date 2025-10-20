# Infrastructure as Code (CloudFormation)

このディレクトリには、AWS Multi-Account構成のインフラストラクチャコードが含まれています。

## ディレクトリ構造

```
infra/
├── platform/                    # Platform Account用
│   ├── stack.yaml              # 親スタック
│   ├── nested/                 # ネストスタック
│   │   ├── network.yaml        # VPC, Subnets, NAT Gateways
│   │   └── connectivity.yaml   # Transit Gateway, Client VPN, RAM
│   ├── parameters-dev.json     # 開発環境パラメータ
│   └── parameters-prod.json    # 本番環境パラメータ
├── service/                     # Service Account用
│   ├── 01-network.yaml         # VPC, Transit Gateway Attachment
│   ├── 02-database.yaml        # RDS PostgreSQL, Secrets Manager
│   ├── 03-compute.yaml         # ECS Fargate, ALB, Auto Scaling
│   ├── parameters-dev.json     # 開発環境パラメータ
│   └── parameters-prod.json    # 本番環境パラメータ
└── README.md                    # このファイル
```

## デプロイ前提条件

### Platform Account

1. **S3バケット作成**（Nested Templates用）
   ```bash
   aws s3 mb s3://myapp-dev-cfn-templates --region ap-northeast-1
   ```

2. **Client VPN用証明書の作成**
   ```bash
   # サーバー証明書
   openssl genrsa -out server-key.pem 2048
   openssl req -new -key server-key.pem -out server-csr.pem
   openssl x509 -req -days 3650 -in server-csr.pem -signkey server-key.pem -out server-cert.pem

   # ACMにインポート
   aws acm import-certificate \
     --certificate fileb://server-cert.pem \
     --private-key fileb://server-key.pem \
     --region ap-northeast-1

   # クライアント証明書も同様に作成してACMにインポート
   ```

3. **Nested TemplatesをS3にアップロード**
   ```bash
   aws s3 cp infra/platform/nested/ s3://myapp-dev-cfn-templates/nested/ --recursive
   ```

### Service Account

1. **ECRリポジトリ作成**
   ```bash
   aws ecr create-repository --repository-name myapp/public-web --region ap-northeast-1
   aws ecr create-repository --repository-name myapp/admin-dashboard --region ap-northeast-1
   aws ecr create-repository --repository-name myapp/batch-processing --region ap-northeast-1
   ```

2. **ACM証明書取得**（Admin Dashboard ALB用）
   ```bash
   # AWS Certificate Managerでドメイン証明書を取得
   # または、既存証明書のARNを確認
   aws acm list-certificates --region ap-northeast-1
   ```

## デプロイ手順

### 1. Platform Accountのデプロイ

```bash
# 1. Change Set作成
aws cloudformation create-change-set \
  --stack-name myapp-dev-platform \
  --change-set-name myapp-dev-platform-changeset-$(date +%Y%m%d%H%M%S) \
  --template-body file://infra/platform/stack.yaml \
  --parameters file://infra/platform/parameters-dev.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# 2. Change Set確認
aws cloudformation describe-change-set \
  --stack-name myapp-dev-platform \
  --change-set-name <CHANGE_SET_NAME> \
  --region ap-northeast-1

# 3. Change Set実行
aws cloudformation execute-change-set \
  --stack-name myapp-dev-platform \
  --change-set-name <CHANGE_SET_NAME> \
  --region ap-northeast-1

# 4. デプロイ完了確認
aws cloudformation wait stack-create-complete \
  --stack-name myapp-dev-platform \
  --region ap-northeast-1
```

### 2. Transit Gateway IDとRoute Table IDの取得

```bash
# Platform Accountデプロイ後、以下のコマンドで取得
aws cloudformation describe-stacks \
  --stack-name myapp-dev-platform \
  --query 'Stacks[0].Outputs' \
  --region ap-northeast-1
```

取得した値を `infra/service/parameters-dev.json` の以下のパラメータに設定：
- `TransitGatewayId`
- `TransitGatewayRouteTableId`

### 3. Service Account - Networkのデプロイ

```bash
# Service Accountへスイッチ
export AWS_PROFILE=service-account

# 1. Change Set作成
aws cloudformation create-change-set \
  --stack-name myapp-dev-service-network \
  --change-set-name myapp-dev-service-network-changeset-$(date +%Y%m%d%H%M%S) \
  --template-body file://infra/service/01-network.yaml \
  --parameters file://infra/service/parameters-dev.json#01-network \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# 2-3. Change Set確認と実行（Platform Accountと同様）

# 4. デプロイ完了確認
aws cloudformation wait stack-create-complete \
  --stack-name myapp-dev-service-network \
  --region ap-northeast-1
```

### 4. Service Account - Databaseのデプロイ

```bash
aws cloudformation create-change-set \
  --stack-name myapp-dev-service-database \
  --change-set-name myapp-dev-service-database-changeset-$(date +%Y%m%d%H%M%S) \
  --template-body file://infra/service/02-database.yaml \
  --parameters file://infra/service/parameters-dev.json#02-database \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# Change Set確認・実行・完了確認（前述と同様）
```

### 5. Service Account - Computeのデプロイ

```bash
aws cloudformation create-change-set \
  --stack-name myapp-dev-service-compute \
  --change-set-name myapp-dev-service-compute-changeset-$(date +%Y%m%d%H%M%S) \
  --template-body file://infra/service/03-compute.yaml \
  --parameters file://infra/service/parameters-dev.json#03-compute \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# Change Set確認・実行・完了確認（前述と同様）
```

## パラメータのカスタマイズ

### Platform Account (`parameters-dev.json`)

| パラメータ | 説明 | デフォルト値 |
|----------|------|------------|
| ProjectName | プロジェクト名 | myapp |
| Environment | 環境名 (dev/prod) | dev |
| ServiceAccountId | Service AccountのAWSアカウントID | 123456789012 |
| VpcCidr | Platform VPCのCIDR | 10.0.0.0/16 |
| ClientVpnCidr | Client VPNクライアントCIDR | 172.16.0.0/22 |
| ServerCertificateArn | VPNサーバー証明書ARN | - |
| ClientRootCertificateArn | VPNクライアント証明書ARN | - |
| NestedTemplatesBucketName | S3バケット名 | myapp-dev-cfn-templates |

### Service Account - Network (`parameters-dev.json#01-network`)

| パラメータ | 説明 | デフォルト値 |
|----------|------|------------|
| ProjectName | プロジェクト名 | myapp |
| Environment | 環境名 (dev/prod) | dev |
| VpcCidr | Service VPCのCIDR | 10.1.0.0/16 |
| PlatformVpcCidr | Platform VPCのCIDR（ルーティング用） | 10.0.0.0/16 |
| TransitGatewayId | Transit Gateway ID | - |
| TransitGatewayRouteTableId | Transit Gateway Route Table ID | - |

### Service Account - Database (`parameters-dev.json#02-database`)

| パラメータ | 説明 | デフォルト値 |
|----------|------|------------|
| ProjectName | プロジェクト名 | myapp |
| Environment | 環境名 (dev/prod) | dev |
| DBInstanceClass | RDSインスタンスクラス | db.t3.micro (dev) / db.t3.medium (prod) |
| DBAllocatedStorage | ストレージサイズ (GB) | 20 (dev) / 100 (prod) |
| DBBackupRetentionDays | バックアップ保持日数 | 7 (dev) / 30 (prod) |
| DBMasterUsername | DBマスターユーザー名 | postgres |

### Service Account - Compute (`parameters-dev.json#03-compute`)

| パラメータ | 説明 | デフォルト値 |
|----------|------|------------|
| ProjectName | プロジェクト名 | myapp |
| Environment | 環境名 (dev/prod) | dev |
| ECRRepositoryUri | ECRリポジトリURI | - |
| PublicWebImageTag | Public Webイメージタグ | latest (dev) / v1.0.0 (prod) |
| AdminDashboardImageTag | Admin Dashboardイメージタグ | latest (dev) / v1.0.0 (prod) |
| BatchProcessingImageTag | Batch Processingイメージタグ | latest (dev) / v1.0.0 (prod) |
| PublicWebDesiredCount | Public Webタスク数 | 2 (dev) / 4 (prod) |
| AdminDashboardDesiredCount | Admin Dashboardタスク数 | 2 |
| BatchProcessingDesiredCount | Batch Processingタスク数 | 1 (dev) / 2 (prod) |
| AdminCertificateArn | Admin Dashboard ALB証明書ARN | - |

## スタック削除手順

**重要：** 削除は逆順で実行してください。

```bash
# 1. Service Account - Compute
aws cloudformation delete-stack --stack-name myapp-dev-service-compute --region ap-northeast-1
aws cloudformation wait stack-delete-complete --stack-name myapp-dev-service-compute --region ap-northeast-1

# 2. Service Account - Database
aws cloudformation delete-stack --stack-name myapp-dev-service-database --region ap-northeast-1
aws cloudformation wait stack-delete-complete --stack-name myapp-dev-service-database --region ap-northeast-1

# 3. Service Account - Network
aws cloudformation delete-stack --stack-name myapp-dev-service-network --region ap-northeast-1
aws cloudformation wait stack-delete-complete --stack-name myapp-dev-service-network --region ap-northeast-1

# 4. Platform Account (Service Accountの削除後)
export AWS_PROFILE=platform-account
aws cloudformation delete-stack --stack-name myapp-dev-platform --region ap-northeast-1
aws cloudformation wait stack-delete-complete --stack-name myapp-dev-platform --region ap-northeast-1
```

## トラブルシューティング

### Transit Gateway Attachmentが失敗する

**原因：** RAM Resource Shareの承認が必要

**解決策：**
```bash
# Service Accountで承認
aws ram get-resource-share-invitations --region ap-northeast-1
aws ram accept-resource-share-invitation --resource-share-invitation-arn <ARN> --region ap-northeast-1
```

### RDSインスタンス作成が失敗する

**原因：** Secrets Managerのパスワード生成で使用できない文字が含まれている

**解決策：** CloudFormation テンプレートの `ExcludeCharacters` を確認・調整

### ECSタスクが起動しない

**原因：**
1. ECRイメージが存在しない
2. Secrets ManagerまたはParameter Storeの値が取得できない
3. Security Groupで通信がブロックされている

**解決策：**
```bash
# 1. ECRイメージ確認
aws ecr describe-images --repository-name myapp/public-web --region ap-northeast-1

# 2. Secrets Manager確認
aws secretsmanager get-secret-value --secret-id myapp/dev/db/credentials --region ap-northeast-1

# 3. ECSタスクログ確認
aws logs tail /ecs/myapp-dev/public-web --follow --region ap-northeast-1
```

## セキュリティ推奨事項

1. **パラメータファイルの管理**
   - AWSアカウントID、証明書ARN等の実際の値に置き換える
   - `.gitignore`に `**/secrets.json` を追加（機密情報は別管理）

2. **IAMロールの最小権限化**
   - 各サービスに必要最小限の権限のみ付与

3. **暗号化の有効化**
   - すべてのリソース（RDS、S3、Secrets Manager）で暗号化を有効化済み

4. **監視の有効化**
   - CloudWatch Container Insights有効化済み
   - RDS Enhanced Monitoring有効化済み

## 参考ドキュメント

- [AWS CloudFormation ベストプラクティス](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/best-practices.html)
- [AWS Multi-Account戦略](https://aws.amazon.com/jp/organizations/getting-started/best-practices/)
- [AWS Transit Gateway](https://docs.aws.amazon.com/ja_jp/vpc/latest/tgw/what-is-transit-gateway.html)
- [AWS Client VPN](https://docs.aws.amazon.com/ja_jp/vpn/latest/clientvpn-admin/what-is.html)
