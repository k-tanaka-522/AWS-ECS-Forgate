# CloudFormation詳細設計書

## 1. 概要

### 1.1 目的と責任範囲
本ドキュメントでは、ECSForgateプロジェクトにおけるCloudFormationを用いたインフラストラクチャのコード化（IaC）の詳細設計を定義します。CloudFormationテンプレートの構造、ネストスタックの活用、環境分離の方法、パラメータ管理などを詳細に説明し、効率的で保守性の高いインフラ管理を実現します。

> **注意**: CloudFormationテンプレートの実際のデプロイ手順と段階的な適用方法については、`iac/cloudformation/README.md`を参照してください。このREADMEファイルには、メインスタックのデプロイ方法、ネストスタックの段階的追加手順、およびトラブルシューティング方法などが詳細に記載されています。

### 1.2 設計のポイント
- ネストスタックを活用した構造化されたテンプレート管理
- 環境（開発・ステージング・本番）ごとの設定分離
- 共通コンポーネントの再利用性向上
- 変更管理とデプロイの効率化
- セキュリティとコンプライアンスの確保
- 依存関係の明確化と管理

## 2. CloudFormationアーキテクチャの概要

### 2.1 全体構造図

```
┌───────────────────────────────────────────────────────────────────┐
│                       メインスタックテンプレート                      │
│                      (environment-main.yaml)                       │
└─────────────────────────────────┬─────────────────────────────────┘
               ┌──────────────────┼───────────────────┐
               │                  │                   │
               ▼                  ▼                   ▼
┌─────────────────────┐ ┌──────────────────┐ ┌──────────────────────┐
│  ネットワークスタック   │ │  コンピューティング  │ │   データベーススタック  │
│  (network.yaml)     │ │    スタック       │ │   (database.yaml)    │
└─────────────────────┘ │ (computing.yaml) │ └──────────────────────┘
                        └──────────────────┘
                               │
                         ┌─────┴─────┐
                         │           │
                         ▼           ▼
                ┌──────────────┐ ┌────────────────┐
                │  ECSスタック  │ │  ALBスタック    │
                │ (ecs.yaml)   │ │  (alb.yaml)    │
                └──────────────┘ └────────────────┘
```

### 2.2 主要コンポーネント構成

| コンポーネント | テンプレート名 | 役割 |
|--------------|--------------|------|
| メインスタック | environment-main.yaml | 環境ごとのパラメータ管理、ネストスタックの調整 |
| ネットワークスタック | network.yaml | VPC、サブネット、ルートテーブル、セキュリティグループ等のネットワークリソース |
| データベーススタック | database.yaml | RDS、パラメータグループ、サブネットグループ等のデータベースリソース |
| コンピューティングスタック | computing.yaml | ECS、ALB関連リソースの管理（下位のネストスタックを呼び出し） |
| ECSスタック | ecs.yaml | ECSクラスター、タスク定義、サービス、Auto Scalingの設定 |
| ALBスタック | alb.yaml | Application Load Balancer、ターゲットグループ、リスナー設定 |
| 監視スタック | monitoring.yaml | CloudWatch、X-Ray、アラームの設定 |
| CI/CDスタック | cicd.yaml | CI/CD関連リソースの定義（別途デプロイ可能） |

## 3. ネストスタック設計

### 3.1 ネストスタックの利点

- **モジュール化**: 各機能を独立したテンプレートとして管理
- **再利用性**: 共通コンポーネントを複数環境で再利用
- **変更範囲の限定**: 特定コンポーネントの変更時に影響範囲を限定
- **デプロイの効率化**: 変更のあったコンポーネントのみを更新
- **依存関係の明確化**: スタック間の依存関係を明示的に定義
- **スタックあたりのリソース制限回避**: AWS CloudFormationのスタックあたりのリソース制限（500リソース）を回避

### 3.2 メインスタックの設計例

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'ECSForgate プロジェクト メインスタック ({{環境名}})'

Parameters:
  EnvironmentName:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - stg
      - prd
    Description: 環境名（dev/stg/prd）

  VpcCidr:
    Type: String
    Default: 10.0.0.0/16
    Description: VPCのCIDRブロック

  # その他パラメータ...

Resources:
  # ネットワークスタック
  NetworkStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://${ArtifactBucket}.s3.${AWS::Region}.amazonaws.com/cloudformation/templates/network.yaml'
      Parameters:
        EnvironmentName: !Ref EnvironmentName
        VpcCidr: !Ref VpcCidr
        # その他のネットワーク関連パラメータ
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName

  # データベーススタック
  DatabaseStack:
    Type: AWS::CloudFormation::Stack
    DependsOn: NetworkStack
    Properties:
      TemplateURL: !Sub 'https://${ArtifactBucket}.s3.${AWS::Region}.amazonaws.com/cloudformation/templates/database.yaml'
      Parameters:
        EnvironmentName: !Ref EnvironmentName
        VpcId: !GetAtt NetworkStack.Outputs.VpcId
        PrivateSubnet1Id: !GetAtt NetworkStack.Outputs.PrivateSubnet1Id
        PrivateSubnet2Id: !GetAtt NetworkStack.Outputs.PrivateSubnet2Id
        DBSecurityGroupId: !GetAtt NetworkStack.Outputs.DBSecurityGroupId
        # その他のデータベース関連パラメータ
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName

  # コンピューティングスタック
  ComputingStack:
    Type: AWS::CloudFormation::Stack
    DependsOn: 
      - NetworkStack
      - DatabaseStack
    Properties:
      TemplateURL: !Sub 'https://${ArtifactBucket}.s3.${AWS::Region}.amazonaws.com/cloudformation/templates/computing.yaml'
      Parameters:
        EnvironmentName: !Ref EnvironmentName
        VpcId: !GetAtt NetworkStack.Outputs.VpcId
        PublicSubnet1Id: !GetAtt NetworkStack.Outputs.PublicSubnet1Id
        PublicSubnet2Id: !GetAtt NetworkStack.Outputs.PublicSubnet2Id
        PrivateSubnet1Id: !GetAtt NetworkStack.Outputs.PrivateSubnet1Id
        PrivateSubnet2Id: !GetAtt NetworkStack.Outputs.PrivateSubnet2Id
        EcsSecurityGroupId: !GetAtt NetworkStack.Outputs.EcsSecurityGroupId
        AlbSecurityGroupId: !GetAtt NetworkStack.Outputs.AlbSecurityGroupId
        DbEndpoint: !GetAtt DatabaseStack.Outputs.DbEndpoint
        # その他のコンピューティング関連パラメータ
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName

  # 監視スタック
  MonitoringStack:
    Type: AWS::CloudFormation::Stack
    DependsOn: ComputingStack
    Properties:
      TemplateURL: !Sub 'https://${ArtifactBucket}.s3.${AWS::Region}.amazonaws.com/cloudformation/templates/monitoring.yaml'
      Parameters:
        EnvironmentName: !Ref EnvironmentName
        EcsClusterName: !GetAtt ComputingStack.Outputs.EcsClusterName
        EcsServiceName: !GetAtt ComputingStack.Outputs.EcsServiceName
        LoadBalancerArn: !GetAtt ComputingStack.Outputs.LoadBalancerArn
        # その他の監視関連パラメータ
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName

Outputs:
  VpcId:
    Description: VPC ID
    Value: !GetAtt NetworkStack.Outputs.VpcId
  ApiEndpoint:
    Description: API Endpoint
    Value: !GetAtt ComputingStack.Outputs.ApiEndpoint
  DatabaseEndpoint:
    Description: Database Endpoint
    Value: !GetAtt DatabaseStack.Outputs.DbEndpoint
  # その他の必要な出力...
```

### 3.3 コンピューティングスタックの設計例

コンピューティングスタックは、さらに下位のネストスタックを呼び出す構造とします：

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'ECSForgate プロジェクト コンピューティングスタック'

Parameters:
  EnvironmentName:
    Type: String
    Description: 環境名（dev/stg/prd）
  
  VpcId:
    Type: String
    Description: VPC ID
  
  # その他必要なパラメータ...

Resources:
  # ECSスタック
  EcsStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://${ArtifactBucket}.s3.${AWS::Region}.amazonaws.com/cloudformation/templates/ecs.yaml'
      Parameters:
        EnvironmentName: !Ref EnvironmentName
        VpcId: !Ref VpcId
        PrivateSubnet1Id: !Ref PrivateSubnet1Id
        PrivateSubnet2Id: !Ref PrivateSubnet2Id
        EcsSecurityGroupId: !Ref EcsSecurityGroupId
        # その他のECS関連パラメータ
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName

  # ALBスタック
  AlbStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://${ArtifactBucket}.s3.${AWS::Region}.amazonaws.com/cloudformation/templates/alb.yaml'
      Parameters:
        EnvironmentName: !Ref EnvironmentName
        VpcId: !Ref VpcId
        PublicSubnet1Id: !Ref PublicSubnet1Id
        PublicSubnet2Id: !Ref PublicSubnet2Id
        AlbSecurityGroupId: !Ref AlbSecurityGroupId
        EcsServiceName: !GetAtt EcsStack.Outputs.EcsServiceName
        # その他のALB関連パラメータ
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName

Outputs:
  EcsClusterName:
    Description: ECS Cluster Name
    Value: !GetAtt EcsStack.Outputs.EcsClusterName
  EcsServiceName:
    Description: ECS Service Name
    Value: !GetAtt EcsStack.Outputs.EcsServiceName
  LoadBalancerArn:
    Description: Load Balancer ARN
    Value: !GetAtt AlbStack.Outputs.LoadBalancerArn
  ApiEndpoint:
    Description: API Endpoint URL
    Value: !GetAtt AlbStack.Outputs.LoadBalancerDnsName
  # その他の必要な出力...
```

## 4. 環境分離戦略

### 4.1 環境別リソース命名規則

環境別にリソースを区別するため、以下の命名規則を採用します：

| リソースタイプ | 命名規則 | 例 |
|--------------|---------|-----|
| VPC | ecsforgate-{env}-vpc | ecsforgate-dev-vpc |
| サブネット | ecsforgate-{env}-{pub/priv}-subnet-{az} | ecsforgate-dev-priv-subnet-1a |
| RDS | ecsforgate-{env}-db | ecsforgate-dev-db |
| ECS クラスター | ecsforgate-{env}-cluster | ecsforgate-dev-cluster |
| ECS サービス | ecsforgate-{env}-api-service | ecsforgate-dev-api-service |
| ALB | ecsforgate-{env}-alb | ecsforgate-dev-alb |
| CloudWatch ロググループ | /ecs/ecsforgate-{env}-api | /ecs/ecsforgate-dev-api |

### 4.2 環境別構成ファイル

各環境のパラメータを管理するため、環境ごとのJSONファイルを用意します：

**dev/parameters.json**:
```json
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "dev"
  },
  {
    "ParameterKey": "VpcCidr",
    "ParameterValue": "10.0.0.0/16"
  },
  {
    "ParameterKey": "PrivateSubnet1Cidr",
    "ParameterValue": "10.0.1.0/24"
  },
  {
    "ParameterKey": "PrivateSubnet2Cidr",
    "ParameterValue": "10.0.2.0/24"
  },
  {
    "ParameterKey": "PublicSubnet1Cidr",
    "ParameterValue": "10.0.101.0/24"
  },
  {
    "ParameterKey": "PublicSubnet2Cidr",
    "ParameterValue": "10.0.102.0/24"
  },
  {
    "ParameterKey": "DbInstanceClass",
    "ParameterValue": "db.t3.small"
  },
  {
    "ParameterKey": "DbMultiAZ",
    "ParameterValue": "false"
  },
  {
    "ParameterKey": "EcsTaskCpu",
    "ParameterValue": "1024"
  },
  {
    "ParameterKey": "EcsTaskMemory",
    "ParameterValue": "2048"
  },
  {
    "ParameterKey": "EcsTaskDesiredCount",
    "ParameterValue": "1"
  },
  {
    "ParameterKey": "EcsTaskMaxCount",
    "ParameterValue": "2"
  }
]
```

**stg/parameters.json**と**prd/parameters.json**も同様に、ステージング環境と本番環境に適した値を設定します。

### 4.3 環境別の差分管理

環境ごとの主な差分は以下の通りです：

| 機能/リソース | 開発環境（dev） | ステージング環境（stg） | 本番環境（prd） |
|-------------|--------------|-------------------|--------------| 
| VPC/ネットワーク | 単一AZ | マルチAZ（2AZ） | マルチAZ（2AZ） |
| ECS Fargate | 最小1タスク、最大2タスク | 最小2タスク、最大5タスク | 最小2タスク、最大10タスク |
| RDSインスタンス | db.t3.small, シングルAZ | db.t3.medium, マルチAZ | db.t3.large, マルチAZ |
| ALBタイプ | 内部 | 内部 | 内部 |
| アラート通知 | 重大な問題のみ、メールのみ | すべての問題、メールのみ | すべての問題、メール+SMS |
| ログ保持期間 | 14日間 | 30日間 | 90日間 |
| バックアップ | 自動バックアップ（7日間） | 自動バックアップ（7日間）+ 週次スナップショット | 自動バックアップ（7日間）+ 週次スナップショット + 月次スナップショット（1年） |

## 5. パラメータ管理戦略

### 5.1 パラメータのカテゴリ分類

パラメータは以下のカテゴリに分類して管理します：

1. **環境識別子**：環境名、タグなど
2. **ネットワーク設定**：CIDR範囲、サブネット構成など
3. **コンピューティングリソース**：ECSタスク設定、Auto Scaling設定など
4. **データベース設定**：インスタンスクラス、バックアップ設定など
5. **監視・ロギング設定**：アラーム閾値、ログ保持期間など
6. **セキュリティ設定**：暗号化設定、IAMロール名など

### 5.2 SSMパラメータストアの活用

以下のパターンでSSMパラメータストアを活用します：

1. **環境設定パラメータ**：頻繁に変更されない設定
   ```
   /ecsforgate/{env}/config/vpc_cidr
   /ecsforgate/{env}/config/private_subnet_1_cidr
   ```

2. **運用パラメータ**：運用中に調整が必要なパラメータ
   ```
   /ecsforgate/{env}/operation/ecs_desired_count
   /ecsforgate/{env}/operation/autoscaling_threshold
   ```

### 5.3 シークレット管理

機密情報はAWS Secrets Managerで管理します：

```
ecsforgate/{env}/db-connection-string
ecsforgate/{env}/db-username
ecsforgate/{env}/db-password
```

### 5.4 パラメータ参照の例

CloudFormationテンプレート内でのパラメータ参照例：

```yaml
Parameters:
  EnvironmentName:
    Type: String
    Default: dev
    Description: 環境名（dev/stg/prd）

Resources:
  EcsService:
    Type: AWS::ECS::Service
    Properties:
      ServiceName: !Sub ecsforgate-${EnvironmentName}-api-service
      Cluster: !Sub ecsforgate-${EnvironmentName}-cluster
      # その他のプロパティ...
      
  CloudWatchLogsGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub /ecs/ecsforgate-${EnvironmentName}-api
      RetentionInDays: !FindInMap [EnvironmentMap, !Ref EnvironmentName, LogRetention]

Mappings:
  EnvironmentMap:
    dev:
      LogRetention: 14
    stg:
      LogRetention: 30
    prd:
      LogRetention: 90
```

## 6. スタック間の依存関係と出力管理

### 6.1 スタック出力の設計

各スタックは、他のスタックから参照される可能性のあるリソースをOutputsセクションでエクスポートします：

```yaml
Outputs:
  VpcId:
    Description: VPC ID
    Value: !Ref Vpc
    Export:
      Name: !Sub ${EnvironmentName}-VpcId
  
  PrivateSubnet1Id:
    Description: Private Subnet 1 ID
    Value: !Ref PrivateSubnet1
    Export:
      Name: !Sub ${EnvironmentName}-PrivateSubnet1Id
  
  # その他の出力...
```

### 6.2 クロススタック参照

スタック間の参照には、GetAttまたはImportValue関数を使用します：

1. **ネストスタック内のGetAtt参照**：
```yaml
EcsSecurityGroupId: !GetAtt NetworkStack.Outputs.EcsSecurityGroupId
```

2. **独立したスタック間のImportValue参照**：
```yaml
VpcId: !ImportValue 
  !Sub ${EnvironmentName}-VpcId
```

### 6.3 依存関係の明示化

スタック間の依存関係は、DependsOnプロパティで明示します：

```yaml
DatabaseStack:
  Type: AWS::CloudFormation::Stack
  DependsOn: NetworkStack
  Properties:
    # プロパティ定義...
```

## 7. デプロイ戦略

### 7.1 段階的デプロイフロー

CloudFormationスタックのデプロイは、依存関係を考慮した以下の順序で行います：

1. ネットワークスタック（VPC、サブネット、セキュリティグループ）
2. データベーススタック（RDS、サブネットグループ）
3. コンピューティングスタック（ECS、ALB）
4. 監視スタック（CloudWatch、X-Ray）
5. CI/CDスタック（別途デプロイ）

### 7.2 デプロイスクリプト

以下のようなデプロイスクリプトを用意して、デプロイを効率化します：

```bash
#!/bin/bash
# deploy.sh

# 使用方法
if [ "$#" -lt 2 ]; then
  echo "使用方法: $0 <環境名> <アクション>"
  echo "環境名: dev, stg, prd"
  echo "アクション: create, update, delete"
  exit 1
fi

ENVIRONMENT=$1
ACTION=$2
REGION="ap-northeast-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
S3_BUCKET="ecsforgate-cfn-templates-${ACCOUNT_ID}"
S3_PREFIX="${ENVIRONMENT}"
STACK_NAME="ecsforgate-${ENVIRONMENT}"

# S3バケットの確認・作成
if ! aws s3 ls "s3://${S3_BUCKET}" &> /dev/null; then
  echo "S3バケット ${S3_BUCKET} を作成します..."
  aws s3 mb "s3://${S3_BUCKET}" --region ${REGION}
fi

# テンプレートのパッケージ化
echo "CloudFormationテンプレートをパッケージ化しています..."
aws cloudformation package \
  --template-file iac/cloudformation/templates/environment-main.yaml \
  --s3-bucket ${S3_BUCKET} \
  --s3-prefix ${S3_PREFIX} \
  --output-template-file packaged-template.yaml

# スタックのデプロイ
echo "${ENVIRONMENT}環境のスタックを${ACTION}しています..."
case ${ACTION} in
  create)
    aws cloudformation create-stack \
      --stack-name ${STACK_NAME} \
      --template-body file://packaged-template.yaml \
      --parameters file://iac/cloudformation/config/${ENVIRONMENT}/parameters.json \
      --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
      --region ${REGION} \
      --tags Key=Environment,Value=${ENVIRONMENT}
    
    echo "スタック作成を開始しました。完了まで待機します..."
    aws cloudformation wait stack-create-complete --stack-name ${STACK_NAME} --region ${REGION}
    ;;
  
  update)
    aws cloudformation update-stack \
      --stack-name ${STACK_NAME} \
      --template-body file://packaged-template.yaml \
      --parameters file://iac/cloudformation/config/${ENVIRONMENT}/parameters.json \
      --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
      --region ${REGION}
    
    echo "スタック更新を開始しました。完了まで待機します..."
    aws cloudformation wait stack-update-complete --stack-name ${STACK_NAME} --region ${REGION}
    ;;
  
  delete)
    echo "警告: ${ENVIRONMENT}環境のスタックを削除します。この操作は取り消せません。"
    read -p "続行しますか？ (y/n): " CONFIRM
    if [[ ${CONFIRM} == "y" ]]; then
      aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${REGION}
      echo "スタック削除を開始しました。完了まで待機します..."
      aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME} --region ${REGION}
    else
      echo "スタック削除を中止しました。"
      exit 0
    fi
    ;;
  
  *)
    echo "不明なアクション: ${ACTION}"
    exit 1
    ;;
esac

echo "操作が完了しました。"
```

### 7.3.ChangeSetの活用

重要な変更を行う前に、ChangeSetを活用して変更の影響を確認します：

```bash
# ChangeSetの作成
aws cloudformation create-change-set \
  --stack-name ${STACK_NAME} \
  --change-set-name ${CHANGE_SET_NAME} \
  --template-body file://packaged-template.yaml \
  --parameters file://iac/cloudformation/config/${ENVIRONMENT}/parameters.json \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND

# ChangeSetの内容確認
aws cloudformation describe-change-set \
  --stack-name ${STACK_NAME} \
  --change-set-name ${CHANGE_SET_NAME}

# ChangeSetの実行
aws cloudformation execute-change-set \
  --stack-name ${STACK_NAME} \
  --change-set-name ${CHANGE_SET_NAME}
```

## 8. スタックポリシーとアクセス制御

### 8.1 スタックポリシーの設定

本番環境では、重要なリソースを保護するためのスタックポリシーを設定します：

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "Update:*",
      "Principal": "*",
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": ["Update:Delete", "Update:Replace"],
      "Principal": "*",
      "Resource": "LogicalResourceId/ProductionDatabase"
    }
  ]
}
```

### 8.2 IAMアクセス制御

CloudFormationテンプレートのデプロイ権限を環境ごとに制限するIAMポリシー例：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DescribeStacks",
        "cloudformation:ValidateTemplate"
      ],
      "Resource": [
        "arn:aws:cloudformation:*:*:stack/ecsforgate-dev-*/*"
      ]
    }
  ]
}
```

## 9. CloudFormationリソース定義

### 9.1 主要リソースタイプとパラメータ

各テンプレートで使用する主要なリソースタイプとそのパラメータ例：

#### VPCリソース（network.yaml）

```yaml
Resources:
  Vpc:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCidr
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: !Sub ecsforgate-${EnvironmentName}-vpc
```

#### RDSリソース（database.yaml）

```yaml
Resources:
  DbSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      DBSubnetGroupDescription: !Sub ecsforgate-${EnvironmentName}-db-subnet-group
      SubnetIds:
        - !Ref PrivateSubnet1Id
        - !Ref PrivateSubnet2Id
      Tags:
        - Key: Name
          Value: !Sub ecsforgate-${EnvironmentName}-db-subnet-group

  DbInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      DBInstanceIdentifier: !Sub ecsforgate-${EnvironmentName}-db
      DBSubnetGroupName: !Ref DbSubnetGroup
      VPCSecurityGroups:
        - !Ref DBSecurityGroupId
      Engine: postgres
      EngineVersion: 13.7
      DBInstanceClass: !Ref DbInstanceClass
      MultiAZ: !Ref DbMultiAZ
      StorageType: gp3
      AllocatedStorage: !Ref DbAllocatedStorage
      MasterUsername: !Ref DbUsername
      MasterUserPassword: !Ref DbPassword
      BackupRetentionPeriod: !FindInMap [EnvironmentMap, !Ref EnvironmentName, BackupRetention]
      StorageEncrypted: true
      Tags:
        - Key: Name
          Value: !Sub ecsforgate-${EnvironmentName}-db
```

#### ECSリソース（ecs.yaml）

```yaml
Resources:
  EcsCluster:
    Type: AWS::ECS::Cluster
    Properties:
      ClusterName: !Sub ecsforgate-${EnvironmentName}-cluster
      ClusterSettings:
        - Name: containerInsights
          Value: enabled
      Tags:
        - Key: Name
          Value: !Sub ecsforgate-${EnvironmentName}-cluster

  EcsTaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      Family: !Sub ecsforgate-${EnvironmentName}-api-task
      Cpu: !Ref EcsTaskCpu
      Memory: !Ref EcsTaskMemory
      NetworkMode: awsvpc
      RequiresCompatibilities:
        - FARGATE
      ExecutionRoleArn: !Ref EcsTaskExecutionRole
      TaskRoleArn: !Ref EcsTaskRole
      ContainerDefinitions:
        - Name: api-container
          Image: !Ref ContainerImage
          Essential: true
          PortMappings:
            - ContainerPort: 8080
              HostPort: 8080
              Protocol: tcp
          LogConfiguration:
            LogDriver: awslogs
            Options:
              awslogs-group: !Sub /ecs/ecsforgate-${EnvironmentName}-api
              awslogs-region: !Ref AWS::Region
              awslogs-stream-prefix: ecs
          Environment:
            - Name: SPRING_PROFILES_ACTIVE
              Value: !Ref EnvironmentName
          Secrets:
            - Name: SPRING_DATASOURCE_URL
              ValueFrom: !Sub arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:ecsforgate/${EnvironmentName}/db-connection-string
            - Name: SPRING_DATASOURCE_USERNAME
              ValueFrom: !Sub arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:ecsforgate/${EnvironmentName}/db-username
            - Name: SPRING_DATASOURCE_PASSWORD
              ValueFrom: !Sub arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:ecsforgate/${EnvironmentName}/db-password

  EcsService:
    Type: AWS::ECS::Service
    DependsOn: AlbListener
    Properties:
      ServiceName: !Sub ecsforgate-${EnvironmentName}-api-service
      Cluster: !Ref EcsCluster
      TaskDefinition: !Ref EcsTaskDefinition
      LaunchType: FARGATE
      DesiredCount: !Ref EcsTaskDesiredCount
      DeploymentConfiguration:
        MaximumPercent: 200
        MinimumHealthyPercent: 100
      NetworkConfiguration:
        AwsvpcConfiguration:
          SecurityGroups:
            - !Ref EcsSecurityGroupId
          Subnets:
            - !Ref PrivateSubnet1Id
            - !If [UseDualAZ, !Ref PrivateSubnet2Id, !Ref "AWS::NoValue"]
      LoadBalancers:
        - ContainerName: api-container
          ContainerPort: 8080
          TargetGroupArn: !Ref AlbTargetGroup
      HealthCheckGracePeriodSeconds: 60
      Tags:
        - Key: Name
          Value: !Sub ecsforgate-${EnvironmentName}-api-service
```

## 10. 検証と運用

### 10.1 テンプレート検証

テンプレートのデプロイ前に、以下の検証を実施します：

1. **構文検証**：`aws cloudformation validate-template`
2. **セキュリティチェック**：cfn-nagによるセキュリティ上の問題検出
3. **リンター**：cfn-lintによるベストプラクティス違反の検出
4. **ドリフト検出**：既存スタックのドリフト検出

### 10.2 デプロイ時の検証

デプロイ中とデプロイ後に、以下の検証を実施します：

1. **リソース作成の確認**：CloudFormationコンソールでのステータス確認
2. **ロールバック条件の確認**：CloudFormationコンソールでのロールバックトリガー設定
3. **リソース依存関係の検証**：デプロイシーケンスの確認

### 10.3 運用上の考慮点

1. **スタックの更新頻度制限**：本番環境の更新はメンテナンスウィンドウ内に実施
2. **スタックの削除防止**：本番環境の削除防止（TerminationProtection）の有効化
3. **リソース制限監視**：AWSサービス制限に対するモニタリング
4. **コスト監視**：環境ごとのコストタグ付けと定期的なコスト分析

## 11. リスクと対策

環境ごとにCloudFormationスタックを適用する際のリスクと対策：

| リスク | 影響度 | 対策 |
|-------|-------|------| 
| テンプレートのバグ | 高 | 開発環境での十分なテスト、ChangeSetによる変更確認 |
| パラメータ誤設定 | 高 | パラメータのデフォルト値設定、AllowedValuesによる制約 |
| スタック更新失敗 | 中 | 自動ロールバック設定、復旧手順の整備 |
| リソース制限超過 | 中 | 事前のサービス制限確認、リソース使用量モニタリング |
| 環境間の差異 | 中 | マッピングテーブルの活用、環境別パラメータの明確な管理 |
| 権限不足 | 低 | IAMロールの適切な権限設定、事前の権限検証 |

## 12. 今後の展望

CloudFormation設計の今後の改善方針：

1. **リソースタイプの最新化**：新しいAWSサービスやリソースタイプのサポート
2. **インフラテストの強化**：CloudFormationテンプレートの自動テスト拡充
3. **サーバーレス統合**：Lambda、API Gateway等のサーバーレスサービスとの統合
4. **マルチアカウント戦略**：開発/ステージング/本番を異なるAWSアカウントで管理
5. **インフラCI/CD強化**：インフラ変更のCI/CDパイプライン整備

## 13. まとめ

本設計では、CloudFormationのネストスタック機能を活用し、モジュール化された再利用可能なインフラストラクチャコードの管理方法を定義しました。環境ごとの設定を明確に分離し、パラメータ管理を効率化することで、ECSForgateプロジェクトのインフラストラクチャ管理を効率的かつ安全に行うことができます。

ネストスタック構造により、各コンポーネントは独立して管理され、変更の影響範囲を限定することができます。また、環境ごとのパラメータ分離により、開発環境からステージング環境、本番環境まで一貫した方法でリソースをデプロイすることが可能になります。
