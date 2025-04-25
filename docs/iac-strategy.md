# IaC (Infrastructure as Code) 設計方針

## 概要

本プロジェクトでは、AWSでプライベート接続なAPIサービスを構築するために、以下のInfrastructure as Code（IaC）の方針を採用します。

## ディレクトリ構造

```
ECSForgate/
├── iac/
│   ├── cloudformation/         # CloudFormation関連
│   │   ├── templates/          # サービス別テンプレート
│   │   │   ├── vpc.yaml        # VPCとネットワーク構成
│   │   │   ├── rds.yaml        # PostgreSQL RDS
│   │   │   ├── ecs-cluster.yaml # ECSクラスター
│   │   │   ├── ecs-task.yaml   # ECSタスク定義とサービス
│   │   │   ├── ecr.yaml        # ECRリポジトリ
│   │   │   ├── alb.yaml        # Application Load Balancer
│   │   │   ├── apigateway.yaml # API Gateway
│   │   │   ├── sns.yaml        # SNS通知
│   │   │   ├── cloudwatch.yaml # CloudWatchモニタリング
│   │   │   ├── xray.yaml       # X-Ray設定
│   │   │   ├── connect.yaml    # Amazon Connect（監視・通知）
│   │   │   ├── codecommit.yaml # CodeCommit（または他のGitサービス連携）
│   │   │   └── pipeline.yaml   # CI/CD パイプライン
│   │   ├── config/             # 環境別設定
│   │   │   ├── dev/            # 開発環境
│   │   │   │   └── parameters.json
│   │   │   ├── stg/            # ステージング環境
│   │   │   │   └── parameters.json
│   │   │   └── prd/            # 本番環境
│   │   │       └── parameters.json
│   │   └── scripts/            # デプロイスクリプト
│   │       ├── deploy.sh       # スタックデプロイ用
│   │       └── validate.sh     # テンプレート検証用
│   └── terraform/              # （将来的に使用する場合）
│       ├── modules/
│       ├── environments/
│       └── scripts/
├── app/                        # アプリケーションコード
│   ├── src/                    # ソースコード
│   ├── Dockerfile              # コンテナイメージ定義
│   ├── buildspec.yml           # CodeBuild設定
│   └── docker-compose.yml      # ローカル開発用
├── docs/                       # ドキュメント
│   ├── handover.md            # 引き継ぎ情報
│   ├── knowledge.md           # 知識ベース
│   └── iac-strategy.md        # 本ドキュメント
└── README.md
```

## CloudFormation設計原則

### 1. モジュール化とサービス単位での分割

各AWSサービスを独立したCloudFormationテンプレートとして実装します。この方法には以下のメリットがあります：

- **関心の分離**: サービスごとに管理が容易になる
- **再利用性**: 特定のサービス設定を他プロジェクトでも利用可能
- **変更管理**: サービスごとの変更履歴が明確に
- **障害分離**: あるテンプレートの問題が他に波及しない

### 2. 環境ごとのパラメータ化

環境（dev/stg/prd）ごとの差異はパラメータファイルで管理します：

- 基本構成はテンプレートで定義
- 環境依存の値はパラメータファイルに分離
- 同一テンプレートを複数環境で再利用

### 3. 命名規則

#### 論理ID（テンプレート内の参照名）
- PascalCase形式（例: `PublicSubnet1`）
- 目的が明確な名前を使用

#### 物理名（作成されるリソース名）
- 環境名をプレフィックスに使用（例: `dev-public-subnet-1`）
- ハイフン区切りの小文字を使用
- `!Sub ${EnvironmentName}-resource-name` 形式で一貫性を確保

### 4. 出力とクロススタック参照

スタック間の依存関係を管理するために：

- 重要な値は `Outputs` セクションでエクスポート
- 環境名をプレフィックスにしたエクスポート名を使用
- 他のスタックからは `!ImportValue` で参照

### 5. セキュリティのベストプラクティス

- 最小特権の原則に従ったIAMポリシー設計
- セキュリティグループは必要最小限のルールで構成
- シークレット情報はSecrets Managerで管理

### 6. コメントとドキュメント

- テンプレート内のコメントは基本的に日本語で記述
- 以下の構造でコメントを記述し、後続のドキュメント生成を容易にする：
  - セクション見出しコメント（`# ---------------- セクション名 ----------------`）
  - リソースの目的と機能を説明するコメント（`# リソースの説明`）
  - 複雑なロジックや条件に対する補足コメント
- CloudWatch通知やダッシュボードなどのユーザーインターフェース要素も日本語表記
- 各環境（dev/stg/prd）で共通のメッセージとなる部分はパラメータを活用

## デプロイ戦略

### 段階的デプロイ

1. ネットワーク層（VPC）を最初にデプロイ
2. データ層（RDS）をデプロイ
3. アプリケーション層（ECS, ALB）をデプロイ
4. インテグレーション層（API Gateway）をデプロイ
5. 運用層（CloudWatch, SNS, X-Ray, CI/CD）をデプロイ

### 環境間の展開

1. 開発環境（dev）で十分にテスト
2. ステージング環境（stg）で本番想定テスト
3. 本番環境（prd）へ展開

## バージョン管理戦略

- 各テンプレートのバージョンはGitで管理
- テンプレートの大きな変更時はChangeSetを作成して変更を確認
- 本番変更前に必ずスタックポリシーを検討

## CI/CD戦略

### コンテナイメージビルド戦略

コンテナイメージのビルドとデプロイは以下の方針で行います：

1. **コンテナビルド責務の分離**
   - ECSタスク定義はIaCとして管理（ecs-task.yaml）
   - Dockerfileはアプリケーションコード（app/）と共に管理
   - ビルドプロセスはCodeBuildで実行（app/buildspec.yml）

2. **Dockerイメージビルドフロー**
   - ソースコード変更がリポジトリにプッシュされるとパイプラインを起動
   - CodeBuildがDockerfileからイメージをビルド
   - イメージにタグ付け（コミットハッシュとlatestタグ）
   - ECRにイメージをプッシュ
   - ECSサービスを更新して新しいイメージをデプロイ

3. **buildspec.yml 構成**
   - pre_build: ECRログイン、環境変数設定
   - build: Dockerイメージのビルドとタグ付け
   - post_build: ECRへのプッシュとECSサービス更新

4. **GitリポジトリとCodePipelineの統合**
   - 当初はCodeCommitを使用
   - 将来的に他のGitサービス（GitHub, GitLab等）への移行も考慮
   - WebhookやCodeStarConnectionsを使用して外部Gitサービスとの連携も可能

### CI/CDパイプライン構成

CI/CDパイプラインは以下の段階で構成します：

1. **Source Stage**
   - GitリポジトリからソースコードをチェックアウトOr GitRepositoryからソースコード取得

2. **Build Stage**
   - CodeBuildによるDockerイメージのビルド
   - ECRへのイメージプッシュ
   - テストの実行（将来的に拡張）

3. **Deploy Stage**
   - 開発環境へのデプロイ（自動）
   - ステージング環境へのデプロイ（手動承認後）
   - 本番環境へのデプロイ（手動承認後）

4. **通知とフィードバック**
   - デプロイの成功/失敗をSNSで通知
   - CloudWatchでパイプライン実行のモニタリング

## 今後の拡張性

- Terraformへの対応も視野に入れたモジュール設計
- 新しいAWSサービス追加時も同じパターンで拡張可能
- テスト自動化の強化（ユニットテスト、インテグレーションテスト）
- Blue/Greenデプロイメントの導入
