# 05_API設計

> AWS Multi-Account Sample Application - API設計

**作成日**: 2025-10-24 (Round 3)
**バージョン**: 3.0

---

## 1. API概要

### 1.1 API仕様

| 項目 | 設定値 |
|------|--------|
| APIスタイル | REST API |
| プロトコル | HTTPS (TLS 1.2+) |
| ベースURL | https://api.example.com/api/v1 |
| 認証方式 | Bearer Token (JWT) ※検証用は簡易実装 |
| レスポンス形式 | JSON |
| 文字エンコーディング | UTF-8 |

### 1.2 共通仕様

**HTTPヘッダー**:
```
Content-Type: application/json; charset=utf-8
Authorization: Bearer {token}
X-Request-ID: {uuid}
```

**レスポンス形式**:
```json
{
  "status": "success" | "error",
  "data": { ... },
  "error": {
    "code": "ERROR_CODE",
    "message": "エラーメッセージ"
  }
}
```

---

## 2. Public Web API

### 2.1 商品一覧取得

**エンドポイント**: `GET /api/v1/products`

**リクエスト**:
```http
GET /api/v1/products?category=カテゴリA&limit=10&offset=0
```

**クエリパラメータ**:
| パラメータ | 型 | 必須 | デフォルト | 説明 |
|----------|-----|------|----------|------|
| category | string | × | - | カテゴリフィルタ |
| limit | integer | × | 100 | 取得件数 (最大100) |
| offset | integer | × | 0 | オフセット |

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "products": [
      {
        "product_id": "660e8400-e29b-41d4-a716-446655440000",
        "product_name": "サンプル商品A",
        "description": "商品Aの説明",
        "price": 1000.00,
        "stock": 100,
        "category": "カテゴリA"
      }
    ],
    "total": 1,
    "limit": 10,
    "offset": 0
  }
}
```

### 2.2 注文作成

**エンドポイント**: `POST /api/v1/orders`

**リクエスト**:
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "items": [
    {
      "product_id": "660e8400-e29b-41d4-a716-446655440000",
      "quantity": 2
    }
  ]
}
```

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "order_id": "770e8400-e29b-41d4-a716-446655440000",
    "total_amount": 2000.00,
    "status": "pending",
    "order_date": "2025-10-24T10:00:00Z"
  }
}
```

---

## 3. Admin API

### 3.1 ユーザー一覧取得

**エンドポイント**: `GET /api/v1/admin/users`

**注意**: VPN経由のみアクセス可能

**レスポンス**:
```json
{
  "status": "success",
  "data": {
    "users": [
      {
        "user_id": "550e8400-e29b-41d4-a716-446655440000",
        "email": "test1@example.com",
        "name": "テストユーザー1",
        "created_at": "2025-10-20T10:00:00Z"
      }
    ],
    "total": 1
  }
}
```

---

**前章**: [04_データベース設計.md](./04_データベース設計.md)
**次章**: [06_セキュリティ設計.md](./06_セキュリティ設計.md)
