# 1周目テスト詳細計画

**実施日**: 2025-10-24
**目的**: 初見実行で問題点を洗い出す

---

## 🎯 この周の目的

1. **現状の aidev で何ができるか確認**
2. **問題点を洗い出す**
3. **技術標準の不足を特定する**
4. **PHASE_GUIDE.md の改善点を特定する**

---

## 📋 準備

### 環境セットアップ

```bash
cd /c/dev2/aiDev/test/round1

# aidev コピー
cp -r ../../.claude .
cp ../../CLAUDE.md .
cp ../../.gitignore .

# 企画書・要件定義書を配置
# GitHub からクローン
git clone https://github.com/k-tanaka-522/AWS-ECS-Forgate.git temp
mkdir -p docs
cp temp/docs/01_企画書.md docs/ 2>/dev/null || echo "企画書がないので後で作成"
cp temp/docs/02_要件定義書.md docs/ 2>/dev/null || echo "要件定義書がないので後で作成"
rm -rf temp

# .claude-state を初期化（設計フェーズから開始）
mkdir -p .claude-state
cat > .claude-state/project-state.json <<EOF
{
  "projectName": "AWS-ECS-Forgate",
  "currentPhase": "design",
  "status": "ongoing",
  "updatedAt": "$(date -Iseconds)"
}
EOF
```

---

## 🚀 実行手順

### フェーズ1: 設計フェーズ

**Claude への指示**:
> 「設計フェーズから開始します。
>
> AWS ECS Fargate でコンテナアプリケーションをデプロイするシステムの基本設計を行ってください。
>
> 要件:
> - FastAPI バックエンド（Python）
> - PostgreSQL データベース（RDS）
> - ALB + ECS Fargate
> - CloudFormation でインフラ構築」

**期待される動作**:
1. PHASE_GUIDE.md（設計フェーズ）を読み込む
2. 技術選定を行う
3. 代替案・トレードオフを提示する
4. システム構成図（Mermaid）を生成する
5. 基本設計書を生成する

**検証項目**:
- [ ] PHASE_GUIDE.md を読み込んだか
- [ ] 技術選定の理由が明確か
- [ ] 代替案・トレードオフがあるか
- [ ] システム構成図があるか
- [ ] CloudFormation 3 principles に言及したか

### フェーズ2: 実装フェーズ

**期待される動作**:
1. PHASE_GUIDE.md（実装フェーズ）を読み込む
2. 技術標準（41_python.md, 45_cloudformation.md）を参照する
3. 事前説明 → 生成 → 事後説明の原則を守る
4. FastAPI コードを生成する
5. テストコードを生成する
6. CloudFormation テンプレートを生成する
7. **デプロイスクリプトを生成する** ⭐重要

**検証項目**:
- [ ] 技術標準を参照したか
- [ ] 事前説明があったか
- [ ] コードが生成されたか
- [ ] テストコードが生成されたか
- [ ] CloudFormation テンプレートが生成されたか
- [ ] デプロイスクリプトが生成されたか

### フェーズ3: テストフェーズ

**期待される動作**:
1. PHASE_GUIDE.md（テストフェーズ）を読み込む
2. テスト計画を提示する
3. テストを実行する
4. カバレッジを確認する

**検証項目**:
- [ ] テスト計画があったか
- [ ] テストが実行されたか
- [ ] カバレッジが表示されたか

### フェーズ4: 納品フェーズ

**期待される動作**:
1. PHASE_GUIDE.md（納品フェーズ）を読み込む
2. README.md を生成する
3. デプロイ手順書を生成する（dry-run含む）
4. 運用手順書を生成する（必要に応じて）

**検証項目**:
- [ ] README.md が生成されたか
- [ ] デプロイ手順書が生成されたか
- [ ] dry-run が含まれているか

---

## 🔍 レビュー観点

### システムアーキテクト視点

**設計フェーズ**:
- 技術選定は妥当か
- 代替案は適切か
- トレードオフは明確か
- スケーラビリティは考慮されているか

**実装フェーズ**:
- CloudFormation 3 principles に準拠しているか
- ネットワーク設計は適切か
- セキュリティは考慮されているか

### CTO視点

**技術標準の完全性**:
- デプロイスクリプト生成の指示は十分か
- FastAPI のベストプラクティスは含まれているか
- Docker 標準は必要か
- GitHub Actions 標準は必要か

**PHASE_GUIDE.md の実用性**:
- 指示は明確か
- 実際に機能したか
- 改善点はどこか

---

## 📊 予想される問題点

### 仮説1: デプロイスクリプトが生成されない

**理由**:
- CloudFormation 標準にデプロイスクリプト生成の指示がない可能性
- PHASE_GUIDE.md（実装フェーズ）にデプロイスクリプトの記載が不足

**改善案**:
- `45_cloudformation.md` にデプロイスクリプト生成を明記
- `2.4.6.1.7_デプロイ自動化設計.md` を強化

### 仮説2: FastAPI コードの品質が低い

**理由**:
- `41_python.md` に FastAPI 特有のベストプラクティスがない

**改善案**:
- `41_python.md` に FastAPI セクションを追加

### 仮説3: Docker 関連の成果物がない

**理由**:
- Docker 標準がない

**改善案**:
- `47_docker.md` を新規作成

---

**作成日**: 2025-10-24
