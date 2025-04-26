# ECS Fargate詳細設計書

## 1. 概要

### 1.1 目的と責任範囲
本ドキュメントでは、ECSForgateプロジェクトにおけるECS Fargate（Elastic Container Service with Fargate）の詳細設計を定義します。ECS Fargateはプロジェクトのアプリケーション実行環境として機能し、コンテナベースのマイクロサービスの実行を担当します。

### 1.2 設計のポイント
- サーバーレスコンテナ実行環境によるインフラ運用負荷の軽減
- 高可用性と耐障害性を確保するためのマルチAZ構成
- 負荷に応じた自動スケーリング機能の実装
- セキュリティを考慮したタスク定義とネットワーク設計
- コスト最適化と性能のバランスを考慮したリソース割り当て

## 2. コンテナ化アーキテクチャの設計

### 2.1 コンテナ化戦略
Spring Bootアプリケーションをコンテナ化するための戦略は以下の通りです：

- **単一コンテナ**：アプリケーションロジックを単一コンテナにパッケージ化
- **ステートレス設計**：コンテナ内に状態を持たない設計（データはRDSに保存）
- **12ファクターアプリ準拠**：環境変数による設定、ログのストリーミング、ステートレス設計
- **ヘルスチェック**：アプリケーション組み込みのヘルスエンドポイントによる状態監視
- **標準ポート**：コンテナは標準的な8080ポートでサービスを公開

### 2.2 Dockerfileの設計

#### 2.2.1 マルチステージビルド
効率的なコンテナイメージを作成するためのマルチステージビルドを採用します。特定のUbuntuバージョン（22.04）を明示的に指定することで、バージョン固定によるビルドの再現性と安定性を確保します：

```dockerfile
# ビルドステージ
FROM ubuntu:22.04 AS build

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .
RUN ./gradlew clean build -x test

# 実行ステージ
FROM ubuntu:22.04

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y \
    openjdk-11-jre-headless \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8080/api/health || exit 1

# 実行ユーザーを設定（root以外）
RUN addgroup --system --gid 1001 appuser && \
    adduser --system --uid 1001 --gid 1001 appuser
USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

#### 2.2.2 コンテナイメージの管理

##### 2.2.2.1 イメージリポジトリとECR設定
- **イメージリポジトリ**：AWS ECR（Elastic Container Registry）を使用
- **リポジトリ名**：`ecsforgate-api`（アプリケーションイメージ用）、`ecsforgate-base`（ベースイメージ用）
- **イメージスキャン**：ECRの自動スキャン機能を有効化し、脆弱性を検出
- **タグイミュータビリティ**：リリース/凍結イメージに対して有効化（同一タグへの上書きを防止）
- **ライフサイクルポリシー**：
  - 開発用非凍結イメージ：30日以上経過した未使用イメージを自動削除
  - 凍結/リリースイメージ：削除保護を有効化（手動管理）

##### 2.2.2.2 ベースイメージ戦略（手動凍結イメージ）
- **目的**：安定性と再現性を確保するための手動管理された基盤イメージ
- **イメージ構成**：
  - Ubuntu 22.04を明示的に固定使用
  - Java 11ランタイム（固定バージョン）
  - 四半期ごとにセキュリティパッチを適用した新バージョンを作成
- **凍結プロセス**：
  - 四半期ごとに計画的に手動ビルド（3月、6月、9月、12月）
  - ビルド後の脆弱性スキャンと検証テスト
  - 検証完了後に「凍結」タグを付与（overwrite禁止）
- **タグ戦略**：
  - ビルド中：`base-{年号}-Q{四半期}-building`（例：`base-2025-Q2-building`）
  - 検証中：`base-{年号}-Q{四半期}-candidate`（例：`base-2025-Q2-candidate`）
  - 凍結完了：`base-{年号}-Q{四半期}-frozen`（例：`base-2025-Q2-frozen`）
- **リポジトリ**：`ecsforgate-base`（ベースイメージ専用リポジトリ）

##### 2.2.2.3 アプリケーションイメージ戦略
- **目的**：アプリケーションコードのみの変更を反映するイメージ
- **構成**：
  - FROM句で凍結済みベースイメージを参照（例：`FROM ${ECR_REPO}/ecsforgate-base:base-2025-Q2-frozen`）
  - アプリケーションJARファイルのみを追加
- **環境別タグ戦略**：
  - 開発環境：`dev-{コミットハッシュ}-{日付}`（例：`dev-f8a7b9c-20250427`）
  - ステージング環境：`stg-{リリース候補バージョン}`（例：`stg-rc-1.0.0`）
  - 本番環境リリース前：`prd-candidate-{バージョン}`（例：`prd-candidate-1.0.0`）
  - 本番環境リリース後：`{セマンティックバージョン}`（例：`1.0.0`、`1.0.1`）
  - 本番リリース凍結版：`{セマンティックバージョン}-frozen`（例：`1.0.0-frozen`）
- **CI/CDとの統合**：
  - 開発環境：CI/CDパイプラインで自動的にビルド・デプロイ
  - ステージング環境：CI/CDパイプラインで自動ビルド、承認後デプロイ
  - 本番環境：CI/CDで候補イメージをビルド、検証・承認後に凍結タグ付与

##### 2.2.2.4 イメージ凍結ワークフロー
1. **ベースイメージの凍結（四半期ごと）**：
   - セキュリティパッチを適用した新ベースイメージを手動ビルド
   - 検証環境でのテスト実施
   - 問題がなければ凍結タグ（`-frozen`）を付与
   - CI/CDパイプラインの設定を更新して新ベースイメージを参照

2. **本番リリースイメージの凍結（リリースごと）**：
   - CI/CDパイプラインで候補イメージをビルド（`prd-candidate-{バージョン}`）
   - ステージング環境での検証
   - 承認後、イメージに本番バージョンタグ（`{バージョン}`）を付与
   - デプロイ完了後、イメージ凍結タグ（`{バージョン}-frozen`）を付与

##### 2.2.2.5 バージョン管理の考慮点
- AWSのコンテナサービス自動更新による影響を回避
- 明示的なバージョン管理による再現性の確保
- セキュリティパッチは計画的に適用（四半期ごとの見直し）
- 内部マイクロサービスという特性を考慮したセキュリティアップデート方針
- ロールバック可能性を確保するための凍結イメージ戦略

## 3. ECSクラスタ設計

### 3.1 クラスタ構成

| 環境 | クラスタ名 | デプロイタイプ | 容量プロバイダー |
|-----|---------|-------------|--------------|
| 開発環境（dev） | ecsforgate-dev-cluster | FARGATE | FARGATE, FARGATE_SPOT |
| ステージング環境（stg） | ecsforgate-stg-cluster | FARGATE | FARGATE |
| 本番環境（prd） | ecsforgate-prd-cluster | FARGATE | FARGATE |

### 3.2 容量プロバイダー戦略

#### 開発環境
- FARGATE_SPOT: 80%（コスト最適化のため）
- FARGATE: 20%（最小限の安定リソースを確保）

#### ステージング環境
- FARGATE: 100%（安定性優先）

#### 本番環境
- FARGATE: 100%（信頼性と可用性を最大化）

### 3.3 クラスタ監視
- CloudWatch Container Insightsの有効化
- デフォルトタグの設定（Project, Environment, ManagedBy）

## 4. タスク定義設計

### 4.1 タスク実行ロール（Task Execution Role）
ECSタスクの実行に必要な権限を持つIAMロールを定義します：

- **ロール名**：`ecsforgate-{env}-task-execution-role`
- **ポリシー**：
  - `AmazonECSTaskExecutionRolePolicy`（マネージドポリシー）
  - ECRからのイメージプル権限
  - CloudWatch Logsへのログ書き込み権限
  - AWS Secrets Managerからのシークレット読み取り権限

### 4.2 タスクロール（Task Role）
アプリケーションがAWSリソースにアクセスするための権限を持つIAMロールを定義します：

- **ロール名**：`ecsforgate-{env}-task-role`
- **ポリシー**：
  - RDSへのアクセス権限
  - Systems Managerパラメータストアへのアクセス権限
  - Secrets Managerからの特定シークレット読み取り権限
  - CloudWatch Metricsへのメトリクス書き込み権限
  - X-Rayへのトレース送信権限

### 4.3 タスク定義パラメータ

| パラメータ | 開発環境 | ステージング環境 | 本番環境 |
|----------|---------|----------------|---------|
| タスク定義名 | ecsforgate-api-dev | ecsforgate-api-stg | ecsforgate-api-prd |
| CPU単位 | 0.5 vCPU (512) | 1 vCPU (1024) | 1 vCPU (1024) |
| メモリ | 1 GB | 2 GB | 2 GB |
| ネットワークモード | awsvpc | awsvpc | awsvpc |
| コンテナ名 | api-container | api-container | api-container |
| イメージURI | {account}.dkr.ecr.{region}.amazonaws.com/ecsforgate-api:latest | {account}.dkr.ecr.{region}.amazonaws.com/ecsforgate-api:rc-{version} | {account}.dkr.ecr.{region}.amazonaws.com/ecsforgate-api:{version} |
| ポートマッピング | 8080:8080 | 8080:8080 | 8080:8080 |
| ログ設定 | awslogs | awslogs | awslogs |
| ロググループ | /ecs/ecsforgate-api-dev | /ecs/ecsforgate-api-stg | /ecs/ecsforgate-api-prd |

### 4.4 環境変数設定

以下の環境変数をタスク定義に含めます：

```
# 共通設定
SPRING_PROFILES_ACTIVE={環境名}
JAVA_OPTS=-Xms512m -Xmx{メモリの80%} -XX:+UseG1GC

# データベース接続情報 (Secrets Managerから取得)
SPRING_DATASOURCE_URL=jdbc:postgresql://${DB_HOST}:5432/${DB_NAME}
SPRING_DATASOURCE_USERNAME=${DB_USER}
SPRING_DATASOURCE_PASSWORD=${DB_PASSWORD}

# アプリケーション設定
APP_LOG_LEVEL=INFO (dev), INFO (stg), WARN (prd)
```

### 4.5 シークレット管理

機密情報はAWS Secrets Managerを使用して管理し、タスク定義から参照します：

```json
{
  "secrets": [
    {
      "name": "DB_HOST",
      "valueFrom": "arn:aws:secretsmanager:{region}:{account}:secret:ecsforgate/{env}/db-host"
    },
    {
      "name": "DB_NAME",
      "valueFrom": "arn:aws:secretsmanager:{region}:{account}:secret:ecsforgate/{env}/db-name"
    },
    {
      "name": "DB_USER",
      "valueFrom": "arn:aws:secretsmanager:{region}:{account}:secret:ecsforgate/{env}/db-user"
    },
    {
      "name": "DB_PASSWORD",
      "valueFrom": "arn:aws:secretsmanager:{region}:{account}:secret:ecsforgate/{env}/db-password"
    }
  ]
}
```

### 4.6 コンテナヘルスチェック設定

タスク定義には以下のヘルスチェック設定を含めます：

```json
{
  "healthCheck": {
    "command": [
      "CMD-SHELL",
      "curl -f http://localhost:8080/api/health || exit 1"
    ],
    "interval": 30,
    "timeout": 5,
    "retries": 3,
    "startPeriod": 60
  }
}
```

## 5. ECSサービス設計

### 5.1 サービス構成

| パラメータ | 開発環境 | ステージング環境 | 本番環境 |
|----------|---------|----------------|---------|
| サービス名 | ecsforgate-api-dev-service | ecsforgate-api-stg-service | ecsforgate-api-prd-service |
| 起動タイプ | FARGATE | FARGATE | FARGATE |
| タスク数 | 1 | 2 | 2 |
| 最小ヘルス率 | 100% | 100% | 100% |
| 最大率 | 200% | 200% | 200% |
| デプロイ方法 | ローリング更新 | ブルー/グリーン（CodeDeploy） | ブルー/グリーン（CodeDeploy） |
| サービス検出 | 無効 | 無効 | 無効 |
| ロードバランサー | 内部ALB | 内部ALB | 内部ALB |
| サブネット | PrivateAppSubnetA | PrivateAppSubnetA, PrivateAppSubnetB | PrivateAppSubnetA, PrivateAppSubnetB |

### 5.2 ネットワーク構成

- **ネットワークモード**：awsvpc（Fargateの要件）
- **セキュリティグループ**：
  - **名前**：`ecsforgate-{env}-ecs-sg`
  - **インバウンドルール**：
    - ALBセキュリティグループからの8080ポートへのTCPトラフィックを許可
  - **アウトバウンドルール**：
    - RDSセキュリティグループへの5432ポートへのTCPトラフィックを許可
    - 外部APIアクセス用にHTTPS（443）を許可
    - CloudWatchへのアクセスを許可（443）

### 5.3 ロードバランサー連携

#### 5.3.1 ターゲットグループ設定
- **名前**：`ecsforgate-{env}-tg`
- **ターゲットタイプ**：IP
- **プロトコル/ポート**：HTTP/8080
- **VPC**：アプリケーションVPC
- **ヘルスチェック**：
  - **パス**：`/api/health`
  - **プロトコル**：HTTP
  - **ポート**：8080
  - **正常しきい値**：3
  - **非正常しきい値**：2
  - **タイムアウト**：5秒
  - **間隔**：30秒
  - **成功コード**：200-299

#### 5.3.2 ロードバランサー設定
- **タイプ**：Application Load Balancer（内部）
- **名前**：`ecsforgate-{env}-alb`
- **スキーム**：内部
- **リスナー**：
  - HTTP（80）：内部クライアント向け
  - HTTPS（443）：将来拡張用
- **セキュリティグループ**：
  - **名前**：`ecsforgate-{env}-alb-sg`
  - **インバウンドルール**：
    - VPC内（10.0.0.0/16）からのHTTP（80）とHTTPS（443）を許可
  - **アウトバウンドルール**：
    - ECSセキュリティグループの8080ポートへのトラフィックを許可

### 5.4 サービス検出
現在の要件では、サービス検出は必要ありません。ALBを使用してサービスディスカバリを実現します。将来的に複数のマイクロサービス間連携が必要になった場合は、AWS Cloud MapとAWS App Meshの導入を検討します。

## 6. Auto Scaling設定

### 6.1 Auto Scaling戦略

サービスのスケーリングは、以下のメトリクスに基づいて自動的に行います：

| 環境 | スケーリングメトリクス | スケールアウト閾値 | スケールイン閾値 | クールダウン期間 |
|-----|-------------------|---------------|--------------|------------|
| 開発環境 | CPU使用率 | 70% | 30% | 300秒 |
| ステージング環境 | CPU使用率 | 70% | 30% | 300秒 |
| 本番環境 | CPU使用率, リクエスト数 | CPU: 70%, リクエスト: 1000/min | CPU: 30%, リクエスト: 500/min | 300秒 |

### 6.2 ターゲット追跡スケーリングポリシー

各環境に対して以下のターゲット追跡スケーリングポリシーを設定します：

#### 6.2.1 CPU使用率ベースのスケーリング
```json
{
  "TargetValue": 70.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
  },
  "ScaleOutCooldown": 300,
  "ScaleInCooldown": 300
}
```

#### 6.2.2 リクエスト数ベースのスケーリング（本番環境のみ）
```json
{
  "TargetValue": 800.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ALBRequestCountPerTarget",
    "ResourceLabel": "{load-balancer-arn}/{target-group-arn}"
  },
  "ScaleOutCooldown": 300,
  "ScaleInCooldown": 300
}
```

### 6.3 スケーリング範囲

| 環境 | 最小タスク数 | 最大タスク数 | スケーリングステップ |
|-----|-----------|-----------|---------------|
| 開発環境 | 1 | 2 | 1 |
| ステージング環境 | 2 | 5 | 1 |
| 本番環境 | 2 | 10 | 2 |

## 7. ロギングと監視

### 7.1 ロギング設計

#### 7.1.1 アプリケーションログ
- **ログドライバー**：awslogs
- **ロググループ**：/ecs/ecsforgate-api-{env}
- **ログストリーム**：{コンテナ名}/{タスクID}
- **保持期間**：
  - 開発環境：14日間
  - ステージング環境：30日間
  - 本番環境：90日間
- **ログフォーマット**：JSON形式（構造化ログ）
- **ログレベル**：
  - 開発環境：INFO
  - ステージング環境：INFO
  - 本番環境：WARN

#### 7.1.2 コンテナログ
- ECSコンテナのstdout/stderrをCloudWatch Logsに送信
- Fargateプラットフォームログを有効化し、診断情報の保存

### 7.2 メトリクス収集

以下のメトリクスを収集し、監視に活用します：

- **ECSメトリクス**：
  - CPUUtilization
  - MemoryUtilization
  - RunningTaskCount
  - PendingTaskCount
  - ServiceCount

- **アプリケーションメトリクス**：
  - HTTP要求レスポンス時間
  - HTTP要求数/秒
  - HTTPステータスコード（2xx, 4xx, 5xx）
  - アプリケーション固有のカスタムメトリクス

- **ALBメトリクス**：
  - RequestCount
  - TargetResponseTime
  - HTTPCode_Target_2XX_Count
  - HTTPCode_Target_4XX_Count
  - HTTPCode_Target_5XX_Count

### 7.3 分散トレーシング

X-Rayを使用して分散トレーシングを実装します：

- Spring Bootアプリケーションにx-ray-sdk-javaを組み込み
- トレースコンテキストの伝播設定
- サンプリングルールの設定：
  - 開発環境：100%（すべてのリクエストをトレース）
  - ステージング環境：50%
  - 本番環境：10%（パフォーマンス影響を最小化）

### 7.4 アラート設定

| アラート名 | 条件 | 通知方法 | 重要度 |
|----------|------|---------|-------|
| High CPU Utilization | CPUUtilization > 閾値(80%)が5分間継続 | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 |
| Task Count Changed | RunningTaskCount < DesiredTaskCount | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 |
| High Error Rate | HTTPCode_Target_5XX_Count > 10 (1分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 |
| High Response Time | TargetResponseTime > 1秒 (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 |
| Failed Health Check | HealthyHostCount < DesiredTaskCount | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 |

## 8. デプロイ戦略

### 8.1 デプロイ方法

| 環境 | デプロイ方式 | ロールバック | ダウンタイム |
|-----|------------|-----------|-----------|
| 開発環境 | ローリング更新 | 手動 | 最小限 |
| ステージング環境 | ブルー/グリーン（CodeDeploy） | 自動 | なし |
| 本番環境 | ブルー/グリーン（CodeDeploy） | 自動 | なし |

### 8.2 ローリング更新（開発環境）

- 最小ヘルス率：100%
- 最大率：200%
- 古いタスクの停止前に新しいタスクが正常であることを確認

### 8.3 ブルー/グリーン更新（ステージング・本番環境）

- AWS CodeDeployを使用したブルー/グリーンデプロイ
- デプロイ設定：
  - **CodeDeployServiceRole**: `ecsforgate-{env}-codedeploy-role`
  - **デプロイグループ**: `ecsforgate-{env}-deploy-group`
  - **リスナー設定**:
    - 本番リスナー: ALBのHTTPリスナー（ポート80）
    - テストリスナー: なし（オプション）
  - **デプロイ設定**: CodeDeployDefault.ECSAllAtOnce

### 8.4 ロールバック戦略

- **自動ロールバックトリガー**:
  - ヘルスチェック失敗
  - デプロイタイムアウト（デフォルト：30分）
- **手動ロールバック**:
  - AWS Management Consoleから実行
  - AWS CLIを使用してロールバックコマンドを実行

### 8.5 デプロイ監視

- CodeDeployデプロイの進行状況監視
- CloudWatchダッシュボードによるデプロイ前後のメトリクス比較
- ログ分析によるエラー検出

## 9. コスト最適化

### 9.1 Fargateコスト最適化戦略

| 戦略 | 開発環境 | ステージング環境 | 本番環境 |
|-----|---------|----------------|---------|
| Fargate Spotの使用 | 有効（80%） | 無効 | 無効 |
| リソース最適化 | 必要最小限 | 余裕を持った設定 | パフォーマンス優先 |
| タスク自動停止 | 夜間・週末の自動停止 | なし | なし |
| コンテナイメージサイズ最適化 | マルチステージビルド | マルチステージビルド | マルチステージビルド |

### 9.2 リソース見積もり

#### 開発環境
- CPU: 0.5 vCPU × 1タスク = 0.5 vCPU
- メモリ: 1 GB × 1タスク = 1 GB
- 平均稼働時間: 8時間/日 × 5日/週 = 週40時間
- 月間コスト見積もり: 約$25-30

#### ステージング環境
- CPU: 1 vCPU × 2タスク = 2 vCPU
- メモリ: 2 GB × 2タスク = 4 GB
- 稼働時間: 24時間/日 × 7日/週
- 月間コスト見積もり: 約$125-150

#### 本番環境
- CPU: 1 vCPU × 平均3タスク = 3 vCPU
- メモリ: 2 GB × 平均3タスク = 6 GB
- 稼働時間: 24時間/日 × 7日/週
- 月間コスト見積もり: 約$200-250

### 9.3 コスト監視

- **AWS Cost Explorer**を使用したECSサービスコストの監視
- コストタグの設定と分析
- 予算アラートの設定

## 10. セキュリティ設計

### 10.1 コンテナセキュリティ

- Ubuntu 22.04の固定バージョン使用による安定性と検証負荷軽減
- 非rootユーザーでのコンテナ実行
- 読み取り専用ファイルシステムの使用（可能な場合）
- 最小権限の原則に基づくIAMポリシー設定
- ECRイメージスキャンによる脆弱性検出
- イメージの署名と検証（将来拡張）
- セキュリティアップデートの計画的適用スケジュールの策定
- 内部マイクロサービスという特性を考慮したバージョン管理戦略

### 10.2 ネットワークセキュリティ

- プライベートサブネット内でのタスク実行
- セキュリティグループによるきめ細かなトラフィック制御
- VPCエンドポイントを使用したAWSサービスへのプライベート接続
- タスク間通信の暗号化（将来拡張）

### 10.3 認証・認可

- AWS Secrets Managerを使用した機密情報の管理
- IAMロールに基づくAWSリソースへのアクセス制御
- JWTトークンによるAPIアクセス認証

### 10.4 FISC安全対策基準対応

- 運用ログの取得と保存
- アクセス制御の実装
- 暗号化措置の適用
- セキュリティモニタリングの実施

## 11. 環境差分

環境ごとの主な差分は以下の通りです：

| 設定項目 | 開発環境（dev） | ステージング環境（stg） | 本番環境（prd） |
|---------|--------------|-------------------|--------------| 
| タスク数 | 1 | 2 | 2 (Auto Scaling: 2-10) |
| CPU/メモリ | 0.5 vCPU / 1 GB | 1 vCPU / 2 GB | 1 vCPU / 2 GB |
| Fargateタイプ | FARGATE + FARGATE_SPOT | FARGATE | FARGATE |
| デプロイ方法 | ローリング更新 | ブルー/グリーン | ブルー/グリーン |
| マルチAZ | 無効 | 有効 | 有効 |
| ロギングレベル | INFO | INFO | WARN |
| X-Rayサンプリング | 100% | 50% | 10% |
| 自動停止 | 夜間・週末 | なし | なし |

## 12. CloudFormationリソース定義

ECS Fargate構成のためのCloudFormationリソースタイプと主要パラメータを以下に示します：

### 12.1 主要リソースタイプ
- **AWS::ECS::Cluster**: ECSクラスタを定義
- **AWS::ECS::TaskDefinition**: タスク定義を定義
- **AWS::ECS::Service**: ECSサービスを定義
- **AWS::IAM::Role**: タスク実行ロールとタスクロールを定義
- **AWS::ElasticLoadBalancingV2::TargetGroup**: ALBターゲットグループを定義
- **AWS::ApplicationAutoScaling::ScalableTarget**: Auto Scalingターゲットを定義
- **AWS::ApplicationAutoScaling::ScalingPolicy**: スケーリングポリシーを定義
- **AWS::CloudWatch::Alarm**: メトリクスアラームを定義

### 12.2 主要パラメータ例

```yaml
Parameters:
  EnvironmentName:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - stg
      - prd
    Description: 環境名（dev/stg/prd）

  AppName:
    Type: String
    Default: ecsforgate-api
    Description: アプリケーション名

  ContainerCpu:
    Type: Number
    Default: 512
    AllowedValues:
      - 256
      - 512
      - 1024
      - 2048
      - 4096
    Description: コンテナに割り当てるCPU単位（1024=1vCPU）

  ContainerMemory:
    Type: Number
    Default: 1024
    AllowedValues:
      - 512
      - 1024
      - 2048
      - 3072
      - 4096
      - 8192
    Description: コンテナに割り当てるメモリ量（MB）

  TaskCount:
    Type: Number
    Default: 1
    Description: 実行するタスク数

  MaxTaskCount:
    Type: Number
    Default: 2
    Description: 最大タスク数

  ContainerImage:
    Type: String
    Description: コンテナイメージURI
    
  MultiAzEnabled:
    Type: String
    Default: false
    AllowedValues:
      - true
      - false
    Description: マルチAZ配置を有効にするかどうか
```

## 13. 考慮すべきリスクと対策

| リスク | 影響度 | 対策 |
|-------|-------|------|
| タスク起動失敗 | 高 | ヘルスチェックの実装、自動復旧メカニズム、アラート設定 |
| リソース不足 | 中 | 適切なリソース割り当て、Auto Scalingの設定、キャパシティ予測 |
| デプロイ障害 | 高 | ブルー/グリーンデプロイ、自動ロールバック、段階的デプロイ |
| ネットワーク分断 | 高 | マルチAZ配置、接続リトライロジック、フェイルオーバーテスト |
| サービス間連携障害 | 中 | リトライメカニズム、サーキットブレーカー、障害切り分け対策 |
| コンテナクラッシュ | 高 | ヘルスチェック、自動再起動、障害理由の記録と分析 |

## 14. 設計検証方法

本ECS Fargate設計の妥当性を確認するために、以下の検証を実施します：

### 14.1 機能検証
- タスク起動テスト
- コンテナヘルスチェック動作確認
- アプリケーションログ出力確認
- ALB経由でのアクセス確認

### 14.2 性能検証
- 負荷テストによるスケーリング動作確認
- コンテナリソース使用率監視
- レスポンスタイム計測
- トランザクション処理能力検証

### 14.3 可用性検証
- マルチAZ配置の有効性確認
- タスク障害時の自動復旧確認
- ロードバランサーヘルスチェック確認
- フェイルオーバーテスト

### 14.4 セキュリティ検証
- IAMロールとポリシーの検証
- セキュリティグループの有効性確認
- シークレット管理の検証
- コンテナ内部からの不正アクセス試行テスト

## 15. 運用考慮点

### 15.1 通常運用時の考慮点
- CloudWatch Logsによるログモニタリング
- Container Insightsによるメトリクス監視
- 定期的なリソース使用状況レポートの確認
- コンテナイメージの更新と管理

### 15.2 障害発生時の考慮点
- アラート通知の迅速な把握と対応
- ログ分析による障害原因の特定
- タスク再起動による迅速な復旧
- 障害状況の切り分けとエスカレーションフロー

### 15.3 メンテナンス時の考慮点
- 計画的なバージョンアップデート
- デプロイ時間帯の設定（低負荷時）
- ブルー/グリーンデプロイによる無停止更新
- ロールバック手順の整備

## 16. パフォーマンスチューニング

### 16.1 Javaコンテナの最適化
- JVM設定のチューニング（GCポリシー、ヒープサイズ）
- コンテナリソース（CPU/メモリ）の最適化
- Spring Bootアプリケーションのパフォーマンス設定

### 16.2 ECS Fargateのパフォーマンス最適化
- タスク配置戦略の最適化
- Auto Scaling設定の調整
- ネットワークパフォーマンスの最適化
- データベース接続プーリングの設定

### 16.3 アプリケーションのパフォーマンス監視
- X-Rayによるトレース分析
- CloudWatch Performance Insightsの活用
- カスタムメトリクスの収集と分析
- ボトルネックの特定と対策

## 17. AWS Well-Architected Framework対応

設計は、AWSのWell-Architected Frameworkの5つの柱に準拠しています：

### 17.1 運用上の優秀性
- IaCによるインフラストラクチャの管理
- CI/CDパイプラインの構築
- 包括的なモニタリングとアラート設定
- 自動化されたデプロイとロールバック

### 17.2 セキュリティ
- 最小権限の原則に基づくIAMロール設定
- セキュリティグループによるネットワークセキュリティ強化
- シークレット管理とデータ暗号化
- コンテナセキュリティの実装

### 17.3 信頼性
- マルチAZ構成による高可用性
- 自動復旧メカニズムの実装
- ヘルスチェックとモニタリング
- ロードバランシングによる負荷分散

### 17.4 パフォーマンス効率
- 適切なリソースサイジング
- Auto Scalingによる負荷対応
- パフォーマンスモニタリングとチューニング
- トラフィックパターンに基づいた最適化

### 17.5 コスト最適化
- Fargate Spotの活用
- リザーブドインスタンスとSavings Planの検討
- 開発環境の自動停止
- リソース使用状況の継続的なモニタリングと最適化
