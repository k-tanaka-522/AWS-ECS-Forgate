#!/bin/bash
# 2周目テスト環境セットアップスクリプト

echo "============================================"
echo "2周目テスト環境セットアップ"
echo "============================================"
echo ""

# 現在のディレクトリ確認
if [[ ! -f "STATUS.md" ]]; then
    echo "❌ エラー: .aidev-temp/test/ ディレクトリで実行してください"
    exit 1
fi

echo "📋 前提条件チェック..."
echo ""

# 1周目レポート確認
if [[ ! -f "reports/round1-report.md" ]]; then
    echo "⚠️  警告: reports/round1-report.md が見つかりません"
    echo "1周目テストは完了していますか？"
    read -p "続行しますか？ (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "中止しました"
        exit 0
    fi
fi

# .claude/ の改善確認
echo ""
echo "⚠️  重要: .claude/ の改善は完了していますか？"
echo ""
echo "1周目で見つかった問題を以下のファイルに反映してください:"
echo "  - .claude/docs/40_standards/45_cloudformation.md"
echo "  - .claude/docs/10_facilitation/2.4_実装フェーズ/"
echo ""
read -p ".claude/ の改善が完了している場合は 'y' を入力: " improved
if [[ ! "$improved" =~ ^[Yy]$ ]]; then
    echo ""
    echo "まず .claude/ を改善してから、このスクリプトを再実行してください。"
    exit 0
fi

echo ""
echo "🚀 2周目環境を作成します..."
echo ""

# 2周目ディレクトリ作成
mkdir -p round2/{docs,src,tests,infra,scripts,.claude-state}

# 改善版 .claude をコピー
echo "📁 .claude/ をコピー中..."
cp -r ../../.claude round2/
cp ../../.gitignore round2/

# 企画書・要件定義書をコピー（1周目と同じ）
echo "📄 企画書・要件定義書をコピー中..."
cp round1/docs/01_企画書.md round2/docs/
cp round1/docs/02_要件定義書.md round2/docs/

# project-state.json 作成
echo "⚙️  project-state.json を作成中..."
cat > round2/.claude-state/project-state.json <<'EOF'
{
  "project": {
    "name": "AWS Multi-Account Sample Application",
    "type": "infrastructure",
    "phase": "design",
    "created_at": "2025-10-24T12:00:00Z",
    "updated_at": "2025-10-24T12:00:00Z"
  },
  "phases": {
    "planning": {
      "status": "completed",
      "started_at": "2025-10-24T11:00:00Z",
      "completed_at": "2025-10-24T11:30:00Z",
      "document": "docs/01_企画書.md"
    },
    "requirements": {
      "status": "completed",
      "started_at": "2025-10-24T11:30:00Z",
      "completed_at": "2025-10-24T12:00:00Z",
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
cat > round2/README.md <<'EOF'
# 2周目テスト環境

**作成日**: 2025-10-24
**目的**: 1周目の改善を反映して再テスト

---

## 📋 1周目からの改善点

[1周目レポートを参照して記入してください]

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
code .aidev-temp/test/round2
```

### ステップ2: Claude Codeで新しい会話を開始

### ステップ3: 以下をClaude Codeに指示（1周目と同じ）

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

## ✅ 確認ポイント

### 1周目の問題が解消されているか

- [ ] [1周目の問題1] が解消されたか
- [ ] [1周目の問題2] が解消されたか

### 新しい問題がないか

- [ ] 新しい問題が発生していないか

---

## 📊 テスト完了後

```bash
./check-results.sh
```

レポート作成:
```bash
code ../reports/round2-report.md
```
EOF

# check-results.sh をコピー
echo "🔧 check-results.sh をコピー中..."
cp round1/check-results.sh round2/
chmod +x round2/check-results.sh

echo ""
echo "✅ 2周目環境セットアップ完了！"
echo ""
echo "次のステップ:"
echo "1. VS Codeで開く: code .aidev-temp/test/round2"
echo "2. Claude Codeで新しい会話を開始"
echo "3. round2/README.md の指示に従ってテスト実行"
echo ""
echo "============================================"
