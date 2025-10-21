# CloudFormation詳細設計

> AWS Multi-Account Sample Application - Infrastructure as Code

---

## 1. はじめに

### 1.1 本ドキュメントの目的

本書は、AWS Multi-Account Sample ApplicationのCloudFormationテンプレート詳細設計書です。
基本設計書で定義されたインフラ構成を、CloudFormationで実装するための詳細仕様を定義します。

### 1.2 対象範囲

| Account | スタック | 対象リソース |
|---------|---------|------------|
| Platform Account | `platform-stack` | Shared VPC, Transit Gateway, Client VPN |
| Service Account | `service-network-stack` | Service VPC, Transit Gateway Attachment |
| Service Account | `service-database-stack` | RDS PostgreSQL, Secrets Manager |
| Service Account | `service-compute-stack` | ECS Fargate, ALB, Auto Scaling |
| Service Account | `service-monitoring-stack` | CloudWatch Alarms, Dashboard, SNS |

---

## 2. スタック分割戦略

### 2.1 分割方針

**採用パターン**: レイヤー別分割 + ネストスタック

**分割理由**:

| 理由 | 詳細 |
|------|------|
| **責務の分離** | Network/Database/Compute/Monitoringで明確に分離 |
| **部分的な更新** | 一部のスタックのみ更新可能（リスク低減） |
| **ロールバックの粒度** | 失敗時に該当スタックのみロールバック |
| **保守性** | 各スタック300行以内を目標、レビューしやすい |

### 2.2 スタック依存関係

```
Platform Account
    └── platform-stack (親スタック)
         ├── nested/network.yaml
         └── nested/connectivity.yaml

Service Account
    ├── service-network-stack (1番目)
    ├── service-database-stack (2番目、Network依存)
    ├── service-compute-stack (3番目、Network + Database依存)
    └── service-monitoring-stack (4番目、Compute依存)
```

**デプロイ順序**:
1. Platform Account: `platform-stack`
2. Service Account: `service-network-stack`
3. Service Account: `service-database-stack`
4. Service Account: `service-compute-stack`
5. Service Account: `service-monitoring-stack`

---

## 3. Platform Account 詳細設計

### 3.1 スタック構成

**親スタック**: `infra/platform/stack.yaml`

**ネストスタック**:
- `infra/platform/nested/network.yaml` - VPC, Subnets, NAT Gateway
- `infra/platform/nested/connectivity.yaml` - Transit Gateway, Client VPN

### 3.2 stack.yaml（親スタック）

**目的**: ネストスタックの統合管理、パラメータ受け渡し

**Parameters**:

| パラメータ名 | 型 | デフォルト値 | 説明 |
|------------|-------|------------|------|
| ProjectName | String | myapp | プロジェクト名 |
| Environment | String | dev | 環境名（dev/prod） |
| ServiceAccountId | String | - | Service AccountのAWSアカウントID（12桁） |
| VpcCidr | String | 10.0.0.0/16 | Platform VPC CIDR |
| ClientVpnCidr | String | 172.16.0.0/22 | Client VPN CIDR |
| ServerCertificateArn | String | - | Client VPNサーバー証明書ARN（ACM） |
| ClientRootCertificateArn | String | - | Client VPNクライアント証明書ARN（ACM） |
| NestedTemplatesBucketName | String | - | ネストテンプレート格納S3バケット名 |

**Resources**:

| リソース論理ID | タイプ | 説明 |
|--------------|-------|------|
| NetworkStack | AWS::CloudFormation::Stack | ネットワークスタック |
| ConnectivityStack | AWS::CloudFormation::Stack | 接続スタック（Transit Gateway, Client VPN） |

**Outputs**:

| Output名 | 値 | Export名 | 用途 |
|---------|-----|---------|------|
| VpcId | NetworkStack.Outputs.VpcId | `${ProjectName}-${Environment}-platform-vpc-id` | Service Accountから参照 |
| TransitGatewayId | ConnectivityStack.Outputs.TransitGatewayId | `${ProjectName}-${Environment}-transit-gateway-id` | Service Accountから参照 |
| ClientVpnEndpointId | ConnectivityStack.Outputs.ClientVpnEndpointId | `${ProjectName}-${Environment}-client-vpn-endpoint-id` | - |

### 3.3 nested/network.yaml

**目的**: Platform Shared VPCの構築

**Resources**:

| リソース | タイプ | 説明 | 推定行数 |
|---------|-------|------|---------|
| SharedVPC | AWS::EC2::VPC | 10.0.0.0/16 | 10行 |
| InternetGateway | AWS::EC2::InternetGateway | IGW | 8行 |
| PublicSubnet1 | AWS::EC2::Subnet | 10.0.1.0/24 (AZ-1a) | 12行 |
| PublicSubnet2 | AWS::EC2::Subnet | 10.0.2.0/24 (AZ-1c) | 12行 |
| PrivateSubnet1 | AWS::EC2::Subnet | 10.0.11.0/24 (AZ-1a) | 12行 |
| PrivateSubnet2 | AWS::EC2::Subnet | 10.0.12.0/24 (AZ-1c) | 12行 |
| NatGateway1 | AWS::EC2::NatGateway | AZ-1a NAT | 12行 |
| NatGateway2 | AWS::EC2::NatGateway | AZ-1c NAT | 12行 |
| PublicRouteTable | AWS::EC2::RouteTable | Public用ルートテーブル | 10行 |
| PrivateRouteTable1 | AWS::EC2::RouteTable | Private AZ-1a用 | 10行 |
| PrivateRouteTable2 | AWS::EC2::RouteTable | Private AZ-1c用 | 10行 |
| （Routes, Associations等） | - | ルート設定 | 約60行 |

**推定合計**: 約180-200行

**CIDR計算**:
```yaml
# !Cidr 関数で自動計算
PublicSubnet1:
  CidrBlock: !Select [0, !Cidr [!Ref VpcCidr, 4, 8]]  # 10.0.1.0/24
PublicSubnet2:
  CidrBlock: !Select [1, !Cidr [!Ref VpcCidr, 4, 8]]  # 10.0.2.0/24
PrivateSubnet1:
  CidrBlock: !Select [2, !Cidr [!Ref VpcCidr, 4, 8]]  # 10.0.11.0/24
PrivateSubnet2:
  CidrBlock: !Select [3, !Cidr [!Ref VpcCidr, 4, 8]]  # 10.0.12.0/24
```

### 3.4 nested/connectivity.yaml

**目的**: Transit Gateway、Client VPNの構築

**Resources**:

| リソース | タイプ | 説明 | 推定行数 |
|---------|-------|------|---------|
| TransitGateway | AWS::EC2::TransitGateway | TGW | 15行 |
| TransitGatewayAttachmentPlatform | AWS::EC2::TransitGatewayAttachment | Platform VPC接続 | 12行 |
| TransitGatewayRouteTablePlatform | AWS::EC2::TransitGatewayRouteTable | Platform用ルートテーブル | 10行 |
| TransitGatewayResourceShare | AWS::RAM::ResourceShare | Service Accountに共有 | 15行 |
| ClientVpnEndpoint | AWS::EC2::ClientVpnEndpoint | VPN Endpoint | 25行 |
| ClientVpnTargetNetworkAssociation1 | AWS::EC2::ClientVpnTargetNetworkAssociation | AZ-1a接続 | 10行 |
| ClientVpnTargetNetworkAssociation2 | AWS::EC2::ClientVpnTargetNetworkAssociation | AZ-1c接続 | 10行 |
| ClientVpnAuthorizationRuleSharedVpc | AWS::EC2::ClientVpnAuthorizationRule | Shared VPCアクセス許可 | 10行 |
| ClientVpnAuthorizationRuleServiceVpc | AWS::EC2::ClientVpnAuthorizationRule | Service VPCアクセス許可 | 10行 |
| ClientVpnRouteToTransitGateway | AWS::EC2::ClientVpnRoute | TGW向けルート | 12行 |
| ClientVpnSecurityGroup | AWS::EC2::SecurityGroup | VPN用SG | 18行 |
| VpnLogGroup | AWS::Logs::LogGroup | VPN接続ログ | 8行 |
| （VPC Routes等） | - | ルート追加 | 約40行 |

**推定合計**: 約200-220行

**Transit Gateway設計ポイント**:
```yaml
TransitGateway:
  Properties:
    DefaultRouteTableAssociation: disable  # 明示的なルートテーブル管理
    DefaultRouteTablePropagation: disable  # 明示的なルートテーブル管理
    DnsSupport: enable
    VpnEcmpSupport: enable
```

---

## 4. Service Account 詳細設計

### 4.1 スタック構成

| スタック名 | ファイルパス | 目的 |
|-----------|------------|------|
| service-network-stack | `infra/service/01-network.yaml` | Service VPC, Transit Gateway Attachment |
| service-database-stack | `infra/service/02-database.yaml` | RDS PostgreSQL, Secrets Manager |
| service-compute-stack | `infra/service/03-compute.yaml` | ECS, ALB, Auto Scaling |
| service-monitoring-stack | `infra/service/04-monitoring.yaml` | CloudWatch Alarms, Dashboard |

### 4.2 01-network.yaml

**目的**: Service VPCとTransit Gateway接続

**Parameters**:

| パラメータ名 | 型 | デフォルト値 | 説明 |
|------------|-------|------------|------|
| ProjectName | String | myapp | プロジェクト名 |
| Environment | String | dev | 環境名 |
| VpcCidr | String | 10.1.0.0/16 | Service VPC CIDR |
| PlatformVpcCidr | String | 10.0.0.0/16 | Platform VPC CIDR（ルーティング用） |
| TransitGatewayId | String | - | Platform AccountのTGW ID（RAMで共有） |
| TransitGatewayRouteTableId | String | - | Platform AccountのTGW Route Table ID |

**Resources**（推定行数）:

| リソース | タイプ | 推定行数 |
|---------|-------|---------|
| ServiceVPC | AWS::EC2::VPC | 10行 |
| InternetGateway | AWS::EC2::InternetGateway | 8行 |
| PublicSubnet x2 | AWS::EC2::Subnet | 24行 (12行 x2) |
| PrivateSubnet x2 | AWS::EC2::Subnet | 24行 (12行 x2) |
| NatGateway x2 | AWS::EC2::NatGateway | 24行 (12行 x2) |
| TransitGatewayAttachmentService | AWS::EC2::TransitGatewayAttachment | 12行 |
| PublicRouteTable | AWS::EC2::RouteTable | 10行 |
| PrivateRouteTable x2 | AWS::EC2::RouteTable | 20行 (10行 x2) |
| Routes（Internet, TGW） | AWS::EC2::Route | 約50行 |
| Route Table Associations | AWS::EC2::SubnetRouteTableAssociation | 約30行 |
| Outputs | - | 約50行 |

**推定合計**: 約260-280行

### 4.3 02-database.yaml

**目的**: RDS PostgreSQL、Secrets Manager

**Parameters**:

| パラメータ名 | 型 | デフォルト値 | 説明 |
|------------|-------|------------|------|
| ProjectName | String | myapp | プロジェクト名 |
| Environment | String | dev | 環境名 |
| DBInstanceClass | String | db.t3.medium | RDSインスタンスクラス |
| DBAllocatedStorage | Number | 100 | ストレージ容量（GB） |
| DBMaxAllocatedStorage | Number | 200 | Auto Scaling最大容量 |

**Resources**（推定行数）:

| リソース | タイプ | 推定行数 |
|---------|-------|---------|
| DBSubnetGroup | AWS::RDS::DBSubnetGroup | 12行 |
| DBSecurityGroup | AWS::EC2::SecurityGroup | 15行 |
| DBSecret | AWS::SecretsManager::Secret | 18行 |
| DBSecretAttachment | AWS::SecretsManager::SecretTargetAttachment | 8行 |
| DBInstance | AWS::RDS::DBInstance | 50行 |
| DBEncryptionKey | AWS::KMS::Key | 30行 |
| DBEncryptionKeyAlias | AWS::KMS::Alias | 8行 |
| RDSMonitoringRole | AWS::IAM::Role | 20行 |
| Parameter Store（DBHost等） | AWS::SSM::Parameter | 約30行 (10行 x3) |
| Outputs | - | 約30行 |

**推定合計**: 約220-240行

**Secrets Manager設計**:
```yaml
DBSecret:
  Type: AWS::SecretsManager::Secret
  Properties:
    GenerateSecretString:
      SecretStringTemplate: '{"username": "postgres"}'
      GenerateStringKey: password
      PasswordLength: 32
      ExcludeCharacters: '"@/\'
      RequireEachIncludedType: true

# CloudFormationでDynamic Reference使用
DBInstance:
  Properties:
    MasterUsername: !Sub '{{resolve:secretsmanager:${DBSecret}:SecretString:username}}'
    MasterUserPassword: !Sub '{{resolve:secretsmanager:${DBSecret}:SecretString:password}}'
```

### 4.4 03-compute.yaml

**目的**: ECS Fargate、ALB、Auto Scaling

**⚠️ 注意**: このファイルは**推定600-700行**になる見込みです。

**Resources**（推定行数）:

| リソース | タイプ | 推定行数 |
|---------|-------|---------|
| ECSCluster | AWS::ECS::Cluster | 10行 |
| ECSTaskExecutionRole | AWS::IAM::Role | 40行 |
| ECSTaskRole | AWS::IAM::Role | 30行 |
| PublicWebLogGroup | AWS::Logs::LogGroup | 8行 |
| PublicWebTaskDefinition | AWS::ECS::TaskDefinition | 80行 |
| PublicWebSecurityGroup | AWS::EC2::SecurityGroup | 25行 |
| PublicALB | AWS::ElasticLoadBalancingV2::LoadBalancer | 20行 |
| PublicALBSecurityGroup | AWS::EC2::SecurityGroup | 20行 |
| PublicWebTargetGroup | AWS::ElasticLoadBalancingV2::TargetGroup | 25行 |
| PublicALBListenerHTTPS | AWS::ElasticLoadBalancingV2::Listener | 15行 |
| PublicALBListenerHTTP | AWS::ElasticLoadBalancingV2::Listener | 12行 |
| PublicWebService | AWS::ECS::Service | 40行 |
| PublicWebAutoScalingTarget | AWS::ApplicationAutoScaling::ScalableTarget | 15行 |
| PublicWebAutoScalingPolicy | AWS::ApplicationAutoScaling::ScalingPolicy | 15行 |
| （Admin Service - 同様の構成） | - | 約280行 |
| （Batch Service - Scheduled Task） | - | 約100行 |
| RDSSecurityGroupIngress x3 | AWS::EC2::SecurityGroupIngress | 約30行 |
| Outputs | - | 約50行 |

**推定合計**: 約650-700行

**⚠️ 300行超過の理由**:
1. **3つのサービス（Public/Admin/Batch）を含む**
   - 各サービスごとにTask Definition、Service、ALB、Auto Scalingが必要
   - 分割するとかえって設定の重複が発生

2. **将来的な分割案**:
   - `03-compute.yaml`（親スタック、200行）
   - `nested/ecs-public.yaml`（250行）
   - `nested/ecs-admin.yaml`（250行）
   - `nested/ecs-batch.yaml`（150行）

3. **現時点の判断**:
   - **検証・デモ用のため、1ファイルで実装**
   - 本番化時にネスト構造に分割を検討

### 4.5 04-monitoring.yaml

**目的**: CloudWatch Alarms、Dashboard、SNS

**Resources**（推定行数）:

| リソース | タイプ | 推定行数 |
|---------|-------|---------|
| CriticalAlertsTopic | AWS::SNS::Topic | 10行 |
| WarningAlertsTopic | AWS::SNS::Topic | 10行 |
| ECSPublicCPUAlarm | AWS::CloudWatch::Alarm | 20行 |
| ECSPublicMemoryAlarm | AWS::CloudWatch::Alarm | 20行 |
| （各サービスのAlarm）| - | 約120行 |
| RDSCPUAlarm | AWS::CloudWatch::Alarm | 20行 |
| RDSConnectionsAlarm | AWS::CloudWatch::Alarm | 20行 |
| （RDS関連Alarm） | - | 約80行 |
| ALBTargetHealthAlarm | AWS::CloudWatch::Alarm | 20行 |
| （ALB関連Alarm） | - | 約60行 |
| Dashboard | AWS::CloudWatch::Dashboard | 80行 |
| Outputs | - | 約20行 |

**推定合計**: 約460-500行

**⚠️ 300行超過の理由**:
1. **多数のAlarm定義**
   - ECS（Public/Admin/Batch）: 各3-4 Alarm
   - RDS: 6-7 Alarm
   - ALB: 4-5 Alarm
   - 合計約20個のAlarm

2. **将来的な分割案**:
   - `04-monitoring.yaml`（親スタック、100行）
   - `nested/alarms-ecs.yaml`（200行）
   - `nested/alarms-rds.yaml`（150行）
   - `nested/dashboard.yaml`（100行）

3. **現時点の判断**:
   - **検証・デモ用のため、1ファイルで実装**
   - 本番化時にネスト構造に分割を検討

---

## 5. パラメータファイル設計

### 5.1 環境別パラメータファイル

**Platform Account**:
- `infra/platform/parameters-dev.json`
- `infra/platform/parameters-prod.json`

**Service Account**:
- `infra/service/parameters-dev.json`
- `infra/service/parameters-prod.json`

### 5.2 parameters-dev.json（Platform Account）

```json
[
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "myapp"
  },
  {
    "ParameterKey": "Environment",
    "ParameterValue": "dev"
  },
  {
    "ParameterKey": "ServiceAccountId",
    "ParameterValue": "123456789012"
  },
  {
    "ParameterKey": "VpcCidr",
    "ParameterValue": "10.0.0.0/16"
  },
  {
    "ParameterKey": "ClientVpnCidr",
    "ParameterValue": "172.16.0.0/22"
  },
  {
    "ParameterKey": "ServerCertificateArn",
    "ParameterValue": "arn:aws:acm:ap-northeast-1:123456789012:certificate/xxx"
  },
  {
    "ParameterKey": "ClientRootCertificateArn",
    "ParameterValue": "arn:aws:acm:ap-northeast-1:123456789012:certificate/yyy"
  },
  {
    "ParameterKey": "NestedTemplatesBucketName",
    "ParameterValue": "myapp-cfn-templates-123456789012"
  }
]
```

### 5.3 parameters-prod.json（差分のみ）

```json
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "prod"
  },
  {
    "ParameterKey": "VpcCidr",
    "ParameterValue": "10.2.0.0/16"
  }
]
```

---

## 6. Outputs/Export戦略

### 6.1 Export設計

**基本方針**: スタック間でリソースを参照するため、重要なリソースIDをExport

**命名規則**: `${ProjectName}-${Environment}-${ResourceType}-${Identifier}`

**Platform Account Exports**:

| Export名 | 値 | 参照元 |
|---------|-----|--------|
| `myapp-dev-platform-vpc-id` | Platform VPC ID | - |
| `myapp-dev-transit-gateway-id` | Transit Gateway ID | Service Account（必須） |
| `myapp-dev-transit-gateway-route-table-id` | TGW Route Table ID | Service Account（必須） |

**Service Account Exports**:

| Export名 | 値 | 参照元 |
|---------|-----|--------|
| `myapp-dev-service-vpc-id` | Service VPC ID | Database, Compute, Monitoring |
| `myapp-dev-service-private-subnet-1a-id` | Private Subnet 1a ID | Database, Compute |
| `myapp-dev-service-private-subnet-1c-id` | Private Subnet 1c ID | Database, Compute |
| `myapp-dev-db-endpoint` | RDS Endpoint | Compute |
| `myapp-dev-db-secret-arn` | Secrets Manager ARN | Compute |
| `myapp-dev-rds-sg-id` | RDS Security Group ID | Compute（Ingress追加用） |

### 6.2 ImportValue使用例

```yaml
# 03-compute.yamlでRDS Security Group IDをインポート
RDSSecurityGroupIngressFromPublicWeb:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !ImportValue
      Fn::Sub: ${ProjectName}-${Environment}-rds-sg-id
    IpProtocol: tcp
    FromPort: 5432
    ToPort: 5432
    SourceSecurityGroupId: !Ref PublicWebSecurityGroup
```

---

## 7. セキュリティグループ設計

### 7.1 SecurityGroup一覧

| SecurityGroup名 | 用途 | Ingress | Egress |
|---------------|------|---------|--------|
| PublicALBSecurityGroup | Public Web用ALB | 0.0.0.0/0:443, 0.0.0.0/0:80 | All |
| AdminALBSecurityGroup | Admin用ALB | 10.0.0.0/16:443（Platform VPCのみ） | All |
| PublicWebSecurityGroup | Public Web ECS | ALB Public SG:8080 | HTTPS:443, RDS:5432 |
| AdminSecurityGroup | Admin ECS | ALB Admin SG:8080 | HTTPS:443, RDS:5432 |
| BatchSecurityGroup | Batch ECS | - | HTTPS:443, RDS:5432 |
| RDSSecurityGroup | RDS PostgreSQL | ECS SGs:5432 | - |
| ClientVpnSecurityGroup | Client VPN Endpoint | 172.16.0.0/22:All | All |

### 7.2 RDS Security Group Ingress設計

**問題**: RDS Security GroupはDatabase Stackで作成されるが、ECS Security GroupsはCompute Stackで作成される

**解決策**: Compute Stackで`AWS::EC2::SecurityGroupIngress`を個別に作成

```yaml
# 03-compute.yamlで追加
RDSSecurityGroupIngressFromPublicWeb:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !ImportValue ${ProjectName}-${Environment}-rds-sg-id
    IpProtocol: tcp
    FromPort: 5432
    ToPort: 5432
    SourceSecurityGroupId: !Ref PublicWebSecurityGroup
    Description: Allow from Public Web ECS

RDSSecurityGroupIngressFromAdmin:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !ImportValue ${ProjectName}-${Environment}-rds-sg-id
    IpProtocol: tcp
    FromPort: 5432
    ToPort: 5432
    SourceSecurityGroupId: !Ref AdminSecurityGroup
    Description: Allow from Admin ECS

RDSSecurityGroupIngressFromBatch:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !ImportValue ${ProjectName}-${Environment}-rds-sg-id
    IpProtocol: tcp
    FromPort: 5432
    ToPort: 5432
    SourceSecurityGroupId: !Ref BatchSecurityGroup
    Description: Allow from Batch ECS
```

---

## 8. タグ戦略

### 8.1 必須タグ

| タグキー | 値 | 用途 |
|---------|-----|------|
| Name | `${ProjectName}-${Environment}-${ResourceType}` | リソース識別 |
| Environment | `${Environment}` | 環境識別 |
| ManagedBy | CloudFormation | 管理ツール識別 |
| Project | `${ProjectName}` | プロジェクト識別 |

### 8.2 タグ付与例

```yaml
Resources:
  ServiceVPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCidr
      Tags:
        - Key: Name
          Value: !Sub ${ProjectName}-${Environment}-service-vpc
        - Key: Environment
          Value: !Ref Environment
        - Key: ManagedBy
          Value: CloudFormation
        - Key: Project
          Value: !Ref ProjectName
```

---

## 9. エラーハンドリング

### 9.1 DeletionPolicy

| リソース | DeletionPolicy | 理由 |
|---------|---------------|------|
| RDS PostgreSQL | Snapshot | データ保護 |
| S3 Bucket（ログ用） | Retain | ログ保持 |
| KMS Key | Retain | 暗号化キー保護 |
| その他 | Delete（デフォルト） | 検証用のため削除 |

```yaml
DBInstance:
  Type: AWS::RDS::DBInstance
  DeletionPolicy: Snapshot  # スタック削除時にスナップショット作成
  Properties:
    # ...
```

### 9.2 よくあるエラーと対処法

| エラーコード | 原因 | 対処法 |
|-------------|------|--------|
| CIDR重複 | VPC CIDR重複 | パラメータファイルでCIDR変更 |
| Export名重複 | 同名Export存在 | 既存スタック削除またはExport名変更 |
| リソース制限超過 | AWS Service Quotas | AWS Supportに上限緩和申請 |
| Cross-Stack参照エラー | 参照先スタック未作成 | デプロイ順序確認 |

---

## 10. 実装方針 ⭐⭐⭐

### 10.1 ファイル分割方針

**基本方針**: レイヤー別分割 + 1ファイル300行以内を目標

**ディレクトリ構成**:

```
infra/
├── platform/
│   ├── stack.yaml              # 親スタック（推定: 200行）
│   ├── parameters-dev.json     # devパラメータ
│   ├── parameters-prod.json    # prodパラメータ
│   └── nested/
│       ├── network.yaml        # VPC, Subnets（推定: 200行）
│       └── connectivity.yaml   # TGW, Client VPN（推定: 220行）
└── service/
    ├── 01-network.yaml         # Service VPC（推定: 280行）
    ├── 02-database.yaml        # RDS, Secrets Manager（推定: 240行）
    ├── 03-compute.yaml         # ECS, ALB（推定: 700行 ⚠️）
    ├── 04-monitoring.yaml      # CloudWatch（推定: 500行 ⚠️）
    ├── parameters-dev.json
    └── parameters-prod.json
```

### 10.2 推定行数と分割理由

| ファイル | 推定行数 | 判定 | 理由・対応 |
|---------|---------|------|-----------|
| platform/stack.yaml | 200行 | ✅ 適合 | ネストスタックの統合管理のみ、シンプル |
| platform/nested/network.yaml | 200行 | ✅ 適合 | VPC、サブネット、NAT Gateway |
| platform/nested/connectivity.yaml | 220行 | ✅ 適合 | Transit Gateway、Client VPN |
| service/01-network.yaml | 280行 | ✅ 適合 | Service VPC、TGW Attachment、ルート設定 |
| service/02-database.yaml | 240行 | ✅ 適合 | RDS、Secrets Manager、KMS |
| service/03-compute.yaml | **700行** | ⚠️ 超過 | 3サービス（Public/Admin/Batch）含む |
| service/04-monitoring.yaml | **500行** | ⚠️ 超過 | 約20個のAlarm + Dashboard |

**300行超過ファイルの対応方針**:

#### service/03-compute.yaml（700行）

**超過理由**:
- 3つのサービス（Public Web、Admin、Batch）を含む
- 各サービスごとにTask Definition、Service、ALB、Target Group、Auto Scalingが必要
- 単純計算: 1サービス約230行 x 3 = 690行

**現時点の判断**:
- ✅ **検証・デモ用のため、1ファイルで実装**
- 理由: 各サービスの設定が似ており、1ファイルで比較・レビューしやすい
- ネスト構造に分割するとかえって設定の重複・参照が複雑化

**将来的な改善案（本番化時）**:
```
service/
├── 03-compute.yaml          # 親スタック（200行）
└── nested/
    ├── ecs-public.yaml      # Public Web（250行）
    ├── ecs-admin.yaml       # Admin Dashboard（250行）
    └── ecs-batch.yaml       # Batch Processing（150行）
```

#### service/04-monitoring.yaml（500行）

**超過理由**:
- 約20個のCloudWatch Alarmを定義（各20行）
- CloudWatch Dashboard（80行）
- SNS Topics（20行）

**現時点の判断**:
- ✅ **検証・デモ用のため、1ファイルで実装**
- 理由: 監視設定は一括で確認したい、分割するとかえって全体像が見えにくい

**将来的な改善案（本番化時）**:
```
service/
├── 04-monitoring.yaml       # 親スタック（100行）
└── nested/
    ├── alarms-ecs.yaml      # ECS Alarms（200行）
    ├── alarms-rds.yaml      # RDS Alarms（150行）
    ├── alarms-alb.yaml      # ALB Alarms（100行）
    └── dashboard.yaml       # Dashboard（100行）
```

### 10.3 技術標準の適用

**参照標準**: `.claude/docs/40_standards/45_cloudformation.md`

| 技術標準項目 | 適用状況 | 詳細 |
|------------|---------|------|
| **Change Sets必須** | ✅ 適用 | デプロイスクリプトで実装（後述） |
| **パラメータ駆動** | ✅ 適用 | Environment、ProjectName、VpcCidr等 |
| **Outputs/Export** | ✅ 適用 | VPC ID、Subnet IDs、TGW ID等 |
| **ファイル分割（300行推奨）** | ⚠️ 一部超過 | 03-compute.yaml、04-monitoring.yamlが超過<br>→ 検証用のため許容、本番化時に分割 |
| **命名規則** | ✅ 適用 | `${ProjectName}-${Environment}-${ResourceType}` |
| **タグ戦略** | ✅ 適用 | Name、Environment、ManagedBy、Project |
| **DeletionPolicy** | ✅ 適用 | RDS: Snapshot、S3/KMS: Retain |

### 10.4 実装時の注意事項

**1. デプロイ順序を厳守**

```bash
# ❌ Bad: 順序を無視
aws cloudformation deploy --template-file service/03-compute.yaml  # NG: VPC未作成

# ✅ Good: 順序を守る
# 1. Platform Account
aws cloudformation create-change-set --template-file platform/stack.yaml

# 2. Service Account（順番に）
aws cloudformation create-change-set --template-file service/01-network.yaml
aws cloudformation create-change-set --template-file service/02-database.yaml
aws cloudformation create-change-set --template-file service/03-compute.yaml
aws cloudformation create-change-set --template-file service/04-monitoring.yaml
```

**2. Cross-Stack参照の確認**

実装時に以下を確認：
- [ ] Export名が正しいか（`!Sub ${ProjectName}-${Environment}-xxx`）
- [ ] ImportValue参照先が正しいか
- [ ] 参照先スタックが先にデプロイされているか

**3. Secrets Manager Dynamic Reference**

```yaml
# ✅ Good: Dynamic Reference使用
MasterUserPassword: !Sub '{{resolve:secretsmanager:${DBSecret}:SecretString:password}}'

# ❌ Bad: ハードコード
MasterUserPassword: "MyPassword123"  # 絶対NG
```

**4. Security Group Ingress追加**

RDS Security GroupへのIngress追加は、Compute Stackで実施：
```yaml
# 03-compute.yaml
RDSSecurityGroupIngressFromPublicWeb:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !ImportValue ${ProjectName}-${Environment}-rds-sg-id
    # ...
```

### 10.5 実装チェックリスト

実装前に以下を確認：

- [ ] 設計書の「10. 実装方針」を読んだ
- [ ] ファイル分割方針を理解した
- [ ] 推定行数を確認した
- [ ] 技術標準（`.claude/docs/40_standards/45_cloudformation.md`）を確認した
- [ ] デプロイ順序を理解した

実装中に以下を確認：

- [ ] パラメータ駆動になっているか（ハードコード禁止）
- [ ] Outputs/Exportが適切か
- [ ] 命名規則に従っているか
- [ ] タグが付与されているか
- [ ] DeletionPolicyが適切か

実装後に以下を確認：

- [ ] 推定行数と実際の行数を比較
- [ ] 300行を大きく超過していないか
- [ ] 超過している場合、理由を設計書に記載したか

---

## 11. 次のステップ

詳細設計書の次のドキュメント：
- [02_データベース詳細設計.md](02_データベース詳細設計.md)
- [03_アプリケーション詳細設計.md](03_アプリケーション詳細設計.md)
- [04_監視詳細設計.md](04_監視詳細設計.md)
- [05_デプロイ手順.md](05_デプロイ手順.md)

---

## 付録

### A. 変更履歴

| 日付 | 版数 | 変更内容 | 承認者 |
|------|------|----------|--------|
| 2025-10-21 | 1.0 | 初版作成（実装方針含む） | - |

### B. 参考資料

- AWS CloudFormation公式ドキュメント: https://docs.aws.amazon.com/cloudformation/
- AWS Transit Gateway公式ドキュメント: https://docs.aws.amazon.com/vpc/latest/tgw/
- AWS Client VPN公式ドキュメント: https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/
