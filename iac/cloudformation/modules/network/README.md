# ネットワークモジュール

VPC、サブネット、セキュリティグループなどのネットワークリソースを管理します。

## 構成

- VPC
- パブリックサブネット (2AZ)
- プライベートサブネット (2AZ)
- インターネットゲートウェイ
- NAT ゲートウェイ
- セキュリティグループ
  - ALB用
  - ECS用
  - RDS用
- VPCエンドポイント
  - Secrets Manager
  - ECR
  - CloudWatch Logs

## 環境差分

各環境で異なるCIDRレンジを使用：

```
dev:
  vpc: 10.0.0.0/16
  public-1: 10.0.0.0/24
  public-2: 10.0.1.0/24
  private-1: 10.0.2.0/24
  private-2: 10.0.3.0/24

stg:
  vpc: 10.1.0.0/16
  public-1: 10.1.0.0/24
  public-2: 10.1.1.0/24
  private-1: 10.1.2.0/24
  private-2: 10.1.3.0/24

prd:
  vpc: 10.2.0.0/16
  public-1: 10.2.0.0/24
  public-2: 10.2.1.0/24
  private-1: 10.2.2.0/24
  private-2: 10.2.3.0/24
```

## パラメータ

| パラメータ名 | 説明 | デフォルト値 |
|------------|------|------------|
| Environment | 環境名 (dev/stg/prd) | dev |
| VpcCidr | VPCのCIDRレンジ | 10.0.0.0/16 |
| PublicSubnet1Cidr | パブリックサブネット1のCIDR | 10.0.0.0/24 |
| PublicSubnet2Cidr | パブリックサブネット2のCIDR | 10.0.1.0/24 |
| PrivateSubnet1Cidr | プライベートサブネット1のCIDR | 10.0.2.0/24 |
| PrivateSubnet2Cidr | プライベートサブネット2のCIDR | 10.0.3.0/24 |

## 出力値

| 出力名 | 説明 | 用途 |
|--------|------|------|
| VpcId | VPC ID | 他のスタックでの参照用 |
| PublicSubnet1Id | パブリックサブネット1 ID | ALBの配置 |
| PublicSubnet2Id | パブリックサブネット2 ID | ALBの配置 |
| PrivateSubnet1Id | プライベートサブネット1 ID | ECS/RDSの配置 |
| PrivateSubnet2Id | プライベートサブネット2 ID | ECS/RDSの配置 |
| AlbSecurityGroupId | ALB用セキュリティグループID | ALBの設定 |
| EcsSecurityGroupId | ECS用セキュリティグループID | ECSタスクの設定 |
| RdsSecurityGroupId | RDS用セキュリティグループID | RDSの設定 |

## 依存関係

このモジュールは他のモジュールに依存しません。他のモジュールから以下のように参照されます：

- computeモジュール: VPC、サブネット、セキュリティグループ
- databaseモジュール: VPC、プライベートサブネット、セキュリティグループ
