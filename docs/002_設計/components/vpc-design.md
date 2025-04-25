# VPC詳細設計書

## 1. 概要

### 1.1 目的と責任範囲
本ドキュメントでは、ECSForgateプロジェクトにおけるVPC（Virtual Private Cloud）の詳細設計を定義します。VPCはプロジェクト全体のネットワーク基盤となり、セキュアな通信環境を提供する責任を持ちます。

### 1.2 設計のポイント
- プライベートネットワーク内でのセキュアな通信環境の構築
- マルチAZ構成による高可用性の確保
- FISC安全対策基準に準拠したセキュリティ設計
- 論理的な分離による機能ごとのセキュリティ境界の定義
- スケーラビリティを考慮したCIDR設計

## 2. CIDR設計

### 2.1 VPC CIDR設計

各環境に対して以下のCIDRブロックを割り当てます：

| 環境 | VPC CIDR | 備考 |
|-----|----------|------|
| 開発環境（dev） | 10.0.0.0/16 | 最大65,536 IPアドレス |
| ステージング環境（stg） | 10.1.0.0/16 | 最大65,536 IPアドレス |
| 本番環境（prd） | 10.2.0.0/16 | 最大65,536 IPアドレス |

### 2.2 サブネットCIDR設計

環境ごとに以下のサブネットを構成します。各環境は共通の構成となりますが、ここでは開発環境の例を示します：

| サブネット名 | CIDR | アベイラビリティゾーン | 用途 |
|------------|------|----------------------|------|
| PublicSubnetA | 10.0.0.0/24 | ap-northeast-1a | NAT Gateway、ALB（将来拡張用） |
| PublicSubnetB | 10.0.1.0/24 | ap-northeast-1c | NAT Gateway、ALB（将来拡張用） |
| PrivateAppSubnetA | 10.0.10.0/24 | ap-northeast-1a | ECS Fargateタスク、内部ALB |
| PrivateAppSubnetB | 10.0.11.0/24 | ap-northeast-1c | ECS Fargateタスク、内部ALB |
| PrivateDataSubnetA | 10.0.20.0/24 | ap-northeast-1a | RDS、その他データストア |
| PrivateDataSubnetB | 10.0.21.0/24 | ap-northeast-1c | RDS、その他データストア |

### 2.3 IPアドレス割り当て計画

各サブネットでのIP割り当て計画は以下の通りです：

- 各サブネットは/24 CIDR（256 IPアドレス）を持ち、そのうち使用可能なIPアドレスは251個
  - AWS予約アドレス: 最初の4つのIPアドレスと最後のIPアドレス
- Private App Subnetでは、ECS Fargateタスクに対して動的にIPアドレスが割り当てられる
  - 各タスクは1つのENI（Elastic Network Interface）を使用
  - 最大タスク数: 開発環境では20、ステージング環境では50、本番環境では100を想定
- Private Data Subnetでは、RDSインスタンスとその他将来的なデータストアのためのIPアドレスを確保

## 3. アベイラビリティゾーン戦略

### 3.1 AZ選択
- 開発環境: 単一AZ（ap-northeast-1a）
- ステージング環境: 2つのAZ（ap-northeast-1a, ap-northeast-1c）
- 本番環境: 2つのAZ（ap-northeast-1a, ap-northeast-1c）

### 3.2 AZ分散の考え方
- リソースは選択したAZ間で均等に分散
- 単一AZ障害時にも継続的にサービスを提供できる設計
- リージョン内の異なるAZを選択することでAZ障害のリスクを軽減

## 4. サブネット階層構成

### 4.1 パブリックサブネット（Public Subnet）
- **目的**: NAT Gateway配置、および将来的な外部向けALBの設置先
- **特徴**: 
  - インターネットゲートウェイからの直接アクセス可能
  - 各AZに1つずつ配置
  - ECSForgateタスクは配置しない（セキュリティ要件）
- **ルーティング**:
  - デフォルトルート: インターネットゲートウェイ向け
  - ローカルルート: VPC内通信

### 4.2 プライベートアプリケーションサブネット（Private App Subnet）
- **目的**: ECS Fargateタスクと内部ALBの配置
- **特徴**:
  - インターネットからの直接アクセス不可
  - 各AZに1つずつ配置
  - APサブネットとして論理的に分離
- **ルーティング**:
  - デフォルトルート: NAT Gateway向け（外部API呼び出し等のため）
  - ローカルルート: VPC内通信

### 4.3 プライベートデータサブネット（Private Data Subnet）
- **目的**: RDSおよびその他データストアの配置
- **特徴**:
  - インターネットからの直接アクセス不可
  - 各AZに1つずつ配置
  - DBサブネットとして論理的に分離
  - アプリケーション層からのみアクセス可能
- **ルーティング**:
  - デフォルトルート: なし（インターネットアクセス不要）
  - ローカルルート: VPC内通信のみ

## 5. ルートテーブル設計

各サブネットタイプごとに独立したルートテーブルを設定します：

### 5.1 パブリックルートテーブル
- **割り当て先**: PublicSubnetA, PublicSubnetB
- **ルート**:
  - 10.0.0.0/16 -> local（VPC内通信）
  - 0.0.0.0/0 -> igw-xxxxx（インターネットゲートウェイ）

### 5.2 プライベートアプリケーションルートテーブル（AZ-A）
- **割り当て先**: PrivateAppSubnetA
- **ルート**:
  - 10.0.0.0/16 -> local（VPC内通信）
  - 0.0.0.0/0 -> nat-xxxxx-a（AZ-AのNAT Gateway）

### 5.3 プライベートアプリケーションルートテーブル（AZ-B）
- **割り当て先**: PrivateAppSubnetB
- **ルート**:
  - 10.0.0.0/16 -> local（VPC内通信）
  - 0.0.0.0/0 -> nat-xxxxx-b（AZ-BのNAT Gateway）

### 5.4 プライベートデータルートテーブル
- **割り当て先**: PrivateDataSubnetA, PrivateDataSubnetB
- **ルート**:
  - 10.0.0.0/16 -> local（VPC内通信のみ）

## 6. NACLとセキュリティグループの詳細ルール

### 6.1 ネットワークACL（NACL）設計

#### 6.1.1 パブリックサブネットNACL
- **インバウンド**:
  | ルール# | タイプ | プロトコル | ポート範囲 | ソース | 許可/拒否 |
  |--------|------|----------|---------|-------|---------|
  | 100 | HTTP | TCP | 80 | 0.0.0.0/0 | 許可 |
  | 110 | HTTPS | TCP | 443 | 0.0.0.0/0 | 許可 |
  | 120 | エフェメラルポート | TCP | 1024-65535 | 0.0.0.0/0 | 許可 |
  | * | すべてのトラフィック | すべて | すべて | 0.0.0.0/0 | 拒否 |

- **アウトバウンド**:
  | ルール# | タイプ | プロトコル | ポート範囲 | 送信先 | 許可/拒否 |
  |--------|------|----------|---------|-------|---------|
  | 100 | すべてのトラフィック | すべて | すべて | 0.0.0.0/0 | 許可 |

#### 6.1.2 プライベートアプリケーションサブネットNACL
- **インバウンド**:
  | ルール# | タイプ | プロトコル | ポート範囲 | ソース | 許可/拒否 |
  |--------|------|----------|---------|-------|---------|
  | 100 | HTTP | TCP | 80 | 10.0.0.0/16 | 許可 |
  | 110 | HTTPS | TCP | 443 | 10.0.0.0/16 | 許可 |
  | 120 | カスタムTCP | TCP | 8080 | 10.0.0.0/16 | 許可 |
  | 130 | エフェメラルポート | TCP | 1024-65535 | 0.0.0.0/0 | 許可 |
  | * | すべてのトラフィック | すべて | すべて | 0.0.0.0/0 | 拒否 |

- **アウトバウンド**:
  | ルール# | タイプ | プロトコル | ポート範囲 | 送信先 | 許可/拒否 |
  |--------|------|----------|---------|-------|---------|
  | 100 | すべてのトラフィック | すべて | すべて | 0.0.0.0/0 | 許可 |

#### 6.1.3 プライベートデータサブネットNACL
- **インバウンド**:
  | ルール# | タイプ | プロトコル | ポート範囲 | ソース | 許可/拒否 |
  |--------|------|----------|---------|-------|---------|
  | 100 | PostgreSQL | TCP | 5432 | 10.0.10.0/24 | 許可 |
  | 110 | PostgreSQL | TCP | 5432 | 10.0.11.0/24 | 許可 |
  | 120 | エフェメラルポート | TCP | 1024-65535 | 10.0.0.0/16 | 許可 |
  | * | すべてのトラフィック | すべて | すべて | 0.0.0.0/0 | 拒否 |

- **アウトバウンド**:
  | ルール# | タイプ | プロトコル | ポート範囲 | 送信先 | 許可/拒否 |
  |--------|------|----------|---------|-------|---------|
  | 100 | エフェメラルポート | TCP | 1024-65535 | 10.0.0.0/16 | 許可 |
  | * | すべてのトラフィック | すべて | すべて | 0.0.0.0/0 | 拒否 |

### 6.2 セキュリティグループ設計
セキュリティグループは、特定のリソースに対するファイアウォールとして機能します。詳細なセキュリティグループルールは各コンポーネント詳細設計書で定義しますが、基本方針は以下の通りです：

- **原則**: 最小権限の原則に従い、必要最低限のトラフィックのみを許可
- **ステートフル**: セキュリティグループはステートフルなので、往路の通信を許可すれば復路は自動的に許可される
- **暗黙の拒否**: 明示的に許可されていないすべてのトラフィックは拒否される

主要なセキュリティグループ：
1. **内部ALBセキュリティグループ**
2. **ECS Fargateタスクセキュリティグループ**
3. **RDSセキュリティグループ**

## 7. VPCエンドポイント設定

AWSサービスへのセキュアなアクセスを提供するために、以下のVPCエンドポイントを設定します：

### 7.1 インターフェースエンドポイント（PrivateLink）
| サービス名 | サブネット配置 | セキュリティグループ | プライベートDNS | 
|-----------|--------------|-------------------|--------------|
| ecr.api | PrivateAppSubnetA, PrivateAppSubnetB | ECR-APIエンドポイントSG | 有効 |
| ecr.dkr | PrivateAppSubnetA, PrivateAppSubnetB | ECR-DKRエンドポイントSG | 有効 |
| logs | PrivateAppSubnetA, PrivateAppSubnetB | CloudWatchLogsエンドポイントSG | 有効 |
| monitoring | PrivateAppSubnetA, PrivateAppSubnetB | CloudWatchMonitoringエンドポイントSG | 有効 |
| ssm | PrivateAppSubnetA, PrivateAppSubnetB | SSMエンドポイントSG | 有効 |

### 7.2 ゲートウェイエンドポイント
| サービス名 | ルートテーブル | ポリシー |
|-----------|--------------|---------|
| s3 | PrivateAppRouteTableA, PrivateAppRouteTableB | 最小権限ポリシー |
| dynamodb | PrivateAppRouteTableA, PrivateAppRouteTableB（将来使用のため） | 最小権限ポリシー |

## 8. NAT設定

### 8.1 NAT Gateway設計
- **配置**: 各パブリックサブネット（PublicSubnetA, PublicSubnetB）に1つずつ
- **目的**: プライベートサブネット内のリソースがインターネットにアクセスするため
- **耐障害性**: 各AZに独立したNAT Gatewayを配置し、単一AZ障害時にも通信を維持

| 環境 | NAT Gateway数 | Elastic IP | 配置場所 |
|-----|--------------|------------|---------|
| 開発環境 | 1 | 1 | PublicSubnetA |
| ステージング環境 | 2 | 2 | PublicSubnetA, PublicSubnetB |
| 本番環境 | 2 | 2 | PublicSubnetA, PublicSubnetB |

### 8.2 NAT設定の考慮点
- **コスト**: NAT Gateway時間料金と処理データ量に応じた課金
- **パフォーマンス**: 最大5Gbpsのスループットを提供し、必要に応じて自動的にスケール
- **メンテナンス**: AWSマネージドサービスとして自動的にメンテナンス

## 9. 監視とアラーム設定

### 9.1 VPC関連の監視メトリクス
- **NAT Gateway**:
  - BytesOutToDestination
  - BytesOutToSource
  - BytesInFromDestination
  - BytesInFromSource
  - PacketsDropCount
  - ErrorPortAllocation
  
- **VPCフローログ**:
  - 拒否されたトラフィック
  - 異常なトラフィックパターン

### 9.2 設定するアラーム
- **NAT Gateway**:
  - ErrorPortAllocation > 0（5分間）: NAT Gateway Port割り当てエラー
  - PacketsDropCount > 100（5分間）: パケットドロップが多発
  
- **VPCフローログ分析（CloudWatch Logs Insights）**:
  - 拒否トラフィックの急増
  - 不正なアクセスパターン検出

## 10. タグ設定

すべてのVPCリソースに以下のタグを設定し、リソースの識別と管理を容易にします：

| タグキー | タグ値（例） | 説明 |
|---------|------------|------|
| Project | ECSForgate | プロジェクト名 |
| Environment | dev/stg/prd | 環境識別子 |
| Component | VPC | コンポーネント種別 |
| ManagedBy | CloudFormation | 管理ツール |
| CostCenter | IT-Infrastructure | コスト配賦先 |
| CreatedBy | Deployment-Pipeline | 作成者/作成手段 |
| CreatedDate | 2025-04-26 | 作成日 |

## 11. セキュリティ対策

### 11.1 FISC対応セキュリティ対策
- VPCフローログの有効化とログの永続的な保存
- すべてのサブネットに適切なNACLを設定
- VPCエンドポイントの使用による通信の暗号化と保護
- プライベートサブネットの論理的分離とアクセス制御
- 定期的なセキュリティ設定のレビューと監査

### 11.2 NACLとセキュリティグループの相互補完
- NACLはサブネットレベルでのステートレスな防御境界として機能
- セキュリティグループはインスタンスレベルでのステートフルな制御を提供
- 両者を組み合わせることでより強固な多層防御を実現

## 12. 環境差分

環境ごとの主な差分は以下の通りです：

| 設定項目 | 開発環境（dev） | ステージング環境（stg） | 本番環境（prd） |
|---------|--------------|-------------------|--------------| 
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| AZ構成 | 単一AZ (a) | マルチAZ (a,c) | マルチAZ (a,c) |
| NAT Gateway | 単一 | 冗長 (各AZに1つ) | 冗長 (各AZに1つ) |
| VPCフローログ | 主要サブネットのみ | すべてのサブネット | すべてのサブネット |
| VPCエンドポイント | 必要最低限 | すべて | すべて |
| NACL | 基本ルールのみ | 詳細なルール | 厳格なルール |
| フローログ保持期間 | 14日間 | 30日間 | 90日間 |

## 13. CloudFormationリソース定義

VPC構成のためのCloudFormationリソースタイプと主要パラメータを以下に示します：

### 13.1 主要リソースタイプ
- **AWS::EC2::VPC**: VPCを定義
- **AWS::EC2::Subnet**: サブネットを定義
- **AWS::EC2::RouteTable**: ルートテーブルを定義
- **AWS::EC2::Route**: ルートを定義
- **AWS::EC2::SubnetRouteTableAssociation**: サブネットとルートテーブルの関連付け
- **AWS::EC2::InternetGateway**: インターネットゲートウェイを定義
- **AWS::EC2::VPCGatewayAttachment**: VPCとインターネットゲートウェイの関連付け
- **AWS::EC2::NatGateway**: NAT Gatewayを定義
- **AWS::EC2::EIP**: Elastic IPを定義
- **AWS::EC2::NetworkAcl**: ネットワークACLを定義
- **AWS::EC2::NetworkAclEntry**: ネットワークACLルールを定義
- **AWS::EC2::SubnetNetworkAclAssociation**: サブネットとネットワークACLの関連付け
- **AWS::EC2::VPCEndpoint**: VPCエンドポイントを定義

### 13.2 主要パラメータ例

```yaml
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
    Description: VPC用のCIDRブロック

  PublicSubnetACidr:
    Type: String
    Default: 10.0.0.0/24
    Description: パブリックサブネットA用のCIDRブロック

  PublicSubnetBCidr:
    Type: String
    Default: 10.0.1.0/24
    Description: パブリックサブネットB用のCIDRブロック

  PrivateAppSubnetACidr:
    Type: String
    Default: 10.0.10.0/24
    Description: プライベートアプリケーションサブネットA用のCIDRブロック

  PrivateAppSubnetBCidr:
    Type: String
    Default: 10.0.11.0/24
    Description: プライベートアプリケーションサブネットB用のCIDRブロック

  PrivateDataSubnetACidr:
    Type: String
    Default: 10.0.20.0/24
    Description: プライベートデータサブネットA用のCIDRブロック

  PrivateDataSubnetBCidr:
    Type: String
    Default: 10.0.21.0/24
    Description: プライベートデータサブネットB用のCIDRブロック

  AvailabilityZoneA:
    Type: String
    Default: ap-northeast-1a
    Description: 使用するアベイラビリティゾーンA

  AvailabilityZoneB:
    Type: String
    Default: ap-northeast-1c
    Description: 使用するアベイラビリティゾーンB

  MultiAzEnabled:
    Type: String
    Default: false
    AllowedValues:
      - true
      - false
    Description: マルチAZ構成を有効にするかどうか（開発環境では無効）
```

## 14. 考慮すべきリスクと対策

| リスク | 影響度 | 対策 |
|-------|-------|------|
| サブネットIPアドレス枯渇 | 中 | 十分なサイズのCIDRブロックを割り当て、将来の成長を見込んだ設計 |
| 単一AZ障害 | 高 | マルチAZ構成、AZ間での冗長化 |
| VPCエンドポイント障害 | 中 | マルチAZへのエンドポイント配置、障害時のアラート設定 |
| セキュリティ設定不備 | 高 | セキュリティレビュー、定期的な監査、自動化ツールによる検証 |
| NAT Gatewayのコスト増加 | 低 | トラフィック監視、アウトバウンドトラフィックの最適化 |

## 15. 設計検証方法

本VPC設計の妥当性を確認するために、以下の検証を実施します：

1. **AWSコンソールでの検証**:
   - VPC設計が意図通りに反映されているか視覚的に確認
   - ルートテーブル、NACL、セキュリティグループの設定確認

2. **ネットワーク接続性テスト**:
   - サブネット間の通信テスト
   - VPCエンドポイント経由のAWSサービスアクセステスト
   - インターネットアクセステスト（NAT Gateway経由）

3. **セキュリティテスト**:
   - 意図しないアクセスが拒否されることを確認
   - NACLとセキュリティグループの効果を検証
   - VPCフローログの出力確認

## 16. 運用考慮点

### 16.1 通常運用時の考慮点
- VPCフローログの定期的なレビュー
- NACLとセキュリティグループの設定確認
- NAT Gatewayのトラフィックモニタリング

### 16.2 障害発生時の考慮点
- AZ障害時の影響と復旧手順
- NAT Gateway障害時の切り替え手順
- VPCエンドポイント障害時の対応

### 16.3 メンテナンス時の考慮点
- ネットワーク設定変更時の影響評価手順
- CIDR拡張時の手順と考慮点
- サブネット追加時の手順
