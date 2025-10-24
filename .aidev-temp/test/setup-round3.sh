#!/bin/bash
# 3周目テスト環境セットアップスクリプト

echo "============================================"
echo "3周目テスト環境セットアップ（最終評価）"
echo "============================================"
echo ""

# 現在のディレクトリ確認
if [[ ! -f "STATUS.md" ]]; then
    echo "❌ エラー: .aidev-temp/test/ ディレクトリで実行してください"
    exit 1
fi

echo "📋 前提条件チェック..."
echo ""

# 2周目レポート確認
if [[ ! -f "reports/round2-report.md" ]]; then
    echo "❌ エラー: reports/round2-report.md が見つかりません"
    echo "2周目テストは完了していますか？"
    exit 1
fi

# .claude/ の改善確認
echo ""
echo "⚠️  重要: 2周目で見つかった問題の改善は完了していますか？"
echo ""
read -p ".claude/ の改善が完了している場合は 'y' を入力: " improved
if [[ ! "$improved" =~ ^[Yy]$ ]]; then
    echo ""
    echo "まず .claude/ を改善してから、このスクリプトを再実行してください。"
    exit 0
fi

echo ""
echo "🚀 3周目環境を作成します（最終評価）..."
echo ""

# 3周目ディレクトリ作成
mkdir -p round3/{docs,src,tests,infra,scripts,.claude-state}

# 最終版 .claude をコピー
echo "📁 .claude/ をコピー中..."
cp -r ../../.claude round3/
cp ../../.gitignore round3/

# 企画書・要件定義書をコピー（1・2周目と同じ）
echo "📄 企画書・要件定義書をコピー中..."
cp round1/docs/01_企画書.md round3/docs/
cp round1/docs/02_要件定義書.md round3/docs/

# project-state.json 作成
echo "⚙️  project-state.json を作成中..."
cat > round3/.claude-state/project-state.json <<'EOF'
{
  "project": {
    "name": "AWS Multi-Account Sample Application",
    "type": "infrastructure",
    "phase": "design",
    "created_at": "2025-10-24T14:00:00Z",
    "updated_at": "2025-10-24T14:00:00Z"
  },
  "phases": {
    "planning": {
      "status": "completed",
      "started_at": "2025-10-24T13:00:00Z",
      "completed_at": "2025-10-24T13:30:00Z",
      "document": "docs/01_企画書.md"
    },
    "requirements": {
      "status": "completed",
      "started_at": "2025-10-24T13:30:00Z",
      "completed_at": "2025-10-24T14:00:00Z",
      "document": "docs/02_要件定義書.md"
    },
    "design": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "implementation": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "testing": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "deployment": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    }
  }
}
EOF

# README.md 作成
echo "📝 README.md を作成中..."
cat > round3/README.md <<'EOF'
# 3周目テスト環境（最終評価）

**作成日**: 2025-10-24
**目的**: 実用レベルに達しているか最終確認

---

## 📋 2周目からの改善点

[2周目レポートを参照して記入してください]

1. **[改善内容1]**
   - 対応ファイル:
   - 変更内容:

2. **[改善内容2]**
   - 対応ファイル:
   - 変更内容:

---

## 🚀 テスト開始方法

### ステップ1: VS Codeで開く
```bash
code .aidev-temp/test/round3
```

### ステップ2: Claude Codeで新しい会話を開始

### ステップ3: 以下をClaude Codeに指示（1・2周目と同じ）

```
設計フェーズから開始します。

docs/01_企画書.md と docs/02_要件定義書.md を読んで、AWS Multi-Account構成でのインフラ設計を行ってください。

技術要件:
- CloudFormation でインフラ構築
- Platform Account: 共通ネットワーク基盤（Transit Gateway, VPN）
- Service Account: 3サービス構成（Public Web, Admin Dashboard, Batch）
- ECS Fargate + RDS PostgreSQL + ALB

設計が完了したら、実装フェーズ、テストフェーズ、納品フェーズと順番に進めてください。
```

---

## ✅ 最終確認ポイント

### 1周目・2周目の問題がすべて解消されているか

- [ ] [1周目の問題1] が解消されたか
- [ ] [1周目の問題2] が解消されたか
- [ ] [2周目の問題1] が解消されたか

### 実用レベルに達しているか

#### 必須項目（すべて合格必要）
- [ ] デプロイスクリプトが自動生成される
- [ ] CloudFormation 3 principles 準拠
- [ ] 技術標準を正しく参照している

#### 推奨項目（80%以上）
- [ ] 代替案・トレードオフが提示される
- [ ] システム構成図が分かりやすい
- [ ] README.md が十分に詳細
- [ ] デプロイ手順書が実用的
- [ ] コード品質が高い

### 本番プロジェクトで使えるか

- [ ] 実用レベル判定: [本番使用可能 / 一部改善必要 / 改善必要]

---

## 📊 テスト完了後

```bash
./check-results.sh
```

レポート作成:
```bash
code ../reports/round3-report.md
```

最終レポート作成:
```bash
code ../reports/final-report.md
```
EOF

# check-results.sh をコピー
echo "🔧 check-results.sh をコピー中..."
cp round1/check-results.sh round3/
chmod +x round3/check-results.sh

echo ""
echo "✅ 3周目環境セットアップ完了！"
echo ""
echo "次のステップ:"
echo "1. VS Codeで開く: code .aidev-temp/test/round3"
echo "2. Claude Codeで新しい会話を開始"
echo "3. round3/README.md の指示に従ってテスト実行"
echo "4. 最終レポートを作成"
echo ""
echo "============================================"
