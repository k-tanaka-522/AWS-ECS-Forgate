# ドキュメント生成フロー

## 概要

このドキュメントは、プロジェクト固有のドキュメント・規約を体系的に生成するためのフローを定義します。

---

## 1. ドキュメント体系の全体像

### 1.1 フェーズ別の生成物

| フェーズ | 生成物 | 目的 | テンプレート |
|---------|--------|------|------------|
| **企画** | 企画書 | ビジネス背景・目的の明確化 | [01_planning/](../30_templates/01_planning/) |
| **要件定義** | 要件定義書 | 機能・非機能要件の確定 | [02_requirements/](../30_templates/02_requirements/) |
| **設計（基本）** | ①基本設計書<br>②**プロジェクト固有の基本設計規約** | アーキテクチャ・技術選定<br>プロジェクト固有の設計ルール | [03_design/](../30_templates/03_design/) |
| **設計（詳細）** | ①詳細設計書<br>②**プロジェクト固有の詳細設計規約** | DB設計、API設計<br>命名規則・モジュール分割方針 | （基本設計書の一部） |
| **実装** | ①ソースコード<br>②**プロジェクト固有のコード規約** | 実装<br>コーディングルール | [04_implementation/](../30_templates/04_implementation/) |
| **テスト** | ①テスト設計書<br>②テストコード<br>③**プロジェクト固有のテスト設計規約** | テスト戦略・テストケース<br>テスト実装<br>テストルール | [05_testing/](../30_templates/05_testing/) |
| **デプロイ** | ①デプロイ手順書<br>②CI/CD設定<br>③運用手順書 | デプロイ自動化・運用 | [06_deployment/](../30_templates/06_deployment/) |

### 1.2 規約の階層構造

```
.claude/docs/40_standards/          ← 汎用的な技術標準（全プロジェクト共通）
├── 41_common.md                    # 共通標準
├── 42_infrastructure.md            # インフラ標準
├── 43_frontend.md                  # フロントエンド標準
├── 44_backend.md                   # バックエンド標準
└── 45_secrets-management.md        # シークレット管理標準

docs/standards/                      ← プロジェクト固有の規約（このプロジェクト専用）
├── 00_プロジェクト概要.md           ← プロジェクトタイプを定義
│
├── アプリケーション/                # Webアプリ開発の場合のみ生成
│   ├── 01_基本設計規約.md           ← アプリのアーキテクチャ、技術選定
│   ├── 02_詳細設計規約.md           ← DB設計、API設計、ディレクトリ構造
│   └── 03_コード規約.md             ← React/Node.js等のコーディング規約
│
├── インフラ/                        # インフラ構築の場合のみ生成
│   ├── 01_基本設計規約.md           ← インフラアーキテクチャ、AWS構成
│   ├── 02_詳細設計規約.md           ← VPC設計、セキュリティグループ、IAM設計
│   └── 03_IaCコード規約.md          ← Terraform/CloudFormationコーディング規約
│
└── 04_テスト設計規約.md             ← テスト戦略（共通）
```

**重要な考え方：**
- `.claude/docs/40_standards/` = **汎用的なベストプラクティス**（React、Node.js、AWSの一般的な標準）
- `.claude/docs/30_templates/` = **ドキュメントのテンプレート**（企画書、要件定義書、設計書の雛形）
- `docs/standards/` = **プロジェクト固有のルール**（このプロジェクトの技術選定・要件に基づく具体的な規約）
- **プロジェクトタイプ別に規約を分離**：アプリケーション開発とインフラ構築で規約が異なる

---

## 2. プロジェクトタイプの判定

### 2.1 プロジェクトタイプの定義

要件定義フェーズで、プロジェクトタイプを判定してください：

| プロジェクトタイプ | 説明 | 生成する規約 |
|----------------|------|------------|
| **アプリケーション開発** | Webアプリ、モバイルアプリ等 | アプリケーション/ 配下 |
| **インフラ構築** | AWS環境構築、IaC等 | インフラ/ 配下 |
| **ハイブリッド** | Webアプリ + インフラ両方 | 両方 |

### 2.2 プロジェクトタイプの記録

`docs/standards/00_プロジェクト概要.md` に記録：

```markdown
# プロジェクト概要

## プロジェクトタイプ
- [x] アプリケーション開発
- [x] インフラ構築

## 技術スタック
- フロントエンド: React 19
- バックエンド: Node.js 20
- データベース: PostgreSQL
- インフラ: AWS（Terraform）
- CI/CD: GitHub Actions

## プロジェクト規模
- ユーザー数: 月間10万人
- トラフィック: 100万PV/月
- チームサイズ: 5名
```

---

## 3. プロジェクト固有規約の生成フロー

### 3.1 アプリケーション開発の場合

#### 3.1.1 基本設計規約の生成

**タイミング：** 要件定義完了後、基本設計開始時

**入力情報：**
- 要件定義書の内容
- 技術スタック（React, Node.js等）
- 非機能要件（性能、セキュリティ、スケーラビリティ）

**生成内容：**

```markdown
# 基本設計規約（プロジェクト固有）

## 1. アーキテクチャ方針

### 1.1 採用アーキテクチャ
- **3層アーキテクチャ**（Web, API, DB）
- **マイクロサービス** or **モノリシック**（プロジェクト規模から判断）

### 1.2 レイヤー分割
- Presentation層：React（UI/UX）
- Application層：Node.js + Express（ビジネスロジック）
- Data層：PostgreSQL（データ永続化）

### 1.3 技術選定の根拠
- なぜReactか（要件との紐付け）
- なぜNode.jsか
- なぜPostgreSQLか

## 2. 非機能要件への対応方針

### 2.1 性能要件
- 要件：「応答時間2秒以内」
- 対応策：
  - Redis キャッシュ導入
  - CloudFront CDN導入
  - データベースインデックス最適化

### 2.2 セキュリティ要件
- 要件：「個人情報保護法対応」
- 対応策：
  - Cognito認証
  - データ暗号化（S3, RDS）
  - アクセスログ記録

### 2.3 可用性要件
- 要件：「稼働率99.9%」
- 対応策：
  - Multi-AZ構成
  - Auto Scaling
  - ヘルスチェック

## 3. インフラ設計方針

### 3.1 AWS構成
- VPC設計（CIDR、サブネット）
- ECS Fargate（コンテナ）
- RDS PostgreSQL（Multi-AZ）
- S3（ファイルストレージ）
- CloudFront（CDN）

### 3.2 環境戦略
- dev：開発環境（コスト最適化）
- stg：ステージング環境（本番相当）
- prod：本番環境（高可用性）

## 4. データ設計方針

### 4.1 データベース設計原則
- 正規化（第3正規形まで）
- パフォーマンスのための非正規化判断基準
- インデックス設計方針

### 4.2 データ保持期間
- 個人情報：法定保存期間（〇年）
- ログデータ：〇日間
- バックアップ：〇世代

## 5. API設計方針

### 5.1 RESTful API設計
- エンドポイント命名規則
- HTTPメソッドの使い分け
- ステータスコードの定義

### 5.2 認証・認可
- JWT トークン認証
- ロールベースアクセス制御（RBAC）

## 6. エラーハンドリング方針

### 6.1 エラーレベル
- CRITICAL / ERROR / WARNING / INFO

### 6.2 ログ出力先
- アプリケーションログ：CloudWatch Logs
- アクセスログ：S3
- エラー通知：SNS → Slack

---

このプロジェクト固有の基本設計規約は、詳細設計・実装時に必ず参照してください。
```

**Claude の動作：**
1. 要件定義書を読み込む
2. 技術スタックを確認
3. 非機能要件を抽出
4. `.claude/docs/40_standards/`の技術標準を参照
5. プロジェクト固有の基本設計規約を生成
6. `docs/standards/01_基本設計規約.md` に保存

---

### 2.2 詳細設計規約の生成

**タイミング：** 基本設計完了後、詳細設計開始時

**入力情報：**
- 基本設計書
- プロジェクト固有の基本設計規約
- データベーススキーマ案
- API仕様案

**生成内容：**

```markdown
# 詳細設計規約（プロジェクト固有）

## 1. ディレクトリ構造

### 1.1 バックエンド（Node.js）
```
src/
├── controllers/       # APIエンドポイント
├── services/          # ビジネスロジック
├── repositories/      # データアクセス層
├── models/            # データモデル
├── middlewares/       # 認証、ログ等
├── utils/             # 共通ユーティリティ
└── config/            # 設定ファイル
```

### 1.2 フロントエンド（React）
```
src/
├── components/        # 再利用可能コンポーネント
├── pages/             # ページコンポーネント
├── hooks/             # カスタムフック
├── contexts/          # Context API
├── services/          # API通信
├── utils/             # ユーティリティ
└── styles/            # スタイル
```

## 2. 命名規則

### 2.1 テーブル名
- **複数形、スネークケース**：`users`, `care_applications`

### 2.2 カラム名
- **スネークケース**：`user_id`, `created_at`

### 2.3 API エンドポイント
- **リソース名（複数形）**：`/api/v1/users`, `/api/v1/care-applications`

### 2.4 関数名（バックエンド）
- **動詞 + 名詞（キャメルケース）**：`getUser()`, `createCareApplication()`

### 2.5 コンポーネント名（React）
- **パスカルケース**：`UserProfile`, `CareApplicationForm`

## 3. データベース設計

### 3.1 主キー
- すべてのテーブルに`id`（UUID）を使用
- 理由：分散システムでの一意性確保

### 3.2 タイムスタンプ
- すべてのテーブルに以下を必須：
  - `created_at TIMESTAMP NOT NULL`
  - `updated_at TIMESTAMP NOT NULL`

### 3.3 論理削除
- 物理削除せず、`deleted_at`フラグで論理削除
- 理由：データ復旧、監査ログ

### 3.4 インデックス設計
- 検索条件になるカラムにインデックス
- 複合インデックスの順序：選択性の高い順

## 4. API 設計

### 4.1 リクエストフォーマット
```json
{
  "data": {
    "user": {
      "name": "田中太郎",
      "email": "tanaka@example.com"
    }
  }
}
```

### 4.2 レスポンスフォーマット
```json
{
  "status": "success",
  "data": {
    "user": {
      "id": "uuid-xxx",
      "name": "田中太郎",
      "email": "tanaka@example.com"
    }
  }
}
```

### 4.3 エラーレスポンス
```json
{
  "status": "error",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "メールアドレスが不正です",
    "details": [
      {"field": "email", "message": "無効な形式"}
    ]
  }
}
```

## 5. モジュール分割方針

### 5.1 単一責任の原則
- 1つのファイルは1つの責務のみ
- 行数の目安：200行以内

### 5.2 レイヤーの依存関係
```
Controller → Service → Repository → Model
（上位層は下位層に依存、逆は禁止）
```

### 5.3 共通処理の切り出し
- 3回以上同じコードが出たら共通化

---

このプロジェクト固有の詳細設計規約は、実装時に必ず参照してください。
```

---

### 2.3 コード規約の生成

**タイミング：** 実装開始時

**入力情報：**
- 技術スタック（React, TypeScript, Node.js等）
- 詳細設計規約
- `.claude/docs/40_standards/`の技術標準

**生成内容：**

```markdown
# コード規約（プロジェクト固有）

## 1. 共通規約

### 1.1 言語・フレームワークバージョン
- Node.js: 20.x LTS
- React: 18.x
- TypeScript: 5.x

### 1.2 コードフォーマット
- **ESLint + Prettier** 使用
- インデント：2スペース
- セミコロン：必須
- クォート：シングルクォート

### 1.3 型安全性
- TypeScript strict モード有効化
- `any`型の使用禁止（型推論できない場合は`unknown`）

## 2. バックエンド（Node.js）規約

### 2.1 非同期処理
- **async/await** 使用（Promiseチェーンは非推奨）
- エラーハンドリング必須

```typescript
// ✅ 良い例
async function getUser(userId: string): Promise<User> {
  try {
    const user = await userRepository.findById(userId);
    if (!user) {
      throw new NotFoundError('User not found');
    }
    return user;
  } catch (error) {
    logger.error('Failed to get user', { userId, error });
    throw error;
  }
}

// ❌ 悪い例
function getUser(userId) {
  return userRepository.findById(userId)
    .then(user => {
      if (!user) throw new Error('Not found');
      return user;
    });
}
```

### 2.2 ログ出力
- すべてのCRUD操作でログ出力
- 個人情報はマスキング

```typescript
logger.info('User created', {
  userId: user.id,
  email: maskEmail(user.email)
});
```

### 2.3 環境変数
- `.env`ファイルで管理
- `dotenv`で読み込み
- 必須環境変数のバリデーション

## 3. フロントエンド（React）規約

### 3.1 コンポーネント設計
- 関数コンポーネント + Hooks 使用（クラスコンポーネント禁止）
- Props の型定義必須

```typescript
// ✅ 良い例
interface UserProfileProps {
  user: User;
  onEdit: (user: User) => void;
}

export const UserProfile: React.FC<UserProfileProps> = ({ user, onEdit }) => {
  return (
    <div>
      <h1>{user.name}</h1>
      <button onClick={() => onEdit(user)}>編集</button>
    </div>
  );
};

// ❌ 悪い例
export const UserProfile = (props) => {
  return <div>{props.user.name}</div>;
};
```

### 3.2 状態管理
- ローカル状態：`useState`
- グローバル状態：`Context API`（または Redux Toolkit）
- サーバー状態：`React Query`

### 3.3 API 通信
- `axios` 使用
- エラーハンドリング必須
- ローディング状態の管理

```typescript
const { data, isLoading, error } = useQuery({
  queryKey: ['user', userId],
  queryFn: () => api.getUser(userId),
});

if (isLoading) return <LoadingSpinner />;
if (error) return <ErrorMessage error={error} />;
```

## 4. テストコード規約

### 4.1 テストカバレッジ目標
- ユニットテスト：80%以上
- 統合テスト：主要フロー100%

### 4.2 テストファイル命名
- `*.test.ts`（Jestの場合）
- テスト対象と同じディレクトリに配置

### 4.3 テストケース命名
```typescript
describe('UserService', () => {
  describe('createUser', () => {
    it('正常系：新規ユーザーを作成できる', async () => {
      // ...
    });

    it('異常系：メールアドレスが重複している場合、エラーを返す', async () => {
      // ...
    });
  });
});
```

---

このプロジェクト固有のコード規約は、実装時に必ず遵守してください。
```

**Claude の動作：**
1. 要件定義書を読み込む
2. 技術スタックを確認
3. `.claude/docs/40_standards/`の技術標準を参照
4. プロジェクト固有のコード規約を生成
5. `docs/standards/アプリケーション/03_コード規約.md`に保存

---

### 3.2 インフラ構築の場合

#### 3.2.1 基本設計規約の生成

**タイミング：** 要件定義完了後、基本設計開始時

**入力情報：**
- 要件定義書の内容
- インフラ技術スタック（AWS, Terraform/CloudFormation等）
- 非機能要件（可用性、セキュリティ、スケーラビリティ）

**生成内容：**

```markdown
# 基本設計規約（インフラ・プロジェクト固有）

## 1. インフラアーキテクチャ方針

### 1.1 採用アーキテクチャ
- **Multi-AZ構成**（高可用性要件を満たすため）
- **VPC分離**（dev / stg / prod）

### 1.2 AWS構成
- コンピューティング：ECS Fargate
- データベース：RDS PostgreSQL（Multi-AZ）
- ストレージ：S3
- CDN：CloudFront
- 認証：Cognito

### 1.3 技術選定の根拠
- なぜECS Fargateか（要件との紐付け）
  - 要件：「運用負荷を最小化したい」
  - 対応：サーバーレスコンテナで運用不要
- なぜTerraformか
  - 要件：「複数環境を効率的に管理したい」
  - 対応：モジュール化で環境差分を管理

## 2. 非機能要件への対応方針

### 2.1 可用性要件
- 要件：「稼働率99.9%」
- 対応策：
  - Multi-AZ構成
  - Auto Scaling
  - ヘルスチェック
  - ALB による負荷分散

### 2.2 セキュリティ要件
- 要件：「個人情報保護法対応」
- 対応策：
  - VPC内にプライベートサブネット配置
  - セキュリティグループで最小権限
  - RDS暗号化
  - S3暗号化
  - Secrets Manager でパスワード管理

### 2.3 スケーラビリティ要件
- 要件：「将来的に10倍の負荷に対応」
- 対応策：
  - ECS Auto Scaling
  - RDS リードレプリカ
  - CloudFront によるキャッシュ

## 3. IaCツール選定

### 3.1 採用ツール
- **Terraform** を採用

### 3.2 選定理由
- モジュール化しやすい
- 複数環境の管理が容易
- マルチクラウド対応（将来的にGCP追加の可能性）

### 3.3 代替案との比較
| ツール | メリット | デメリット | 採用理由 |
|--------|---------|-----------|---------|
| Terraform | モジュール化、マルチクラウド | 学習コスト | ✅ 採用 |
| CloudFormation | AWS特化、ネイティブ | AWS専用 | AWS専用ならOK |
| CDK | プログラミング言語 | 複雑 | 複雑なロジック不要 |
```

**Claude の動作：**
1. 要件定義書を読み込む
2. インフラ要件を確認
3. `.claude/docs/40_standards/42_infrastructure.md`を参照
4. プロジェクト固有の基本設計規約を生成
5. `docs/standards/インフラ/01_基本設計規約.md`に保存

#### 3.2.2 詳細設計規約の生成

**タイミング：** 基本設計完了後、詳細設計開始時

**生成内容：**

```markdown
# 詳細設計規約（インフラ・プロジェクト固有）

## 1. ディレクトリ構造

### 1.1 Terraform ディレクトリ構造
```
infra/
├── modules/                    # 再利用可能なモジュール
│   ├── vpc/
│   ├── ecs/
│   └── rds/
│
├── environments/               # 環境ごとの設定
│   ├── dev/
│   ├── stg/
│   └── prod/
│
└── shared/                     # 共通設定
```

## 2. 命名規則

### 2.1 リソース命名規則
- 形式：`{project}-{env}-{resource}-{purpose}`
- 例：`myapp-prod-ecs-web`, `myapp-prod-rds-main`

### 2.2 変数命名規則
- スネークケース：`vpc_cidr`, `db_instance_class`

## 3. VPC設計

### 3.1 CIDR設計
- dev: 10.0.0.0/16
- stg: 10.1.0.0/16
- prod: 10.2.0.0/16

### 3.2 サブネット分割
- パブリックサブネット：/24（ALB配置）
- プライベートサブネット：/24（ECS, RDS配置）
- 3AZ構成（ap-northeast-1a, 1c, 1d）

## 4. セキュリティグループ設計

### 4.1 ALB用セキュリティグループ
- Ingress：443（HTTPS）← 0.0.0.0/0
- Egress：All ← ECS セキュリティグループ

### 4.2 ECS用セキュリティグループ
- Ingress：8080 ← ALB セキュリティグループ
- Egress：443 ← 0.0.0.0/0（外部API通信用）

### 4.3 RDS用セキュリティグループ
- Ingress：5432 ← ECS セキュリティグループ
- Egress：なし

## 5. IAM設計

### 5.1 ECS タスクロール
- S3読み書き権限
- Secrets Manager読み取り権限
- CloudWatch Logs書き込み権限

### 5.2 CI/CD用IAMユーザー
- ECS更新権限
- ECR push権限
```

**Claude の動作：**
1. 基本設計書を読み込む
2. VPC、セキュリティグループ、IAM設計
3. `.claude/docs/40_standards/42_infrastructure.md`を参照
4. プロジェクト固有の詳細設計規約を生成
5. `docs/standards/インフラ/02_詳細設計規約.md`に保存

#### 3.2.3 IaCコード規約の生成

**タイミング：** 実装開始時

**生成内容：**

```markdown
# IaCコード規約（プロジェクト固有）

## 1. Terraform コーディング規約

### 1.1 ファイル命名規則
- main.tf：リソース定義
- variables.tf：変数定義
- outputs.tf：出力定義
- versions.tf：Terraformバージョン指定

### 1.2 リソース定義順序
1. Data sources
2. Locals
3. Resources（依存関係順）
4. Outputs

### 1.3 コメント規則
```hcl
# リソースの目的を説明
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr  # CIDR設計に基づく

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}
```

### 1.4 変数のデフォルト値
- 環境別の値：デフォルト値なし（terraform.tfvarsで必須指定）
- 共通の値：デフォルト値あり

### 1.5 モジュール化
- 3回以上同じリソース定義が出たらモジュール化
- モジュールは`modules/`配下に配置

### 1.6 環境差分の管理
- `environments/{env}/terraform.tfvars`で管理
- 機密情報は`secrets.tfvars`（.gitignore除外）

## 2. CloudFormation コーディング規約

### 2.1 ネストスタック構造
- 親スタック：`stack.yaml`
- 子テンプレート：`nested/`配下

### 2.2 パラメータ命名規則
- パスカルケース：`VpcCIDR`, `DbInstanceClass`

### 2.3 タグ必須化
すべてのリソースに以下のタグを必須：
- Name
- Environment
- ManagedBy
```

**Claude の動作：**
1. 詳細設計書を読み込む
2. `.claude/docs/40_standards/42_infrastructure.md`を参照
3. プロジェクト固有のIaCコード規約を生成
4. `docs/standards/インフラ/03_IaCコード規約.md`に保存

---

### 3.3 ハイブリッド（アプリ + インフラ）の場合

両方の規約を生成：
- `docs/standards/アプリケーション/` 配下
- `docs/standards/インフラ/` 配下

---

### 3.4 テスト設計規約の生成

**タイミング：** テストフェーズ開始時

**入力情報：**
- テスト戦略
- 要件定義書（テストすべき機能）
- コード規約

**生成内容：**

```markdown
# テスト設計規約（プロジェクト固有）

## 1. テスト戦略

### 1.1 テストレベル
- **ユニットテスト**：個別関数・コンポーネント
- **統合テスト**：API、DB連携
- **E2Eテスト**：主要ユースケース

### 1.2 テストツール
- ユニットテスト：**Jest**
- E2Eテスト：**Playwright**
- APIテスト：**Supertest**

## 2. テストケース設計方針

### 2.1 正常系・異常系
- すべての機能で正常系・異常系の両方をテスト

### 2.2 境界値テスト
- 入力値の境界値を必ずテスト

### 2.3 カバレッジ目標
- ユニットテスト：80%以上
- 統合テスト：主要フロー100%

## 3. テストデータ管理

### 3.1 テストデータ
- Fixtureファイルで管理
- 本番データ使用禁止

### 3.2 テスト環境
- 専用のテストDB使用
- テスト実行後にクリーンアップ

## 4. CI/CD統合

### 4.1 自動テスト
- すべてのPull Requestでテスト自動実行
- テスト失敗時はマージ禁止

---

このプロジェクト固有のテスト設計規約は、テスト実装時に必ず参照してください。
```

---

## 3. Claude の動作フロー

### 3.1 企画フェーズ
```
1. ユーザーからビジネス背景をヒアリング
2. `.claude/docs/30_templates/01_planning/template.md`を読み込む
3. テンプレートに沿って企画書を生成
4. `docs/01_企画書.md`に保存
5. ユーザーに提示してレビュー依頼
```

### 3.2 要件定義フェーズ
```
1. 企画書を読み込む
2. `.claude/docs/30_templates/02_requirements/template.md`を読み込む
3. ユーザーから機能・非機能要件をヒアリング
4. テンプレートに沿って要件定義書を生成
5. `docs/02_要件定義書.md`に保存
6. プロジェクトタイプを判定し、`docs/standards/00_プロジェクト概要.md`に記録
```

### 3.3 基本設計フェーズ
```
1. 要件定義書を読み込む
2. `.claude/docs/30_templates/03_design/template.md`を読み込む
3. `.claude/docs/40_standards/`の技術標準を参照
4. テンプレートに沿って基本設計書を生成
5. `docs/03_基本設計書.md`に保存
6. プロジェクト固有の基本設計規約を生成（アプリ or インフラ or 両方）
7. `docs/standards/{アプリケーション or インフラ}/01_基本設計規約.md`に保存
8. ユーザーに提示してレビュー依頼
```

### 3.4 詳細設計フェーズ
```
1. 基本設計書を読み込む
2. 基本設計規約を参照
3. プロジェクト固有の詳細設計規約を生成
4. `docs/standards/{アプリケーション or インフラ}/02_詳細設計規約.md`に保存
5. ユーザーに提示してレビュー依頼
```

### 3.5 実装フェーズ
```
1. 詳細設計書を読み込む
2. 詳細設計規約を参照
3. プロジェクト固有のコード規約を生成
4. `docs/standards/{アプリケーション or インフラ}/03_{コード or IaCコード}規約.md`に保存
5. `.eslintrc.json`、`.prettierrc`等の設定ファイルも生成
6. 規約に従ってコードを生成
7. review-task-generator.mdに従ってレビュータスクを生成
```

---

## 4. まとめ

**従来の問題点：**
- 汎用的な技術標準のみで、プロジェクト固有のルールがない
- コード生成時に一貫性が保てない
- ドキュメントと実装が乖離

**改善策：**
- フェーズごとにプロジェクト固有の規約を自動生成
- 要件 → 基本設計規約 → 詳細設計規約 → コード規約 → テスト設計規約の流れで、一貫性を確保
- 生成した規約を必ず参照してコード生成

**Claude の責務：**
- 各フェーズで適切なタイミングで規約を生成
- 生成した規約を厳守してドキュメント・コードを作成
- 規約の根拠（なぜこのルールか）を明示
