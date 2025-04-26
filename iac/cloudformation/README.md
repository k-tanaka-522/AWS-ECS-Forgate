# CloudFormation デプロイ手順書

## 目次
1. [前提条件](#前提条件)
2. [デプロイの基本方針](#デプロイの基本方針)
3. [段階的なデプロイ手順](#段階的なデプロイ手順)
   - [ステップ1: 基本インフラの手動デプロイ](#ステップ1-基本インフラの手動デプロイ)
   - [ステップ2: GitHub連携のためのSecrets Manager設定](#ステップ2-github連携のためのsecrets-manager設定)
   - [ステップ3: CI/CDパイプラインの手動デプロイ](#ステップ3-cicdパイプラインの手動デプロイ)
   - [ステップ4: CI/CDパイプラインによる自動デプロイ](#ステップ4-cicdパイプラインによる自動デプロイ)
4. [環境別デプロイ](#環境別デプロイ)
5. [トラブルシューティング](#トラブルシューティング)

## 前提条件

### 必要な環境
- AWS CLIがインストールされ、適切な権限を持つIAMユーザーで設定済み
- JDK 11以上（アプリケーションビルド用）
- Git（リポジトリ操作用）
- GitHubアカウントとリポジトリのアクセス権

### AWS CLIの設定確認
```bash
# AWS CLIのバージョン確認
aws --version

# 認証情報の確認
aws sts get-caller-identity

# デフォルトリージョンの確認
aws configure get region
```

## デプロイの基本方針

「最小単位での実装と検証」の原則に基づき、デプロイは以下の2段階のアプローチで行います：

1. **手動デプロイ（初期インフラとCI/CD）**
   - 基本的なネットワークインフラを手動でデプロイ（メインスタック）
   - CI/CDパイプライン自体を手動でデプロイ

2. **CI/CDによる自動デプロイ（アプリケーションとその関連インフラ）**
   - アプリケーションコードの変更をトリガーとして、CI/CDパイプラインが自動実行
   - アプリケーションのビルド、テスト、デプロイが自動化

## 段階的なデプロイ手順

### ステップ1: 基本インフラの手動デプロイ

#### 1.1 テンプレートの検証
```bash
# テンプレート構文の検証
./scripts/validate.sh templates/environment-main.yaml

# または直接AWS CLIを使用
aws cloudformation validate-template --template-body file://templates/environment-main.yaml
```

#### 1.2 メインスタックの準備
メインスタック（environment-main.yaml）を編集して、ネストスタック部分をコメントアウトします。以下のリソースだけを含む最小構成にします：

- 基本パラメータ（環境名、VPC CIDR等）
- タグ設定
- 出力値
- ネットワークリソース（VPC、サブネット、セキュリティグループ）

#### 1.3 メインスタックのデプロイ
```bash
# 開発環境へのデプロイ
./scripts/deploy.sh dev

# または直接AWS CLIを使用
aws cloudformation deploy \
  --template-file templates/environment-main.yaml \
  --stack-name dev-ecsforgate-stack \
  --parameter-overrides file://config/dev/parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --tags Environment=dev Project=ECSForgate
```

#### 1.4 スタックの確認
デプロイが完了したら、AWS Management Consoleでスタックの状態を確認します。特に以下の点を確認します：
- スタックのステータスが「CREATE_COMPLETE」になっていること
- 出力値が正しく設定されていること

### ステップ2: GitHub連携のためのSecrets Manager設定

#### 2.1 GitHubトークンの発行
1. GitHubアカウントにログイン
2. Settings → Developer settings → Personal access tokens → Generate new token
3. 必要な権限を選択（最低限「repo」と「admin:repo_hook」）
4. トークンを生成し、安全な場所に一時的に保存

#### 2.2 AWS Secrets Managerへのトークン保存
```bash
# AWS CLIを使用してシークレットを作成
aws secretsmanager create-secret \
  --name "github/tokens" \
  --description "GitHub Personal Access Tokens" \
  --secret-string "{\"GitHubToken\":\"ghp_xxxxxxxxxxxxxxxxxxxx\"}"

# シークレットが正しく作成されたことを確認
aws secretsmanager describe-secret --secret-id "github/tokens"
```

### ステップ3: CI/CDパイプラインの手動デプロイ

#### 3.1 CI/CDテンプレートの検証
```bash
# テンプレート構文の検証
./scripts/validate.sh templates/cicd-github.yaml

# または直接AWS CLIを使用
aws cloudformation validate-template --template-body file://templates/cicd-github.yaml
```

#### 3.2 CI/CDテンプレートの編集
cicd-github.yamlを編集して、以下の変更を行います：
- GitHubトークンをSecretsManagerから参照するように設定：
  ```yaml
  GitHubWebhook:
    Type: AWS::CodePipeline::Webhook
    Properties:
      Authentication: GITHUB_HMAC
      AuthenticationConfiguration:
        SecretToken: '{{resolve:secretsmanager:github/tokens:SecretString:GitHubToken}}'
      ...
  ```

#### 3.3 CI/CDパイプラインのデプロイ
```bash
# 専用スクリプトを使用（GitHubリポジトリ情報を渡す）
./scripts/deploy-cicd-github.sh \
  --github-owner "<GitHubアカウント名>" \
  --github-repo "<リポジトリ名>" \
  --github-branch "main"

# または直接AWS CLIを使用
aws cloudformation deploy \
  --template-file templates/cicd-github.yaml \
  --stack-name dev-ecsforgate-cicd-stack \
  --parameter-overrides \
    GitHubOwner="<GitHubアカウント名>" \
    GitHubRepo="<リポジトリ名>" \
    GitHubBranch="main" \
  --capabilities CAPABILITY_NAMED_IAM
```

#### 3.4 CI/CDパイプラインの確認
1. AWS Management ConsoleでCodePipelineを開き、作成されたパイプラインを確認
2. GitHubリポジトリのSettings → Webhooksを開き、Webhookが正しく設定されていることを確認

### ステップ4: CI/CDパイプラインによる自動デプロイ

CI/CDパイプラインが構築されたら、以降はGitHubリポジトリへのコード変更をトリガーとして、自動的にデプロイが実行されます。

#### 4.1 最小構成アプリケーションの準備と自動デプロイ
1. ヘルスチェックAPIのみを含む最小構成のアプリケーションコードを作成
2. GitHubリポジトリにプッシュ
3. CI/CDパイプラインが自動的にトリガーされることを確認
   - AWS Management ConsoleでCodePipelineの進行を監視
   - ビルド、テスト、デプロイの各ステージが自動的に実行される

#### 4.2 デプロイ状況の確認
```bash
# ALBのDNS名を取得
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name dev-ecsforgate-stack \
  --query "Stacks[0].Outputs[?OutputKey=='ApplicationLoadBalancerDNS'].OutputValue" \
  --output text)

# ヘルスチェックAPIにアクセス
curl http://$ALB_DNS/api/health
```

#### 4.3 段階的な機能追加と自動デプロイ
1. RDS接続機能を追加したアプリケーションコードを作成
2. GitHubリポジトリにプッシュ
3. CI/CDパイプラインがトリガーされ、更新されたアプリケーションが自動的にデプロイ
4. デプロイ後、アプリケーションの動作を確認
   ```bash
   # レコードAPIにアクセス
   curl http://$ALB_DNS/api/records
   ```

## 環境別デプロイ

### 開発環境（dev）
上記の手順で開発環境（dev）へのデプロイが完了します。

### ステージング環境（stg）
開発環境で検証が完了したら、同様の手順でステージング環境にデプロイします：

1. **手動部分**
   ```bash
   # メインスタックのデプロイ（ネットワーク部分）
   ./scripts/deploy.sh stg
   
   # CI/CDパイプラインのデプロイ（release/*ブランチ用）
   ./scripts/deploy-cicd-github.sh \
     --github-owner "<GitHubアカウント名>" \
     --github-repo "<リポジトリ名>" \
     --github-branch "release/*" \
     --environment stg
   ```

2. **自動部分**
   - release/*ブランチへのプッシュでCI/CDパイプラインが起動
   - ステージング環境へのデプロイが自動実行

### 本番環境（prd）
ステージング環境での検証が完了したら、同様の手順で本番環境にデプロイします：

1. **手動部分**
   ```bash
   # メインスタックのデプロイ（ネットワーク部分）
   ./scripts/deploy.sh prd
   
   # CI/CDパイプラインのデプロイ（mainブランチ用）
   ./scripts/deploy-cicd-github.sh \
     --github-owner "<GitHubアカウント名>" \
     --github-repo "<リポジトリ名>" \
     --github-branch "main" \
     --environment prd
   ```

2. **自動部分**
   - mainブランチへのプッシュでCI/CDパイプラインが起動
   - 承認ステップが必要（マニュアル承認が必要）
   - 承認後、本番環境へのデプロイが自動実行

## トラブルシューティング

### CloudFormationスタックのデプロイに失敗した場合
1. AWS Management ConsoleでCloudFormationを開き、スタックの「イベント」タブを確認
2. エラーメッセージを確認し、原因を特定
3. テンプレートを修正して再デプロイ
4. 必要に応じてスタックをロールバック
   ```bash
   aws cloudformation delete-stack --stack-name dev-ecsforgate-stack
   ```

### CI/CDパイプラインが起動しない場合
1. GitHubリポジトリのWebhook設定を確認
2. GitHubトークンの権限を確認
3. CodePipelineの設定を確認
4. ログを確認して問題を特定

### ECSサービスが起動しない場合
1. ECSコンソールでタスク定義とサービスの状態を確認
2. タスクの詳細ページでイベントとログを確認
3. CloudWatchログを確認してエラーメッセージを特定
4. コンテナの正常性を確認

### RDS接続に失敗する場合
1. セキュリティグループの設定を確認（インバウンドルールでECSからのアクセスが許可されているか）
2. RDSエンドポイント、データベース名、ユーザー名、パスワードが正しいか確認
3. アプリケーションのログでエラーメッセージを確認
4. 接続テストツールを使用して直接接続を試行
