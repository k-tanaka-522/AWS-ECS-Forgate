# 共通技術標準・コード規約

このドキュメントは、すべての技術領域に共通する技術標準とコード規約を定義しています。

---

## 1. 4つの基本方針

### 1.1 品質確保
**目的：** 保守可能で長期的に運用できるコードを生成する

**原則：**
- 保守可能なコード構造
- 適切なモジュール/コンポーネント分割
- 技術的負債の最小化
- 自己説明的なコード

### 1.2 安全性確保
**目的：** セキュリティリスクを最小化し、本番環境を保護する

**原則：**
- 本番環境への直接操作禁止
- 機密情報の適切な管理
- 権限の最小化原則
- 入力値の検証

### 1.3 一貫性の維持
**目的：** チーム全体で統一された品質を保つ

**原則：**
- コーディング規約の統一
- 命名規則の標準化
- ディレクトリ構造の統一
- コメント規則の統一

### 1.4 ベストプラクティスの適用
**目的：** 業界標準の推奨パターンを適用する

**原則：**
- 各技術領域の推奨パターン
- セキュリティ対策の標準化
- パフォーマンスの最適化
- テスタビリティの確保

---

## 2. コード生成時の適用フロー

### 2.1 事前説明
コード生成前に、ユーザーに説明する：

```
これからコードを生成します。

以下の技術標準を適用します：
- モジュール分割による再利用性の向上
- 環境差分の見やすい管理
- 直感的なディレクトリ構造
- シークレット情報の分離

生成後に、各部分について詳しく説明します。
```

### 2.2 コード生成
技術標準に従って自動生成

### 2.3 事後説明（学習機会）
生成後に、詳しく説明する：

```
生成したコードについて説明します。

【main.tfについて】
このファイルは...

【モジュール分割について】
なぜこのように分けたかというと...

【環境差分管理について】
dev/stg/prodの差分は...
```

---

## 3. 共通項目（全技術領域）

### 3.1 モジュール/コンポーネント分割

**原則：**
- **単一責任の原則**：1つのモジュールは1つの責務
- **適切な粒度**：大きすぎず、小さすぎず
- **再利用可能**：他のプロジェクトでも使える設計
- **疎結合**：モジュール間の依存を最小化

**例：**
```
# ❌ 悪い例：すべてを1ファイルに
main.tf (2000行)

# ✅ 良い例：責務ごとに分割
vpc.tf
security_groups.tf
ec2.tf
rds.tf
```

### 3.2 環境差分の管理

**原則：**
- dev/stg/prodの差分を見やすく整理
- 環境変数・パラメーターファイルで管理
- **シークレット情報は必ず分離**（ハードコード禁止）

**ディレクトリ構造例：**
```
environments/
├── dev/
│   ├── terraform.tfvars          # 非機密パラメータ（Git管理OK）
│   ├── secrets.tfvars            # 機密パラメータ（.gitignoreで除外）
│   └── backend.tf
├── stg/
│   ├── terraform.tfvars
│   ├── secrets.tfvars            # .gitignoreで除外
│   └── backend.tf
└── prod/
    ├── terraform.tfvars
    ├── secrets.tfvars            # .gitignoreで除外
    └── backend.tf

.gitignore                         # secrets.tfvars を必ず除外
```

**パラメーターファイル例：**

```hcl
# environments/dev/terraform.tfvars（非機密）
environment = "dev"
instance_type = "t3.micro"
db_instance_class = "db.t3.micro"
vpc_cidr = "10.0.0.0/16"
```

```hcl
# environments/dev/secrets.tfvars（機密）← Git管理しない
db_password = "DevPassword123!"
api_key = "dev-api-key-xxxxxxxxxx"
```

```hcl
# environments/prod/terraform.tfvars（非機密）
environment = "prod"
instance_type = "t3.large"
db_instance_class = "db.t3.large"
vpc_cidr = "10.2.0.0/16"
```

```hcl
# environments/prod/secrets.tfvars（機密）← Git管理しない
db_password = "ProdSecurePassword456!"
api_key = "prod-api-key-yyyyyyyyyy"
```

**重要：.gitignore に必ず追加**
```
# .gitignore
**/secrets.tfvars
**/*.env
**/.env*
```

### 3.3 直感的な構成

**原則：**
- 誰が見ても分かるディレクトリ構造
- 自己説明的な命名
- 適切なコメント

**命名規則：**
```
# ❌ 悪い例
a.tf
tmp.tf
test123.tf

# ✅ 良い例
vpc.tf
ec2_web_server.tf
rds_postgresql.tf
```

**コメント規則：**
```
# ❌ 悪い例：何をしているか分からない
resource "aws_instance" "web" {
  ami = "ami-xxx"
}

# ✅ 良い例：目的と理由を明記
# Webサーバー用のEC2インスタンス
# ALBからのトラフィックを受け取る
resource "aws_instance" "web" {
  ami = "ami-xxx"  # Amazon Linux 2023
}
```

### 3.4 シークレット情報の分離

**原則：**
- ハードコード禁止
- 環境変数の使用
- `.gitignore`で除外

**対象：**
- APIキー
- データベースパスワード
- AWSクレデンシャル
- 暗号化キー

**実装例：**
```hcl
# ❌ 悪い例：ハードコード
password = "MyPassword123"

# ✅ 良い例：環境変数
password = var.db_password

# ✅ 良い例：AWS Secrets Manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}
```

---

## 4. 命名規則

### 4.1 変数・関数名

**原則：**
- snake_case（推奨）または camelCase
- 自己説明的な名前
- 省略しない（ただし、一般的な略語は可）

**例：**
```
# ❌ 悪い例
n = 10
tmp = getData()
x = calc(y)

# ✅ 良い例
max_retry_count = 10
user_data = get_user_data()
total_price = calculate_total_price(items)
```

### 4.2 リソース名

**原則：**
- プロジェクト名-環境-リソースタイプ-用途

**例：**
```
# AWS
myapp-prod-ec2-web-01
myapp-prod-rds-postgresql
myapp-prod-s3-logs

# GCP
myapp-prod-compute-web-01
myapp-prod-sql-postgresql
```

### 4.3 ファイル名

**原則：**
- 小文字
- ハイフン区切りまたはアンダースコア区切り
- 内容が分かる名前

**例：**
```
# ❌ 悪い例
File1.tf
MAIN.TF

# ✅ 良い例
vpc-networking.tf
ec2-web-servers.tf
rds-database.tf
```

---

## 5. コメント規則

### 5.1 コメントを書くべき場所

**必須：**
- ファイルの先頭（ファイルの目的）
- 複雑なロジック
- なぜそうするのか（Whyを説明）

**不要：**
- 自明なコード
- 何をしているか（Whatは書かない）

**例：**
```python
# ❌ 悪い例：自明
# iに1を足す
i = i + 1

# ✅ 良い例：理由を説明
# リトライ回数を増やす（タイムアウト対策）
retry_count += 1
```

### 5.2 ファイルヘッダー

```
# ファイル名: vpc.tf
# 目的: VPCとサブネットの定義
# 作成日: 2025-09-30
# 備考: パブリック/プライベートサブネットを各AZに作成
```

---

## 6. ディレクトリ構造

### 6.1 基本構造（IaC例）

```
project-root/
├── modules/              # 再利用可能なモジュール
│   ├── vpc/
│   ├── ec2/
│   └── rds/
├── environments/         # 環境ごとの設定
│   ├── dev/
│   ├── stg/
│   └── prod/
├── shared/              # 共通設定
│   ├── variables.tf
│   └── outputs.tf
└── README.md            # プロジェクト説明
```

### 6.2 基本構造（Webアプリ例）

```
project-root/
├── src/
│   ├── components/      # UIコンポーネント
│   ├── pages/           # ページ
│   ├── services/        # API通信等
│   ├── utils/           # ユーティリティ
│   └── types/           # 型定義
├── public/              # 静的ファイル
├── tests/               # テスト
└── docs/                # ドキュメント
```

---

## 7. エラーハンドリング

### 7.1 原則

**原則：**
- すべてのエラーを適切に処理
- ユーザーに分かりやすいエラーメッセージ
- ログに詳細を記録
- リトライ可能なエラーはリトライ

### 7.2 実装例

```python
# ❌ 悪い例：エラーを無視
try:
    data = fetch_data()
except:
    pass

# ✅ 良い例：適切なハンドリング
try:
    data = fetch_data()
except ConnectionError as e:
    logger.error(f"接続エラー: {e}")
    # リトライロジック
    data = retry_fetch_data()
except ValueError as e:
    logger.error(f"データが不正です: {e}")
    raise
```

---

## 8. ロギング

### 8.1 ログレベル

- **ERROR**: エラー発生時
- **WARN**: 警告（処理は継続）
- **INFO**: 重要な情報
- **DEBUG**: デバッグ情報

### 8.2 ログに含めるべき情報

```
[2025-09-30 15:30:00] [ERROR] [module_name] Failed to connect to database: timeout after 30s
- User: user123
- Action: fetch_user_data
- Retry: 3/3
- Details: {connection_details}
```

---

## 9. テスト

### 9.1 テストの種類

- **単体テスト**: 関数・メソッド単位
- **結合テスト**: モジュール間連携
- **E2Eテスト**: エンドツーエンド

### 9.2 テストコードの命名

```python
# テスト関数の命名規則
def test_[機能]_[条件]_[期待結果]():
    pass

# 例
def test_calculate_total_price_with_discount_returns_correct_value():
    pass

def test_user_login_with_invalid_password_raises_error():
    pass
```

---

## 10. ドキュメント

### 10.1 必須ドキュメント

- **README.md**: プロジェクト概要、セットアップ手順
- **ARCHITECTURE.md**: アーキテクチャ説明
- **API.md**: API仕様（APIがある場合）
- **DEPLOYMENT.md**: デプロイ手順

### 10.2 README.mdの構成

```markdown
# プロジェクト名

## 概要
このプロジェクトは...

## 技術スタック
- Frontend: React
- Backend: Node.js
- Database: PostgreSQL

## セットアップ
\`\`\`bash
npm install
npm run dev
\`\`\`

## デプロイ
...
```

---

## 11. バージョン管理（Git）

### 11.1 コミットメッセージ

**形式：**
```
[type] 簡潔な説明

詳細な説明（必要に応じて）

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**type:**
- feat: 新機能
- fix: バグ修正
- docs: ドキュメント
- refactor: リファクタリング
- test: テスト追加
- chore: その他

### 11.2 .gitignoreの基本

```
# 環境変数
.env
.env.local

# 依存関係
node_modules/
venv/

# ビルド成果物
dist/
build/

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# 状態ファイル（プロジェクト固有）
.claude-state/
```

---

## 12. まとめ

このドキュメントは、すべての技術領域に共通する基準です。

各技術領域固有の標準は、以下を参照してください：
- `.claude/docs/40_standards/42_infrastructure.md` - インフラ（IaC）
- `.claude/docs/40_standards/43_frontend.md` - フロントエンド
- `.claude/docs/40_standards/44_backend.md` - バックエンド
- `.claude/docs/40_standards/45_database.md` - データベース

コード生成時は、必ずこの共通標準を適用してください。