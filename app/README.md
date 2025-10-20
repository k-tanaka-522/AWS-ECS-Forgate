# Application Monorepo

このディレクトリには、3つのNode.jsサービスと共通ライブラリが含まれています。

## ディレクトリ構造

```
app/
├── public/                  # Public Web Service (一般ユーザー向け)
│   ├── src/
│   │   ├── index.js        # エントリーポイント
│   │   └── app.js          # Expressアプリケーション
│   ├── Dockerfile          # Dockerイメージビルド
│   └── package.json
├── admin/                   # Admin Dashboard (管理者向け、VPN経由のみ)
│   ├── src/
│   │   ├── index.js
│   │   └── app.js
│   ├── Dockerfile
│   └── package.json
├── batch/                   # Batch Processing (データ処理・集計)
│   ├── src/
│   │   └── index.js
│   ├── Dockerfile
│   └── package.json
├── shared/                  # 共通ライブラリ
│   ├── db/
│   │   └── connection.js   # データベース接続プール
│   ├── index.js
│   └── package.json
├── package.json            # ルートpackage.json (npm workspaces)
└── README.md               # このファイル
```

## 技術スタック

- **Runtime**: Node.js 20 (LTS)
- **Framework**: Express.js 4.18.x
- **Database**: PostgreSQL 15 (via pg 8.11.x)
- **Container**: Docker (Multi-stage build)
- **Package Management**: npm workspaces (Monorepo)

## ローカル開発環境セットアップ

### 1. 依存関係インストール

```bash
cd app
npm run install:all
```

### 2. 環境変数設定

`.env.example` をコピーして `.env` を作成：

```bash
cp .env.example .env
```

`.env` ファイルに以下の値を設定：

```env
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=myapp_dev
DB_USER=postgres
DB_PASSWORD=your_password_here

# Application Configuration
NODE_ENV=development
PORT=8080

# Batch Configuration (batch serviceのみ)
BATCH_INTERVAL=3600000  # 1 hour in milliseconds
```

### 3. PostgreSQLの起動

Docker Composeを使用する場合：

```bash
docker-compose up -d postgres
```

または、ローカルPostgreSQLを使用する場合、データベースを作成：

```sql
CREATE DATABASE myapp_dev;
```

### 4. サービス起動

各サービスを個別に起動：

```bash
# Public Web Service
cd public
npm run dev

# Admin Dashboard Service
cd admin
npm run dev

# Batch Processing Service
cd batch
npm run dev
```

## Dockerビルド

### 個別ビルド

```bash
# Public Web Service
npm run docker:build:public

# Admin Dashboard Service
npm run docker:build:admin

# Batch Processing Service
npm run docker:build:batch
```

### 全サービスビルド

```bash
npm run docker:build
```

### Dockerイメージ実行（ローカルテスト）

```bash
# Public Web Service
docker run -p 8080:8080 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=myapp_dev \
  -e DB_USER=postgres \
  -e DB_PASSWORD=your_password \
  myapp-public-web:latest

# Admin Dashboard Service
docker run -p 8081:8080 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=myapp_dev \
  -e DB_USER=postgres \
  -e DB_PASSWORD=your_password \
  myapp-admin-dashboard:latest

# Batch Processing Service
docker run \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=myapp_dev \
  -e DB_USER=postgres \
  -e DB_PASSWORD=your_password \
  -e BATCH_INTERVAL=60000 \
  myapp-batch-processing:latest
```

## ECRへのプッシュ

### 1. ECRログイン

```bash
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com
```

### 2. イメージタグ付け

```bash
# Public Web Service
docker tag myapp-public-web:latest 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/public-web:latest
docker tag myapp-public-web:latest 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/public-web:v1.0.0

# Admin Dashboard Service
docker tag myapp-admin-dashboard:latest 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/admin-dashboard:latest
docker tag myapp-admin-dashboard:latest 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/admin-dashboard:v1.0.0

# Batch Processing Service
docker tag myapp-batch-processing:latest 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/batch-processing:latest
docker tag myapp-batch-processing:latest 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/batch-processing:v1.0.0
```

### 3. イメージプッシュ

```bash
# Public Web Service
docker push 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/public-web:latest
docker push 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/public-web:v1.0.0

# Admin Dashboard Service
docker push 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/admin-dashboard:latest
docker push 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/admin-dashboard:v1.0.0

# Batch Processing Service
docker push 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/batch-processing:latest
docker push 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp/batch-processing:v1.0.0
```

## API エンドポイント

### Public Web Service (Port 8080)

- `GET /health` - ヘルスチェック
- `GET /` - サービス情報
- `GET /api/users` - ユーザー一覧取得
- `POST /api/users` - ユーザー登録
- `GET /api/stats` - 統計情報取得

### Admin Dashboard Service (Port 8080, VPN経由のみ)

- `GET /health` - ヘルスチェック
- `GET /` - サービス情報
- `GET /api/admin/stats` - システム統計情報（管理者用）
- `GET /api/admin/users` - 全ユーザー一覧（ページネーション）
- `DELETE /api/admin/users/:id` - ユーザー削除
- `GET /api/admin/system` - システム情報

### Batch Processing Service

- 自動実行（定期バッチ）
- `aggregateDailyStats()` - 日次統計集計
- `cleanupOldData()` - 古いデータクリーンアップ
- `generateMonthlyReport()` - 月次レポート生成（月初のみ）

## データベーススキーマ（サンプル）

```sql
-- Users テーブル
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(255) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Orders テーブル
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  total_amount DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Order Items テーブル
CREATE TABLE order_items (
  id SERIAL PRIMARY KEY,
  order_id INTEGER REFERENCES orders(id),
  product_id INTEGER,
  quantity INTEGER NOT NULL,
  price DECIMAL(10, 2) NOT NULL
);

-- Daily Stats テーブル (Batch処理で使用)
CREATE TABLE daily_stats (
  id SERIAL PRIMARY KEY,
  date DATE NOT NULL,
  metric_name VARCHAR(255) NOT NULL,
  metric_value NUMERIC NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(date, metric_name)
);

-- Monthly Reports テーブル (Batch処理で使用)
CREATE TABLE monthly_reports (
  id SERIAL PRIMARY KEY,
  year_month VARCHAR(7) UNIQUE NOT NULL,  -- YYYY-MM
  total_users INTEGER,
  total_orders INTEGER,
  total_revenue DECIMAL(12, 2),
  generated_at TIMESTAMP DEFAULT NOW()
);

-- Audit Logs テーブル
CREATE TABLE audit_logs (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  action VARCHAR(255) NOT NULL,
  details TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## テスト

```bash
# 全サービスのテスト実行
npm run test

# 個別サービスのテスト実行
cd public && npm test
cd admin && npm test
cd batch && npm test
```

## Lint

```bash
# 全サービスのLint実行
npm run lint
```

## トラブルシューティング

### データベース接続エラー

**エラー**: `DB_HOST environment variable is required`

**解決策**: `.env` ファイルに `DB_HOST` が設定されているか確認

---

**エラー**: `Connection timeout`

**解決策**:
1. PostgreSQLが起動しているか確認
2. `DB_HOST` と `DB_PORT` が正しいか確認
3. ファイアウォール設定を確認

### Docker イメージビルドエラー

**エラー**: `npm ERR! code ENOENT`

**解決策**: ルートディレクトリ (`app/`) からビルドを実行してください

```bash
cd app
npm run docker:build:public
```

### ECS デプロイ後にタスクが起動しない

**原因**:
1. 環境変数が正しく設定されていない
2. Secrets Manager/Parameter Storeの値が取得できない
3. ECRイメージが存在しない

**解決策**:
1. CloudFormation テンプレートのパラメータを確認
2. ECS タスクログを確認 (`/ecs/myapp-dev/public-web`)
3. IAM ロールの権限を確認

## 参考リンク

- [Express.js Documentation](https://expressjs.com/)
- [node-postgres (pg) Documentation](https://node-postgres.com/)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [npm Workspaces](https://docs.npmjs.com/cli/v7/using-npm/workspaces)
