# Hello ECS Service

## 概要

AWS ECS Fargate上で動作する簡単なWebアプリケーションです。
RDS PostgreSQLデータベースからメッセージを取得して表示します。

## 機能

- **メインページ (`/`)**: RDSから "Hello ECS Service" メッセージを取得して美しいUIで表示
- **ヘルスチェック (`/health`)**: ALB用のヘルスチェックエンドポイント
- **API (`/api/messages`)**: 全メッセージをJSON形式で取得

## 技術スタック

- **Runtime**: Node.js 20
- **Framework**: Express.js
- **Database**: PostgreSQL 15 (Amazon RDS)
- **Container**: Docker
- **Deployment**: AWS ECS Fargate

## ローカル開発

### 前提条件

- Node.js 20以上
- Docker
- PostgreSQL（ローカルまたはRDS）

### セットアップ

```bash
# 依存関係のインストール
npm install

# 環境変数の設定
cp .env.example .env
# .env ファイルを編集してDB接続情報を設定

# 開発サーバーの起動
npm run dev
```

### 環境変数

以下の環境変数が必要です:

| 変数名 | 説明 | デフォルト値 |
|--------|------|------------|
| `DB_HOST` | PostgreSQLホスト名 | localhost |
| `DB_PORT` | PostgreSQLポート番号 | 5432 |
| `DB_NAME` | データベース名 | careapp |
| `DB_USER` | データベースユーザー名 | postgres |
| `DB_PASSWORD` | データベースパスワード | - |
| `PORT` | アプリケーションポート | 3000 |
| `NODE_ENV` | 実行環境 | development |

### Dockerでの実行

```bash
# イメージのビルド
docker build -t careapp/hello-ecs:latest .

# コンテナの起動
docker run -p 3000:3000 \
  -e DB_HOST=your-db-host \
  -e DB_USER=postgres \
  -e DB_PASSWORD=your-password \
  -e DB_NAME=careapp \
  careapp/hello-ecs:latest
```

## データベース初期化

`db/init.sql` を実行してテーブルを作成し、初期データを投入します:

```bash
psql -h <DB_HOST> -U <DB_USER> -d <DB_NAME> -f db/init.sql
```

## デプロイ

AWSへのデプロイ手順は [DEPLOYMENT.md](../DEPLOYMENT.md) を参照してください。

## API仕様

### GET /
メインページ（HTML）

### GET /health
ヘルスチェックエンドポイント

**レスポンス:**
```json
{
  "status": "healthy"
}
```

### GET /api/messages
全メッセージを取得

**レスポンス:**
```json
[
  {
    "id": 1,
    "message": "Hello ECS Service",
    "created_at": "2025-10-03T...",
    "updated_at": "2025-10-03T..."
  }
]
```

## アーキテクチャ

```
Internet
    |
    v
Application Load Balancer (Public Subnet)
    |
    v
ECS Fargate Task (Private Subnet)
    |
    v
RDS PostgreSQL (Private Subnet)
```

## セキュリティ

- ✅ 非rootユーザーでコンテナ実行
- ✅ プライベートサブネットに配置
- ✅ セキュリティグループで通信制限
- ✅ DBパスワードは環境変数で管理（将来的にSecrets Manager移行）

## ライセンス

MIT
