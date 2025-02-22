# コンピュートモジュール

ECS Fargate、ALB、AutoScalingなどのコンピュートリソースを管理します。

## 構成

- ECS
  - クラスター
  - タスク定義
  - サービス
- Application Load Balancer
  - ターゲットグループ
  - HTTPSリスナー
  - HTTPリスナー（HTTPSへリダイレクト）
- Auto Scaling
  - スケーリングポリシー
  - CloudWatchアラーム
- IAM
  - タスク実行ロール
  - タスクロール
- ACM
  - SSL/TLS証明書

## 環境差分

各環境で異なるリソースサイズを使用：

```
dev:
  task:
    cpu: 256 (0.25vCPU)
    memory: 512MB
  desired_count: 2
  auto_scaling:
    min: 1
    max: 4

stg:
  task:
    cpu: 512 (0.5vCPU)
    memory: 1024MB
  desired_count: 2
  auto_scaling:
    min: 1
    max: 4

prd:
  task:
    cpu: 1024 (1vCPU)
    memory: 2048MB
  desired_count: 2
  auto_scaling:
    min: 2
    max: 8
```

## パラメータ

| パラメータ名 | 説明 | デフォルト値 |
|------------|------|------------|
| Environment | 環境名 (dev/stg/prd) | dev |
| ContainerImage | コンテナイメージURI | - |
| ContainerPort | コンテナポート | 3000 |
| TaskCpu | タスクのCPUユニット | 256 |
| TaskMemory | タスクのメモリ(MB) | 512 |
| DesiredCount | 希望するタスク数 | 2 |

## 出力値

| 出力名 | 説明 | 用途 |
|--------|------|------|
| LoadBalancerDNS | ALBのDNS名 | アプリケーションアクセス用 |
| ServiceName | ECSサービス名 | デプロイ時の参照用 |
| ClusterName | ECSクラスター名 | デプロイ時の参照用 |

## 依存関係

このモジュールは以下のモジュールに依存します：

- networkモジュール
  - VPC ID
  - サブネット ID
  - セキュリティグループ ID
- databaseモジュール
  - RDSエンドポイント
  - データベース認証情報
- authモジュール
  - Cognito User Pool ID
  - Cognito Client ID

## シークレット管理

以下のシークレットをAWS Secrets Managerで管理：

- データベース接続情報
  - WORDPRESS_DB_PASSWORD
  - WORDPRESS_DB_HOST
- Cognito設定
  - COGNITO_USER_POOL_ID
  - COGNITO_CLIENT_ID
- AWS認証情報
  - AWS_ACCESS_KEY_ID
  - AWS_SECRET_ACCESS_KEY

## デプロイ時の注意点

1. コンテナイメージのビルドとプッシュが必要
2. シークレットの事前作成が必要
3. SSL証明書のDNS検証が必要
4. ヘルスチェックパスの設定確認が必要
