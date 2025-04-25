# API Gateway詳細設計書

## 1. 概要

### 1.1 目的と責任範囲
本ドキュメントでは、ECSForgateプロジェクトにおけるAmazon API Gatewayの詳細設計を定義します。API Gatewayはプロジェクトのフロントエンド層として機能し、内部ALBへの安全なアクセス提供とAPI管理を担当します。

### 1.2 設計のポイント
- プライベートAPIエンドポイントによる内部サービスへの安全なアクセス提供
- VPC内部のリソース（ALB）との安全な統合
- JWT認証によるAPI呼び出しの認可
- アクセスコントロールとスロットリングによるセキュリティ強化
- APIのバージョン管理とステージング環境の分離

## 2. API Gatewayタイプと構成

### 2.1 API Gateway選定

プロジェクト要件に基づき、「HTTP API」タイプを選定します。

| 比較項目 | REST API | HTTP API | 選定理由 |
|---------|----------|----------|---------|
| 機能セット | 豊富 | 軽量 | 必要な機能が限定的なため、軽量なHTTP APIで十分 |
| コスト | 高め | 低め | コスト効率の観点からHTTP APIが有利 |
| レイテンシー | 標準 | 低い | パフォーマンス要件を満たせる |
| 統合タイプ | 全種類対応 | 主要統合のみ | プロジェクトではVPC Link統合が必要で、HTTP APIでサポート済み |
| API管理 | 豊富 | 基本的な機能 | 基本的なAPI管理機能で十分 |
| JWT認証 | 要カスタム実装 | ネイティブサポート | JWT認証要件に合致 |

### 2.2 API命名規則

| 環境 | API名 | API ID |
|-----|------|--------|
| 開発環境（dev） | ecsforgate-api-dev | 自動生成 |
| ステージング環境（stg） | ecsforgate-api-stg | 自動生成 |
| 本番環境（prd） | ecsforgate-api-prd | 自動生成 |

### 2.3 エンドポイントタイプ

| 設定項目 | 値 | 説明 |
|---------|-----|-----|
| タイプ | プライベート | VPC内からのみアクセス可能なプライベートAPIエンドポイント |
| プロトコル | HTTPS | TLS暗号化通信のみ使用 |
| API Gateway URL | https://{api-id}.execute-api.{region}.amazonaws.com/{stage} | 基本URL形式 |
| カスタムドメイン | なし（将来拡張可能性あり） | 現段階ではカスタムドメイン不要 |

## 3. VPC統合

### 3.1 VPC Endpoint (Interface)

API Gatewayをプライベートアクセスするために、VPCエンドポイント（インターフェイス）を設定します：

| 設定項目 | 値 | 説明 |
|---------|-----|-----|
| サービス名 | com.amazonaws.{region}.execute-api | API Gatewayサービスエンドポイント |
| VPC | プロジェクトVPC | 対象VPC |
| サブネット | PrivateAppSubnetA, PrivateAppSubnetB | 配置サブネット |
| セキュリティグループ | ecsforgate-{env}-api-gw-endpoint-sg | エンドポイント用セキュリティグループ |
| ポリシー | 最小権限 | VPC内IPアドレス範囲からのみアクセス許可 |
| プライベートDNS | 有効 | 標準URLでのアクセスを可能に |

### 3.2 VPC Link

API GatewayからVPC内のALBに接続するためのVPC Linkを設定します：

| 設定項目 | 値 | 説明 |
|---------|-----|-----|
| 名前 | ecsforgate-{env}-vpc-link | VPC Link名 |
| VPC | プロジェクトVPC | 対象VPC |
| サブネット | PrivateAppSubnetA, PrivateAppSubnetB | 配置サブネット |
| セキュリティグループ | ecsforgate-{env}-vpc-link-sg | VPC Link用セキュリティグループ |

### 3.3 セキュリティグループ設定

#### 3.3.1 API Gateway VPC Endpointセキュリティグループ
- **名前**: ecsforgate-{env}-api-gw-endpoint-sg
- **インバウンドルール**:
  - HTTPS (443) - ソース: 10.0.0.0/16 (VPC CIDR)
- **アウトバウンドルール**:
  - すべてのトラフィック - 送信先: 0.0.0.0/0

#### 3.3.2 VPC Linkセキュリティグループ
- **名前**: ecsforgate-{env}-vpc-link-sg
- **インバウンドルール**:
  - すべてのトラフィック - ソース: API Gateway VPC Endpointセキュリティグループ
- **アウトバウンドルール**:
  - HTTP (80) - 送信先: ALBセキュリティグループ

## 4. API設計

### 4.1 API統合設定

| 統合タイプ | ターゲット | 説明 |
|----------|----------|------|
| HTTP | 内部ALB (VPC Link経由) | VPC内の内部ALBに統合 |
| 統合URI | http://ecsforgate-{env}-alb-{random-id}.{region}.elb.amazonaws.com | ALBのDNS名 |
| タイムアウト | 30秒 | 統合リクエストタイムアウト値 |
| プロトコル | HTTP | バックエンドプロトコル |

### 4.2 ルート定義

以下のAPIルート（エンドポイント）を定義します：

| HTTPメソッド | リソースパス | 統合ターゲット | 認証 | スロットリング |
|------------|------------|--------------|------|-------------|
| ANY | /{proxy+} | ALB | JWT | 標準レート |
| GET | /health | ALB:/api/health | なし | 高レート |
| GET | /api/records | ALB:/api/records | JWT | 標準レート |
| GET | /api/records/{id} | ALB:/api/records/{id} | JWT | 標準レート |
| POST | /api/records | ALB:/api/records | JWT | 標準レート |
| PUT | /api/records/{id} | ALB:/api/records/{id} | JWT | 標準レート |
| DELETE | /api/records/{id} | ALB:/api/records/{id} | JWT | 標準レート |

### 4.3 パラメータマッピング

リクエストパラメータの適切なマッピングを設定します：

| パラメータタイプ | ソース | 送信先 | 説明 |
|--------------|------|-------|------|
| パスパラメータ | URL | ALBのURL | 例: {id} -> {id} |
| クエリパラメータ | URL | ALBへのクエリ文字列 | 例: ?limit=10 -> ?limit=10 |
| ヘッダー | リクエストヘッダー | ALBへのヘッダー | 例: Authorization -> Authorization |

### 4.4 レスポンスマッピング

以下のレスポンスマッピングを設定します：

| HTTPステータスコード | 説明 | マッピング |
|--------------------|------|----------|
| 2XX | 成功レスポンス | ALBからのレスポンスをそのまま返却 |
| 4XX | クライアントエラー | ALBからのレスポンスをそのまま返却 |
| 5XX | サーバーエラー | ALBからのレスポンスをそのまま返却 |
| 504 | ゲートウェイタイムアウト | カスタムエラーメッセージ |

## 5. 認証・認可設定

### 5.1 JWT認証

API Gateway HTTP APIのネイティブJWT認証機能を使用して、以下の設定を行います：

| 設定項目 | 値 | 説明 |
|---------|-----|-----|
| アイデンティティソース | $request.header.Authorization | JWT取得元 |
| 発行者 | https://ecsforgate.auth0.com/ | JWT発行者URL |
| オーディエンス | ecsforgate-api | JWT対象サービス識別子 |
| アルゴリズム | RS256 | 署名アルゴリズム |
| 鍵ロケーション | JWKS URL | JWKSエンドポイント |
| キャッシュ | 1時間 | JWKS情報キャッシュ時間 |

### 5.2 スコープと権限設定

JWTに含まれるスコープに基づいて、以下の権限を設定します：

| スコープ | メソッド | リソースパス | 説明 |
|---------|---------|------------|------|
| read | GET | /api/records, /api/records/{id} | 記録の参照権限 |
| write | POST, PUT | /api/records, /api/records/{id} | 記録の作成・更新権限 |
| delete | DELETE | /api/records/{id} | 記録の削除権限 |

### 5.3 APIキー設定

現段階ではAPIキー認証は使用せず、JWT認証のみを採用します。将来的な要件変更時に検討します。

## 6. APIステージ設定

### 6.1 ステージ構成

各環境に対して以下のステージを構成します：

| 環境 | ステージ名 | 説明 |
|-----|----------|------|
| 開発環境 | dev | 開発環境用ステージ |
| ステージング環境 | stg | ステージング環境用ステージ |
| 本番環境 | v1 | 本番環境用ステージ（バージョニング） |

### 6.2 ステージ変数

以下のステージ変数を定義し、環境ごとの設定差分を管理します：

| 変数名 | 説明 | 設定例 |
|-------|------|-------|
| environmentName | 環境名 | dev, stg, prd |
| albDnsName | ALBのDNS名 | ecsforgate-{env}-alb-{random-id}.{region}.elb.amazonaws.com |
| loggingLevel | ログレベル | INFO, ERROR |
| throttlingRate | スロットリングレート | dev:300, stg:500, prd:1000 |

### 6.3 自動デプロイ

環境ごとのCI/CDパイプラインを通じて、ステージへの自動デプロイを設定します：

| 環境 | トリガー | デプロイ方法 | 承認フロー |
|-----|---------|------------|----------|
| 開発環境 | 開発ブランチへのコミット | 自動 | なし |
| ステージング環境 | ステージングブランチへのマージ | 自動 | なし |
| 本番環境 | リリースタグの作成 | 自動 | 手動承認後 |

## 7. キャッシュとスロットリング

### 7.1 APIキャッシュ設定

| 設定項目 | 開発環境 | ステージング環境 | 本番環境 |
|---------|---------|----------------|---------|
| キャッシュ有効化 | 無効 | 有効 | 有効 |
| キャッシュサイズ | - | 0.5GB | 1.0GB |
| TTL | - | 300秒 | 300秒 |
| 暗号化 | - | 有効 | 有効 |
| パラメータキャッシュ | - | クエリ文字列、ヘッダー | クエリ文字列、ヘッダー |

### 7.2 スロットリング設定

| 設定項目 | 開発環境 | ステージング環境 | 本番環境 |
|---------|---------|----------------|---------|
| レートリミット（アカウント） | 300リクエスト/秒 | 500リクエスト/秒 | 1000リクエスト/秒 |
| バーストリミット（アカウント） | 500リクエスト | 800リクエスト | 2000リクエスト |
| レートリミット（ルート） | /health: 100/秒<br>その他: 50/秒 | /health: 200/秒<br>その他: 100/秒 | /health: 300/秒<br>その他: 200/秒 |

### 7.3 使用量プラン

将来的な拡張に備えて、以下の使用量プランを検討します（現段階では未実装）：

| プラン名 | リクエスト上限 | スロットリング | 課金 | 対象API |
|---------|-------------|-------------|------|--------|
| 基本プラン | 100,000 / 月 | 100/秒 | なし | すべてのAPI |
| 標準プラン | 1,000,000 / 月 | 500/秒 | なし | すべてのAPI |
| 拡張プラン | 10,000,000 / 月 | 1000/秒 | なし | すべてのAPI |

## 8. ロギングとモニタリング

### 8.1 アクセスログ設定

CloudWatch Logsへのアクセスログ記録を設定します：

| 設定項目 | 値 | 説明 |
|---------|-----|-----|
| ログ有効化 | 有効 | API呼び出しのログ記録 |
| ロググループ | /aws/apigateway/ecsforgate-{env} | ロググループ名 |
| ログ形式 | JSON | ログフォーマット |
| 保持期間 | 開発: 14日<br>ステージング: 30日<br>本番: 90日 | ログ保持期間 |

### 8.2 実行ログ設定

API Gatewayの詳細実行ログを有効化します：

| 設定項目 | 開発環境 | ステージング環境 | 本番環境 |
|---------|---------|----------------|---------|
| ログレベル | INFO | INFO | ERROR |
| フル実行ログ | 有効 | 必要に応じて | 無効 |
| データトレース | 有効 | 必要に応じて | 無効 |

### 8.3 CloudWatchメトリクス

以下のメトリクスを監視します：

| メトリクス | 説明 | データポイント | 統計 |
|----------|------|-------------|------|
| Count | API呼び出し数 | 1分 | Sum |
| 4XXError | 4XXエラー数 | 1分 | Sum |
| 5XXError | 5XXエラー数 | 1分 | Sum |
| Latency | レイテンシー | 1分 | Average, p95, p99 |
| IntegrationLatency | 統合レイテンシー | 1分 | Average, p95, p99 |
| CacheHitCount | キャッシュヒット数 | 1分 | Sum |
| CacheMissCount | キャッシュミス数 | 1分 | Sum |

### 8.4 アラート設定

以下のアラートを設定します：

| アラート名 | 条件 | 通知方法 | 重要度 |
|----------|------|---------|-------|
| High5XXErrorRate | 5XXError > 10 (1分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 |
| High4XXErrorRate | 4XXError > 100 (1分間) | 開発：メール<br>ステージング：メール<br>本番：メール | 中 |
| HighLatency | Latency (p95) > 1000ms (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 |
| APITrafficSpike | Count > 通常平均の300% | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 |

## 9. ドキュメント管理

### 9.1 OpenAPI仕様

API GatewayのOpenAPI 3.0仕様を管理します：

| 設定項目 | 値 | 説明 |
|---------|-----|-----|
| OpenAPI定義 | ecsforgate-api-{env}.yaml | OpenAPI仕様ファイル名 |
| 管理方法 | GitリポジトリでのIaC管理 | 定義ファイルの管理方法 |
| インポート/エクスポート | CI/CDパイプライン連携 | 定義ファイルの自動反映 |

### 9.2 APIドキュメント

**OpenAPIベースのドキュメント例**:

```yaml
openapi: 3.0.1
info:
  title: ECSForgate API
  description: 確認記録用APIサービス
  version: '1.0'
paths:
  /api/records:
    get:
      summary: 確認記録の一覧取得
      security:
        - JWTAuthorizer: []
      responses:
        '200':
          description: OK
    post:
      summary: 新規確認記録の作成
      security:
        - JWTAuthorizer: []
      responses:
        '201':
          description: Created
  /api/records/{id}:
    get:
      summary: 特定の確認記録の取得
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      security:
        - JWTAuthorizer: []
      responses:
        '200':
          description: OK
    put:
      summary: 確認記録の更新
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      security:
        - JWTAuthorizer: []
      responses:
        '200':
          description: OK
    delete:
      summary: 確認記録の削除
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      security:
        - JWTAuthorizer: []
      responses:
        '204':
          description: No Content
components:
  securitySchemes:
    JWTAuthorizer:
      type: oauth2
      flows:
        implicit:
          authorizationUrl: https://ecsforgate.auth0.com/authorize
          scopes:
            read: Read access
            write: Write access
            delete: Delete access
```

## 10. WAF連携

### 10.1 AWS WAF設定

将来的なセキュリティ強化として、AWS WAFとの連携を検討します：

| 設定項目 | 値 | 説明 |
|---------|-----|-----|
| WAF有効化 | 開発：無効<br>ステージング：無効<br>本番：有効 | AWS WAFの有効化状態 |
| WAFウェブACL名 | ecsforgate-{env}-waf-acl | ウェブACL名 |
| ルール群 | AWS管理ルール + カスタムルール | 適用するWAFルール群 |

### 10.2 WAFルール設定

本番環境に適用するWAFルールを以下のように設定します：

| ルール名 | タイプ | 優先度 | アクション | 説明 |
|---------|------|-------|----------|------|
| AWSManagedRulesCommonRuleSet | マネージドルール | 10 | Block | 共通脆弱性に対する保護 |
| AWSManagedRulesKnownBadInputsRuleSet | マネージドルール | 20 | Block | 既知の不正入力パターン防御 |
| RateBasedRule | レートベース | 100 | Block | IPごとに5分間で1000リクエスト制限 |
| PreventSQLi | カスタム | 200 | Block | SQLインジェクション試行の検出とブロック |
| PreventXSS | カスタム | 300 | Block | XSS試行の検出とブロック |

## 11. 環境差分

環境ごとの主な差分は以下の通りです：

| 設定項目 | 開発環境（dev） | ステージング環境（stg） | 本番環境（prd） |
|---------|--------------|-------------------|--------------| 
| ステージ名 | dev | stg | v1 |
| キャッシュ | 無効 | 有効（0.5GB） | 有効（1.0GB） |
| スロットリング（アカウント） | 300/秒 | 500/秒 | 1000/秒 |
| ログレベル | INFO | INFO | ERROR |
| データトレース | 有効 | 必要に応じて | 無効 |
| WAF統合 | 無効 | 無効 | 有効 |
| バックアップ計画 | 無効 | 無効 | 有効 |

## 12. CloudFormationリソース定義

API Gateway構成のためのCloudFormationリソースタイプと主要パラメータを以下に示します：

### 12.1 主要リソースタイプ
- **AWS::ApiGatewayV2::Api**: API Gatewayの定義
- **AWS::ApiGatewayV2::Stage**: APIステージの定義
- **AWS::ApiGatewayV2::Route**: APIルートの定義
- **AWS::ApiGatewayV2::Integration**: バックエンド統合の定義
- **AWS::ApiGatewayV2::Authorizer**: JWT認証設定の定義
- **AWS::ApiGatewayV2::VpcLink**: VPCリンクの定義
- **AWS::EC2::SecurityGroup**: VPCエンドポイントとVPCリンク用のセキュリティグループ定義
- **AWS::EC2::VPCEndpoint**: VPCエンドポイントの定義
- **AWS::Logs::LogGroup**: ログ設定の定義
- **AWS::CloudWatch::Alarm**: アラートの定義

### 12.2 主要パラメータ例

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

  StageName:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - stg
      - v1
    Description: APIステージ名

  VpcId:
    Type: AWS::EC2::VPC::Id
    Description: VPC ID

  PrivateAppSubnetA:
    Type: AWS::EC2::Subnet::Id
    Description: アプリケーション層プライベートサブネットA

  PrivateAppSubnetB:
    Type: AWS::EC2::Subnet::Id
    Description: アプリケーション層プライベートサブネットB

  AlbId:
    Type: String
    Description: 内部ALBのID

  AlbDnsName:
    Type: String
    Description: 内部ALBのDNS名

  JwtIssuer:
    Type: String
    Default: https://ecsforgate.auth0.com/
    Description: JWT発行者URL

  JwtAudience:
    Type: String
    Default: ecsforgate-api
    Description: JWT対象サービス識別子

  LogRetentionDays:
    Type: Number
    Default: 14
    AllowedValues:
      - 7
      - 14
      - 30
      - 60
      - 90
    Description: ログの保持期間（日）

  ThrottlingRateLimit:
    Type: Number
    Default: 300
    Description: APIスロットリングレート（1秒あたりのリクエスト数）
```

## 13. 考慮すべきリスクと対策

| リスク | 影響度 | 対策 |
|-------|-------|------|
| 認証障害 | 高 | JWT認証の冗長化、フォールバックメカニズム |
| VPC接続障害 | 高 | VPCエンドポイントの冗長化、接続監視 |
| APIスロットリング超過 | 中 | 適切なレート制限、クライアントへの429応答 |
| キャッシュ整合性問題 | 中 | 適切なTTL設定、無効化メカニズムの実装 |
| JWT署名検証失敗 | 高 | 鍵のローテーション計画、監視強化 |
| リクエスト/レスポンスサイズ上限 | 中 | サイズ制限ガイドライン、分割転送の検討 |

## 14. 設計検証方法

本API Gateway設計の妥当性を確認するために、以下の検証を実施します：

### 14.1 機能検証
- VPCエンドポイント経由のアクセス確認
- VPC Link統合の動作確認
- JWT認証の有効性確認
- API呼び出し結果の検証

### 14.2 性能検証
- レイテンシー測定
- スループット検証
- スロットリング動作確認
- キャッシュ有効性検証

### 14.3 セキュリティ検証
- JWT認証バイパス試行のブロック確認
- 異常パターンリクエストの処理確認
- 暗号化通信の検証
- 権限分離の有効性確認

### 14.4 可用性検証
- AZ障害時の動作確認
- エンドポイント冗長性の検証
- 継続的な負荷下での安定性確認
- エラー処理の検証

## 15. 運用考慮点

### 15.1 通常運用時の考慮点
- APIトラフィックとメトリクスの定期的な分析
- キャッシュヒット率の監視と最適化
- JWT認証の状態監視
- パフォーマンス傾向の分析

### 15.2 障害発生時の考慮点
- エラーログの迅速な分析
- トラブルシューティングのための一時的なログレベル調整
- 問題の切り分け手順（API Gateway、VPC Link、バックエンドALB）
- 復旧優先順位の設定

### 15.3 メンテナンス時の考慮点
- API定義変更時の互換性維持
- ステージデプロイの計画的実施
- クライアントへの変更通知プロセス
- JWT認証情報のローテーション計画
