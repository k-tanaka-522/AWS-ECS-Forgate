# WordPressとCognito認証の設定手順

## 1. Cognitoユーザープールの作成

### 1.1 基本設定
```bash
# ユーザープールの作成
aws cognito-idp create-user-pool \
  --pool-name ${ENV}-escforgate-pool \
  --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":true,"RequireLowercase":true,"RequireNumbers":true,"RequireSymbols":true}}' \
  --auto-verified-attributes email

# アプリクライアントの作成
aws cognito-idp create-user-pool-client \
  --user-pool-id <user-pool-id> \
  --client-name wordpress-client \
  --no-generate-secret \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH
```

### 1.2 コールバックURL設定
- 許可されているコールバックURL: `https://${ENV}.tk-niigata.com/wp-login.php`
- 許可されているログアウトURL: `https://${ENV}.tk-niigata.com`

## 2. Secrets Managerの設定

### 2.1 必要なシークレットの作成
```bash
# データベース接続情報
aws secretsmanager create-secret \
  --name ${ENV}/wordpress/db-password \
  --secret-string "your-db-password"

aws secretsmanager create-secret \
  --name ${ENV}/wordpress/db-host \
  --secret-string "your-db-host"

# Cognito設定
aws secretsmanager create-secret \
  --name ${ENV}/wordpress/cognito-pool-id \
  --secret-string "your-user-pool-id"

aws secretsmanager create-secret \
  --name ${ENV}/wordpress/cognito-client-id \
  --secret-string "your-client-id"

# AWS認証情報
aws secretsmanager create-secret \
  --name ${ENV}/wordpress/aws-access-key \
  --secret-string "your-access-key"

aws secretsmanager create-secret \
  --name ${ENV}/wordpress/aws-secret-key \
  --secret-string "your-secret-key"
```

## 3. WordPressの初期設定

### 3.1 管理者アカウントの作成
```bash
# ECSタスクに接続
aws ecs execute-command \
  --cluster ${ENV}-escforgate-cluster \
  --task <task-id> \
  --container wordpress \
  --command "/bin/bash" \
  --interactive

# WordPressの初期設定
wp core install \
  --url=https://${ENV}.tk-niigata.com \
  --title="ESCForgate WordPress" \
  --admin_user=admin \
  --admin_password=<password> \
  --admin_email=admin@example.com \
  --allow-root
```

### 3.2 Cognitoプラグインの設定
1. WordPressの管理画面にログイン
2. プラグイン > インストール済みプラグイン
3. AWS Cognito認証プラグインを有効化
4. プラグインの設定画面で以下を設定：
   - User Pool ID
   - Client ID
   - AWS Region
   - Callback URL

## 4. 動作確認

### 4.1 認証フローのテスト
1. WordPressサイトにアクセス
2. ログインページでCognito認証を選択
3. Cognitoのログイン画面が表示されることを確認
4. テストユーザーでログインを試行

### 4.2 セキュリティ確認
- HTTPS接続が強制されることを確認
- 認証なしでの管理画面アクセスが制限されることを確認
- Cognitoユーザープールのパスワードポリシーが適用されることを確認

## 5. トラブルシューティング

### 5.1 ログの確認
```bash
# CloudWatchログの確認
aws logs get-log-events \
  --log-group-name /ecs/${ENV}-escforgate \
  --log-stream-name ecs/wordpress/<task-id>

# WordPressのデバッグログ
wp debug log --allow-root
```

### 5.2 一般的な問題と解決方法
1. Cognito認証エラー
   - コールバックURLの設定を確認
   - クライアントIDとシークレットの設定を確認

2. WordPress接続エラー
   - データベース接続設定の確認
   - SSL証明書の設定確認

3. プラグインの動作不具合
   - 最新バージョンへの更新
   - 権限設定の確認
