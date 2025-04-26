# ECSForgate プロジェクト

Spring BootによるAPIサービスをAWS ECS Fargateにデプロイするためのプロジェクトです。

## 開発環境のセットアップ

### 必要な環境
- Java 11以上
- Gradle
- Docker
- AWS CLI（最新版）
- Git

### ローカル環境での実行
1. リポジトリをクローンする
   ```bash
   git clone https://github.com/k-tanaka-522/AWS-ECS-Forgate.git
   cd AWS-ECS-Forgate
   ```

2. APIアプリケーションをビルドする
   ```bash
   cd app/api
   ./gradlew clean build
   ```

3. ローカルでの実行（オプション）
   ```bash
   ./gradlew bootRun
   ```

4. Dockerイメージのビルド（オプション）
   ```bash
   docker build -t ecsforgate-api .
   docker run -p 8080:8080 ecsforgate-api
   ```

## CI/CD環境の設定

### GitHub連携の設定手順

#### 1. GitHubのPersonal Access Tokenの発行

1. GitHubにログインし、右上のプロフィールアイコンから「Settings」を選択
2. 左側のメニューから「Developer settings」を選択
3. 「Personal access tokens」→「Tokens (classic)」を選択
4. 「Generate new token」→「Generate new token (classic)」をクリック
5. トークンに以下の権限を付与:
   - `repo` (全て)
   - `admin:repo_hook` (特にwrite:repo_hookとread:repo_hook)
6. トークンを生成し、安全な場所に保存（このトークンは後ほどAWS CodePipelineの設定で使用）

#### 2. AWS側でのCI/CD環境の構築

以下のコマンドを実行して、CloudFormationを使ってCI/CD環境を構築します：

```bash
# 開発環境用CI/CD環境の構築
cd iac/cloudformation/scripts
./deploy-cicd-github.sh dev create \
  --parameters ParameterKey=GitHubOwner,ParameterValue=k-tanaka-522 \
  ParameterKey=GitHubRepo,ParameterValue=AWS-ECS-Forgate \
  ParameterKey=GitHubBranch,ParameterValue=develop \
  ParameterKey=GitHubToken,ParameterValue=あなたのGitHubトークン \
  ParameterKey=NotificationEmail,ParameterValue=通知先メールアドレス

# ステージング環境用CI/CD環境の構築（オプション）
./deploy-cicd-github.sh stg create \
  --parameters ParameterKey=GitHubOwner,ParameterValue=k-tanaka-522 \
  ParameterKey=GitHubRepo,ParameterValue=AWS-ECS-Forgate \
  ParameterKey=GitHubBranch,ParameterValue=release/* \
  ParameterKey=GitHubToken,ParameterValue=あなたのGitHubトークン \
  ParameterKey=NotificationEmail,ParameterValue=通知先メールアドレス

# 本番環境用CI/CD環境の構築（オプション）
./deploy-cicd-github.sh prd create \
  --parameters ParameterKey=GitHubOwner,ParameterValue=k-tanaka-522 \
  ParameterKey=GitHubRepo,ParameterValue=AWS-ECS-Forgate \
  ParameterKey=GitHubBranch,ParameterValue=main \
  ParameterKey=GitHubToken,ParameterValue=あなたのGitHubトークン \
  ParameterKey=NotificationEmail,ParameterValue=通知先メールアドレス
```

注意:
- GitHubトークンは、厳重に管理してください。実際の運用では、AWS SecretsManagerなどを使用することを推奨します。
- パラメータ値は実際の環境に合わせて適宜変更してください。

#### 3. Webhook設定の確認

CI/CD環境のデプロイが完了したら、GitHubリポジトリのWebhook設定を確認します：

1. リポジトリのページで「Settings」→「Webhooks」を選択
2. AWS CodePipelineのWebhookが正しく登録されていることを確認
3. 最近のデリバリー履歴を確認し、Webhookが正常に動作していることを確認

#### 4. CI/CDパイプラインの動作確認

1. コードの変更をcommitし、対応するブランチにpushする
2. AWS Management ConsoleのCodePipelineページで、パイプラインが自動的に開始されることを確認
3. ビルド、テスト、デプロイの各ステージが正常に完了することを確認

## ブランチ戦略

本プロジェクトでは、GitFlowをベースとしたブランチ戦略を採用しています：

- `main`: 本番環境用のリリースブランチ
- `develop`: 開発環境用の統合ブランチ
- `feature/*`: 機能開発用のブランチ（developから分岐）
- `release/*`: リリース準備用のブランチ（developから分岐、ステージング環境にデプロイ）
- `hotfix/*`: 緊急修正用のブランチ（mainから分岐）

## 環境別設定

各環境（dev/stg/prd）の設定値は以下のディレクトリで管理されています：

```
/iac/cloudformation/config/{環境名}/parameters.json
```

環境固有の設定を変更する場合は、該当するパラメータファイルを編集してください。

## インフラ環境のデプロイ

基本的なCI/CD環境の構築後、実際のアプリケーション実行環境（VPC、RDS、ECSなど）をデプロイします：

```bash
cd iac/cloudformation/scripts
./deploy.sh dev create  # 開発環境の構築
./deploy.sh stg create  # ステージング環境の構築
./deploy.sh prd create  # 本番環境の構築
```

## プロジェクトの構成

- `/app/api/`: Spring Bootアプリケーションのソースコード
- `/docs/`: プロジェクトドキュメント
- `/iac/`: Infrastructure as Code（CloudFormationテンプレート）
- `/scripts/`: デプロイ用スクリプト

## 参考ドキュメント

- [設計ドキュメント](/docs/002_設計/)
- [要件定義](/docs/001_要件定義/)
