# GitHubリポジトリ連携設定手順

## 関連設計書
- [CI/CD詳細設計書](/docs/002_設計/components/cicd-design.md)
- [CloudFormation詳細設計書](/docs/002_設計/components/cloudformation-design.md)

## 目的
本ドキュメントでは、AWS CodePipelineとGitHubリポジトリを連携させるための設定手順を説明します。この連携により、GitHubリポジトリへのコードプッシュをトリガーとして、自動的にCI/CDパイプラインが実行されるようになります。

## 前提条件
- AWS CLIがインストールされ、適切な権限を持つIAMユーザーで設定済み
- GitHubアカウントとリポジトリの管理権限を保有
- プロジェクトのソースコードがGitHubリポジトリにプッシュ済み

## 1. GitHubリポジトリの準備

### 1.1 GitHubリポジトリの作成（既存のリポジトリがない場合）

```bash
# リポジトリ名：AWS-ECS-Forgate
# 説明：Spring BootアプリケーションをECS Fargateで実行するためのプロジェクト
# アクセス：Private
# README：有効
# .gitignore：Java
```

### 1.2 GitHubリポジトリのクローン

```bash
# リポジトリをローカル環境にクローン
git clone https://github.com/[GitHubユーザー名]/AWS-ECS-Forgate.git
cd AWS-ECS-Forgate
```

### 1.3 プロジェクトファイルの準備

```bash
# プロジェクトファイルをクローンしたリポジトリにコピー
cp -r /path/to/ecsforgate/* .

# ファイルをコミット
git add .
git commit -m "Initial commit for ECS Forgate project"
git push origin main
```

## 2. GitHub Personal Access Token (PAT)の作成

AWS CodePipelineがGitHubリポジトリにアクセスするためのトークンを作成します。

### 2.1 GitHubでのPAT作成手順

1. GitHubアカウントにログイン
2. 右上のプロファイルアイコンをクリック → Settings
3. 左サイドバーの「Developer settings」をクリック
4. 「Personal access tokens」 → 「Tokens (classic)」をクリック
5. 「Generate new token」 → 「Generate new token (classic)」をクリック
6. トークンに名前を付ける（例：ECSForgate-CICD）
7. 以下の権限を選択：
   - `repo` （すべてのサブ項目）
   - `admin:repo_hook` （サブ項目の `write:repo_hook` も選択）
8. 「Generate token」ボタンをクリック
9. 生成されたトークンをコピーして安全な場所に保存（表示は一度だけ）

## 3. AWS Secrets Managerへのトークン保存

GitHubトークンをAWS Secrets Managerに安全に保存します。

```bash
# AWS CLIを使用してシークレットを作成
aws secretsmanager create-secret \
  --name "github/token" \
  --description "GitHub Personal Access Token for ECSForgate CI/CD" \
  --secret-string "{\"token\":\"ghp_xxxxxxxxxxxxxxxxxxxx\"}"

# シークレットが正しく作成されたことを確認
aws secretsmanager describe-secret --secret-id "github/token"
```

※ `ghp_xxxxxxxxxxxxxxxxxxxx` を実際に生成したGitHub PATに置き換えてください。

## 4. CI/CDパイプラインのデプロイ

### 4.1 CI/CDテンプレートの検証

```bash
# テンプレート構文の検証
cd /mnt/c/dev2/ECSForgate
./iac/cloudformation/scripts/validate.sh iac/cloudformation/templates/cicd-github.yaml

# または直接AWS CLIを使用
aws cloudformation validate-template --template-body file://iac/cloudformation/templates/cicd-github.yaml
```

### 4.2 CI/CDパイプラインのデプロイ（開発環境）

```bash
# 専用スクリプトを使用
cd /mnt/c/dev2/ECSForgate
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "k-tanaka-522" \
  --github-repo "AWS-ECS-Forgate" \
  --github-branch "develop" \
  --environment dev

# または直接AWS CLIを使用
aws cloudformation deploy \
  --template-file iac/cloudformation/templates/cicd-github.yaml \
  --stack-name dev-ecsforgate-cicd-stack \
  --parameter-overrides \
    GitHubOwner="k-tanaka-522" \
    GitHubRepo="AWS-ECS-Forgate" \
    GitHubBranch="develop" \
    Environment="dev" \
  --capabilities CAPABILITY_NAMED_IAM
```

### 4.3 CI/CDパイプラインのデプロイ（ステージング環境）

```bash
# ステージング環境用のCI/CDパイプラインをデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "k-tanaka-522" \
  --github-repo "AWS-ECS-Forgate" \
  --github-branch "release/*" \
  --environment stg
```

### 4.4 CI/CDパイプラインのデプロイ（本番環境）

```bash
# 本番環境用のCI/CDパイプラインをデプロイ
./iac/cloudformation/scripts/deploy-cicd-github.sh \
  --github-owner "k-tanaka-522" \
  --github-repo "AWS-ECS-Forgate" \
  --github-branch "main" \
  --environment prd
```

## 5. デプロイ結果の確認

### 5.1 CloudFormationスタックの確認

```bash
# スタックの状態を確認
aws cloudformation describe-stacks --stack-name dev-ecsforgate-cicd-stack --query "Stacks[0].StackStatus"
```

スタックのステータスが `CREATE_COMPLETE` または `UPDATE_COMPLETE` であることを確認します。

### 5.2 AWS CodePipelineの確認

AWS Management Consoleにログインし、以下の手順で確認します：

1. CodePipelineサービスに移動
2. 「ecsforgate-pipeline-dev」（開発環境）をクリック
3. パイプラインの構成と各ステージを確認

### 5.3 GitHubウェブフックの確認

GitHubリポジトリに正しくウェブフックが設定されているか確認します：

1. GitHubリポジトリにアクセス
2. 「Settings」 → 「Webhooks」に移動
3. ウェブフックのリストにAWS CodePipelineへのウェブフックが存在することを確認
4. ウェブフックのURLが正しいAWSアカウントとリージョンを指していることを確認

## 6. パイプラインのテスト

### 6.1 テスト用の変更をプッシュ

パイプラインが正しく動作するか、テスト用の変更をプッシュして確認します。

```bash
# 開発ブランチに切り替え
git checkout -b develop
# または既存のdevelopブランチがある場合
# git checkout develop

# テスト用のファイルを作成
echo "# CI/CDパイプラインテスト" > test.md

# 変更をコミットしてプッシュ
git add test.md
git commit -m "CI/CDパイプラインのテスト"
git push origin develop
```

### 6.2 パイプラインの実行状況確認

```bash
# パイプラインの実行状況を確認
aws codepipeline get-pipeline-state --name ecsforgate-pipeline-dev
```

または、AWS Management ConsoleのCodePipelineダッシュボードで実行状況を視覚的に確認します。

## 7. トラブルシューティング

### 7.1 ウェブフックが作成されない場合

1. GitHub PATの権限が正しいか確認（`admin:repo_hook`権限が必要）
2. Secrets Managerに登録したトークンの値が正しいか確認
3. CloudFormationのイベントログを確認し、エラーメッセージを特定

### 7.2 パイプラインが自動起動しない場合

1. GitHubリポジトリのウェブフック設定ページで「Recent Deliveries」を確認
2. ウェブフックのペイロードとレスポンスを確認
3. AWS CloudTrailログでCodePipelineのAPIコールを確認

### 7.3 CloudFormationスタックのデプロイに失敗した場合

1. スタックのイベントを確認して失敗の原因を特定
2. テンプレートを修正して再デプロイ
3. 既存のスタックを削除する必要がある場合：
   ```bash
   aws cloudformation delete-stack --stack-name dev-ecsforgate-cicd-stack
   ```

## 8. セキュリティに関する注意事項

1. GitHub PATは定期的にローテーションすることをお勧めします（90日ごと）
2. パイプラインで使用するIAMロールとポリシーは最小権限の原則に従って設定してください
3. GitHubリポジトリへのアクセス管理を厳格に行い、不要なコラボレーターを削除してください
4. トークンを含むシークレットには、適切なタグを付けて管理対象を明確にしてください

## 参考情報

- [AWS CodePipeline ユーザーガイド](https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/welcome.html)
- [GitHub Webhook ドキュメント](https://docs.github.com/ja/developers/webhooks-and-events/webhooks/about-webhooks)
- [AWS CloudFormation ユーザーガイド](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/Welcome.html)
- [AWS Secrets Manager ユーザーガイド](https://docs.aws.amazon.com/ja_jp/secretsmanager/latest/userguide/intro.html)
