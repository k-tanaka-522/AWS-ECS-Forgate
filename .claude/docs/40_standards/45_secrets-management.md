# シークレット管理標準

## 概要

機密情報（パスワード、APIキー、証明書等）を安全に管理するための標準とベストプラクティスです。

---

## 1. 基本原則

### 1.1 絶対にやってはいけないこと
- ❌ **ハードコード禁止**：コード内に直接記述
- ❌ **Git管理禁止**：機密情報をGitにコミット
- ❌ **平文保存禁止**：暗号化せずにファイル保存
- ❌ **共有禁止**：Slack/メール等で送信

### 1.2 やるべきこと
- ✅ **専用サービス使用**：AWS Secrets Manager / GitHub Secrets / 環境変数
- ✅ **暗号化**：保存・転送時は必ず暗号化
- ✅ **アクセス制御**：最小権限の原則
- ✅ **ローテーション**：定期的なパスワード変更

---

## 2. 環境別のシークレット管理方法

### 2.1 ローカル開発環境

**方法1: .env ファイル（推奨）**

```bash
# .env（Git管理しない）
DB_PASSWORD=DevPassword123!
API_KEY=dev-api-key-xxxxxxxxxx
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=xxxxx...
```

```bash
# .gitignore（必須）
.env
.env.*
!.env.example
```

```bash
# .env.example（Gitにコミット可）← 値は入れない
DB_PASSWORD=
API_KEY=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
```

**コードでの読み込み（Node.js例）**
```javascript
// .env ファイルを読み込む
require('dotenv').config();

const dbPassword = process.env.DB_PASSWORD;
const apiKey = process.env.API_KEY;

if (!dbPassword || !apiKey) {
  throw new Error('Required environment variables are not set');
}
```

**Claude（AI）の動作：**
1. コード生成時、`.env.example`を自動生成
2. ユーザーに「`.env`ファイルを作成し、実際の値を設定してください」とタスク生成
3. `.gitignore`に`.env`を追加

---

### 2.2 CI/CD環境（GitHub Actions）

**GitHub Secrets を使用**

**手順：**

```bash
# 1. GitHubリポジトリのSettings → Secrets and variables → Actions へ移動

# 2. "New repository secret" をクリック

# 3. 以下のシークレットを登録：
Name: DB_PASSWORD
Secret: ProdPassword456!

Name: AWS_ACCESS_KEY_ID
Secret: AKIA...

Name: AWS_SECRET_ACCESS_KEY
Secret: xxxxx...
```

**GitHub Actions ワークフローでの使用：**

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-1

      - name: Deploy to ECS
        env:
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
          API_KEY: ${{ secrets.API_KEY }}
        run: |
          # デプロイコマンド
          aws ecs update-service ...
```

**Claude（AI）の動作：**
1. GitHub Actionsワークフローを生成
2. ユーザーに以下のタスクを提示：

```markdown
## タスク: GitHub Secrets の登録

以下のシークレットをGitHubに登録してください。

### 手順
1. GitHubリポジトリの `Settings` → `Secrets and variables` → `Actions` へ移動
2. `New repository secret` をクリック
3. 以下を1つずつ登録：

- [ ] `AWS_ACCESS_KEY_ID` = （AWSアクセスキーID）
- [ ] `AWS_SECRET_ACCESS_KEY` = （AWSシークレットアクセスキー）
- [ ] `DB_PASSWORD` = （本番DBパスワード）
- [ ] `API_KEY` = （外部API キー）

### 登録後の確認
登録したシークレットは `Settings` → `Secrets and variables` → `Actions` で確認できます。
（値は表示されませんが、名前は確認できます）

### 参考
[GitHub Secrets 公式ドキュメント](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
```

---

### 2.3 AWS環境（本番・ステージング）

**AWS Secrets Manager を使用（推奨）**

**1. シークレットの作成**

```bash
# AWS CLIでシークレットを作成
aws secretsmanager create-secret \
  --name myapp/prod/db-password \
  --description "Production DB password" \
  --secret-string "ProdSecurePassword456!" \
  --region ap-northeast-1
```

または、AWS Consoleから：
1. AWS Secrets Manager → `Store a new secret`
2. Secret type: `Other type of secret`
3. Key/value pairs:
   - `password`: `ProdSecurePassword456!`
4. Secret name: `myapp/prod/db-password`

**2. Terraform でシークレットを参照**

```hcl
# Secrets Managerからシークレットを取得
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "myapp/${var.environment}/db-password"
}

# RDSインスタンスでシークレットを使用
resource "aws_db_instance" "main" {
  identifier           = "${var.project_name}-${var.environment}-db"
  engine              = "postgres"
  instance_class      = var.db_instance_class
  allocated_storage   = 20

  username = "admin"
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]

  # ...
}
```

**3. ECS タスク定義でシークレットを使用**

```json
{
  "containerDefinitions": [
    {
      "name": "app",
      "image": "myapp:latest",
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:myapp/prod/db-password"
        },
        {
          "name": "API_KEY",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:myapp/prod/api-key"
        }
      ]
    }
  ]
}
```

**Claude（AI）の動作：**
1. Terraformコード生成時、Secrets Manager参照を含める
2. ユーザーに以下のタスクを提示：

```markdown
## タスク: AWS Secrets Manager へのシークレット登録

以下のシークレットをAWS Secrets Managerに登録してください。

### 手順1: AWS CLIで登録（推奨）

```bash
# 本番環境のDBパスワード
aws secretsmanager create-secret \
  --name myapp/prod/db-password \
  --description "Production DB password" \
  --secret-string '{"password":"YOUR_SECURE_PASSWORD"}' \
  --region ap-northeast-1

# 本番環境のAPIキー
aws secretsmanager create-secret \
  --name myapp/prod/api-key \
  --description "Production API Key" \
  --secret-string '{"api_key":"YOUR_API_KEY"}' \
  --region ap-northeast-1
```

### 手順2: AWS Consoleで登録（GUI）

1. AWS Console → `Secrets Manager` → `Store a new secret`
2. Secret type: `Other type of secret`
3. Key/value pairs:
   - Key: `password`, Value: `YOUR_SECURE_PASSWORD`
4. Secret name: `myapp/prod/db-password`
5. 同様に `myapp/prod/api-key` も作成

### チェックリスト
- [ ] `myapp/prod/db-password` 作成完了
- [ ] `myapp/prod/api-key` 作成完了
- [ ] ステージング環境用 `myapp/stg/db-password` 作成完了
- [ ] ステージング環境用 `myapp/stg/api-key` 作成完了

### 登録後の確認
```bash
# 登録されているか確認
aws secretsmanager list-secrets --region ap-northeast-1

# 値を取得（確認用）
aws secretsmanager get-secret-value --secret-id myapp/prod/db-password --region ap-northeast-1
```
```

---

### 2.4 コンテナ環境（Docker）

**Docker Secrets を使用（本番）**

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    image: myapp:latest
    secrets:
      - db_password
      - api_key
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password
      API_KEY_FILE: /run/secrets/api_key

secrets:
  db_password:
    external: true
  api_key:
    external: true
```

```bash
# シークレットを作成
echo "ProdPassword456!" | docker secret create db_password -
echo "prod-api-key-xxx" | docker secret create api_key -

# デプロイ
docker stack deploy -c docker-compose.yml myapp
```

**環境変数を使用（開発）**

```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  app:
    image: myapp:latest
    env_file:
      - .env  # .gitignoreで除外
```

---

## 3. シークレットのローテーション（定期変更）

### 3.1 なぜローテーションが必要か
- セキュリティリスク低減
- 漏洩時の影響最小化
- コンプライアンス要件

### 3.2 ローテーション戦略

| シークレットの種類 | ローテーション頻度 | 方法 |
|-------------|-----------|------|
| DBパスワード | 90日ごと | AWS Secrets Manager自動ローテーション |
| APIキー | 180日ごと | 手動 + アラート |
| AWS IAMキー | 90日ごと | 手動 + アラート |
| 証明書 | 1年ごと | Let's Encrypt自動更新 |

**AWS Secrets Manager 自動ローテーション設定例：**

```hcl
resource "aws_secretsmanager_secret" "db_password" {
  name = "myapp/prod/db-password"

  # 90日ごとに自動ローテーション
  rotation_rules {
    automatically_after_days = 90
  }
}

resource "aws_secretsmanager_secret_rotation" "db_password" {
  secret_id           = aws_secretsmanager_secret.db_password.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 90
  }
}
```

---

## 4. Claude（AI）の責務

### 4.1 コード生成時
1. **ハードコード検出**：機密情報がコードに含まれていたら警告
2. **環境変数化**：シークレットは環境変数・Secrets Manager参照に置き換え
3. **.gitignore生成**：`.env`, `secrets.tfvars`等を除外

### 4.2 タスク生成
コード生成後、ユーザーに以下のタスクを提示：

```markdown
## タスク: シークレット情報の設定

以下のシークレットを設定してください。

### ローカル開発環境
1. `.env`ファイルを作成（`.env.example`を参考）
2. 以下の値を設定：
   - [ ] `DB_PASSWORD` = （開発用DBパスワード）
   - [ ] `API_KEY` = （開発用APIキー）

### CI/CD環境（GitHub Secrets）
1. GitHubリポジトリの Settings → Secrets へ移動
2. 以下を登録：
   - [ ] `AWS_ACCESS_KEY_ID`
   - [ ] `AWS_SECRET_ACCESS_KEY`
   - [ ] `DB_PASSWORD`
   - [ ] `API_KEY`

### 本番環境（AWS Secrets Manager）
1. AWS CLIまたはConsoleでシークレット作成
2. 以下を登録：
   - [ ] `myapp/prod/db-password`
   - [ ] `myapp/prod/api-key`

### 確認
- [ ] ローカル環境で正常に動作するか確認
- [ ] CI/CDパイプラインで正常にデプロイできるか確認
```

### 4.3 セキュリティチェック
生成したコード内に以下が含まれていないか自動チェック：
- パスワード文字列
- APIキー文字列
- AWS認証情報
- 秘密鍵

---

## 5. まとめ

| 環境 | 推奨方法 | 理由 |
|-----|---------|------|
| **ローカル開発** | `.env`ファイル | シンプル、開発者ごとに異なる値 |
| **CI/CD** | GitHub Secrets | GitHubと統合、暗号化済み |
| **本番・ステージング** | AWS Secrets Manager | 自動ローテーション、監査ログ、暗号化 |
| **コンテナ** | Docker Secrets / 環境変数 | コンテナと統合 |

**重要：**
- 絶対にGitにコミットしない
- 必ず暗号化する
- 定期的にローテーション
- 最小権限の原則
