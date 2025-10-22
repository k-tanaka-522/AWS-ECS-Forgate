# AWS CloudFormation 規約

## 基本方針

- **Change Sets必須**（dry-run）
- **Well-Architected Framework準拠**
- **設計で判断**（技術標準は推奨であり、プロジェクト要件に応じて調整可能）

---

## スタック分割の原則

### なぜスタックを分割するのか？

**AWS公式推奨**: ライフサイクル・オーナーシップで分割

**理由:**
1. **疎結合**: チーム間の依存を減らす
2. **責任分離**: 各チームが独立して更新可能
3. **変更リスクの最小化**: 影響範囲を限定
4. **更新頻度の最適化**: 頻繁に変更するリソースを分離

### 分割の基準

| 基準 | 説明 | 例 |
|------|------|-----|
| **ライフサイクル** | 更新頻度 | ネットワーク（年単位）vs コンピュート（日単位） |
| **オーナーシップ** | 責任チーム | インフラチーム vs 開発チーム |
| **依存関係** | 疎結合 | VPC（独立）vs ECS（VPCに依存） |

### 典型的な分割パターン

```
✅ 推奨：ライフサイクル別に分割

network-stack          # 更新頻度: 低（数ヶ月〜年単位）
├── VPC
├── Subnet
├── RouteTable
└── InternetGateway

storage-stack          # 更新頻度: 低〜中（週〜月単位）
├── RDS
├── DynamoDB
└── S3

compute-stack          # 更新頻度: 高（日〜週単位）
├── ECS Service
├── ALB
├── Auto Scaling
└── Task Definition
```

**メリット:**
- ✅ ネットワーク変更時にコンピュートリソースに影響しない
- ✅ アプリデプロイ時にデータベースに影響しない
- ✅ チームごとに独立して作業可能

### クロススタック参照（Export/Import）

**network-stack** (Exportする側)
```yaml
Outputs:
  VpcId:
    Value: !Ref VPC
    Export:
      Name: !Sub ${ProjectName}-${Environment}-VpcId

  PrivateSubnetIds:
    Value: !Join [",", [!Ref PrivateSubnet1, !Ref PrivateSubnet2]]
    Export:
      Name: !Sub ${ProjectName}-${Environment}-PrivateSubnetIds
```

**compute-stack** (Importする側)
```yaml
Resources:
  ECSService:
    Type: AWS::ECS::Service
    Properties:
      NetworkConfiguration:
        AwsvpcConfiguration:
          Subnets: !Split
            - ","
            - !ImportValue
                Fn::Sub: ${ProjectName}-${Environment}-PrivateSubnetIds
```

---

## ディレクトリ構造

### 推奨構造（スタック分割 + 環境差分集約）

```
infra/cloudformation/
├── stacks/                        # スタック定義（ライフサイクル別）
│   ├── network/
│   │   └── main.yaml             # VPC, Subnet, RouteTable
│   ├── storage/
│   │   └── main.yaml             # RDS, DynamoDB, S3
│   └── compute/
│       └── main.yaml             # ECS, ALB, Auto Scaling
│
├── templates/                     # 再利用可能なテンプレート部品
│   ├── network/
│   │   ├── vpc.yaml
│   │   ├── subnet.yaml
│   │   └── route-table.yaml
│   ├── storage/
│   │   ├── rds.yaml
│   │   ├── dynamodb.yaml
│   │   └── s3.yaml
│   └── compute/
│       ├── ecs-cluster.yaml
│       ├── ecs-service.yaml
│       └── alb.yaml
│
└── parameters/                    # 環境差分を集約
    ├── dev.json
    └── prod.json
```

### 使い方

```bash
# 1. Network Stack（最初、滅多に更新しない）
aws cloudformation deploy \
  --stack-name myapp-dev-network \
  --template-file stacks/network/main.yaml \
  --parameter-overrides file://parameters/dev.json

# 2. Storage Stack（時々更新）
aws cloudformation deploy \
  --stack-name myapp-dev-storage \
  --template-file stacks/storage/main.yaml \
  --parameter-overrides file://parameters/dev.json

# 3. Compute Stack（頻繁に更新）
aws cloudformation deploy \
  --stack-name myapp-dev-compute \
  --template-file stacks/compute/main.yaml \
  --parameter-overrides file://parameters/dev.json
```

### parameters/dev.json の例（環境差分を集約）

```json
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "dev"
  },
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "myapp"
  },
  {
    "ParameterKey": "VpcCidr",
    "ParameterValue": "10.1.0.0/16"
  },
  {
    "ParameterKey": "DBInstanceClass",
    "ParameterValue": "db.t3.micro"
  },
  {
    "ParameterKey": "ECSTaskCpu",
    "ParameterValue": "256"
  }
]
```

**すべての環境差分（dev/prod）がこのファイルに集約される**

### 複雑なプロジェクトの場合

Platform Account / Service Account など、複数のAWSアカウントを使用する場合：

```
infra/cloudformation/
├── platform/                      # Platform Account用
│   ├── stacks/
│   │   ├── network/
│   │   │   └── main.yaml
│   │   └── connectivity/
│   │       └── main.yaml         # TGW, RAM
│   ├── templates/
│   │   └── ...
│   └── parameters/
│       ├── dev.json
│       └── prod.json
│
└── service/                       # Service Account用
    ├── stacks/
    │   ├── network/
    │   ├── storage/
    │   └── compute/
    ├── templates/
    │   └── ...
    └── parameters/
        ├── dev.json
        └── prod.json
```

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
