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

### 1.2 AWS IaCツールの選定

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

### 2.2 CloudFormation の標準構造（ネストスタック）

**推奨構造（実運用フィードバック反映）：**

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

## 8. 可用性・冗長化

### 8.1 マルチAZ構成

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