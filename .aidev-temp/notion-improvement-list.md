# Notion 規約 改善リスト（修正箇所洗い出し）

**作成日**: 2025-10-19
**レビュー担当**: Claude (CTO/Architect視点)
**目的**: Notionドキュメントの「肉付け」が必要な箇所を特定し、優先順位をつけて改善する

---

## 📊 レビューサマリー

### 全体評価

| カテゴリ | ステータス | 充実度 | 優先度 |
|---------|----------|-------|-------|
| CloudFormation規約 | ✅ 良好 | 80% | 中 |
| Terraform規約 | ✅ 良好 | 75% | 中 |
| Python規約 | ⚠️ 要改善 | 40% | 高 |
| TypeScript規約 | ✅ 良好 | 70% | 中 |
| C# .NET Core規約 | ✅ 良好 | 65% | 中 |
| Go言語規約 | ✅ 良好 | 70% | 中 |
| セキュリティ・運用基準 | ❌ 不足 | 10% | **最優先** |
| ファシリテーション戦略 | ⚠️ 要改善 | 30% | 高 |

---

## 🔥 最優先改善項目（Critical）

### 1. **4.7 セキュリティ・運用基準** - 最も不足

**現状**:
- 記述内容が1段落のみ（約50文字）
- 具体的なガイドラインが皆無
- Good/Bad Exampleなし

**必要な肉付け**:

#### 1.1 セキュリティベストプラクティス
```
【追加すべき内容】
- AWS Well-Architected Framework 6つの柱
  - 運用の優秀性
  - セキュリティ
  - 信頼性
  - パフォーマンス効率
  - コスト最適化
  - 持続可能性

- 具体的なセキュリティ対策
  - IAMポリシー最小権限の原則
  - VPCセキュリティグループ設計
  - 暗号化（転送中・保管中）
  - 監査ログ（CloudTrail）
  - WAF/Shield設定
```

#### 1.2 シークレット管理
```
【追加すべき内容】
- AWS Secrets Manager 使用パターン
- Systems Manager Parameter Store 使用パターン
- 環境変数の取り扱い
- .envファイルの管理（.gitignore必須）
- ローテーション戦略

✅ Good Example:
- Secrets Managerでの自動ローテーション設定
- アプリケーション起動時にシークレット取得

❌ Bad Example:
- コード内ハードコード
- 平文でのコミット
- 共有ドライブに保存
```

#### 1.3 本番環境保護
```
【追加すべき内容】
- 本番環境への直接操作禁止
- dry-run必須フロー
- 承認プロセス（PR → レビュー → 承認 → デプロイ）
- Change Setsによる差分確認
- ロールバック手順

✅ Good Example:
terraform plan → レビュー → terraform apply

❌ Bad Example:
本番環境で直接 terraform apply
```

#### 1.4 ログ・監視戦略
```
【追加すべき内容】
- CloudWatch Logs集約
- CloudWatch Alarms設定基準
- X-Ray による分散トレーシング
- メトリクス収集
- ダッシュボード設計

✅ Good Example:
- エラー発生時のSlack通知
- CPU使用率80%超でアラーム
- API応答時間の可視化

❌ Bad Example:
- ログ出力なし
- アラート設定なし
```

#### 1.5 インシデント対応
```
【追加すべき内容】
- インシデント対応フロー
- エスカレーションパス
- 通知チャネル
- ポストモーテム（事後分析）テンプレート
```

**推定作業量**: 8時間
**優先度**: **最優先（P0）**

---

### 2. **ファシリテーション戦略** - 詳細が不足

**現状**:
- 3.1 ヒアリング・コンテクスト管理: 1段落のみ
- 3.2 ドキュメント生成ガイドライン: 未確認
- 3.3 ユーザー配慮・品質確保: 未確認

**必要な肉付け**:

#### 2.1 ヒアリング・コンテクスト管理
```
【追加すべき内容】
- 一問一答のテンプレート
  - 企画フェーズ質問リスト
  - 要件定義フェーズ質問リスト
  - 設計フェーズ質問リスト

- ビジネス背景ヒアリング手法
  - 業種・業態の確認
  - ステークホルダー特定
  - 現在の課題深堀り
  - 成功基準の明確化

✅ Good Example:
「現在、どのような課題がありますか?」
→ ユーザー回答
→ 「具体的には、どのような頻度で発生しますか?」

❌ Bad Example:
複数の質問を一度に投げる
```

#### 2.2 ドキュメント生成ガイドライン
```
【追加すべき内容】
- 各フェーズのドキュメントテンプレート
  - 企画書テンプレート
  - 要件定義書テンプレート
  - 基本設計書テンプレート
  - 詳細設計書テンプレート

- Mermaid図の使い分け
  - システム構成図: graph TB
  - シーケンス図: sequenceDiagram
  - ER図: erDiagram
  - クラス図: classDiagram

✅ Good Example:
ビジネス背景 → 課題 → 解決策 → KPIの流れで記述

❌ Bad Example:
技術詳細から書き始める（ビジネス背景なし）
```

#### 2.3 ユーザー配慮・品質確保
```
【追加すべき内容】
- 一問一答の進め方
  - 質問の順序
  - 深堀りのタイミング
  - 確認のタイミング

- 品質チェックリスト
  - 抜け漏れチェック
  - 矛盾チェック
  - ユーザー承認前の振り返り

✅ Good Example:
「ここまでの内容で、追加・修正したい点はありますか?」

❌ Bad Example:
振り返りなしでいきなりドキュメント提示
```

**推定作業量**: 6時間
**優先度**: **高（P1）**

---

## ⚠️ 改善推奨項目（High Priority）

### 3. **4.3 Python規約** - 内容が薄い

**現状**:
- 型安全性、エラーハンドリング、テスト標準の記述あり
- しかし具体例が少ない

**必要な肉付け**:

#### 3.1 コーディング規約の詳細化
```
【追加すべき内容】
- PEP 8準拠の具体例
  - 命名規則（クラス、関数、変数）
  - インデント（4スペース）
  - 行の長さ（88文字推奨、Black使用）

✅ Good Example:
class UserService:
    def get_user_by_id(self, user_id: str) -> Optional[User]:
        """IDでユーザーを取得"""
        ...

❌ Bad Example:
class userService:  # クラス名はPascalCase
    def GetUserById(self, userId):  # 関数名はsnake_case
        ...
```

#### 3.2 型ヒントの実践例
```
【追加すべき内容】
- 型ヒント必須パターン
  - 関数の引数・戻り値
  - クラス属性
  - Optional/Union/List/Dictの使い分け

✅ Good Example:
from typing import Optional, List

def find_users(
    status: str,
    limit: Optional[int] = None
) -> List[User]:
    ...

❌ Bad Example:
def find_users(status, limit=None):  # 型ヒントなし
    ...
```

#### 3.3 エラーハンドリングパターン
```
【追加すべき内容】
- カスタム例外クラス
- try-exceptの適切な使用
- ログ出力

✅ Good Example:
class UserNotFoundError(Exception):
    pass

try:
    user = get_user(user_id)
except UserNotFoundError:
    logger.error(f"User {user_id} not found")
    raise

❌ Bad Example:
try:
    user = get_user(user_id)
except:  # 例外を無視
    pass
```

#### 3.4 テストパターン
```
【追加すべき内容】
- pytest使用例
- モッキング（unittest.mock）
- テストカバレッジ80%以上

✅ Good Example:
def test_get_user_success():
    user = UserService().get_user_by_id("123")
    assert user.id == "123"

def test_get_user_not_found():
    with pytest.raises(UserNotFoundError):
        UserService().get_user_by_id("invalid")
```

**推定作業量**: 4時間
**優先度**: **高（P1）**

---

## 🔧 追加改善項目（Medium Priority）

### 4. **CloudFormation規約** - さらなる拡充

**現状**: 11セクションで包括的だが、以下を追加すると更に充実

**追加推奨**:

#### 4.1 ネストスタック vs モノリシック選定基準
```
【追加すべき内容】
- 判断フローチャート
- プロジェクト規模別の推奨構成
  - 小規模（リソース数 < 50）: モノリシック
  - 中規模（50 〜 200）: レイヤー分割
  - 大規模（200+）: ネストスタック + モジュール化

✅ Good Example:
VPC/Network スタック
↓ (Output/Export)
ECS スタック
↓
RDS スタック

❌ Bad Example:
すべてを1つのテンプレートに詰め込む（500行超）
```

#### 4.2 Change Sets運用フロー
```
【追加すべき内容】
- Change Set作成 → レビュー → 実行の標準フロー
- CI/CDでの自動化例

✅ Good Example:
aws cloudformation create-change-set \
  --stack-name my-stack \
  --change-set-name my-change-set \
  --template-body file://template.yaml

aws cloudformation describe-change-set \
  --change-set-name my-change-set

# レビュー後
aws cloudformation execute-change-set \
  --change-set-name my-change-set
```

**推定作業量**: 2時間
**優先度**: **中（P2）**

---

### 5. **Terraform規約** - モジュール設計パターン強化

**現状**: 基本的な4階層構成は記載済み

**追加推奨**:

#### 5.1 モジュール設計ベストプラクティス
```
【追加すべき内容】
- 再利用可能なモジュール設計
- 変数設計（required vs optional）
- バージョニング戦略

✅ Good Example:
modules/
├── vpc/
│   ├── main.tf
│   ├── variables.tf（必須変数を明確に）
│   ├── outputs.tf
│   └── README.md
└── ecs/
    └── ...

❌ Bad Example:
すべてをルートに平置き
変数のデフォルト値が不明
```

#### 5.2 State管理のセキュリティ
```
【追加すべき内容】
- S3バックエンド + DynamoDBロック
- State暗号化
- State分離戦略（環境ごと、チームごと）

✅ Good Example:
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

**推定作業量**: 2時間
**優先度**: **中（P2）**

---

### 6. **TypeScript規約** - 追加パターン

**現状**: 基本的な型安全性、非同期処理は記載済み

**追加推奨**:

#### 6.1 高度な型パターン
```
【追加すべき内容】
- Generics の使い方
- Utility Types（Partial, Pick, Omit, Record）
- 型ガード

✅ Good Example:
type User = {
  id: string;
  name: string;
  email: string;
};

type UserCreateInput = Omit<User, 'id'>;

function isUser(value: unknown): value is User {
  return typeof value === 'object' && value !== null && 'id' in value;
}
```

#### 6.2 React/Next.js パターン（該当する場合）
```
【追加すべき内容】
- Hooks の型定義
- Props の型定義
- Server Components vs Client Components

✅ Good Example:
type ButtonProps = {
  label: string;
  onClick: () => void;
  disabled?: boolean;
};

const Button: React.FC<ButtonProps> = ({ label, onClick, disabled = false }) => {
  ...
};
```

**推定作業量**: 3時間
**優先度**: **中（P2）**

---

### 7. **C# .NET Core規約** - 追加パターン

**現状**: DI、例外処理の基本は記載済み

**追加推奨**:

#### 7.1 async/awaitのベストプラクティス
```
【追加すべき内容】
- ConfigureAwait(false) の使い分け
- CancellationToken の利用
- Task.WhenAll の活用

✅ Good Example:
public async Task<User> GetUserAsync(string id, CancellationToken ct)
{
    var user = await _repository.FindByIdAsync(id, ct);
    return user;
}

❌ Bad Example:
public User GetUser(string id)
{
    return _repository.FindByIdAsync(id).Result;  // デッドロックの危険
}
```

#### 7.2 Entity Framework Core パターン
```
【追加すべき内容】
- DbContext のライフタイム管理
- Migration戦略
- パフォーマンス最適化（AsNoTracking等）

✅ Good Example:
var users = await _context.Users
    .AsNoTracking()
    .Where(u => u.IsActive)
    .ToListAsync(ct);
```

**推定作業量**: 2時間
**優先度**: **中（P2）**

---

### 8. **Go言語規約** - 追加パターン

**現状**: エラーハンドリング、並列処理の基本は記載済み

**追加推奨**:

#### 8.1 contextパッケージの活用
```
【追加すべき内容】
- context.WithTimeout
- context.WithCancel
- context.WithValue の適切な使用

✅ Good Example:
func GetUser(ctx context.Context, id string) (*User, error) {
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    user, err := repo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("failed to get user: %w", err)
    }
    return user, nil
}
```

#### 8.2 テーブル駆動テスト
```
【追加すべき内容】
- table-driven tests パターン
- サブテスト（t.Run）

✅ Good Example:
func TestGetUser(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    *User
        wantErr bool
    }{
        {"success", "123", &User{ID: "123"}, false},
        {"not found", "999", nil, true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := GetUser(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("GetUser() error = %v, wantErr %v", err, tt.wantErr)
            }
            // ...
        })
    }
}
```

**推定作業量**: 2時間
**優先度**: **中（P2）**

---

## 📋 改善作業の優先順位まとめ

| 優先度 | 項目 | 推定工数 | 期待効果 |
|-------|-----|---------|---------|
| **P0（最優先）** | セキュリティ・運用基準 | 8時間 | 本番運用時の重大インシデント防止 |
| **P1（高）** | ファシリテーション戦略 | 6時間 | ユーザー対話品質向上 |
| **P1（高）** | Python規約 | 4時間 | コード品質向上 |
| **P2（中）** | CloudFormation規約 | 2時間 | IaC品質向上 |
| **P2（中）** | Terraform規約 | 2時間 | IaC品質向上 |
| **P2（中）** | TypeScript規約 | 3時間 | フロントエンド品質向上 |
| **P2（中）** | C# .NET Core規約 | 2時間 | バックエンド品質向上 |
| **P2（中）** | Go言語規約 | 2時間 | マイクロサービス品質向上 |

**合計推定工数**: 29時間

---

## 🎯 推奨アクションプラン

### フェーズ1（最優先 - 1週間以内）
1. **セキュリティ・運用基準**の完全再構築
   - AWS Well-Architected Framework 準拠
   - シークレット管理フロー
   - 本番環境保護フロー
   - ログ・監視・アラート設計

### フェーズ2（高優先 - 2週間以内）
2. **ファシリテーション戦略**の詳細化
   - ヒアリング質問テンプレート
   - ドキュメント生成テンプレート
   - 品質チェックリスト

3. **Python規約**の拡充
   - コーディング規約詳細
   - 型ヒント実践例
   - エラーハンドリング・テストパターン

### フェーズ3（中優先 - 1ヶ月以内）
4. 各言語規約・IaC規約の追加パターン整備

---

## 📝 レビュー所感

### 良い点
- CloudFormation, Terraform, TypeScript, C#, Go は基本構成が揃っている
- Good/Bad Example の記載がある箇所は理解しやすい
- 階層構造が整理されている

### 改善の余地
- **セキュリティ・運用基準が最も不足** → 本番運用時のリスクが高い
- ファシリテーション戦略が抽象的 → 実践で使いにくい
- Python規約が薄い → 他言語と比較して見劣りする
- Good/Bad Example をさらに充実させると実践的になる

### 総評
「基礎はできているが、実践で使える詳細度には達していない」

特に **セキュリティ・運用基準** と **ファシリテーション戦略** は、
プロジェクト成功の鍵となる部分なので、最優先で肉付けすべき。

---

**次のステップ**: このリストをもとに、優先順位に従ってNotion規約を順次拡充していく。
