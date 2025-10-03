# ベストプラクティス調査フロー

## 概要

技術選定・設計・コード生成の前に、**最新のベストプラクティスを調査**するフローです。

汎用的な技術標準（`.claude/docs/40_standards/`）だけでなく、プロジェクト固有の技術スタックに応じた最新情報を収集します。

---

## 1. なぜ調査が必要か

### 1.1 技術の変化が速い
- フレームワークのバージョンアップ（React 17 → 18 → 19）
- AWSサービスの新機能（例：ECS Fargate の新プラン）
- セキュリティ脆弱性の発見と対策
- ベストプラクティスの変化

### 1.2 プロジェクト固有の要件
- 業界特有の規制（医療、金融、介護等）
- 規模・トラフィックに応じた設計
- チームのスキルセット
- 予算・スケジュール

### 1.3 汎用的な標準だけでは不十分
- `.claude/docs/40_standards/`は一般的なベストプラクティス
- プロジェクト固有の技術選定・要件に合わせた調査が必要

---

## 2. 調査タイミング

### 2.1 技術選定時（要件定義フェーズ）

**調査対象：**
- フロントエンドフレームワーク（React / Vue / Next.js / Svelte）
- バックエンドフレームワーク（Node.js / Python / Go / Rust）
- データベース（PostgreSQL / MySQL / DynamoDB / MongoDB）
- インフラ（AWS / GCP / Azure）
- CI/CDツール（GitHub Actions / GitLab CI / CircleCI）

**調査内容：**
- 最新バージョン
- セキュリティ脆弱性
- コミュニティの活発度
- ライセンス
- チームの習熟度
- プロジェクト要件との適合性

**例：フロントエンドフレームワーク選定**
```
ユーザー: 「Webアプリケーションを作りたい」

Claude:
1. 要件をヒアリング（SPA / SSR / SSG / 規模 / パフォーマンス要件）
2. 【調査実施】
   - WebSearchツールで「React vs Vue 2025 ベストプラクティス」を検索
   - 公式ドキュメント確認（React 19の新機能、破壊的変更）
   - セキュリティアドバイザリ確認
3. 調査結果を .claude-state/research/ に記録
4. ユーザーに選択肢を提示（根拠付き）
5. 決定後、decisions.json に記録
```

---

### 2.2 基本設計時（設計フェーズ）

**調査対象：**
- アーキテクチャパターン（マイクロサービス / モノリシック / モジュラーモノリス）
- インフラ構成（ECS / EKS / Lambda / EC2）
- データベース設計（正規化 / 非正規化 / パーティショニング）
- キャッシュ戦略（Redis / Memcached / CloudFront）
- 認証・認可（Cognito / Auth0 / Firebase Auth）

**調査内容：**
- 規模・トラフィックに応じた設計
- コスト試算
- 可用性・スケーラビリティ
- 運用負荷

**例：インフラ構成の選定**
```
ユーザー: 「AWSにWebアプリをデプロイしたい。月間100万PV想定」

Claude:
1. 要件整理（トラフィック、可用性、予算）
2. 【調査実施】
   - WebSearchツールで「AWS ECS Fargate vs Lambda 2025」を検索
   - AWS公式ドキュメントで料金比較
   - ベストプラクティスホワイトペーパー確認
3. 調査結果を .claude-state/research/ に記録
4. 複数案を提示（ECS Fargate / Lambda / EC2 + Auto Scaling）
5. コスト・運用負荷・スケーラビリティを比較表で提示
6. ユーザーと合意
7. decisions.json に記録
```

---

### 2.3 詳細設計時（設計フェーズ）

**調査対象：**
- ディレクトリ構造（プロジェクト規模に応じたベストプラクティス）
- 命名規則（業界標準、チーム標準）
- データベーススキーマ設計（正規化レベル、インデックス戦略）
- API設計（REST / GraphQL / gRPC）
- エラーハンドリング戦略

**調査内容：**
- 最新のコーディング規約
- フレームワーク固有のベストプラクティス
- パフォーマンス最適化手法

**例：React プロジェクトのディレクトリ構造**
```
Claude:
1. 【調査実施】
   - WebSearchツールで「React 19 project structure best practices 2025」を検索
   - 公式ドキュメント・有名OSSプロジェクト（Vercel, Airbnb等）を参考
2. 規模別の推奨構造を整理
   - 小規模（~10コンポーネント）：フラット構造
   - 中規模（~50コンポーネント）：feature-based
   - 大規模（50+コンポーネント）：domain-driven
3. プロジェクト規模に応じた推奨案を提示
4. .claude-state/research/ に記録
5. docs/standards/02_詳細設計規約.md に反映
```

---

### 2.4 実装時（コード生成前）

**調査対象：**
- 最新のフレームワークバージョン
- 非推奨API・破壊的変更
- セキュリティ脆弱性
- パフォーマンス最適化
- 新機能（React Server Components, TypeScript 5.x等）

**調査内容：**
- 公式ドキュメント
- Migration Guide
- セキュリティアドバイザリ
- GitHub Issueの既知の問題

**例：React 19 でのコード生成**
```
Claude:
1. 【調査実施】
   - WebFetchツールで React公式ドキュメント確認
   - 「React 19 breaking changes」を検索
   - 非推奨APIの確認（useEffect依存関係の変更等）
2. 調査結果を .claude-state/research/ に記録
3. コード生成時、最新ベストプラクティスを適用
   - React 19の新機能（use hook等）を活用
   - 非推奨APIを回避
4. 生成コードにコメントで根拠を記載
```

---

### 2.5 実装中（問題発生時）

**調査対象：**
- エラーメッセージの原因
- 既知のバグ・回避策
- パフォーマンスボトルネック

**調査内容：**
- Stack Overflow
- GitHub Issues
- 公式ドキュメント

**例：ビルドエラー発生**
```
ユーザー: 「npm run buildでエラーが出ます」

Claude:
1. エラーメッセージを確認
2. 【調査実施】
   - WebSearchツールで「エラーメッセージ React 19」を検索
   - GitHub Issueを確認
   - 公式ドキュメントで既知の問題を確認
3. 解決策を提示
4. .claude-state/research/ に記録（同じエラーの再発防止）
```

---

## 3. 調査方法

### 3.1 WebSearchツール（推奨）

**使用タイミング：**
- 最新情報が必要な場合
- 複数の情報源を比較したい場合
- ベストプラクティスのトレンドを知りたい場合

**例：**
```
WebSearch: "React 19 best practices 2025"
WebSearch: "AWS ECS Fargate vs Lambda cost comparison 2025"
WebSearch: "PostgreSQL vs DynamoDB performance 2025"
```

### 3.2 WebFetchツール

**使用タイミング：**
- 公式ドキュメントの特定ページを読む
- GitHub Issueの詳細を確認
- ブログ記事の詳細を読む

**例：**
```
WebFetch: https://react.dev/blog/2024/12/05/react-19
WebFetch: https://docs.aws.amazon.com/ecs/latest/userguide/what-is-fargate.html
```

### 3.3 調査範囲の優先順位

| 優先度 | 調査対象 | 理由 |
|-------|---------|------|
| **最高** | 公式ドキュメント | 最も信頼性が高い |
| **高** | 公式ブログ・リリースノート | 最新情報 |
| **中** | 有名企業の技術ブログ（Vercel, Netlify, AWS等） | 実践的 |
| **低** | Stack Overflow, GitHub Issues | 個別の問題解決 |

---

## 4. 調査結果の記録

### 4.1 記録先

```
.claude-state/research/
├── technology-selection.md       # 技術選定調査
├── architecture-research.md      # アーキテクチャ調査
├── framework-best-practices.md   # フレームワークベストプラクティス
└── security-advisories.md        # セキュリティ情報
```

### 4.2 記録フォーマット

```markdown
# 調査記録: React フレームワーク選定

## 調査日
2025-10-03

## 調査目的
Webアプリケーションのフロントエンドフレームワーク選定

## 調査内容

### 候補
1. React 19
2. Vue 3
3. Next.js 15

### 調査結果

#### React 19
- **最新バージョン**: 19.0.0（2024年12月リリース）
- **新機能**:
  - React Server Components（安定版）
  - use hook（非同期データ取得）
  - Actions（フォーム処理の簡素化）
- **破壊的変更**:
  - useEffect依存配列の厳格化
  - Legacy Contextの削除
- **セキュリティ**: 脆弱性なし（2025年1月時点）
- **コミュニティ**: GitHub Star 230k+、活発
- **学習コスト**: 中（Server Componentsは新概念）

#### Vue 3
- **最新バージョン**: 3.4.0
- **新機能**: Composition API（安定版）
- **セキュリティ**: 脆弱性なし
- **コミュニティ**: GitHub Star 210k+、活発
- **学習コスト**: 低（Reactより簡素）

#### Next.js 15
- **最新バージョン**: 15.0.0
- **特徴**: React + SSR/SSG/ISR
- **セキュリティ**: 脆弱性なし
- **学習コスト**: 高（React + Next.js固有の概念）

### 比較表

| 項目 | React 19 | Vue 3 | Next.js 15 |
|-----|---------|-------|-----------|
| パフォーマンス | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| SEO | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| 学習コスト | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| エコシステム | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

### 参考資料
- [React 19 Release](https://react.dev/blog/2024/12/05/react-19)
- [Vue 3 Documentation](https://vuejs.org/)
- [Next.js 15 Documentation](https://nextjs.org/)

### 推奨
- **SEOが重要な場合**: Next.js 15
- **シンプルなSPAの場合**: React 19
- **学習コスト重視の場合**: Vue 3

### 決定（ユーザーとの合意後）
→ React 19 を採用
→ 理由: チームのReact習熟度が高い、SPAで十分、Server Componentsを試したい

### decisions.json への記録
```json
{
  "id": "dec-003",
  "title": "フロントエンドフレームワークの選定",
  "decision": "React 19",
  "rationale": "チームのReact習熟度が高い、SPAで十分、Server Componentsの新機能を活用",
  "alternatives": ["Vue 3", "Next.js 15"],
  "research_file": ".claude-state/research/technology-selection.md",
  "decided_at": "2025-10-03T14:00:00Z",
  "decided_by": "ユーザー + Claude",
  "phase": "requirements"
}
```
```

---

## 5. Claude（AI）の動作フロー

### 5.1 技術選定時
```
1. ユーザーの要件をヒアリング
2. 候補技術を3つ程度ピックアップ
3. 【調査実施】
   - WebSearchで最新情報を検索
   - WebFetchで公式ドキュメントを確認
   - セキュリティアドバイザリを確認
4. 調査結果を .claude-state/research/ に記録
5. ユーザーに比較表・推奨案を提示
6. ユーザーと合意
7. decisions.json に記録
```

### 5.2 コード生成前
```
1. 技術スタック確認（decisions.jsonから）
2. 【調査実施】
   - 最新バージョン確認
   - 非推奨API確認
   - セキュリティ脆弱性確認
3. ベストプラクティスを適用したコード生成
4. 生成コードにコメントで根拠記載
```

### 5.3 問題発生時
```
1. エラーメッセージ・問題を確認
2. 【調査実施】
   - WebSearchでエラーメッセージ検索
   - GitHub Issueで既知の問題確認
   - 公式ドキュメントで回避策確認
3. 解決策を提示
4. .claude-state/research/ に記録（再発防止）
```

---

## 6. 調査時の注意点

### 6.1 情報の信頼性
- ✅ 公式ドキュメント > 公式ブログ > 企業技術ブログ > 個人ブログ
- ❌ 古い情報（2年以上前）は避ける
- ❌ バージョン不明の情報は避ける

### 6.2 調査時間の制限
- 1つの調査項目：5〜10分以内
- 複数候補の比較：15分以内
- 深掘り調査（必要な場合）：30分以内

### 6.3 ユーザーへの報告
調査結果は必ずユーザーに報告：
```
【調査結果】React 19 のベストプラクティスを調査しました。

主な新機能:
- Server Components（安定版）
- use hook（非同期データ取得）

破壊的変更:
- useEffect依存配列の厳格化

→ これらを踏まえてコードを生成します。

詳細: .claude-state/research/framework-best-practices.md
```

---

## 7. まとめ

### 7.1 調査が必要なタイミング
| フェーズ | 調査対象 | 目的 |
|---------|---------|------|
| **要件定義** | 技術選定 | 最適な技術スタックの選定 |
| **基本設計** | アーキテクチャ、インフラ | 規模・要件に応じた設計 |
| **詳細設計** | ディレクトリ構造、命名規則 | フレームワーク固有のベストプラクティス |
| **実装** | 最新バージョン、新機能 | 最新のベストプラクティス適用 |
| **問題発生時** | エラー原因、回避策 | 問題解決 |

### 7.2 Claude（AI）の責務
1. 適切なタイミングで調査を実施
2. 信頼性の高い情報源を優先
3. 調査結果を記録（.claude-state/research/）
4. ユーザーに分かりやすく報告
5. 決定事項を decisions.json に記録

### 7.3 ユーザーへの価値
- 最新のベストプラクティスを適用したコード
- 根拠のある技術選定
- セキュリティリスクの低減
- 将来の保守性向上
