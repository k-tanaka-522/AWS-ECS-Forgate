# ECSForgate プロジェクト

AWS ECS Fargateを使用したプライベート接続APIサービスの構築プロジェクト

## 概要

このプロジェクトは、AWSのECS Fargateを利用したスケーラブルで堅牢なAPIサービスを構築するためのインフラストラクチャとアプリケーションコードを提供します。Infrastructure as Code (IaC) の原則に従い、環境の再現性と一貫性を確保します。

## 機能

- マルチAZ構成のVPCとプライベートサブネット
- ECS Fargate上で動作するコンテナ化されたAPIサービス
- RDS PostgreSQLデータベース
- API Gatewayによるアクセス制御
- CloudWatchによる監視とアラート

- CI/CDパイプラインによる自動デプロイ

## プロジェクト構造

```
ECSForgate/
├── iac/                        # インフラストラクチャコード
│   ├── cloudformation/         # CloudFormation関連
│   │   ├── templates/          # サービス別テンプレート
│   │   ├── config/             # 環境別設定
│   │   └── scripts/            # デプロイスクリプト
│   └── terraform/              # (将来的に対応予定)
├── app/                        # アプリケーションコード
│   └── ...
└── docs/                       # ドキュメント
    ├── handover.md             # 引き継ぎ情報
    ├── knowledge.md            # 知識ベース
    └── iac-strategy.md         # IaC設計方針
```

## 環境

このプロジェクトは以下の環境をサポートしています：

- **開発環境 (dev)**: 開発とテスト用
- **ステージング環境 (stg)**: 本番前の検証用
- **本番環境 (prd)**: 実運用環境

## セットアップと使用方法

### 前提条件

- AWS CLI v2以降
- AWS認証情報の設定
- bash実行環境
- GitHub リポジトリと個人アクセストークン

### リポジトリのセットアップ

1. GitHubリポジトリのクローン
   ```bash
   git clone https://github.com/k-tanaka-522/AWS-ECS-Forgate.git
   cd AWS-ECS-Forgate
   ```

2. 開発用ブランチでの作業（新機能開発時）
   ```bash
   git checkout develop
   git checkout -b feature/your-feature-name
   # 開発作業後
   git push -u origin feature/your-feature-name
   # その後GitHubでPull Requestを作成
   ```

### CI/CD パイプラインのセットアップ

1. GitHub 個人アクセストークンの作成
   - GitHubの設定 > Developer settings > Personal access tokens で生成
   - 必要な権限: `repo`, `admin:repo_hook` (特にwrite:repo_hookとread:repo_hook)
   - トークンを生成し、安全な場所に保存

2. CI/CD パイプラインのデプロイ
   ```bash
   cd iac/cloudformation/scripts
   ./deploy-cicd-github.sh dev create \
     --parameters ParameterKey=GitHubOwner,ParameterValue=k-tanaka-522 \
     ParameterKey=GitHubRepo,ParameterValue=AWS-ECS-Forgate \
     ParameterKey=GitHubBranch,ParameterValue=develop \
     ParameterKey=GitHubToken,ParameterValue=あなたのGitHubトークン \
     ParameterKey=NotificationEmail,ParameterValue=通知先メールアドレス
   ```
   
   他の環境についても同様に設定可能：
   ```bash
   # ステージング環境
   ./deploy-cicd-github.sh stg create \
     --parameters ParameterKey=GitHubOwner,ParameterValue=k-tanaka-522 \
     ParameterKey=GitHubRepo,ParameterValue=AWS-ECS-Forgate \
     ParameterKey=GitHubBranch,ParameterValue=release/* \
     ...
   
   # 本番環境
   ./deploy-cicd-github.sh prd create \
     --parameters ParameterKey=GitHubOwner,ParameterValue=k-tanaka-522 \
     ParameterKey=GitHubRepo,ParameterValue=AWS-ECS-Forgate \
     ParameterKey=GitHubBranch,ParameterValue=main \
     ...
   ```

### インフラのデプロイ

1. AWS CLIの設定
   ```bash
   aws configure
   ```

2. テンプレートの検証
   ```bash
   cd /path/to/ECSForgate
   ./iac/cloudformation/scripts/validate.sh <テンプレート名>
   ```

3. 手動でのインフラのデプロイ (CI/CD を使わない場合)
   ```bash
   ./iac/cloudformation/scripts/deploy.sh <環境名> <テンプレート名>
   ```

4. CI/CD による自動デプロイ
   ```bash
   # コードを GitHub リポジトリに push することで自動的にデプロイが開始されます
   git add .
   git commit -m "Update application code"
   git push
   ```

## 開発ガイドライン

- 各AWSサービスごとに独立したCloudFormationテンプレートを作成
- 環境間の差異はパラメータファイルで管理
- コードコミット前にテンプレート検証を実行
- 詳細なコメントとドキュメントで実装意図を明確に記述

## ドキュメント

詳細なドキュメントは `docs/` ディレクトリに格納されています：

- [IaC設計方針](docs/iac-strategy.md): インフラストラクチャコードの設計原則
- [知識ベース](docs/knowledge.md): プロジェクトの知識とノウハウ
- [引き継ぎ情報](docs/handover.md): 開発状況と進行中のタスク

## ライセンス

All Rights Reserved - 社内利用限定
