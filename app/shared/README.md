# CareApp Shared Library

各サービスで共通利用するライブラリ

## 内容

### DB接続・モデル
- `src/db/` - データベース接続設定
- `src/models/` - データモデル定義

### ユーティリティ
- `src/utils/` - 共通ユーティリティ関数

### 型定義
- `src/types/` - TypeScript型定義

## 使用方法

```javascript
const { db } = require('@careapp/shared');

// データベース接続
const client = await db.connect();
```
