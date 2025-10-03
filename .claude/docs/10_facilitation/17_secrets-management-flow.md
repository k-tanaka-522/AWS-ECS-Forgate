# シークレット管理タスク生成フロー

## 概要

コード生成時、機密情報（パスワード、APIキー等）が必要な場合、ユーザーに具体的な設定手順をタスクとして提示するフローです。

---

## 1. シークレット情報の検出

コード生成時、以下が必要かどうかを判断してください：

### 1.1 データベース関連
- データベースパスワード（RDS, PostgreSQL, MySQL等）
- データベース接続文字列

### 1.2 認証・認可
- JWTシークレットキー
- APIキー（外部サービス）
- OAuth クライアントID・シークレット

### 1.3 AWS認証
- AWS Access Key ID
- AWS Secret Access Key
- IAM Role ARN

### 1.4 その他
- 暗号化キー
- 証明書・秘密鍵
- Webhookシークレット

---

## 2. タスク生成タイミング

以下のタイミングで、シークレット設定タスクを生成してください：

### 2.1 Terraform/CloudFormation コード生成後
```
✅ 生成完了: CloudFormationテンプレート
→ RDSインスタンスが含まれる
→ DBパスワードが必要
→ タスク生成: 「AWS Secrets Managerにdbパスワードを登録」
```

### 2.2 アプリケーションコード生成後
```
✅ 生成完了: Node.js バックエンドコード
→ 外部API連携コードが含まれる
→ APIキーが必要
→ タスク生成: 「.envファイルにAPIキーを設定」
```

### 2.3 CI/CDパイプライン生成後
```
✅ 生成完了: GitHub Actionsワークフロー
→ AWSへのデプロイが含まれる
→ AWS認証情報が必要
→ タスク生成: 「GitHub SecretsにAWS認証情報を登録」
```

---

## 3. タスク生成テンプレート

### 3.1 ローカル開発環境（.env ファイル）

**ユーザーへの提示内容：**

```markdown
## タスク: 開発環境のシークレット設定

### 手順
1. プロジェクトルートに `.env` ファイルを作成してください

2. 以下の内容を記述してください：
```bash
# データベース接続
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=YOUR_DEV_PASSWORD_HERE  # ← 開発用パスワードを設定

# 外部API
API_KEY=YOUR_API_KEY_HERE  # ← APIキーを設定
```

3. `.gitignore` に以下が含まれていることを確認してください：
```
.env
.env.*
!.env.example
```

4. `.env.example` ファイルを作成（Gitにコミット可）：
```bash
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=  # ← 値は空にする
API_KEY=
```

### チェックリスト
- [ ] `.env` ファイルを作成
- [ ] `DB_PASSWORD` に開発用パスワードを設定
- [ ] `API_KEY` にAPIキーを設定
- [ ] `.gitignore` に `.env` を追加済み
- [ ] `.env.example` を作成

### 確認方法
```bash
# アプリケーションを起動して、正常に動作するか確認
npm run dev
```

### 参考ドキュメント
[シークレット管理標準](.claude/docs/40_standards/45_secrets-management.md#21-ローカル開発環境)
```

**Claude（AI）の動作：**
```javascript
// .claude-state/tasks.json に追加
{
  "id": "secret-task-001",
  "type": "secret-setup",
  "title": "開発環境のシークレット設定（.env）",
  "status": "pending",
  "priority": "high",
  "created_at": "2025-10-03T12:00:00Z",
  "target": {
    "environment": "local",
    "method": ".env file",
    "secrets": [
      "DB_PASSWORD",
      "API_KEY"
    ]
  },
  "instructions": "..."  // 上記のマークダウン内容
}
```

---

### 3.2 CI/CD環境（GitHub Secrets）

**ユーザーへの提示内容：**

```markdown
## タスク: GitHub Secrets の登録

GitHub Actionsで使用するシークレットを登録してください。

### 手順
1. GitHubリポジトリのページを開く

2. `Settings` → `Secrets and variables` → `Actions` へ移動

3. `New repository secret` をクリック

4. 以下のシークレットを1つずつ登録：

#### AWS認証情報
- **Name**: `AWS_ACCESS_KEY_ID`
  - **Secret**: （IAMユーザーのアクセスキーID）

- **Name**: `AWS_SECRET_ACCESS_KEY`
  - **Secret**: （IAMユーザーのシークレットアクセスキー）

#### アプリケーション用
- **Name**: `DB_PASSWORD`
  - **Secret**: （本番環境のDBパスワード）

- **Name**: `API_KEY`
  - **Secret**: （本番環境のAPIキー）

### AWS IAMユーザー作成方法
まだIAMユーザーがない場合：

```bash
# 1. AWS CLIでIAMユーザー作成
aws iam create-user --user-name github-actions-deploy

# 2. ポリシーをアタッチ（例：ECS、ECRへのアクセス）
aws iam attach-user-policy \
  --user-name github-actions-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

# 3. アクセスキーを作成
aws iam create-access-key --user-name github-actions-deploy
```

出力されたアクセスキーIDとシークレットアクセスキーをGitHub Secretsに登録してください。

### チェックリスト
- [ ] `AWS_ACCESS_KEY_ID` 登録完了
- [ ] `AWS_SECRET_ACCESS_KEY` 登録完了
- [ ] `DB_PASSWORD` 登録完了
- [ ] `API_KEY` 登録完了

### 登録確認
1. `Settings` → `Secrets and variables` → `Actions` で、登録したシークレット名が表示されることを確認
2. GitHub Actionsワークフローを実行して、正常にデプロイできるか確認

### 参考ドキュメント
- [シークレット管理標準](.claude/docs/40_standards/45_secrets-management.md#22-cicd環境github-actions)
- [GitHub Secrets公式ドキュメント](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
```

---

### 3.3 AWS環境（Secrets Manager）

**ユーザーへの提示内容：**

```markdown
## タスク: AWS Secrets Manager への登録

本番環境・ステージング環境で使用するシークレットをAWS Secrets Managerに登録してください。

### 方法A: AWS CLI（推奨）

```bash
# 1. 本番環境のDBパスワード
aws secretsmanager create-secret \
  --name myapp/prod/db-password \
  --description "Production DB password" \
  --secret-string '{"password":"YOUR_SECURE_PASSWORD_HERE"}' \
  --region ap-northeast-1

# 2. 本番環境のAPIキー
aws secretsmanager create-secret \
  --name myapp/prod/api-key \
  --description "Production API Key" \
  --secret-string '{"api_key":"YOUR_API_KEY_HERE"}' \
  --region ap-northeast-1

# 3. ステージング環境のDBパスワード
aws secretsmanager create-secret \
  --name myapp/stg/db-password \
  --description "Staging DB password" \
  --secret-string '{"password":"YOUR_STG_PASSWORD_HERE"}' \
  --region ap-northeast-1

# 4. ステージング環境のAPIキー
aws secretsmanager create-secret \
  --name myapp/stg/api-key \
  --description "Staging API Key" \
  --secret-string '{"api_key":"YOUR_STG_API_KEY_HERE"}' \
  --region ap-northeast-1
```

### 方法B: AWS Console（GUI）

1. AWS Console → `Secrets Manager` へ移動

2. `Store a new secret` をクリック

3. Secret type: `Other type of secret` を選択

4. Key/value pairs:
   - Key: `password`
   - Value: （本番DBパスワード）

5. Secret name: `myapp/prod/db-password`

6. 同様に他のシークレットも作成

### パスワード生成方法

安全なパスワードを生成する場合：

```bash
# ランダムパスワード生成（32文字）
openssl rand -base64 32
```

### チェックリスト
- [ ] `myapp/prod/db-password` 作成完了
- [ ] `myapp/prod/api-key` 作成完了
- [ ] `myapp/stg/db-password` 作成完了
- [ ] `myapp/stg/api-key` 作成完了

### 登録確認

```bash
# 登録されているか確認
aws secretsmanager list-secrets --region ap-northeast-1

# 値を取得（確認用）
aws secretsmanager get-secret-value \
  --secret-id myapp/prod/db-password \
  --region ap-northeast-1
```

### Terraformへの反映

シークレット登録後、Terraformで以下のように参照できます：

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "myapp/${var.environment}/db-password"
}

resource "aws_db_instance" "main" {
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}
```

### 参考ドキュメント
- [シークレット管理標準](.claude/docs/40_standards/45_secrets-management.md#23-aws環境本番ステージング)
- [AWS Secrets Manager公式ドキュメント](https://docs.aws.amazon.com/secretsmanager/)
```

---

## 4. Claude（AI）の動作フロー

### 4.1 コード生成時
```
1. コードを生成（例：Terraform RDS）
2. シークレット必要性を判断
   - RDSインスタンス → DBパスワード必要
   - ECS Task定義 → 環境変数・シークレット必要
3. シークレット設定タスクを生成
4. .claude-state/tasks.json に追加
5. ユーザーに提示
```

### 4.2 タスク提示例
```
✅ CloudFormationテンプレートを生成しました。

## 次のステップ

デプロイ前に、以下のシークレット情報を設定してください。

【タスク1】ローカル開発環境
`.env`ファイルを作成し、開発用のDB接続情報を設定してください。
→ [詳細手順](#タスク-開発環境のシークレット設定)

【タスク2】本番環境
AWS Secrets Managerに本番用のDBパスワードを登録してください。
→ [詳細手順](#タスク-aws-secrets-manager-への登録)

【タスク3】CI/CD環境
GitHub SecretsにAWS認証情報を登録してください。
→ [詳細手順](#タスク-github-secrets-の登録)

すべて完了したら、デプロイを実行できます。
```

---

## 5. セキュリティチェック

コード生成後、以下をチェックしてください：

### 5.1 ハードコードされていないか
```python
# ❌ 悪い例
db_password = "MyPassword123!"  # ハードコード

# ✅ 良い例
db_password = os.getenv("DB_PASSWORD")
if not db_password:
    raise ValueError("DB_PASSWORD is not set")
```

### 5.2 .gitignore に追加されているか
```
.env
.env.*
!.env.example
**/secrets.tfvars
**/*.pem
**/*.key
```

### 5.3 .env.example が用意されているか
```bash
# .env.example（Gitにコミット可）
DB_PASSWORD=
API_KEY=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
```

---

## 6. まとめ

**Claude（AI）の責務：**
1. コード生成時、シークレット必要性を判断
2. 環境別（ローカル/CI/CD/本番）の設定手順をタスク化
3. 具体的なコマンド・手順を提示
4. .claude-state/tasks.jsonに記録
5. セキュリティチェック（ハードコード検出）

**ユーザーの責務：**
1. 提示されたタスクに従ってシークレットを設定
2. 絶対にGitにコミットしない
3. 定期的にローテーション
