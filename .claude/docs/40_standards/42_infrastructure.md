# インフラ（IaC）技術標準

このドキュメントは、Infrastructure as Code (IaC) に関する技術標準とベストプラクティスを定義しています。

**Phase 1 検証対象：AWS（Terraform / CloudFormation）**

---

## 1. 基本方針

### 1.1 IaCの原則

- **すべてをコードで管理**：手動操作禁止
- **冪等性の確保**：何度実行しても同じ結果
- **バージョン管理**：Gitで管理
- **レビュー可能**：Pull Requestでレビュー

### 1.2 CloudFormation固有の重要な制約

**⚠️ 重要：CloudFormationテンプレートでの日本語（マルチバイト文字）使用制限**

CloudFormationは**マルチバイト文字（日本語、中国語、韓国語等）のサポートが限定的**です。使用箇所によってはエラーや文字化けが発生します。

---

#### 1.2.1 マルチバイト文字の使用可否マトリクス

| 使用箇所 | 日本語使用 | 制約内容 | 参考 |
|---------|----------|---------|------|
| **論理ID（Logical ID）** | ❌ 不可 | 英数字のみ（A-Za-z0-9）必須 | [公式ドキュメント](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/resources-section-structure.html) |
| **パラメータ名** | ❌ 不可 | 英数字のみ必須 | 同上 |
| **スタック名** | ❌ 不可 | 英数字・ハイフンのみ | AWS命名規則 |
| **Output名/Export名** | ❌ 不可 | 英数字のみ | CloudFormation仕様 |
| **Mapping名/キー** | ❌ 不可 | 英数字のみ | CloudFormation仕様 |
| **コメント（`#`）** | ⚠️ 条件付き | **通常は可能だが、Lambda関数ソース内等では不可** | [実運用事例](https://km-tech.hateblo.jp/entry/2019/12/05/093216) |
| **Description（説明文）** | ❌ 不可 | 日本語入力すると`???`に文字化け | [実運用事例](https://oreout.hatenablog.com/entry/aws/cloudformation/2) |
| **Tags の Value** | ✅ 可能 | UTF-8サポート（ただしAPI取得時に文字化けの報告あり） | [GitHub Issue](https://github.com/aws-cloudformation/cloudformation-coverage-roadmap/issues/814) |
| **UserData/Metadata** | ⚠️ 要Base64 | 直接入力は文字化け、Base64エンコード必須 | [実運用事例](https://dev.classmethod.jp/articles/cfn-multibyte-character-input/) |
| **パラメータのデフォルト値** | ⚠️ 推奨しない | 入力可能だが文字化けリスクあり | 同上 |

---

#### 1.2.2 論理ID（Logical ID）の厳格な制約

**公式仕様：**
> Logical resource names must be **alphanumeric (A-Za-z0-9)** and unique within the template.

**許可される文字：**
- 英字（大文字・小文字）：A-Z, a-z
- 数字：0-9

**禁止される文字：**
- ❌ ハイフン（`-`）
- ❌ アンダースコア（`_`）
- ❌ スペース
- ❌ 日本語・マルチバイト文字

**❌ 悪い例：**
```yaml
Resources:
  VPC本番環境:            # NG：日本語
    Type: AWS::EC2::VPC

  my-vpc:                # NG：ハイフン
    Type: AWS::EC2::VPC

  my_vpc:                # NG：アンダースコア
    Type: AWS::EC2::VPC
```

**✅ 良い例：**
```yaml
Resources:
  # 本番環境用VPC（コメントで補足）
  ProductionVPC:         # OK：英数字のみ、意味が明確
    Type: AWS::EC2::VPC

  DevVpc:                # OK：英数字のみ
    Type: AWS::EC2::VPC
```

---

#### 1.2.3 コメントの制約と注意点

**基本的には日本語コメント可能：**
```yaml
Resources:
  # このVPCは本番環境用です
  ProductionVPC:
    Type: AWS::EC2::VPC
```

**⚠️ 例外：Lambda関数等のソースコード内では不可**

以下のようなケースではエラーが発生します：

```yaml
# ❌ 悪い例：Lambdaソース内の日本語コメント
Resources:
  MyFunction:
    Type: AWS::Lambda::Function
    Properties:
      Code:
        ZipFile: |
          def handler(event, context):
              # データを処理する  ← エラー発生
              return {"statusCode": 200}
```

**エラー例：**
```
Cannot parse template as YAML : special characters are not allowed
```

**✅ 良い例：英語コメントに変更**
```yaml
Resources:
  MyFunction:
    Type: AWS::Lambda::Function
    Properties:
      Code:
        ZipFile: |
          def handler(event, context):
              # Process data
              return {"statusCode": 200}
```

**推奨：**
- テンプレートのトップレベルやリソース定義の外側では日本語コメントOK
- Lambdaソースコード、UserData等の埋め込みスクリプト内では英語を使用

---

#### 1.2.4 Tags での日本語使用

**Tags の `Value` は日本語使用可能：**

```yaml
Resources:
  ProductionVPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      Tags:
        - Key: Name
          Value: 本番環境VPC        # OK：日本語可能
        - Key: Environment
          Value: production         # 推奨：英数字
        - Key: Description
          Value: EC事業用のVPC      # OK：日本語可能
```

**⚠️ 注意点：**
- Tags の `Value` は UTF-8 をサポート
- ただし、`GetTemplate` API等で取得時に文字化けする既知の問題あり（[GitHub Issue #814](https://github.com/aws-cloudformation/cloudformation-coverage-roadmap/issues/814)）
- 実リソースには正しく反映されるが、API経由での確認時は注意

---

#### 1.2.5 UserData/Metadata でのマルチバイト文字

**問題：直接入力すると文字化け**

```yaml
# ❌ 悪い例
UserData:
  Fn::Base64: |
    #!/bin/bash
    echo "ようこそ"  # 文字化けする
```

**✅ 解決策：Base64エンコード**

```yaml
# ✅ 良い例
UserData:
  Fn::Base64:
    Fn::Sub:
      - |
        #!/bin/bash
        echo ${EncodedMessage} | base64 -d
      - EncodedMessage:
          Fn::Base64: "ようこそ"
```

---

#### 1.2.6 実装時の推奨ルール

**必須ルール：**
1. ✅ **論理ID・パラメータ名・スタック名は英数字のみ**
2. ✅ **Description は英語のみ**（日本語は文字化け）
3. ✅ **Lambdaソース・UserData内のコメントは英語のみ**
4. ✅ **Tags の Value は日本語可（ただし英数字推奨）**

**推奨ルール：**
5. ✅ **通常のコメント（`#`）は日本語OK**（可読性向上）
6. ✅ **マルチバイト文字が必要な場合は Base64 エンコード**
7. ✅ **UTF-8 BOM なしで保存**（UTF-8 BOM はエラーの原因）

**実装例：**

```yaml
AWSTemplateFormatVersion: '2010-09-09'
# このテンプレートは本番環境のネットワークを構築します（日本語コメントOK）
Description: 'Production Network Infrastructure'  # 英語のみ

Parameters:
  # 環境名（開発・検証・本番）
  Environment:
    Type: String
    AllowedValues: [dev, stg, prod]
    Default: dev
    Description: 'Environment name'  # 英語のみ

Resources:
  # VPCリソース（本番環境用）
  ProductionVPC:  # 論理IDは英数字のみ
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: 本番VPC  # Tagのvalueは日本語OK
        - Key: Environment
          Value: !Ref Environment  # パラメータ参照

Outputs:
  VpcId:  # 論理IDは英数字のみ
    # VPCのIDを出力
    Description: 'VPC ID'  # 英語のみ
    Value: !Ref ProductionVPC
    Export:
      Name: !Sub '${AWS::StackName}-VpcId'  # スタック名は英数字
```

---

#### 1.2.7 参考資料

- [AWS公式：CloudFormation Resources Syntax](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/resources-section-structure.html)
- [実運用事例：CloudFormationテンプレート内でのマルチバイト文字についての検証](https://zenn.dev/mjxo/articles/b28f7b5496a1dd)
- [実運用事例：CloudFormationのパラメータでマルチバイト文字を入力する](https://dev.classmethod.jp/articles/cfn-multibyte-character-input/)
- [実運用事例：CloudFormationテンプレート内に日本語（マルチバイト文字）が使えなくて英語力を試された話](https://km-tech.hateblo.jp/entry/2019/12/05/093216)
- [GitHub Issue：GetTemplate API does not support non-ASCII characters](https://github.com/aws-cloudformation/cloudformation-coverage-roadmap/issues/1220)

### 1.3 AWS IaCツールの選定

| ツール | 特徴 | 推奨ケース |
|--------|------|-----------|
| **Terraform** | マルチクラウド対応、モジュール化しやすい | 推奨（Phase 1検証） |
| **CloudFormation** | AWS特化、ネストスタック | AWS専用プロジェクト |
| **CDK** | プログラミング言語で記述 | 複雑なロジックが必要な場合 |

---

## 2. ディレクトリ構造

### 2.1 Terraform の標準構造

```
project-root/
├── modules/                    # 再利用可能なモジュール
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── ec2/
│   ├── rds/
│   └── s3/
│
├── environments/               # 環境ごとの設定
│   ├── dev/
│   │   ├── main.tf            # モジュールの呼び出し
│   │   ├── terraform.tfvars   # 環境固有の値
│   │   ├── backend.tf         # ステートファイル設定
│   │   └── variables.tf
│   ├── stg/
│   └── prod/
│
├── shared/                     # 共通設定
│   ├── variables.tf
│   └── data_sources.tf
│
├── .gitignore
└── README.md
```

### 2.2 CloudFormation の標準構造

CloudFormationでは、プロジェクトの規模や要件に応じて以下の2つのパターンから選択してください。

---

#### パターンA: ネストスタック構成（大規模・複雑な構成向け）

**推奨ケース：**
- 多数のリソースを含む大規模プロジェクト
- 子テンプレートを複数プロジェクトで再利用したい場合
- S3バケット管理が許容できる環境

**推奨構造：**

```
project-root/
├── infra/
│   ├── shared/                       # 共有系インフラ（VPC, TGW等）
│   │   ├── stack.yaml                # 親スタック（エントリーポイント）
│   │   ├── nested/                   # ネストスタックの子テンプレート
│   │   │   ├── network.yaml          # VPC, IGW, Subnet
│   │   │   └── connectivity.yaml     # TGW, Client VPN
│   │   ├── parameters-dev.json       # 環境別パラメータ
│   │   ├── parameters-stg.json
│   │   ├── parameters-prod.json
│   │   └── deploy.sh                 # デプロイスクリプト
│   │
│   ├── application/                  # アプリケーション系インフラ
│   │   ├── stack.yaml
│   │   ├── nested/
│   │   │   ├── alb.yaml
│   │   │   ├── ecs.yaml
│   │   │   └── rds.yaml
│   │   ├── parameters-dev.json
│   │   └── deploy.sh
│   │
│   └── monitoring/                   # 監視系インフラ
│       ├── stack.yaml
│       ├── nested/
│       │   ├── cloudwatch.yaml
│       │   └── sns.yaml
│       ├── parameters-dev.json
│       └── deploy.sh
│
└── README.md
```

**命名規則：**
- **親スタック**: `stack.yaml`（エントリーポイントであることが明確）
- **子テンプレート格納ディレクトリ**: `nested/`（ネストスタックであることが明確）
- **子テンプレート**: 機能単位で命名（`network.yaml`, `connectivity.yaml`, `alb.yaml`等）
- **パラメータファイル**: `parameters-{env}.json`

**ディレクトリ分割方針：**
- `shared/`: 複数プロジェクト・アプリで共有するインフラ（VPC, TGW等）
- `application/`: アプリケーション固有のインフラ（ALB, ECS, RDS等）
- `monitoring/`: 監視・ログ系（CloudWatch, SNS等）

**重要：デプロイスクリプトの提供**

各ディレクトリに`deploy.sh`（Mac/Linux）と`deploy.bat`（Windows）を配置。
スクリプトが以下を自動実行：
1. S3バケット作成（存在しない場合）
2. ネストテンプレートをS3にアップロード
3. 親スタックをデプロイ

→ ユーザーはS3バケットの事前準備不要で、`./deploy.sh dev`のみでデプロイ可能。

---

#### パターンB: スプリットスタック構成（中小規模・シンプル構成向け）

**推奨ケース：**
- 中小規模のプロジェクト
- S3バケット管理を避けたい場合（検証・PoC等）
- テンプレートサイズが51,200バイト以内（CloudFormation制限）
- スタック間の依存関係が比較的シンプル

**推奨構造：**

```
project-root/
├── infra/
│   ├── shared/                       # 共有系インフラ（Platform Account）
│   │   ├── network.yaml              # VPC, TGW, Client VPN等
│   │   ├── parameters-poc.json       # 環境別パラメータ
│   │   ├── parameters-prod.json
│   │   └── deploy.sh / deploy.ps1    # デプロイスクリプト
│   │
│   └── app/                          # アプリケーション系インフラ（Service Account）
│       ├── 01-network.yaml           # App VPC, Subnet, NAT Gateway
│       ├── 02-database.yaml          # RDS, Security Group
│       ├── 03-compute.yaml           # ECS Cluster, ALB, Service
│       ├── 04-monitoring.yaml        # CloudWatch, SNS
│       ├── parameters-poc.json       # 環境別パラメータ
│       ├── parameters-prod.json
│       └── deploy.sh / deploy.ps1    # デプロイスクリプト
│
└── README.md
```

**命名規則：**
- **テンプレートファイル**: 番号プレフィックス + 機能名（`01-network.yaml`, `02-database.yaml`等）
  - 番号はデプロイ順序を示す（01 → 02 → 03 → 04）
- **パラメータファイル**: `parameters-{env}.json`

**スタック間連携：Cross-Stack References**

ネストスタックの代わりに、CloudFormationの`Outputs` + `Fn::ImportValue`でスタック間のリソース参照を実現：

```yaml
# 01-network.yaml（出力側）
Outputs:
  VpcId:
    Description: 'VPC ID'
    Value: !Ref AppVPC
    Export:
      Name: !Sub '${AWS::StackName}-VpcId'  # エクスポート名

  PrivateSubnetIds:
    Description: 'Private Subnet IDs'
    Value: !Join [',', [!Ref PrivateSubnet1, !Ref PrivateSubnet2]]
    Export:
      Name: !Sub '${AWS::StackName}-PrivateSubnetIds'
```

```yaml
# 02-database.yaml（参照側）
Parameters:
  NetworkStackName:
    Type: String
    Description: 'Network stack name for cross-stack reference'

Resources:
  DBSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      SubnetIds: !Split [',', !ImportValue
        Fn::Sub: '${NetworkStackName}-PrivateSubnetIds']  # インポート

  DatabaseInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      VPCSecurityGroups:
        - !Ref DBSecurityGroup
      DBSubnetGroupName: !Ref DBSubnetGroup
```

**デプロイ方法：**

```bash
# 順次デプロイ（依存関係順）
cd infra/app

# 1. ネットワーク
aws cloudformation deploy \
  --stack-name myapp-poc-network \
  --template-file 01-network.yaml \
  --parameter-overrides file://parameters-poc.json

# 2. データベース（ネットワークスタック名を渡す）
aws cloudformation deploy \
  --stack-name myapp-poc-database \
  --template-file 02-database.yaml \
  --parameter-overrides file://parameters-poc.json \
    NetworkStackName=myapp-poc-network

# 3. コンピュート
aws cloudformation deploy \
  --stack-name myapp-poc-compute \
  --template-file 03-compute.yaml \
  --parameter-overrides file://parameters-poc.json \
    NetworkStackName=myapp-poc-network \
    DatabaseStackName=myapp-poc-database

# 4. モニタリング
aws cloudformation deploy \
  --stack-name myapp-poc-monitoring \
  --template-file 04-monitoring.yaml \
  --parameter-overrides file://parameters-poc.json \
    ComputeStackName=myapp-poc-compute
```

**メリット：**
- ✅ S3バケット不要（テンプレートをローカルから直接デプロイ）
- ✅ シンプルな構造（フラットなディレクトリ）
- ✅ スタックごとに独立して更新可能
- ✅ 番号プレフィックスでデプロイ順序が明確

**デメリット：**
- ❌ テンプレートサイズ制限（51,200バイト、S3経由なら460,800バイト）
- ❌ Cross-Stack Reference削除時の制約（参照先スタックを先に削除できない）
- ❌ 子テンプレートの再利用性が低い

**推奨：**
- PoC・検証環境ではパターンB（スプリットスタック）
- 本番環境・大規模プロジェクトではパターンA（ネストスタック）

---

## 3. モジュール分割

### 3.1 Terraformモジュール

**原則：**
- リソースタイプごとにモジュール化
- 再利用可能な設計
- 適切な粒度（細かすぎず、大きすぎず）

**モジュールの構成：**

```hcl
# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
      Type = "Public"
    }
  )
}
```

```hcl
# modules/vpc/variables.tf
variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev, stg, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットのCIDRブロックリスト"
  type        = list(string)
}

variable "availability_zones" {
  description = "使用するAvailability Zoneのリスト"
  type        = list(string)
}

variable "tags" {
  description = "共通タグ"
  type        = map(string)
  default     = {}
}
```

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "作成したVPCのID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "作成したパブリックサブネットのIDリスト"
  value       = aws_subnet.public[*].id
}
```

**モジュールの呼び出し：**

```hcl
# environments/dev/main.tf
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones   = ["ap-northeast-1a", "ap-northeast-1c"]

  tags = local.common_tags
}
```

### 3.2 CloudFormation ネストスタック

**親スタック（stack.yaml）：**

```yaml
# infra/shared/stack.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: '共有ネットワークインフラ - 親スタック'

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, stg, prod]
    Description: 環境名

  ProjectName:
    Type: String
    Description: プロジェクト名

  TemplatesBucketName:
    Type: String
    Description: ネストテンプレート格納用S3バケット名

Resources:
  # ネットワークスタック（VPC, Subnet, IGW）
  NetworkStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://${TemplatesBucketName}.s3.${AWS::Region}.amazonaws.com/shared/nested/network.yaml'
      Parameters:
        Environment: !Ref Environment
        ProjectName: !Ref ProjectName
        VpcCIDR: !FindInMap [EnvironmentMap, !Ref Environment, VpcCIDR]

  # 接続性スタック（TGW, Client VPN）
  ConnectivityStack:
    Type: AWS::CloudFormation::Stack
    DependsOn: NetworkStack
    Properties:
      TemplateURL: !Sub 'https://${TemplatesBucketName}.s3.${AWS::Region}.amazonaws.com/shared/nested/connectivity.yaml'
      Parameters:
        Environment: !Ref Environment
        ProjectName: !Ref ProjectName
        VpcId: !GetAtt NetworkStack.Outputs.VpcId
        PrivateSubnetIds: !GetAtt NetworkStack.Outputs.PrivateSubnetIds

Mappings:
  EnvironmentMap:
    dev:
      VpcCIDR: 10.0.0.0/16
    stg:
      VpcCIDR: 10.1.0.0/16
    prod:
      VpcCIDR: 10.2.0.0/16

Outputs:
  VpcId:
    Value: !GetAtt NetworkStack.Outputs.VpcId
    Export:
      Name: !Sub '${ProjectName}-${Environment}-VpcId'
```

**子テンプレート（network.yaml）：**

```yaml
# infra/shared/nested/network.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'VPC・サブネット・IGW'

Parameters:
  Environment:
    Type: String
  ProjectName:
    Type: String
  VpcCIDR:
    Type: String

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCIDR
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-vpc'
        - Key: Environment
          Value: !Ref Environment

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-igw'

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

Outputs:
  VpcId:
    Value: !Ref VPC
  PrivateSubnetIds:
    Value: !Join [',', [!Ref PrivateSubnet1, !Ref PrivateSubnet2]]
```

**デプロイスクリプト（deploy.sh）：**

```bash
#!/bin/bash
# infra/shared/deploy.sh

set -e

ENVIRONMENT=$1
PROJECT_NAME="myproject"  # プロジェクト名
BUCKET_NAME="${PROJECT_NAME}-cfn-templates-${ENVIRONMENT}"

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./deploy.sh <environment>"
    echo "Example: ./deploy.sh dev"
    exit 1
fi

echo "=== CloudFormation Nested Stack Deployment ==="
echo "Project: ${PROJECT_NAME}"
echo "Environment: ${ENVIRONMENT}"
echo ""

# 1. S3バケット作成（存在しない場合）
echo "[1/3] Checking S3 bucket..."
aws s3 mb "s3://${BUCKET_NAME}" 2>/dev/null || echo "  Bucket already exists"

# 2. ネストテンプレートをS3にアップロード
echo "[2/3] Uploading nested templates to S3..."
aws s3 cp nested/network.yaml "s3://${BUCKET_NAME}/shared/nested/"
aws s3 cp nested/connectivity.yaml "s3://${BUCKET_NAME}/shared/nested/"
echo "  Nested templates uploaded"

# 3. 親スタックをデプロイ
echo "[3/3] Deploying CloudFormation stack..."
aws cloudformation deploy \
  --stack-name "${PROJECT_NAME}-${ENVIRONMENT}-SharedNetwork" \
  --template-file stack.yaml \
  --parameter-overrides file://parameters-${ENVIRONMENT}.json \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

echo ""
echo "=== Deployment Complete ==="
```

---

## 4. 環境差分の管理

### 4.1 Terraform での環境差分

**terraform.tfvars による管理：**

```hcl
# environments/dev/terraform.tfvars
environment      = "dev"
aws_region       = "ap-northeast-1"
instance_type    = "t3.micro"
db_instance_class = "db.t3.micro"
min_size         = 1
max_size         = 2
desired_capacity = 1
```

```hcl
# environments/prod/terraform.tfvars
environment      = "prod"
aws_region       = "ap-northeast-1"
instance_type    = "t3.large"
db_instance_class = "db.r5.large"
min_size         = 2
max_size         = 10
desired_capacity = 4
```

**locals での環境別設定：**

```hcl
# environments/dev/main.tf
locals {
  environment = "dev"

  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
  }

  # 環境別の設定
  config = {
    enable_nat_gateway     = false  # dev環境ではコスト削減
    enable_backup          = false
    enable_deletion_protection = false
    multi_az               = false
  }
}
```

```hcl
# environments/prod/main.tf
locals {
  environment = "prod"

  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
  }

  # 環境別の設定
  config = {
    enable_nat_gateway     = true   # prod環境では有効化
    enable_backup          = true
    enable_deletion_protection = true
    multi_az               = true
  }
}
```

### 4.2 CloudFormation での環境差分

```json
// parameters/dev.json
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "dev"
  },
  {
    "ParameterKey": "InstanceType",
    "ParameterValue": "t3.micro"
  },
  {
    "ParameterKey": "DBInstanceClass",
    "ParameterValue": "db.t3.micro"
  }
]
```

```json
// parameters/prod.json
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "prod"
  },
  {
    "ParameterKey": "InstanceType",
    "ParameterValue": "t3.large"
  },
  {
    "ParameterKey": "DBInstanceClass",
    "ParameterValue": "db.r5.large"
  }
]
```

---

## 5. ステートファイル管理

### 5.1 Terraform State

**S3バックエンドの使用（推奨）：**

```hcl
# environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "myproject-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "myproject-terraform-lock"  # ロック用
  }
}
```

**重要：**
- ステートファイルは機密情報を含むため、暗号化必須
- DynamoDBでロック管理（複数人の同時実行を防ぐ）
- バージョニングを有効化

### 5.2 CloudFormation Stack

CloudFormationは自動でステート管理されるため、特別な設定不要。

---

## 6. 命名規則

### 6.1 リソース命名規則

**形式：** `{project}-{environment}-{resource_type}-{purpose}-{number}`

**例：**
```
myapp-prod-ec2-web-01
myapp-prod-rds-postgresql
myapp-prod-s3-logs
myapp-prod-elb-public
myapp-prod-sg-web
```

**Terraform での実装：**

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-web-${count.index + 1}"
  }
}
```

### 6.2 タグ戦略

**必須タグ：**
```hcl
tags = {
  Name        = "リソース名"
  Project     = "プロジェクト名"
  Environment = "dev/stg/prod"
  ManagedBy   = "Terraform"
  Owner       = "チーム名"
  CostCenter  = "コストセンター"
}
```

---

## 7. セキュリティ

### 7.1 機密情報の管理

**❌ 悪い例：ハードコード**
```hcl
resource "aws_db_instance" "main" {
  username = "admin"
  password = "MyPassword123"  # NG！
}
```

**✅ 良い例：AWS Secrets Manager**
```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "${var.project_name}-${var.environment}-db-password"
}

resource "aws_db_instance" "main" {
  username = "admin"
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}
```

**✅ 良い例：環境変数**
```hcl
variable "db_password" {
  description = "データベースパスワード（環境変数 TF_VAR_db_password で設定）"
  type        = string
  sensitive   = true
}
```

### 7.2 セキュリティグループ

**原則：**
- 最小権限の原則
- ソースIPは可能な限り限定
- 不要なポートは開けない

```hcl
resource "aws_security_group" "web" {
  name        = "${var.project_name}-${var.environment}-sg-web"
  description = "Webサーバー用セキュリティグループ"
  vpc_id      = module.vpc.vpc_id

  # HTTPSのみ許可（HTTPは不要）
  ingress {
    description = "HTTPS from ALB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]  # ALBからのみ
  }

  # SSH（踏み台サーバーからのみ）
  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## 8. CloudFormation 開発ワークフロー（推奨プラクティス）

### 8.1 基本原則：小さく始めて段階的に拡張

**❌ 避けるべきパターン：**
- いきなり全リソースを1つのテンプレートに詰め込む
- 検証せずにメインスタックに統合
- ローカルでのテストなしにいきなり本番デプロイ

**✅ 推奨パターン：**
1. 小さな単位でテンプレートを作成
2. 個別に検証・デプロイ確認
3. 動作確認後にメインスタックに統合

---

### 8.2 テンプレート作成の段階的アプローチ

#### ステップ1: 最小構成から開始

```yaml
# 最初はVPCのみ
Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
```

**検証：**
```bash
# 構文チェック
aws cloudformation validate-template --template-body file://vpc.yaml

# デプロイ（dev環境）
aws cloudformation deploy --stack-name test-vpc --template-file vpc.yaml
```

#### ステップ2: 依存リソースを追加

```yaml
# VPC + Subnet を追加
Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16

  PublicSubnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC  # 暗黙的な依存関係
      CidrBlock: 10.0.1.0/24
```

**検証：**
```bash
# 変更セットで影響確認
aws cloudformation create-change-set \
  --stack-name test-vpc \
  --template-body file://vpc.yaml \
  --change-set-name add-subnet

# 変更内容を確認
aws cloudformation describe-change-set \
  --stack-name test-vpc \
  --change-set-name add-subnet

# 問題なければ実行
aws cloudformation execute-change-set \
  --stack-name test-vpc \
  --change-set-name add-subnet
```

#### ステップ3: 動作確認後に次のリソース追加

このサイクルを繰り返して段階的に構築していく。

---

### 8.3 ネストスタック開発のワークフロー

**推奨フロー：**

```
1. 子テンプレート作成（例：network.yaml）
   ↓
2. 子テンプレート単体でデプロイ・検証
   ↓
3. 動作確認OK
   ↓
4. 親スタックに組み込む
   ↓
5. ネストスタックとして再検証
```

**具体例：**

```bash
# ステップ1-2: 子テンプレート単体でテスト
aws cloudformation deploy \
  --stack-name test-network-only \
  --template-file nested/network.yaml \
  --parameter-overrides Environment=dev ProjectName=test

# ステップ3: 動作確認（リソースが正しく作成されているか）
aws cloudformation describe-stacks --stack-name test-network-only

# ステップ4-5: 親スタックに組み込んでテスト
aws s3 cp nested/network.yaml s3://my-templates/nested/
aws cloudformation deploy \
  --stack-name test-parent \
  --template-file stack.yaml \
  --parameter-overrides TemplatesBucketName=my-templates
```

---

### 8.4 リソース依存関係の制御

#### 8.4.1 暗黙的な依存関係（自動）

CloudFormationは`!Ref`、`!GetAtt`、`!Sub`を使うと自動的に依存関係を推測します。

```yaml
Resources:
  VPC:
    Type: AWS::EC2::VPC

  Subnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC  # VPCが先に作成される（暗黙的依存）
```

**並列作成：**
- VPCとSubnetは依存関係があるため順次作成
- 独立した複数のSubnetは並列作成される

#### 8.4.2 明示的な依存関係（DependsOn）

**使用が必要なケース：**

1. **VPCゲートウェイアタッチメント**
```yaml
Resources:
  VPC:
    Type: AWS::EC2::VPC

  InternetGateway:
    Type: AWS::EC2::InternetGateway

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  # ルートテーブルはアタッチメント完了後に作成
  RouteTable:
    Type: AWS::EC2::RouteTable
    DependsOn: AttachGateway  # 明示的依存が必要
    Properties:
      VpcId: !Ref VPC
```

2. **IAMロール+ポリシー+リソース**
```yaml
Resources:
  # IAMロール
  LambdaRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument: {...}

  # ポリシーをアタッチ
  LambdaPolicy:
    Type: AWS::IAM::Policy
    Properties:
      Roles: [!Ref LambdaRole]
      PolicyDocument: {...}

  # Lambda関数（ポリシーアタッチ完了後に作成）
  MyFunction:
    Type: AWS::Lambda::Function
    DependsOn: LambdaPolicy  # 明示的依存が必要
    Properties:
      Role: !GetAtt LambdaRole.Arn
```

3. **ECSクラスター+コンテナインスタンス**
```yaml
Resources:
  ECSCluster:
    Type: AWS::ECS::Cluster

  AutoScalingGroup:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      # ECSクラスターにインスタンスを登録
      ...

  # ECSサービス（インスタンスが利用可能になってから作成）
  ECSService:
    Type: AWS::ECS::Service
    DependsOn: AutoScalingGroup  # 明示的依存が必要
    Properties:
      Cluster: !Ref ECSCluster
```

**調査方法：**
- 各リソースタイプの公式ドキュメントを確認
- エラーが発生したら依存関係を疑う
- CloudFormationのエラーメッセージに従って`DependsOn`を追加

---

### 8.5 開発時の検証ツール

#### 8.5.1 構文チェック（必須）

```bash
# AWSによる検証
aws cloudformation validate-template --template-body file://template.yaml
```

#### 8.5.2 Linter（推奨）

```bash
# cfn-lint（構文・ベストプラクティスチェック）
pip install cfn-lint
cfn-lint template.yaml

# cfn-nag（セキュリティチェック）
gem install cfn-nag
cfn_nag_scan --input-path template.yaml
```

#### 8.5.3 変更セット（本番前必須）

```bash
# 変更内容を事前確認（dry-run相当）
aws cloudformation create-change-set \
  --stack-name mystack \
  --template-body file://template.yaml \
  --change-set-name preview-changes

# 変更内容を確認
aws cloudformation describe-change-set \
  --stack-name mystack \
  --change-set-name preview-changes

# 問題なければ実行
aws cloudformation execute-change-set \
  --stack-name mystack \
  --change-set-name preview-changes
```

---

### 8.6 実装時の推奨フロー（まとめ）

```
【開発フェーズ】
1. テンプレート作成
   ↓
2. ローカルで構文チェック（validate-template, cfn-lint）
   ↓
3. dev環境にデプロイ
   ↓
4. リソースが正しく作成されたか確認
   ↓
5. 次のリソースを追加（ステップ1に戻る）

【統合フェーズ】
6. 子テンプレートをメイン/親スタックに統合
   ↓
7. 変更セットで影響範囲確認
   ↓
8. dev環境で統合テスト

【本番デプロイフェーズ】
9. stg環境で最終確認
   ↓
10. 変更セット作成（本番）
   ↓
11. 変更内容レビュー
   ↓
12. 承認後、本番デプロイ
```

**重要な原則：**
- ✅ **小さく始める**：最小構成から段階的に追加
- ✅ **都度検証**：テンプレートが通ることを確認してから次へ
- ✅ **単体→統合**：子テンプレート単体で検証してから親に組み込む
- ✅ **変更セット活用**：本番前に必ず影響範囲を確認
- ✅ **依存関係は都度調査**：エラーが出たら公式ドキュメント確認

---

## 9. 可用性・冗長化

### 9.1 マルチAZ構成

```hcl
# 複数のAvailability Zoneにサブネットを作成
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
}

# RDSのマルチAZ
resource "aws_db_instance" "main" {
  multi_az = var.environment == "prod" ? true : false
}

# Auto Scalingで複数インスタンス
resource "aws_autoscaling_group" "web" {
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  vpc_zone_identifier = aws_subnet.private[*].id  # 複数AZ
}
```

---

## 9. コスト最適化

### 9.1 環境別のリソースサイズ

```hcl
# locals.tf
locals {
  instance_config = {
    dev = {
      instance_type = "t3.micro"
      volume_size   = 20
    }
    stg = {
      instance_type = "t3.small"
      volume_size   = 30
    }
    prod = {
      instance_type = "t3.large"
      volume_size   = 100
    }
  }
}

resource "aws_instance" "web" {
  instance_type = local.instance_config[var.environment].instance_type
}
```

### 9.2 開発環境のコスト削減

```hcl
# dev環境では不要なリソースを無効化
locals {
  config = {
    enable_nat_gateway = var.environment == "prod" ? true : false
    enable_backup      = var.environment == "prod" ? true : false
  }
}
```

---

## 10. デプロイ戦略

### 10.1 Terraform apply フロー

```bash
# 1. 初期化
terraform init

# 2. プラン（dry-run）
terraform plan -var-file=terraform.tfvars -out=tfplan

# 3. ユーザー確認
# （AIがプラン結果を解析してユーザーに提示）

# 4. 適用
terraform apply tfplan

# 5. 確認
terraform show
```

### 10.2 CloudFormation デプロイフロー

```bash
# 1. Change Set作成（dry-run）
aws cloudformation create-change-set \
  --stack-name myapp-dev \
  --template-body file://templates/main.yaml \
  --parameters file://parameters/dev.json \
  --change-set-name deploy-$(date +%Y%m%d-%H%M%S)

# 2. Change Setの内容確認
aws cloudformation describe-change-set \
  --stack-name myapp-dev \
  --change-set-name deploy-xxx

# 3. 実行
aws cloudformation execute-change-set \
  --stack-name myapp-dev \
  --change-set-name deploy-xxx
```

---

## 11. ロールバック戦略

### 11.1 Terraform

```bash
# 前のバージョンに戻る
git checkout <previous-commit>
terraform plan
terraform apply

# または、stateから直接
terraform state list
terraform state rm <resource>  # 必要に応じて
```

### 11.2 CloudFormation

```bash
# スタックの更新をロールバック（自動）
# CloudFormationは失敗時に自動でロールバック

# 手動ロールバック
aws cloudformation update-stack \
  --stack-name myapp-prod \
  --use-previous-template
```

---

## 12. CI/CD統合

### 12.1 GitHub Actions での自動デプロイ

```yaml
name: Terraform Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Terraform Init
        run: terraform init
        working-directory: ./environments/dev

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        working-directory: ./environments/dev

      - name: Terraform Apply (on main only)
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve tfplan
        working-directory: ./environments/dev
```

---

## 13. まとめ

IaCの技術標準を守ることで：
- 保守可能なインフラコード
- 安全なデプロイ
- 環境間の一貫性
- コスト最適化

を実現できます。

コード生成時は、必ずこの標準に従ってください。