# aidev Claude Code 改修指示書

## 改修目的

Notion ワークスペースとの連携により、**.claude/ をコア部分に集約** し、詳細な規約はすべて Notion から参照するように変更する。

これにより、`.claude/` は軽量化・保守性向上、かつ「生きた規約」が Notion で管理可能になります。

---

## 現状（ビフォー）

```
.claude/docs/
├─ 00_core-principles.md
│   └─ 行動原則など（内容不明）
├─ 10_facilitation/
│   ├─ 11_decision-items.md（フェーズ別決定項目）
│   ├─ 12_phase-transition.md（フェーズ遷移ルール）
│   └─ 13_context-management.md（状態管理）
├─ 40_standards/
│   ├─ 41_common.md（コーディング規約详细）
│   └─ 42_infrastructure.md（インフラ規約详细）
└─ README.md など
```

**問題点：**
- `.claude/` に詳細な規約が入ってる（重い）
- ファイルサイズが大きい
- 規約更新時に `.claude/` を編集（管理が分散）

---

## 改修後（アフター）

```
.claude/docs/
├─ 00_core-principles.md（PM フレームワークのみ）
├─ 10_facilitation/
│   ├─ 11_planning_phase.md（企画フェーズの手順のみ）
│   ├─ 12_requirements_phase.md（要件定義フェーズの手順のみ）
│   ├─ 13_design_phase.md（設計フェーズの手順のみ）
│   ├─ 14_implementation_phase.md（実装フェーズの手順のみ）
│   ├─ 15_testing_phase.md（テストフェーズの手順のみ）
│   ├─ 16_delivery_phase.md（納品フェーズの手順のみ）
│   └─ 【新規】各ファイルに「Notion 参照」セクション追加
├─ 【新規】NOTION_INDEX.md（Notion リンク集）
└─ 40_standards/
    ├─ 41_common.md（削除 or 最小化）
    └─ 42_infrastructure.md（削除 or 最小化）
```

**改善点：**
- `.claude/` は「フェーズ進行ロジック」のみ（軽い）
- 詳細規約はすべて Notion（集約管理）
- 規約更新が簡単（Notion だけ）
- Notion が「生きた規約」として進化可能

---

## 具体的な改修内容

### 1. `.claude/CLAUDE.md`（メインプロンプト）

#### ビフォー
```markdown
【不明】
現在のプロンプトは確認不可
```

#### アフター
```markdown
# aidev: AI 開発ファシリテーター

## あなたの役割

Claude Code 上で動作する AI ファシリテーターとして、PM フレームワークに基づいてシステム開発をガイドします。

- ユーザーとの対話で要件をヒアリング
- プロジェクトのフェーズを追跡
- 各フェーズの決定項目をチェック
- 技術標準は Notion を参照するよう指示
- 成果物を自動生成

## フェーズ管理

### 開発プロセス

1. 企画フェーズ → `.claude/docs/10_facilitation/11_planning_phase.md`
2. 要件定義フェーズ → `.claude/docs/10_facilitation/12_requirements_phase.md`
3. 設計フェーズ → `.claude/docs/10_facilitation/13_design_phase.md`
4. 実装フェーズ → `.claude/docs/10_facilitation/14_implementation_phase.md`
5. テストフェーズ → `.claude/docs/10_facilitation/15_testing_phase.md`
6. 納品フェーズ → `.claude/docs/10_facilitation/16_delivery_phase.md`

### 状態管理

```json
{
  "projectName": "プロジェクト名",
  "currentPhase": "planning | requirements | design | implementation | testing | delivery",
  "status": "ongoing | blocked | completed",
  "updatedAt": "ISO 8601"
}
```

## Notion 連携

詳細な技術規約は Notion ワークスペースで管理：
https://pacific-packet-4aa.notion.site/28f3b027c0d18191abddc81d578ecd68

リンク一覧は → `.claude/docs/NOTION_INDEX.md` を確認

実装時・設計時に「以下を参照してください」と指示。
```

---

### 2. 各フェーズドキュメント（例：14_implementation_phase.md）

#### ビフォー
```markdown
【内容不明】
現在の実装フェーズドキュメントは確認不可
```

#### アフター
```markdown
# 実装フェーズ

## フェーズの目的

要件・設計に基づいて、実装コード・IaC を生成する。

---

## 実施流れ（3ステップ）

### Step 1: 技術スタック確認

ユーザーに確認：
- 使用言語？（Python/TypeScript/Go など）
- フレームワーク？（Django/Express など）
- インフラ？（AWS/GCP など）

### Step 2: Notion 規約参照

【重要】以下を参照してから実装してください：

```
1. .claude/docs/NOTION_INDEX.md を開く

2. 対応する技術を検索
   例：「Python Coding Standards」
   
3. Notion のリンクをブラウザで開く
   例：https://pacific-packet-4aa.notion.site/Python-Coding-Standards-xxxxx

4. ページ内の以下を確認：
   - コーディング規約
   - ✅ Good Example
   - ❌ Bad Example
   - 反パターン注意点

5. 確認内容に基づいて実装
```

### Step 3: 実装 + テスト

- ディレクトリ構成は Notion テンプレートに従う
- コード規約は Notion に従う
- ユニットテストも同時に作成

---

## 決定項目チェックリスト

このフェーズを完了する前に以下を確認：

- [ ] 使用言語確定
- [ ] フレームワーク確定
- [ ] インフラ構成確定
- [ ] 実装チーム（人数・スケジュール）確定
- [ ] Notion 規約を確認済み

---

## 成果物

実装フェーズ完了時に以下が揃う：

```
src/
├─ api/              # API エンドポイント
├─ services/        # ビジネスロジック
├─ models/          # データモデル
└─ utils/           # ユーティリティ

infrastructure/
├─ cloudformation.yml   # IaC
└─ terraform/           # または Terraform

tests/
├─ unit/            # ユニットテスト
└─ integration/     # 統合テスト

docs/
├─ API_仕様.md      # OpenAPI 形式
└─ 実装ガイド.md
```

---

## 次フェーズ移行条件

以下がすべて達成されたら、テストフェーズへ：

✅ 全要件をコードで実装済み
✅ ユニットテスト作成・パス済み
✅ コード品質基準（Notion 規約）達成
✅ コードレビュー完了

---

## トラブル時

**「Notion ページが見えない」場合**
- ブラウザで直接アクセス可能か確認
- URL が正しいか確認（.claude/docs/NOTION_INDEX.md で確認）

**「どの規約を見るべき？」場合**
- 使用言語から該当ページを .claude/docs/NOTION_INDEX.md で検索
- 不明な場合はユーザーに聞く

---

## 補足

このフェーズドキュメントは「何をすべきか」の手順のみ。
詳細な「どうやるか」は Notion で管理。

Notion が更新されたら、自動的に最新ルールが反映される。
```

---

### 3. `.claude/docs/NOTION_INDEX.md`（新規作成）

```markdown
# Notion 技術標準・パターン集

**Notion ワークスペース：**
https://pacific-packet-4aa.notion.site/28f3b027c0d18191abddc81d578ecd68

実装・設計時に該当するページを参照してください。

---

## 企画フェーズ

▶ Business Goal Template
https://pacific-packet-4aa.notion.site/Business-Goal-xxxxx

▶ Stakeholder Analysis Template
https://pacific-packet-4aa.notion.site/Stakeholder-Analysis-xxxxx

---

## 要件定義フェーズ

▶ Functional Requirements Template
https://pacific-packet-4aa.notion.site/Functional-Requirements-xxxxx

▶ Non-Functional Requirements Template
https://pacific-packet-4aa.notion.site/Non-Functional-Requirements-xxxxx

---

## 設計フェーズ

### アーキテクチャパターン

▶ Serverless Pattern
https://pacific-packet-4aa.notion.site/Serverless-Pattern-xxxxx

▶ Microservices Pattern
https://pacific-packet-4aa.notion.site/Microservices-Pattern-xxxxx

▶ Monolith Pattern
https://pacific-packet-4aa.notion.site/Monolith-Pattern-xxxxx

### Infrastructure as Code

▶ CloudFormation Patterns
https://pacific-packet-4aa.notion.site/CloudFormation-Patterns-xxxxx

▶ Terraform Patterns
https://pacific-packet-4aa.notion.site/Terraform-Patterns-xxxxx

### API Design

▶ REST API Standards
https://pacific-packet-4aa.notion.site/REST-API-Standards-xxxxx

▶ GraphQL Standards
https://pacific-packet-4aa.notion.site/GraphQL-Standards-xxxxx

---

## 実装フェーズ

### コーディング規約

▶ **Python Coding Standards**
https://pacific-packet-4aa.notion.site/Python-Coding-Standards-xxxxx

**内容：** 規約 + ✅ Good Example + ❌ Bad Example + 反パターン

▶ **TypeScript Coding Standards**
https://pacific-packet-4aa.notion.site/TypeScript-Coding-Standards-xxxxx

**内容：** 規約 + ✅ Good Example + ❌ Bad Example + 反パターン

▶ **Go Coding Standards**
https://pacific-packet-4aa.notion.site/Go-Coding-Standards-xxxxx

**内容：** 規約 + ✅ Good Example + ❌ Bad Example + 反パターン

### Code Templates

▶ API Endpoint Template
https://pacific-packet-4aa.notion.site/API-Endpoint-Template-xxxxx

▶ Service Layer Template
https://pacific-packet-4aa.notion.site/Service-Layer-Template-xxxxx

▶ Error Handling Pattern
https://pacific-packet-4aa.notion.site/Error-Handling-Pattern-xxxxx

---

## テストフェーズ

▶ Unit Test Patterns
https://pacific-packet-4aa.notion.site/Unit-Test-Patterns-xxxxx

▶ Integration Test Patterns
https://pacific-packet-4aa.notion.site/Integration-Test-Patterns-xxxxx

▶ Test Case Template
https://pacific-packet-4aa.notion.site/Test-Case-Template-xxxxx

---

## 納品フェーズ

▶ Delivery Checklist
https://pacific-packet-4aa.notion.site/Delivery-Checklist-xxxxx

▶ Documentation Template
https://pacific-packet-4aa.notion.site/Documentation-Template-xxxxx

▶ Release Notes Template
https://pacific-packet-4aa.notion.site/Release-Notes-Template-xxxxx

---

## 使い方

1. 現在のフェーズを確認
2. 上記のリンクから対応ページを開く
3. ページ内の規約・サンプル・反パターンを確認
4. 実装に反映

**Notion が更新されたら、自動的に最新ルールが適用されます。**
```

---

## 改修手順（概要）

| 項目 | 対象ファイル | 変更内容 |
|------|-----------|--------|
| メインプロンプト | `.claude/CLAUDE.md` | 上記「アフター」に置き換え |
| 企画フェーズ | `.claude/docs/10_facilitation/11_planning_phase.md` | 「Notion 参照」セクション追加 |
| 要件定義フェーズ | `.claude/docs/10_facilitation/12_requirements_phase.md` | 「Notion 参照」セクション追加 |
| 設計フェーズ | `.claude/docs/10_facilitation/13_design_phase.md` | 「Notion 参照」セクション追加 |
| 実装フェーズ | `.claude/docs/10_facilitation/14_implementation_phase.md` | 上記「アフター」に置き換え（最も変更多い） |
| テストフェーズ | `.claude/docs/10_facilitation/15_testing_phase.md` | 「Notion 参照」セクション追加 |
| 納品フェーズ | `.claude/docs/10_facilitation/16_delivery_phase.md` | 「Notion 参照」セクション追加 |
| 【新規作成】 | `.claude/docs/NOTION_INDEX.md` | 上記全文を新規作成 |
| 削除検討 | `.claude/docs/40_standards/41_common.md` | 詳細規約は Notion に移行済み → 削除 or 最小化 |
| 削除検討 | `.claude/docs/40_standards/42_infrastructure.md` | 詳細規約は Notion に移行済み → 削除 or 最小化 |

---

## 改修完了チェック

- [ ] `.claude/CLAUDE.md` 更新完了
- [ ] `11_planning_phase.md` に「Notion 参照」追加
- [ ] `12_requirements_phase.md` に「Notion 参照」追加
- [ ] `13_design_phase.md` に「Notion 参照」追加
- [ ] `14_implementation_phase.md` 置き換え完了
- [ ] `15_testing_phase.md` に「Notion 参照」追加
- [ ] `16_delivery_phase.md` に「Notion 参照」追加
- [ ] `NOTION_INDEX.md` 新規作成完了
- [ ] `40_standards/` ファイル削除 or 最小化完了
- [ ] Claude Code で動作確認済み

---

## 改修後の効果

✅ `.claude/` がシンプル（PM フレームワークのみ）
✅ 詳細規約は Notion で一元管理
✅ Notion 更新が自動的に次のプロジェクトに反映（生きた規約）
✅ ファイルサイズ削減 → Claude Code の処理も軽い
✅ 保守性向上