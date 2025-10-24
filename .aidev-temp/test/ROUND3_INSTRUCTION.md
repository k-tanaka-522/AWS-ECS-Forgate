# Round 3 テスト実施指示書

**目的**: Round 2 で残った課題（Change Set 対応）を改善し、最終検証を行う

**作成日**: 2025-10-24
**実施予定**: 別セッション

---

## 📋 前提条件

### Round 2 の達成状況

✅ **完了済み**:
1. 基本設計書 13/13章（100%完成）
2. CloudFormation コアテンプレート生成
3. 段階的設計書生成プロセス（2.3.14）実装
4. フェーズ完了基準厳格化（2.3.11）

⚠️ **未達成**（Round 3 で改善）:
1. Change Set を使った段階的デプロイスクリプト
2. テストフェーズの詳細実施
3. ロールバック手順の詳細化

---

## 🎯 Round 3 の目標

### 最優先目標（⭐⭐⭐）

**Change Set による段階的デプロイの完全実装**

現状の問題:
```bash
# Round 2 では直接デプロイ
aws cloudformation deploy --template-file xxx.yaml ...
```

Round 3 で生成すべき:
```bash
# 1. Change Set 作成
scripts/create-changeset.sh

# 2. Change Set 内容確認（dry-run）
scripts/describe-changeset.sh

# 3. ユーザー確認後に実行
scripts/execute-changeset.sh

# 4. ロールバック
scripts/rollback.sh
```

---

## 🚀 実施手順

### Step 1: 環境準備

```bash
# aiDev リポジトリ更新
cd /c/dev2/aiDev
git pull origin main

# sampleAWS リポジトリ更新
cd /c/dev2/sampleAWS
git pull origin main

# 最新のコミット確認
git log --oneline -5
# e91c846 - feat: Complete Round 2 testing (最新)
```

---

### Step 2: 新しいセッションで Round 3 開始

**新しい Claude Code セッションを開く**

---

### Step 3: Claude への指示（コピペ推奨）

```
設計フェーズから開始します。

docs/01_企画書.md と docs/02_要件定義書.md を読んで、AWS Multi-Account構成でのインフラ設計を行ってください。

技術要件:
- CloudFormation でインフラ構築
- Platform Account: 共通ネットワーク基盤（Transit Gateway, VPN）
- Service Account: 3サービス構成（Public Web, Admin Dashboard, Batch）
- ECS Fargate + RDS PostgreSQL + ALB

**重要: デプロイスクリプトは必ず Change Set を使った段階的デプロイ方式で生成してください。**

生成すべきスクリプト:
1. scripts/create-changeset.sh - Change Set作成
2. scripts/describe-changeset.sh - Change Set内容確認
3. scripts/execute-changeset.sh - Change Set実行
4. scripts/rollback.sh - ロールバック

設計が完了したら、実装フェーズ、テストフェーズ、納品フェーズと順番に進めてください。
```

---

## 🔍 観察ポイント（重要）

### 最重要確認項目 ⭐⭐⭐

#### 1. Change Set スクリプトの生成

**確認方法**:
```bash
ls -la scripts/
```

**期待されるファイル**:
- [ ] `scripts/create-changeset.sh`
- [ ] `scripts/describe-changeset.sh`
- [ ] `scripts/execute-changeset.sh`
- [ ] `scripts/rollback.sh`

**スクリプト内容の確認**:
```bash
# create-changeset.sh に期待される内容
aws cloudformation create-change-set \
  --stack-name xxx \
  --change-set-name xxx \
  --template-body file://xxx.yaml \
  ...

# describe-changeset.sh に期待される内容
aws cloudformation describe-change-set \
  --stack-name xxx \
  --change-set-name xxx

# execute-changeset.sh に期待される内容
# ユーザー確認プロンプト
read -p "Execute change set? (yes/no): " confirm
if [ "$confirm" = "yes" ]; then
  aws cloudformation execute-change-set ...
fi

# rollback.sh に期待される内容
aws cloudformation cancel-update-stack ... または
aws cloudformation delete-change-set ...
```

---

#### 2. 基本設計書の完全生成（継続確認）

**確認方法**:
```bash
ls -la docs/03_基本設計書/
wc -l docs/03_基本設計書/*.md
```

**期待される結果**:
- [ ] README.md + 13章すべて存在
- [ ] 各章が実質的な内容を含む（100行以上推奨）
- [ ] Mermaid図 5個以上（03_システム構成図.md）
- [ ] 代替案・トレードオフ 3箇所以上（02_アーキテクチャ設計.md）

---

#### 3. CloudFormation 3 Principles 準拠

**確認方法**: 生成されたテンプレートとスクリプトを確認

**チェック項目**:
- [ ] **責任分離原則**: スタック分割（platform-network, platform-tgw, service-network, etc.）
- [ ] **テンプレート分割原則**: 各スタックが単一責務
- [ ] **段階的デプロイ原則**: Change Set 使用 ← **Round 3 の焦点**

**参照**: `.claude/docs/40_standards/45_cloudformation.md`

---

#### 4. テストフェーズの実施内容

**確認方法**: 会話ログ、`tests/` ディレクトリ

**期待されるテスト**:
- [ ] 単体テスト（pytest）
- [ ] 統合テスト（API エンドポイント）
- [ ] E2Eテスト（Selenium/Playwright）
- [ ] 性能テスト（Locust/JMeter）
- [ ] セキュリティテスト（OWASP ZAP/pip-audit）

---

#### 5. デプロイ手順書の内容

**確認方法**: `docs/デプロイ手順書.md` または `README.md`

**期待される内容**:
```markdown
## デプロイ手順

### 1. Change Set 作成（dry-run）
```bash
./scripts/create-changeset.sh
```

### 2. Change Set 内容確認
```bash
./scripts/describe-changeset.sh
```

### 3. Change Set 実行（本番反映）
```bash
./scripts/execute-changeset.sh
```

### 4. ロールバック（問題発生時）
```bash
./scripts/rollback.sh
```
```

---

## 📝 記録すべき内容

### 成功事例

**Change Set 対応**:
- [ ] create-changeset.sh が自動生成された
- [ ] describe-changeset.sh が自動生成された
- [ ] execute-changeset.sh が自動生成された
- [ ] rollback.sh が自動生成された
- [ ] スクリプトの内容が実用的（エラーハンドリング、ユーザー確認含む）
- [ ] デプロイ手順書に Change Set 手順が含まれる

**基本設計書**（Round 2 から継続）:
- [ ] 13/13章完全生成
- [ ] 必須要素含有（代替案、Mermaid図、技術標準参照）

**テストフェーズ**:
- [ ] 統合テスト実施
- [ ] E2Eテスト実施
- [ ] 性能テスト実施
- [ ] セキュリティテスト実施

---

### 問題点

**Change Set 対応**:
- [ ] スクリプトが生成されなかった（どれが？）
- [ ] スクリプトは生成されたが内容が不十分（具体的に？）
- [ ] デプロイ手順書に Change Set 手順がない

**基本設計書**:
- [ ] 特定の章がスキップされた（どの章？）
- [ ] 必須要素が欠如（何が？）

**テストフェーズ**:
- [ ] 特定のテストが実施されなかった（どれが？）
- [ ] テストコードが生成されなかった

**その他**:
- [ ] （具体的な問題点）

---

### 所要時間

**測定方法**: 会話の開始時刻と終了時刻を記録

- 設計フェーズ: ___分
- 実装フェーズ: ___分
- テストフェーズ: ___分
- 納品フェーズ: ___分
- **合計**: ___時間___分

**参考（Round 1, 2）**:
- Round 1: 約1.5時間
- Round 2: 約1時間（基本設計書のみ）

---

## 📊 評価基準

### Change Set 対応評価

| 項目 | 配点 | 評価基準 | 達成状況 |
|------|------|----------|---------|
| create-changeset.sh 生成 | 10点 | 生成され、実用的な内容 | ☐ |
| describe-changeset.sh 生成 | 10点 | Change Set 内容を表示 | ☐ |
| execute-changeset.sh 生成 | 10点 | ユーザー確認後に実行 | ☐ |
| rollback.sh 生成 | 10点 | ロールバック機能 | ☐ |
| デプロイ手順書 | 10点 | Change Set 手順記載 | ☐ |
| **合計** | **50点** | 40点以上で合格 | **___点** |

---

### 総合評価（Round 2 からの継続項目含む）

| 項目 | 配点 | Round 2 | Round 3 目標 | Round 3 達成 |
|------|------|---------|--------------|-------------|
| 基本設計書生成 | 10点 | 10/10 | 10/10 | ___/10 |
| CloudFormation実装 | 10点 | 9/10 | 10/10 | ___/10 |
| Change Set対応 | 10点 | 0/10 | **8-10/10** | ___/10 |
| デプロイスクリプト | 10点 | 8/10 | **10/10** | ___/10 |
| ドキュメント品質 | 10点 | 9/10 | 9-10/10 | ___/10 |
| テストフェーズ実施 | 10点 | ?/10 | 8-10/10 | ___/10 |
| **総合** | **60点** | 36-46/60 (60-77%) | **52-60/60 (87-100%)** | **___/60 (___%)** |

---

## 🎯 Round 3 成功の定義

### 必須条件（すべて満たす必要あり）

1. ✅ Change Set スクリプト **4つすべて** 生成
2. ✅ スクリプトが **実用的**（dry-run → 確認 → 実行 の流れ）
3. ✅ 基本設計書 **13章完全生成**（Round 2 の継続）

---

### 推奨条件（8割以上達成）

1. デプロイ手順書に Change Set 手順記載
2. テストフェーズが充実（統合、E2E、性能、セキュリティ）
3. ロールバック手順が詳細
4. エラーハンドリング実装（スクリプト内）
5. ログ出力実装（デプロイの追跡可能性）

---

### 実用レベル判定

- **54-60点（90-100%）**: 本番プロジェクトで即使用可能 🎉
- **51-53点（85-89%）**: 軽微な調整で本番使用可能 ✅
- **48-50点（80-84%）**: 一部改善必要 ⚠️
- **48点未満（80%未満）**: 追加改善必要 ❌

---

## 📈 期待される結果

Round 3 で Change Set 対応が完了すれば:

1. ✅ **本番環境への安全なデプロイ** が可能
   - 事前に変更内容を確認（dry-run）
   - ユーザー承認後に実行

2. ✅ **ロールバック** が容易
   - 問題発生時に即座に復旧

3. ✅ **受託開発納品レベル** の品質に到達
   - IPA共通フレーム準拠
   - AWS Well-Architected Framework 準拠

→ **aidev が実用レベルに到達** 🚀

---

## 🔄 Round 3 実施後の流れ

### 1. 結果の記録

**作成するファイル**:
```bash
.aidev-temp/test/round3/ROUND3_REPORT.md
```

**記載内容**:
- 成功事例と問題点
- スクリーンショット（生成されたスクリプト）
- 所要時間
- 評価スコア

---

### 2. aidev への反映

**問題点があれば改善**:
```bash
# Change Set 生成プロセスの追加
.claude/docs/10_facilitation/2.4_実装フェーズ/2.4.6_IaC構築プロセス/2.4.6.1_CloudFormation構築/2.4.6.1.4_Change_Sets運用フロー.md

# テストフェーズガイドの強化
.claude/docs/10_facilitation/2.5_テストフェーズ/PHASE_GUIDE.md
```

---

### 3. 最終判断

**評価基準**:
- **54点以上（90%以上）**: ✅ aidev 完成、Bedrock Multi-Agent 化は不要
- **51-53点（85-89%）**: ✅ aidev 完成、軽微な調整のみ
- **48-50点（80-84%）**: ⚠️ 一部改善後に再評価
- **48点未満（80%未満）**: ❌ 追加改善または Bedrock Multi-Agent 化を検討

---

## 📌 その他の注意事項

### Claude との対話のコツ

**自然な会話**:
```
❌ 悪い例: "CloudFormation テンプレートを生成せよ"
✅ 良い例: "CloudFormation でインフラを構築したいです。設計から始めてください。"
```

**明示的な要求**（重要な場合）:
```
"デプロイスクリプトは必ず Change Set を使った段階的デプロイ方式で生成してください。"
```

**進捗確認**:
```
"現在のフェーズと進捗を教えてください。"
```

---

### トラブルシューティング

#### Change Set スクリプトが生成されない

**対処法**:
```
「Change Set を使ったデプロイスクリプトを生成してください。

必要なスクリプト:
1. create-changeset.sh
2. describe-changeset.sh
3. execute-changeset.sh
4. rollback.sh」
```

---

#### 基本設計書が途中で止まる

**対処法**:
```
「残りの章（XX章から13章まで）も生成してください。」
```

---

#### テストフェーズが簡素

**対処法**:
```
「テストフェーズを詳細に実施してください。

必要なテスト:
- 統合テスト（API エンドポイント）
- E2Eテスト（Selenium）
- 性能テスト（Locust）
- セキュリティテスト（OWASP ZAP）」
```

---

## 📚 参考ドキュメント

### aidev 内部ドキュメント

**CloudFormation 標準**:
```
.claude/docs/40_standards/45_cloudformation.md
```
- CloudFormation 3 Principles
- Change Sets 運用フロー
- dry-run 必須手順

**実装フェーズガイド**:
```
.claude/docs/10_facilitation/2.4_実装フェーズ/PHASE_GUIDE.md
```

**テストフェーズガイド**:
```
.claude/docs/10_facilitation/2.5_テストフェーズ/PHASE_GUIDE.md
```

---

### Round 1, 2 のレポート

**Round 1**:
```
.aidev-temp/test/round1/ROUND1_SUMMARY.md
```

**Round 2**:
```
.aidev-temp/test/round2/ROUND2_REPORT.md
.aidev-temp/test/IMPROVEMENT_ANALYSIS.md
```

---

## 🎉 Round 3 成功を祈っています！

**作成日**: 2025-10-24
**作成者**: Claude（AI開発ファシリテーター）
**Git コミット**: e91c846 (Round 2 完了)
**Git ブランチ**: main
**Git リポジトリ**: https://github.com/k-tanaka-522/AWS-ECS-Forgate.git

---

**Round 3、頑張ってください！Change Set 対応の完全実装を期待しています！** 🚀
