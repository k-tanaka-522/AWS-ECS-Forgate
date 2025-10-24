# 基本設計書

> AWS Multi-Account Sample Application
> Transit Gateway による拠点間閉域接続を実現する技術検証・社内デモ用サンプル

**作成日**: 2025-10-24 (Round 3)
**バージョン**: 3.0
**ステータス**: 設計中

---

## 📋 目次

### [00_概要.md](./00_概要.md)
- システム概要
- システム構成の全体像
- アーキテクチャ方針

### [01_制約事項・前提条件.md](./01_制約事項・前提条件.md)
- 技術的制約
- ビジネス的制約
- 前提条件

### [02_アーキテクチャ設計.md](./02_アーキテクチャ設計.md) ⭐
- Multi-Account 構成設計
- Transit Gateway 設計
- **代替案・トレードオフ分析** (3箇所以上)

### [03_システム構成図.md](./03_システム構成図.md) ⭐
- **Mermaid 図** (5個以上)
- ネットワーク構成図
- サービス間連携図

### [04_データベース設計.md](./04_データベース設計.md)
- RDS PostgreSQL 設計
- テーブル設計
- インデックス設計

### [05_API設計.md](./05_API設計.md)
- REST API 仕様
- エンドポイント設計
- リクエスト/レスポンス設計

### [06_セキュリティ設計.md](./06_セキュリティ設計.md)
- セキュリティグループ設計
- VPN セキュリティ設計
- **技術標準準拠** (49_security.md)

### [07_性能設計.md](./07_性能設計.md)
- レスポンスタイム目標
- Auto Scaling 設計
- キャッシュ戦略

### [08_運用設計.md](./08_運用設計.md)
- CloudWatch 監視設計
- アラート設計
- ログ管理

### [09_インフラ設計・コスト設計.md](./09_インフラ設計・コスト設計.md) ⭐⭐⭐
- CloudFormation スタック設計
- **Change Set デプロイフロー設計** (Round 3 重点項目)
- コスト見積もり

### [10_開発環境・CI_CD設計.md](./10_開発環境・CI_CD設計.md)
- ローカル開発環境
- GitHub Actions CI/CD
- デプロイパイプライン

### [11_テスト戦略.md](./11_テスト戦略.md)
- 単体テスト戦略
- 統合テスト戦略
- E2E テスト戦略
- 性能テスト戦略

### [12_非機能要件対応.md](./12_非機能要件対応.md)
- 可用性対応
- スケーラビリティ対応
- セキュリティ対応

---

## 🎯 Round 3 の重点項目

### Change Set による段階的デプロイ (⭐⭐⭐最重要)

Round 3 では、CloudFormation Change Set を使った安全なデプロイフローを実装します:

1. **create-changeset.sh**: Change Set 作成 (dry-run)
2. **describe-changeset.sh**: 変更内容確認
3. **execute-changeset.sh**: ユーザー承認後に実行
4. **rollback.sh**: ロールバック処理

**参照**:
- `.claude/docs/40_standards/45_cloudformation.md` (CloudFormation 3 Principles)
- `09_インフラ設計・コスト設計.md` (Change Set デプロイフロー設計)

---

## 📝 設計原則

1. **責任分離原則**
   - Platform Account: 共通ネットワーク基盤
   - Service Account: アプリケーション基盤

2. **スタック分割原則**
   - platform-network: VPC, Subnets
   - platform-tgw: Transit Gateway
   - service-network: VPC, NAT GW, TGW Attachment
   - service-database: RDS PostgreSQL
   - service-compute: ECS, ALB

3. **段階的デプロイ原則** (⭐⭐⭐ Round 3 重点)
   - Change Set 作成 → 確認 → 実行
   - dry-run による事前検証
   - ユーザー承認プロセス

---

## 🔍 技術標準準拠

本設計書は以下の技術標準に準拠します:

- `.claude/docs/40_standards/45_cloudformation.md` (CloudFormation 3 Principles)
- `.claude/docs/40_standards/47_python.md` (Python コーディング規約)
- `.claude/docs/40_standards/49_security.md` (セキュリティ・運用基準)

---

## 変更履歴

| 日付 | 版数 | 変更内容 | 承認者 |
|------|------|----------|--------|
| 2025-10-24 | 3.0 | Round 3: Change Set デプロイ設計追加 | - |
| 2025-10-24 | 2.0 | Round 2: 13章完全生成 | - |
| 2025-10-21 | 1.0 | Round 1: 初版作成 | - |
