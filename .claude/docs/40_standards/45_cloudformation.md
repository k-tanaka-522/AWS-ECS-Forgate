# AWS CloudFormation 規約

## 基本方針

- **Change Sets必須**（dry-run）
- **Well-Architected Framework準拠**
- **設計で判断**（技術標準は推奨であり、プロジェクト要件に応じて調整可能）

---

## スタック構成

### 推奨パターン（レイヤー別分割）

```
infra/cloudformation/
├── network.yaml       # VPC, Subnet
├── security.yaml      # SecurityGroup, IAM
├── database.yaml      # RDS
└── compute.yaml       # ECS, ALB
```

**注意:** これは一般的な推奨パターンです。
プロジェクトの規模・要件に応じて、設計で適切な構成を決定してください。

---

## テンプレート規約

### パラメータ必須項目

```yaml
Parameters:
  Environment:
    Type: String
    AllowedValues:
      - dev
      - stg
      - prd
    Description: Environment name

  ProjectName:
    Type: String
    Description: Project name for resource naming
```

### リソース命名規則

```yaml
Resources:
  MyAppVPC:
    Type: AWS::EC2::VPC
    Properties:
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-vpc
        - Key: Environment
          Value: !Ref Environment
```

---

## デプロイ手順（Change Sets必須）

```bash
# ❌ Bad: 直接デプロイ
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name myapp-prd

# ✅ Good: Change Setsで確認
# 1. Change Set作成
aws cloudformation create-change-set \
  --stack-name myapp-prd \
  --change-set-name update-2025-10-19 \
  --template-body file://template.yaml

# 2. Change Set確認
aws cloudformation describe-change-set \
  --stack-name myapp-prd \
  --change-set-name update-2025-10-19

# 3. 承認後、実行
aws cloudformation execute-change-set \
  --stack-name myapp-prd \
  --change-set-name update-2025-10-19
```

---

## Well-Architected Framework

### 6つの柱

1. **セキュリティ**: IAM、暗号化、SecurityGroup
2. **信頼性**: Multi-AZ、バックアップ
3. **パフォーマンス効率**: Auto Scaling
4. **コスト最適化**: リソース最適化
5. **運用上の優秀性**: CloudWatch、ログ
6. **持続可能性**: リソース効率化

---

## ファイル分割

### 基本的な考え方

**長すぎるコードはメンテナンス性が悪い**

- 理解しづらい
- レビューしづらい
- 変更の影響範囲が分かりづらい

### 推奨基準

**目安:** 1ファイル300行以内

**理由:**
- レビューしやすい粒度
- 変更の影響範囲が限定される
- 新メンバーが理解しやすい

### 300行を超える場合

**選択肢:**

1. **分割する**
   - 責務ごとに分割
   - ネスト構造を検討

2. **1ファイルのまま**
   - 合理的な理由があればOK
   - 設計書に理由を記載

**判断基準:**

❌ **形式的**: 「300行だから分割」
✅ **本質的**: 「メンテナンスしやすいか」

### Good Example

#### ✅ 400行だが1ファイル（理由あり）

```
設計書に記載:
「データベーススキーマは密結合のため1ファイルで管理。
 推定400行だが、分割するとかえって複雑になるため1ファイルとする。」
```

#### ✅ 800行をネスト構造に分割

```
設計書に記載:
「compute.yaml は複雑なため、ネスト構造に分割:
 - compute.yaml (親スタック、200行)
 - nested/ecs.yaml (250行)
 - nested/alb.yaml (200行)
 - nested/task-definitions.yaml (150行)」
```

### Bad Example

#### ❌ 752行で1ファイル（理由なし）

```
設計書に記載なし
→ 実装時に「とりあえず全部入れた」
→ なぜこの構成か説明できない
```

---

**参照**: `.claude/docs/10_facilitation/2.4_実装フェーズ/2.4.6_IaC構築プロセス/2.4.6.1_CloudFormation構築/`
