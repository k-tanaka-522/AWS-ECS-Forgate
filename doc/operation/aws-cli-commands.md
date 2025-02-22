# AWS CLI実行コマンド記録

## 0. ECRリポジトリとDBパスワードの設定

```bash
# ECRリポジトリの作成
aws ecr create-repository \
  --repository-name escforgate \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

# ECRリポジトリURIの取得と保存
REPO_URI=$(aws ecr describe-repositories \
  --repository-names escforgate \
  --query 'repositories[0].repositoryUri' \
  --output text)

# コンテナイメージURIをParameter Storeに保存
aws ssm put-parameter \
  --name "/dev/escforgate/container-image" \
  --value "$REPO_URI:latest" \
  --type String \
  --overwrite

# DBパスワードの生成と保存
DB_PASSWORD=$(openssl rand -base64 32)
aws secretsmanager create-secret \
  --name dev/escforgate/db-password \
  --description "RDS database master password" \
  --secret-string "$DB_PASSWORD"

# 生成したパスワードの取得（必要な場合）
aws secretsmanager get-secret-value \
  --secret-id dev/escforgate/db-password \
  --query 'SecretString' \
  --output text
```

## 1. Cognitoユーザープール作成

```bash
# ユーザープールの作成
aws cognito-idp create-user-pool \
  --pool-name dev-escforgate-pool \
  --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":true,"RequireLowercase":true,"RequireNumbers":true,"RequireSymbols":true}}' \
  --auto-verified-attributes email \
  --schema '[{"Name":"email","Required":true,"Mutable":true}]'

# アプリクライアントの作成（ユーザープールIDは実行時に置き換え）
aws cognito-idp create-user-pool-client \
  --user-pool-id <user-pool-id> \
  --client-name wordpress-client \
  --no-generate-secret \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --callback-urls '["https://dev.tk-niigata.com/wp-login.php"]' \
  --logout-urls '["https://dev.tk-niigata.com"]' \
  --allowed-o-auth-flows implicit \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client
```

## 2. Secrets Manager設定

```bash
# データベース接続情報
aws secretsmanager create-secret \
  --name dev/wordpress/db-password \
  --description "WordPress database password" \
  --secret-string "REPLACE_WITH_YOUR_PASSWORD"

aws secretsmanager create-secret \
  --name dev/wordpress/db-host \
  --description "WordPress database host" \
  --secret-string "REPLACE_WITH_YOUR_DB_HOST"

# Cognito設定（ユーザープールIDとクライアントIDは実行時に置き換え）
aws secretsmanager create-secret \
  --name dev/wordpress/cognito-pool-id \
  --description "Cognito User Pool ID" \
  --secret-string "REPLACE_WITH_YOUR_USER_POOL_ID"

aws secretsmanager create-secret \
  --name dev/wordpress/cognito-client-id \
  --description "Cognito Client ID" \
  --secret-string "REPLACE_WITH_YOUR_CLIENT_ID"

# AWS認証情報（実際の値は実行時に置き換え）
aws secretsmanager create-secret \
  --name dev/wordpress/aws-access-key \
  --description "AWS Access Key for WordPress" \
  --secret-string "REPLACE_WITH_YOUR_ACCESS_KEY"

aws secretsmanager create-secret \
  --name dev/wordpress/aws-secret-key \
  --description "AWS Secret Key for WordPress" \
  --secret-string "REPLACE_WITH_YOUR_SECRET_KEY"
```

## 3. ECSクラスターとサービスのデプロイ

```bash
# CloudFormationスタックのデプロイ
aws cloudformation deploy \
  --template-file lac/cloud\ formation/compute.yaml \
  --stack-name dev-escforgate-compute \
  --parameter-overrides \
    Environment=dev \
    ContainerImage=REPLACE_WITH_YOUR_ECR_IMAGE_URI \
    TaskCpu=256 \
    TaskMemory=512 \
    DesiredCount=1 \
  --capabilities CAPABILITY_NAMED_IAM

# デプロイ状態の確認
aws cloudformation describe-stacks \
  --stack-name dev-escforgate-compute \
  --query 'Stacks[0].StackStatus'
```

## 4. WordPressの初期設定

```bash
# タスクIDの取得
aws ecs list-tasks \
  --cluster dev-escforgate-cluster \
  --service-name dev-escforgate-service

# ECSタスクへの接続（タスクIDは実行時に置き換え）
aws ecs execute-command \
  --cluster dev-escforgate-cluster \
  --task <task-id> \
  --container wordpress \
  --command "/bin/bash" \
  --interactive

# 以下はECSタスク内で実行
wp core install \
  --url=https://dev.tk-niigata.com \
  --title="ESCForgate WordPress" \
  --admin_user=admin \
  --admin_password=REPLACE_WITH_YOUR_PASSWORD \
  --admin_email=admin@example.com \
  --allow-root
```

注意: このファイルには実際のパスワードやシークレット値を記録しないでください。実行時に適切な値に置き換えてください。
