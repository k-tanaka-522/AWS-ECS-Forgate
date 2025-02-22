# データベースモジュール

RDSとSecretsManagerのリソースを管理します。

## 構成

- Amazon RDS
  - MySQL 8.0
  - マルチAZ配置
  - 自動バックアップ
  - パラメータグループ
- Secrets Manager
  - データベース認証情報

## 環境差分

各環境で異なるインスタンスタイプとストレージを使用：

```
dev:
  instance:
    class: db.t3.small
    storage: 20GB
  backup:
    retention: 7
  multi_az: false

stg:
  instance:
    class: db.t3.medium
    storage: 50GB
  backup:
    retention: 14
  multi_az: false

prd:
  instance:
    class: db.r5.large
    storage: 100GB
  backup:
    retention: 30
  multi_az: true
```

## パラメータ

| パラメータ名 | 説明 | デフォルト値 |
|------------|------|------------|
| Environment | 環境名 (dev/stg/prd) | dev |
| DBName | データベース名 | wordpress |
| DBUsername | データベースユーザー名 | admin |
| DBInstanceClass | インスタンスクラス | db.t3.small |
| DBAllocatedStorage | ストレージサイズ(GB) | 20 |
| MultiAZ | マルチAZ配置の有効化 | false |
| BackupRetentionPeriod | バックアップ保持期間(日) | 7 |

## 出力値

| 出力名 | 説明 | 用途 |
|--------|------|------|
| DBEndpoint | RDSエンドポイント | アプリケーション接続用 |
| DBSecretArn | DB認証情報のシークレットARN | ECSタスク定義での参照用 |

## 依存関係

このモジュールは以下のモジュールに依存します：

- networkモジュール
  - VPC ID
  - プライベートサブネット ID
  - セキュリティグループ ID

## シークレット管理

以下の情報をSecretsManagerで管理：

```json
{
  "username": "admin",
  "password": "自動生成されたパスワード",
  "engine": "mysql",
  "host": "RDSエンドポイント",
  "port": 3306,
  "dbname": "wordpress"
}
```

## セキュリティ設定

1. ネットワーク
   - プライベートサブネットに配置
   - セキュリティグループでアクセス制限

2. 暗号化
   - 保存時の暗号化有効
   - 転送時の暗号化有効（強制SSL）

3. バックアップ
   - 自動バックアップ
   - スナップショット
   - トランザクションログ

## 監視設定

CloudWatchメトリクス：
- CPU使用率
- メモリ使用率
- ディスク使用量
- IOPS
- レイテンシー

## メンテナンス

1. バックアップウィンドウ
   - dev: 17:00-18:00 UTC
   - stg: 16:00-17:00 UTC
   - prd: 15:00-16:00 UTC

2. メンテナンスウィンドウ
   - dev: 月曜 17:00-18:00 UTC
   - stg: 火曜 16:00-17:00 UTC
   - prd: 水曜 15:00-16:00 UTC
