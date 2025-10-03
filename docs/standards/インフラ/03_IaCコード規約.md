# IaCコード規約（CloudFormation・プロジェクト固有）

## 1. CloudFormation コーディング規約

### 1.1 YAML vs JSON

**採用: YAML**

**理由:**
- コメント記述可能
- 可読性が高い
- 手動編集に適している

```yaml
# ✅ 良い例（YAML）
Resources:
  VPC:  # VPCリソース
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.1.0.0/16
      Tags:
        - Key: Name
          Value: CareApp-POC-VPC-App
```

```json
// ❌ 避ける例（JSON）
{
  "Resources": {
    "VPC": {
      "Type": "AWS::EC2::VPC",
      "Properties": {
        "CidrBlock": "10.1.0.0/16"
      }
    }
  }
}
```

### 1.2 インデント

**ルール:**
- **2スペース**インデント
- タブ文字使用禁止

```yaml
# ✅ 良い例
Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.1.0.0/16

# ❌ 悪い例（4スペース）
Resources:
    VPC:
        Type: AWS::EC2::VPC
```

### 1.3 行の長さ

**ルール:**
- 1行120文字以内推奨
- 長い場合は改行

```yaml
# ✅ 良い例（改行）
Description: |
  CareApp アプリ系ネットワークスタック
  App VPC、サブネット、ALB、セキュリティグループを定義
  依存: CareApp-POC-SharedNetwork（Transit Gateway ID）

# ❌ 悪い例（長すぎる）
Description: CareApp アプリ系ネットワークスタック。App VPC、サブネット、ALB、セキュリティグループを定義。依存: CareApp-POC-SharedNetwork（Transit Gateway ID）
```

## 2. リソース定義規約

### 2.1 リソース定義順序

**依存関係順に記載**

```yaml
Resources:
  # 1. VPC
  VPC:
    Type: AWS::EC2::VPC
    Properties: ...

  # 2. Internet Gateway（VPCに依存）
  InternetGateway:
    Type: AWS::EC2::InternetGateway
    DependsOn: VPC
    Properties: ...

  # 3. Subnets（VPCに依存）
  PublicSubnet1:
    Type: AWS::EC2::Subnet
    DependsOn: VPC
    Properties: ...

  # 4. Route Tables（Subnetsに依存）
  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    DependsOn: PublicSubnet1
    Properties: ...

  # ...（依存関係順）
```

### 2.2 DependsOn使用

**明示的な依存関係がある場合は必ず記載**

```yaml
# ✅ 良い例
Resources:
  VPCGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    DependsOn:
      - VPC
      - InternetGateway
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

# ❌ 悪い例（依存関係不明確）
Resources:
  VPCGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway
```

### 2.3 組み込み関数の使用

**推奨: 短縮形**

```yaml
# ✅ 良い例（短縮形）
Properties:
  VpcId: !Ref VPC
  CidrBlock: !Sub ${VpcCidr}
  SecurityGroups:
    - !ImportValue CareApp-POC-AppNetwork-ECSSecurityGroupID

# ❌ 悪い例（完全形）
Properties:
  VpcId:
    Ref: VPC
  CidrBlock:
    Fn::Sub: ${VpcCidr}
  SecurityGroups:
    - Fn::ImportValue: CareApp-POC-AppNetwork-ECSSecurityGroupID
```

**組み込み関数一覧:**
- `!Ref` - リソース参照
- `!Sub` - 文字列置換
- `!GetAtt` - 属性取得
- `!ImportValue` - Export参照
- `!Join` - 文字列結合
- `!If` - 条件分岐
- `!Equals` - 等価比較

## 3. パラメータ規約

### 3.1 パラメータ定義

**必須フィールド:**
- `Type`
- `Description`

**推奨フィールド:**
- `Default`（オプショナルなパラメータのみ）
- `AllowedValues`（選択肢が限定される場合）
- `AllowedPattern`（正規表現バリデーション）

```yaml
Parameters:
  Environment:
    Type: String
    Description: 環境名（POC/Production）
    AllowedValues:
      - POC
      - Production
    Default: POC

  VpcCidr:
    Type: String
    Description: VPC CIDR（例: 10.1.0.0/16）
    AllowedPattern: ^(10|172|192)\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$
    ConstraintDescription: 有効なプライベートIPアドレス範囲を指定してください

  DBInstanceClass:
    Type: String
    Description: RDSインスタンスクラス
    AllowedValues:
      - db.t3.micro
      - db.t3.small
      - db.m5.large
      - db.m5.xlarge
```

### 3.2 デフォルト値

**POC環境のデフォルト値を設定**

```yaml
Parameters:
  DBInstanceClass:
    Type: String
    Default: db.t3.micro  # POC環境のデフォルト
    AllowedValues:
      - db.t3.micro
      - db.m5.large
```

## 4. Outputs規約

### 4.1 Export必須

**他スタックから参照される可能性があるリソースは必ずExport**

```yaml
Outputs:
  VPCID:
    Description: App VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub ${AWS::StackName}-VPCID

  ALBArn:
    Description: Application Load Balancer ARN
    Value: !Ref ALB
    Export:
      Name: !Sub ${AWS::StackName}-ALBArn

  RDSEndpoint:
    Description: RDS Endpoint
    Value: !GetAtt RDSInstance.Endpoint.Address
    Export:
      Name: !Sub ${AWS::StackName}-RDSEndpoint
```

### 4.2 Export命名規則

```yaml
形式: ${AWS::StackName}-{Resource}

例:
- CareApp-POC-AppNetwork-VPCID
- CareApp-POC-AppNetwork-ALBArn
- CareApp-POC-Database-RDSEndpoint
```

## 5. タグ規約

### 5.1 必須タグ

すべてのリソースに以下を必須：

```yaml
Tags:
  - Key: Name
    Value: !Sub CareApp-${Environment}-{ResourceType}-{Name}
  - Key: Project
    Value: CareApp
  - Key: Environment
    Value: !Ref Environment
  - Key: ManagedBy
    Value: CloudFormation
  - Key: Component
    Value: {Component}  # SharedNetwork/AppNetwork/Database/AppPlatform
```

### 5.2 コスト配分タグ

```yaml
Tags:
  - Key: CostCenter
    Value: Infrastructure  # インフラコスト
  # または
  - Key: CostCenter
    Value: Application  # アプリコスト
```

## 6. セキュリティ規約

### 6.1 Secrets Manager使用

**ハードコード禁止**

```yaml
# ✅ 良い例（Secrets Manager）
Resources:
  DBSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub CareApp-${Environment}-DB-Secret
      GenerateSecretString:
        SecretStringTemplate: '{"username": "admin"}'
        GenerateStringKey: password
        PasswordLength: 32
        ExcludeCharacters: '"@/\'

  RDSInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      MasterUsername: !Sub '{{resolve:secretsmanager:${DBSecret}:SecretString:username}}'
      MasterUserPassword: !Sub '{{resolve:secretsmanager:${DBSecret}:SecretString:password}}'

# ❌ 悪い例（ハードコード）
Resources:
  RDSInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      MasterUsername: admin
      MasterUserPassword: MyPassword123!
```

### 6.2 最小権限IAMロール

```yaml
# ✅ 良い例（必要な権限のみ）
ECSTaskRole:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Principal:
            Service: ecs-tasks.amazonaws.com
          Action: sts:AssumeRole
    Policies:
      - PolicyName: S3Access
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Action:
                - s3:GetObject
                - s3:PutObject
              Resource: !Sub ${S3Bucket.Arn}/*

# ❌ 悪い例（権限過剰）
ECSTaskRole:
  Type: AWS::IAM::Role
  Properties:
    ManagedPolicyArns:
      - arn:aws:iam::aws:policy/AdministratorAccess
```

### 6.3 セキュリティグループ

```yaml
# ✅ 良い例（最小権限）
ECSSecurityGroupIngress:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !Ref ECSSecurityGroup
    IpProtocol: tcp
    FromPort: 8080
    ToPort: 8080
    SourceSecurityGroupId: !Ref ALBSecurityGroup  # 特定のSGのみ許可

# ❌ 悪い例（全開放）
ECSSecurityGroupIngress:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !Ref ECSSecurityGroup
    IpProtocol: tcp
    FromPort: 0
    ToPort: 65535
    CidrIp: 0.0.0.0/0  # 全開放は禁止
```

## 7. 条件分岐規約

### 7.1 Conditions使用

```yaml
Conditions:
  IsProduction: !Equals [!Ref Environment, Production]
  IsPOC: !Equals [!Ref Environment, POC]
  EnableMultiAZ: !Equals [!Ref Environment, Production]

Resources:
  # 本番のみMulti-AZ
  RDSInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      MultiAZ: !If [EnableMultiAZ, true, false]
      DBInstanceClass: !If [IsProduction, db.m5.large, db.t3.micro]

  # 本番のみWAF作成
  WAF:
    Type: AWS::WAFv2::WebACL
    Condition: IsProduction
    Properties:
      # ...
```

## 8. DeletionPolicy規約

### 8.1 本番環境の保護

```yaml
Resources:
  # 本番RDSは削除時にスナップショット作成
  RDSInstance:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: !If [IsProduction, Snapshot, Delete]
    UpdateReplacePolicy: !If [IsProduction, Snapshot, Delete]
    Properties:
      # ...

  # 本番S3は削除保持
  S3Bucket:
    Type: AWS::S3::Bucket
    DeletionPolicy: !If [IsProduction, Retain, Delete]
    Properties:
      # ...
```

## 9. エラーハンドリング規約

### 9.1 CreationPolicy使用

```yaml
# ECSサービスの正常起動を待つ
ECSService:
  Type: AWS::ECS::Service
  CreationPolicy:
    ResourceSignal:
      Timeout: PT15M  # 15分タイムアウト
  Properties:
    # ...
```

### 9.2 UpdatePolicy使用

```yaml
# Auto Scalingグループの更新ポリシー
AutoScalingGroup:
  Type: AWS::AutoScaling::AutoScalingGroup
  UpdatePolicy:
    AutoScalingRollingUpdate:
      MinInstancesInService: 1
      MaxBatchSize: 1
      PauseTime: PT5M
  Properties:
    # ...
```

## 10. ドキュメント規約

### 10.1 ファイルヘッダー必須

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: |
  CareApp アプリ系ネットワークスタック

  このテンプレートは以下を定義します：
  - App VPC（10.1.0.0/16）
  - パブリック/プライベートサブネット
  - Application Load Balancer
  - セキュリティグループ（ALB、ECS、RDS）

  依存スタック:
  - CareApp-POC-SharedNetwork（Transit Gateway ID参照）

  作成日: 2025-10-03
  管理者: インフラチーム

# ...
```

### 10.2 複雑なロジックにコメント

```yaml
# Transit Gateway Attachmentの設定
# Shared VPCとApp VPCを接続し、相互通信を可能にする
TransitGatewayAttachment:
  Type: AWS::EC2::TransitGatewayAttachment
  Properties:
    TransitGatewayId:
      Fn::ImportValue: !Sub CareApp-${Environment}-SharedNetwork-TransitGatewayID
    VpcId: !Ref VPC
    SubnetIds:
      - !Ref PrivateSubnetApp1  # プライベートサブネットに配置
    Tags:
      - Key: Name
        Value: !Sub CareApp-${Environment}-TGW-Attachment-App
```

---

**作成日**: 2025-10-03
**参考資料**:
- [CloudFormation Template Reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html)
- [YAML Syntax](https://yaml.org/spec/1.2/spec.html)
