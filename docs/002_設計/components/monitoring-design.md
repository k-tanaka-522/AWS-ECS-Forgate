# 監視設計書

## 1. 概要

### 1.1 目的と責任範囲
本ドキュメントでは、ECSForgateプロジェクトにおける監視に関する設計を定義します。この設計は、すべてのコンポーネント（VPC、RDS、ECS Fargate、ALB、API Gateway）に関するメトリクス収集、アラート、ダッシュボード、分散トレーシングの方針と実装詳細を規定し、一貫性のある監視体制の実現を担います。

### 1.2 設計のポイント
- 包括的なメトリクス収集とアラート体制による迅速な障害検知と対応
- 各コンポーネントの健全性と性能の可視化
- X-Ray分散トレーシングによるエンドツーエンドのリクエスト追跡
- 環境ごとに適切な監視レベルとアラート閾値の定義
- Amazon Connectによる電話通知機能を将来的に導入

### 1.3 メトリクス実装の区分

本設計におけるメトリクスは以下の区分によって実装方法を明確化します：

1. **インフラ構築のみで実現可能なメトリクス**：
   - AWS標準メトリクス（CloudWatch自動収集メトリクス）
   - インフラ構築時に設定可能なメトリクス（ログフィルタなど）

2. **アプリケーション組み込みが必要なメトリクス**：
   - Spring Boot Actuatorを使用したアプリケーションメトリクス
   - カスタムビジネスメトリクス
   - X-Ray分散トレーシング

これにより、インフラチーム（構築担当）とアプリケーションチーム（開発担当）の役割と責任範囲を明確化します。

## 2. 監視アーキテクチャ

下図は、ECSForgateシステムにおける監視アーキテクチャの概要を示しています：

```
+----------------+   +----------------+   +-----------------+   +---------------+
| ECS Fargate    |   | RDS            |   | ALB             |   | API Gateway   |
| (メトリクス)    |   | (メトリクス)    |   | (メトリクス)     |   | (メトリクス)   |
+----------------+   +----------------+   +-----------------+   +---------------+
        |                    |                     |                   |
        v                    v                     v                   v
+--------------------------------------------------------------------+
|                         CloudWatch                                  |
+--------------------------------------------------------------------+
        |                    |                     |                   |
        v                    v                     v                   v
+----------------+   +----------------+   +-----------------+   +---------------+
| X-Ray          |   | ダッシュボード   |   | アラーム        |   | 通知 (SNS)    |
| (トレース)      |   | (可視化)        |   | (検知)          |   | (通知)        |
+----------------+   +----------------+   +-----------------+   +---------------+
                                                                        |
                                                                        v
                                                               +------------------+
                                                               | Amazon Connect   |
                                                               | (将来的な電話通知) |
                                                               +------------------+
```

## 3. メトリクス収集

以下の主要メトリクスを収集・監視します：

### 3.1 コンポーネント共通メトリクス

| メトリクス種別 | 対象サービス | 収集間隔 | 保持期間 | 実装区分 |
|--------------|------------|---------|---------|----------| 
| 基本メトリクス | 全サービス | 1分 | 15日（詳細）、63日（標準） | インフラ構築のみ |
| 詳細メトリクス | 全サービス（本番のみ） | 1分 | 15日 | インフラ構築のみ |
| カスタムメトリクス | アプリケーション | 1分 | 15日 | アプリケーション組み込み |

### 3.2 コンポーネント別メトリクス

#### 3.2.1 インフラ構築のみで実現可能なメトリクス

##### ECS Fargateメトリクス:
- CPUUtilization
- MemoryUtilization
- RunningTaskCount
- PendingTaskCount

##### RDSメトリクス:
- CPUUtilization
- FreeableMemory
- FreeStorageSpace
- DatabaseConnections
- ReadIOPS/WriteIOPS
- ReadLatency/WriteLatency
- ReplicaLag (マルチAZ)
- BurstBalance
- TransactionLogsDiskUsage
- TransactionLogsGeneration

##### ALBメトリクス:
- ActiveConnectionCount
- ConsumedLCUs
- HTTPCode_ELB_4XX_Count/HTTPCode_ELB_5XX_Count
- HTTPCode_Target_2XX_Count/HTTPCode_Target_4XX_Count/HTTPCode_Target_5XX_Count
- TargetResponseTime
- RequestCount
- RejectedConnectionCount
- ProcessedBytes

##### API Gatewayメトリクス:
- Count
- 4XXError/5XXError
- Latency
- IntegrationLatency
- CacheHitCount/CacheMissCount
- ThrottleCount
- ClientError/ServerError

##### VPCメトリクス:
- NetworkIn/NetworkOut
- PacketsIn/PacketsOut
- VPCFlowLogs

#### 3.2.2 アプリケーション組み込みが必要なメトリクス

##### Spring Bootアプリケーションメトリクス:

###### JVMメトリクス
| メトリクス名 | 説明 | 収集間隔 |
|------------|------|---------| 
| jvm.memory.used | JVMが使用しているメモリ量 | 1分 |
| jvm.memory.committed | JVMに割り当てられたメモリ量 | 1分 |
| jvm.memory.max | 最大メモリ設定 | 1分 |
| jvm.gc.pause | ガベージコレクションの一時停止時間 | 1分 |
| jvm.gc.memory.promoted | プロモーションされたメモリ量 | 1分 |
| jvm.gc.max.data.size | GCサイクル中の最大メモリプールサイズ | 1分 |
| jvm.threads.states | スレッド状態別のスレッド数 | 1分 |
| jvm.classes.loaded | ロードされたクラス数 | 1分 |

###### Spring Boot Actuatorメトリクス
| メトリクス名 | 説明 | 収集間隔 |
|------------|------|---------| 
| http.server.requests | HTTP要求統計（メソッド、パス、ステータスコード別） | 1分 |
| spring.datasource.hikari.connections.active | アクティブなデータベース接続数 | 1分 |
| spring.datasource.hikari.connections.pending | 保留中のデータベース接続リクエスト数 | 1分 |
| system.cpu.usage | システムCPU使用率 | 1分 |
| process.cpu.usage | プロセスCPU使用率 | 1分 |
| tomcat.sessions.active.current | アクティブなセッション数 | 1分 |
| tomcat.global.error | Tomcatエラー数 | 1分 |

###### アプリケーション固有のビジネスメトリクス
| メトリクス名 | 説明 | 収集間隔 |
|------------|------|---------| 
| api.records.created | 作成された確認記録数 | 1分 |
| api.records.retrieved | 取得された確認記録数 | 1分 |
| api.records.updated | 更新された確認記録数 | 1分 |
| api.records.deleted | 削除された確認記録数 | 1分 |
| api.records.failed | 失敗した確認記録操作数 | 1分 |

###### キャッシュとパフォーマンスメトリクス
| メトリクス名 | 説明 | 収集間隔 |
|------------|------|---------| 
| cache.gets | キャッシュ取得回数 | 1分 |
| cache.puts | キャッシュ登録回数 | 1分 |
| cache.evictions | キャッシュ削除回数 | 1分 |
| cache.hit.ratio | キャッシュヒット率 | 1分 |
| spring.data.repository.invocations | リポジトリメソッド呼び出し数 | 1分 |

###### セキュリティメトリクス
| メトリクス名 | 説明 | 収集間隔 |
|------------|------|---------| 
| security.authentication.success | 認証成功数 | 1分 |
| security.authentication.failure | 認証失敗数 | 1分 |
| security.authorization.denied | 認可拒否数 | 1分 |

### 3.3 アプリケーション組み込みのために必要な依存関係と設定

#### 3.3.1 必要な依存関係（build.gradleまたはpom.xml）
```java
// Spring Boot Actuator（メトリクス収集用）
implementation 'org.springframework.boot:spring-boot-starter-actuator'

// CloudWatch連携用
implementation 'io.micrometer:micrometer-registry-cloudwatch'
implementation 'org.springframework.cloud:spring-cloud-starter-aws'

// X-Ray連携用（オプション）
implementation 'com.amazonaws:aws-xray-recorder-sdk-spring'
```

#### 3.3.2 必要な設定（application.properties または application.yml）
```yaml
# Actuator設定
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  metrics:
    export:
      cloudwatch:
        namespace: ECSForgate-${spring.profiles.active:dev}
        batchSize: 20
        step: 1m
    tags:
      application: ecsforgate-api
      environment: ${spring.profiles.active:dev}

# X-Ray設定（オプション）
cloud:
  aws:
    xray:
      enabled: true
```

## 4. アラート設定

### 4.1 メトリクスベースのアラート条件と通知方法

以下のメトリクスベースのアラート条件を設定し、SNSトピックを通じて通知します：

| アラート名 | 条件 | 通知方法 | 重要度 | 実装区分 |
|----------|------|---------|-------|---------| 
| **ECS関連** |
| High CPU Utilization | CPUUtilization > 80% (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 | インフラ構築のみ |
| High Memory Utilization | MemoryUtilization > 80% (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 | インフラ構築のみ |
| Task Count Changed | RunningTaskCount < DesiredTaskCount (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 | インフラ構築のみ |
| **RDS関連** |
| High DB CPU | CPUUtilization > 80% (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 | インフラ構築のみ |
| Low Free Memory | FreeableMemory < 10% (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 | インフラ構築のみ |
| Low Storage Space | FreeStorageSpace < 20% (15分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 | インフラ構築のみ |
| High Connection Count | DatabaseConnections > 80% of max (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 | インフラ構築のみ |
| **ALB関連** |
| High 5XX Error Rate | HTTPCode_ELB_5XX_Count > 10 (1分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 | インフラ構築のみ |
| High 4XX Error Rate | HTTPCode_ELB_4XX_Count > 50 (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール | 中 | インフラ構築のみ |
| High Response Time | TargetResponseTime > 1秒 (p95, 5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 | インフラ構築のみ |
| **API Gateway関連** |
| API Gateway 5XX | 5XXError > 10 (1分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 | インフラ構築のみ |
| API Gateway Latency | Latency > 1000ms (p95, 5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 | インフラ構築のみ |
| API Gateway Throttling | ThrottleCount > 5 (1分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 | インフラ構築のみ |
| **Spring Boot関連** |
| JVM Memory High | jvm.memory.used > 80% (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 | アプリケーション組み込み |
| GC Pause Time High | jvm.gc.pause > 500ms (3回以上/5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 | アプリケーション組み込み |
| HTTP Server Error Rate | http.server.requests (status=5xx) > 5 (1分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 | アプリケーション組み込み |
| Slow HTTP Request | http.server.requests (p95) > 1000ms (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 中 | アプリケーション組み込み |
| DB Connection Pool Saturation | spring.datasource.hikari.connections.active > 80% of max (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 | アプリケーション組み込み |
| Authentication Failure Spike | security.authentication.failure > 10 (5分間) | 開発：メール<br>ステージング：メール<br>本番：メール + SMS | 高 | アプリケーション組み込み |

### 4.2 ログベースのアラート条件と通知方法

以下のログパターンを検出し、アラートを発生させます：

| パターン | 対象ログ | アラート条件 | 重要度 | 実装区分 |
|---------|---------|------------|-------|----------|
| ERROR | アプリケーションログ | 5分間で5回以上 | 高 | インフラ構築のみ |
| WARN（特定パターン） | アプリケーションログ | 5分間で10回以上 | 中 | インフラ構築のみ |
| 500エラー | ALBアクセスログ | 1分間で5回以上 | 高 | インフラ構築のみ |
| 401/403エラー | API Gatewayログ | 5分間で20回以上 | 中 | インフラ構築のみ |
| データベース接続エラー | アプリケーションログ | 1回以上 | 高 | インフラ構築のみ |
| リクエスト遅延 | アプリケーションログ | 5分間でp95 > 1000ms | 中 | インフラ構築のみ |

### 4.3 SNSトピック設定

アラート通知用のSNSトピックを以下のように設定します：

| 環境 | トピック名 | サブスクリプション | 暗号化 | 実装区分 |
|-----|----------|-----------------|-------|----------|
| 開発環境 | ecsforgate-dev-alerts | メール | AWS管理キー | インフラ構築のみ |
| ステージング環境 | ecsforgate-stg-alerts | メール | カスタマー管理キー | インフラ構築のみ |
| 本番環境 | ecsforgate-prd-alerts<br>ecsforgate-prd-critical-alerts | メール<br>メール + SMS | カスタマー管理キー | インフラ構築のみ |

### 4.4 将来的なAmazon Connect連携

将来的に実装予定の重要度「最高」のアラートに対するAmazon Connect連携の設計：

1. **対象アラート**:
   - RDS障害（インスタンス停止、レプリケーション異常）
   - ECSサービス停止
   - ALB健全性低下
   - APIサービス全体のレスポンス不可

2. **Amazon Connect設定**:
   - 電話通知フロー設計
   - 担当者ローテーション連携
   - エスカレーションルール

3. **通知フロー**:
   ```
   CloudWatch Alarm → SNS → Lambda → Amazon Connect → 電話通知
   ```

4. **コールスクリプト例**:
   ```
   こちらはECSForgateシステム監視センターです。
   重大なアラートが発生しました。
   アラート内容：{アラート名}
   発生時刻：{タイムスタンプ}
   対応が必要です。確認のため1を押してください。
   ```

**実装区分**: インフラ構築のみ

## 5. ダッシュボード設計

主要なメトリクスを含むCloudWatchダッシュボードを環境ごとに設計します：

### 5.1 ダッシュボード構成

1. **概要ダッシュボード** (**実装区分**: インフラ構築のみ)
   - サービス全体の健全性
   - 主要メトリクスのサマリー
   - 直近のアラートと障害の概要
   - リクエスト数とエラー率のグラフ
   - CPUとメモリ使用率のグラフ

2. **ECSダッシュボード** (**実装区分**: インフラ構築のみ、Spring Bootメトリクスはアプリケーション組み込み)
   - タスク稼働状況
   - CPU/メモリ使用率（サービス全体と個別タスク）
   - デプロイ状況
   - アプリケーションメトリクス
   - カスタムメトリクスグラフ
   - ヘルスチェック状態

3. **RDSダッシュボード** (**実装区分**: インフラ構築のみ)
   - データベース性能メトリクス
   - 接続数とクエリ統計
   - ストレージ使用率とIOPS
   - レプリケーション状態（マルチAZ）
   - バックアップ状態
   - パフォーマンスインサイト（拡張監視）

4. **ALB/API Gatewayダッシュボード** (**実装区分**: インフラ構築のみ)
   - リクエスト数と応答時間
   - エラー率とステータスコード分布
   - 接続統計
   - ターゲットグループの健全性
   - APIステージごとのメトリクス
   - スロットリング状態

5. **Spring Bootアプリケーションダッシュボード** (**実装区分**: インフラ構築とアプリケーション組み込みの両方が必要)
   - **JVM状態監視**
     - JVMメモリ使用率（ヒープ、非ヒープ）
     - ガベージコレクション活動（回数、一時停止時間）
     - スレッド状態（実行中、ブロック、待機）
     - クラスロード統計
   - **アプリケーションパフォーマンス**
     - エンドポイント別レスポンスタイム
     - リクエスト数とエラー率
     - トランザクション成功率
     - データベース接続プール状態
   - **キャッシュパフォーマンス**
     - キャッシュヒット率
     - キャッシュ使用状況
     - キャッシュエビクション
   - **ビジネスメトリクス**
     - 確認記録操作数（作成/取得/更新/削除）
     - 機能別使用状況
     - エラー発生状況
   - **セキュリティメトリクス**
     - 認証成功/失敗数
     - 認可拒否数
     - セッション数

### 5.2 ダッシュボード自動更新

CI/CDパイプラインの一部として、CloudWatchダッシュボードをコードで管理し、自動更新します：

- CloudFormationテンプレートによるダッシュボード定義
- JSON形式でのダッシュボード設定の管理
- 環境ごとのパラメータ化
- 新機能リリースに合わせたダッシュボード更新自動化

**実装区分**: インフラ構築のみ

### 5.3 ダッシュボードウィジェット例

```json
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ECS", "CPUUtilization", "ServiceName", "${ECSServiceName}", "ClusterName", "${ECSClusterName}" ]
        ],
        "period": 60,
        "stat": "Average",
        "region": "${AWS::Region}",
        "title": "ECS CPU Utilization"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ECS", "MemoryUtilization", "ServiceName", "${ECSServiceName}", "ClusterName", "${ECSClusterName}" ]
        ],
        "period": 60,
        "stat": "Average",
        "region": "${AWS::Region}",
        "title": "ECS Memory Utilization"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "${LoadBalancerName}" ]
        ],
        "period": 60,
        "stat": "p95",
        "region": "${AWS::Region}",
        "title": "ALB Response Time (p95)"
      }
    }
  ]
}
```

## 6. X-Ray分散トレーシング

### 6.1 トレーシング設定

アプリケーションとAWSサービス間のトレースを以下のように設定します：

| コンポーネント | トレーシング設定 | サンプリングルール | 実装区分 |
|--------------|---------------|----------------|----------|
| ECS Fargate (Spring Boot) | X-Ray SDK for Java | 開発: 100%<br>ステージング: 50%<br>本番: 10% | アプリケーション組み込み |
| API Gateway | アクティブトレース | 開発: 100%<br>ステージング: 50%<br>本番: 10% | インフラ構築のみ |
| ALB | アクティブトレース | 開発: 100%<br>ステージング: 50%<br>本番: 10% | インフラ構築のみ |

### 6.2 カスタムサンプリングルール

以下のカスタムサンプリングルールを設定します：

| ルール名 | 優先度 | リザーバサイズ | レート | 条件 | 実装区分 |
|---------|-------|--------------|------|------|----------|
| HealthEndpoints | 10 | 0 | 0% | service="*" AND http.url CONTAINS "/health" | インフラ構築のみ |
| ErrorTraces | 100 | 50 | 50% | service="*" AND http.status >= 400 | インフラ構築のみ |
| APIEndpoints | 200 | 10 | 10% | service="*" AND http.url CONTAINS "/api" | インフラ構築のみ |
| SlowRequests | 150 | 20 | 25% | service="*" AND responseTime > 1000 | インフラ構築のみ |

### 6.3 X-Rayアノテーション

X-Rayトレースには以下のアノテーションを追加します：

- environment: 実行環境（dev/stg/prd）
- service: サービス名
- version: アプリケーションバージョン
- user_id: リクエストユーザーID（存在する場合）
- request_id: リクエスト識別子
- feature_flags: 有効なフィーチャーフラグ

**実装区分**: アプリケーション組み込み

### 6.4 X-Ray実装詳細

#### Spring Bootアプリケーション設定

```java
// X-Ray設定クラス
@Configuration
public class XRayConfig {
    
    @Bean
    public Filter xrayFilter() {
        return new AWSXRayServletFilter("ECSForgate-API");
    }
    
    @Bean
    public WebMvcConfigurer xrayInterceptorConfig(XRayTraceInterceptor interceptor) {
        return new WebMvcConfigurer() {
            @Override
            public void addInterceptors(InterceptorRegistry registry) {
                registry.addInterceptor(interceptor);
            }
        };
    }
}

// トレース用インターセプター
@Component
public class XRayTraceInterceptor implements HandlerInterceptor {
    
    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        Segment segment = AWSXRay.getCurrentSegment();
        if (segment != null) {
            // アノテーション追加
            segment.putAnnotation("environment", "${ENVIRONMENT}");
            segment.putAnnotation("service", "ecsforgate-api");
            segment.putAnnotation("version", "${APP_VERSION}");
            
            // 認証ユーザーがあれば追加
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.getPrincipal() != null) {
                segment.putAnnotation("user_id", auth.getName());
            }
            
            // リクエストID追加
            String requestId = request.getHeader("X-Request-ID");
            if (requestId != null) {
                segment.putAnnotation("request_id", requestId);
            }
        }
        return true;
    }
}
```

**実装区分**: アプリケーション組み込み

## 7. 環境差分

環境ごとの監視に関する主な差分は以下の通りです：

| 設定項目 | 開発環境（dev） | ステージング環境（stg） | 本番環境（prd） | 実装区分 |
|---------|--------------|-------------------|--------------|-----------| 
| 詳細メトリクス | 基本のみ | 基本 + 一部詳細 | すべて有効 | インフラ構築のみ |
| メトリクス収集間隔 | 1分 | 1分 | 1分 | インフラ構築のみ |
| アラート通知 | メールのみ | メールのみ | メール + SMS | インフラ構築のみ |
| X-Rayサンプリング | 100% | 50% | 10% | インフラ構築のみ/アプリケーション組み込み |
| ダッシュボード更新頻度 | リリース時 | リリース時 | リリース時 + 日次（自動） | インフラ構築のみ |
| Amazon Connect連携 | 無効 | 無効 | 将来的に有効化 | インフラ構築のみ |

## 8. CloudFormationリソース定義

監視のためのCloudFormationリソースタイプと主要パラメータを以下に示します：

```yaml
Resources:
  # ダッシュボード定義
  SystemDashboard:
    Type: AWS::CloudWatch::Dashboard
    Properties:
      DashboardName: !Sub "ECSForgate-${EnvironmentName}-Dashboard"
      DashboardBody: !Sub |
        {
          "widgets": [
            {
              "type": "metric",
              "x": 0,
              "y": 0,
              "width": 12,
              "height": 6,
              "properties": {
                "metrics": [
                  [ "AWS/ECS", "CPUUtilization", "ServiceName", "${ECSServiceName}", "ClusterName", "${ECSClusterName}" ]
                ],
                "period": 60,
                "stat": "Average",
                "region": "${AWS::Region}",
                "title": "ECS CPU Utilization"
              }
            }
            // 他のウィジェットも同様に定義
          ]
        }

  # SNSトピック定義
  AlertSNSTopic:
    Type: AWS::SNS::Topic
    Properties:
      DisplayName: !Sub "ECSForgate-${EnvironmentName}-Alerts"
      TopicName: !Sub "ecsforgate-${EnvironmentName}-alerts"
      KmsMasterKeyId: !If [UseCustomKey, !Ref AlertsKmsKey, !Ref "AWS::NoValue"]
      Subscription:
        - Protocol: email
          Endpoint: !Ref AlertEmail
        - !If 
          - IsCriticalEnv
          - Protocol: sms
            Endpoint: !Ref AlertPhone
          - !Ref "AWS::NoValue"
          
  # X-Ray設定
  SamplingRule:
    Type: AWS::XRay::SamplingRule
    Properties:
      SamplingRule:
        RuleName: !Sub "ECSForgate-${EnvironmentName}-ApiSampling"
        Priority: 100
        ReservoirSize: !FindInMap [EnvironmentMap, !Ref EnvironmentName, XRayReservoirSize]
        FixedRate: !FindInMap [EnvironmentMap, !Ref EnvironmentName, XRaySamplingRate]
        ServiceName: "*"
        ServiceType: "*"
        Host: "*"
        HTTPMethod: "*"
        URLPath: "/api/*"
        Version: 1
  
  # メトリクスベースのCloudWatchアラーム
  HighCpuAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${EnvironmentName}-HighCpuUtilization"
      AlarmDescription: "CPU utilization is high for the ECS service"
      MetricName: CPUUtilization
      Namespace: AWS/ECS
      Dimensions:
        - Name: ServiceName
          Value: !Ref ECSServiceName
        - Name: ClusterName
          Value: !Ref ECSClusterName
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 80
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref AlertSNSTopic
      OKActions:
        - !Ref AlertSNSTopic
        
  # ログベースのフィルタとアラーム
  ErrorLogMetricFilter:
    Type: AWS::Logs::MetricFilter
    Properties:
      LogGroupName: !Ref ApplicationLogGroup
      FilterPattern: '{ $.level = "ERROR" }'
      MetricTransformations:
        - MetricName: !Sub "ErrorCount-${EnvironmentName}"
          MetricNamespace: !Sub "ECSForgate/${EnvironmentName}"
          MetricValue: "1"
          DefaultValue: 0
          
  ErrorLogAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${EnvironmentName}-HighErrorRate"
      AlarmDescription: "Error log rate exceeded threshold"
      MetricName: !Sub "ErrorCount-${EnvironmentName}"
      Namespace: !Sub "ECSForgate/${EnvironmentName}"
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 1
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref AlertSNSTopic
      OKActions:
        - !Ref AlertSNSTopic
        
  DatabaseErrorLogMetricFilter:
    Type: AWS::Logs::MetricFilter
    Properties:
      LogGroupName: !Ref ApplicationLogGroup
      FilterPattern: '{ $.message = "*database connection*" && $.level = "ERROR" }'
      MetricTransformations:
        - MetricName: !Sub "DBErrorCount-${EnvironmentName}"
          MetricNamespace: !Sub "ECSForgate/${EnvironmentName}"
          MetricValue: "1"
          DefaultValue: 0
          
  DatabaseErrorAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${EnvironmentName}-DatabaseConnectionError"
      AlarmDescription: "Database connection error detected"
      MetricName: !Sub "DBErrorCount-${EnvironmentName}"
      Namespace: !Sub "ECSForgate/${EnvironmentName}"
      Statistic: Sum
      Period: 60
      EvaluationPeriods: 1
      Threshold: 1
      ComparisonOperator: GreaterThanOrEqualToThreshold
      AlarmActions:
        - !Ref AlertSNSTopic
      OKActions:
        - !Ref AlertSNSTopic
        
  # Spring Boot関連アラーム
  JvmMemoryHighAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${EnvironmentName}-JvmMemoryHigh"
      AlarmDescription: "JVM memory usage is high"
      MetricName: "jvm.memory.used"
      Namespace: !Sub "ECSForgate/${EnvironmentName}"
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 80
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref AlertSNSTopic
      OKActions:
        - !Ref AlertSNSTopic
        
  GcPauseTimeHighAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${EnvironmentName}-GcPauseTimeHigh"
      AlarmDescription: "Garbage collection pause time is high"
      MetricName: "jvm.gc.pause"
      Namespace: !Sub "ECSForgate/${EnvironmentName}"
      Statistic: Maximum
      Period: 300
      EvaluationPeriods: 3
      Threshold: 500
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref AlertSNSTopic
      OKActions:
        - !Ref AlertSNSTopic
        
  HttpServerErrorRateAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${EnvironmentName}-HttpServerErrorRate"
      AlarmDescription: "HTTP server error rate is high"
      MetricName: "http.server.requests"
      Dimensions:
        - Name: status
          Value: "5xx"
      Namespace: !Sub "ECSForgate/${EnvironmentName}"
      Statistic: Sum
      Period: 60
      EvaluationPeriods: 1
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref AlertSNSTopic
      OKActions:
        - !Ref AlertSNSTopic
        
  SlowHttpRequestAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${EnvironmentName}-SlowHttpRequest"
      AlarmDescription: "HTTP request response time is slow"
      MetricName: "http.server.requests"
      Namespace: !Sub "ECSForgate/${EnvironmentName}"
      ExtendedStatistic: p95
      Period: 300
      EvaluationPeriods: 1
      Threshold: 1000
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref AlertSNSTopic
      OKActions:
        - !Ref AlertSNSTopic
```

**実装区分**: インフラ構築のみ

## 9. 考慮すべきリスクと対策

| リスク | 影響度 | 対策 | 実装区分 |
|-------|-------|------|----------|
| アラート過多（アラート疲れ） | 中 | 重要度に基づくフィルタリング、集約設定、段階的通知 | インフラ構築のみ |
| メトリクスデータ量の増大 | 中 | 環境ごとの適切なメトリクス粒度設定、コスト監視 | インフラ構築のみ |
| X-Rayサンプリングによる重要トレース見逃し | 高 | エラートレースの優先サンプリング、重要エンドポイントの高サンプリング率 | インフラ構築のみ |
| 監視の見落とし | 高 | 重要な指標の複数通知経路、ダッシュボード可視化強化 | インフラ構築のみ |
| アラート閾値の不適切な設定 | 中 | 定期的な閾値レビューと調整、環境特性に応じた調整 | インフラ構築のみ |
| 分散トレーシングのオーバーヘッド | 中 | 適切なサンプリング設定、パフォーマンスへの影響監視 | インフラ構築のみ/アプリケーション組み込み |

## 10. 運用手順

### 10.1 日次運用タスク

- **ダッシュボードレビュー**: 主要メトリクスの確認と傾向分析
- **アラート状況確認**: 発生したアラートの確認と対応状況の追跡
- **X-Rayトレース確認**: エラーや遅延のあるトレースの分析

### 10.2 週次運用タスク

- **パフォーマンス分析**: メトリクスデータに基づく傾向分析
- **アラート閾値レビュー**: 過検知/見逃しの確認と閾値調整
- **リソース使用状況確認**: 容量計画と最適化の検討

### 10.3 月次運用タスク

- **監視体制レビュー**: ダッシュボードとアラート設定の見直し
- **メトリクス拡充検討**: 新たな監視指標の追加検討
- **パフォーマンスレポート作成**: 月次性能レポートの作成と共有

### 10.4 障害対応手順

1. **アラート通知受信**
   - 通知内容の確認と影響範囲の特定
   - 必要に応じて緊急対応チームの招集

2. **状況確認**
   - CloudWatchダッシュボードでのメトリクス確認
   - X-Rayトレースによる問題箇所の特定
   - 関連ログの確認

3. **対応実施**
   - 対応策の決定と実施
   - 必要に応じてロールバックや緊急パッチの適用

4. **復旧確認**
   - サービス復旧の確認
   - メトリクスの正常化確認
   - テストリクエストによる動作検証

5. **事後分析と報告**
   - 障害レポートの作成
   - X-Rayトレースとメトリクスを用いた根本原因分析
   - 再発防止策の検討と実施

## 11. Spring Boot Actuatorの実装例

### 11.1 Actuator設定

Spring Boot Actuatorを使用して監視メトリクスを実装する方法を示します：

```java
// build.gradle
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    implementation 'org.springframework.cloud:spring-cloud-starter-aws'
    implementation 'io.micrometer:micrometer-registry-cloudwatch'
}

// application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  metrics:
    export:
      cloudwatch:
        namespace: ECSForgate-${spring.profiles.active:dev}
        batchSize: 20
        step: 1m
    tags:
      application: ecsforgate-api
      environment: ${spring.profiles.active:dev}
```

**実装区分**: アプリケーション組み込み

### 11.2 カスタムメトリクス実装

APIリクエスト測定用のカスタムメトリクス実装例：

```java
@Component
public class MetricsConfig {
    private final MeterRegistry registry;

    public MetricsConfig(MeterRegistry registry) {
        this.registry = registry;
    }
    
    // ビジネスメトリクス用のカウンター
    @Bean
    public Counter recordCreationCounter() {
        return Counter.builder("api.records.created")
                .description("作成された確認記録の数")
                .tag("type", "creation")
                .register(registry);
    }

    @Bean
    public Counter recordRetrievalCounter() {
        return Counter.builder("api.records.retrieved")
                .description("取得された確認記録の数")
                .tag("type", "retrieval")
                .register(registry);
    }
    
    // レスポンスタイム測定タイマー
    @Bean
    public Timer recordProcessingTimer() {
        return Timer.builder("api.records.processing.time")
                .description("確認記録処理時間")
                .publishPercentiles(0.5, 0.95, 0.99)
                .publishPercentileHistogram()
                .register(registry);
    }
    
    // JVMヒープメモリゲージ
    @Bean
    public Gauge jvmHeapUsage() {
        return Gauge.builder("jvm.heap.usage.percent", this, obj -> {
            MemoryMXBean memoryBean = ManagementFactory.getMemoryMXBean();
            MemoryUsage heapUsage = memoryBean.getHeapMemoryUsage();
            return (double) heapUsage.getUsed() / heapUsage.getMax() * 100.0;
        }).register(registry);
    }
}
```

**実装区分**: アプリケーション組み込み

### 11.3 アスペクト利用メトリクス収集

AOP（アスペクト指向プログラミング）を使用したメトリクス収集例：

```java
@Aspect
@Component
public class MetricsAspect {
    private final MeterRegistry registry;
    private final Counter recordCreationCounter;
    private final Counter recordRetrievalCounter;
    private final Timer recordProcessingTimer;

    public MetricsAspect(MeterRegistry registry, 
                          Counter recordCreationCounter,
                          Counter recordRetrievalCounter,
                          Timer recordProcessingTimer) {
        this.registry = registry;
        this.recordCreationCounter = recordCreationCounter;
        this.recordRetrievalCounter = recordRetrievalCounter;
        this.recordProcessingTimer = recordProcessingTimer;
    }

    @Around("execution(* com.example.ecsforgate.service.RecordService.createRecord(..))") 
    public Object measureCreateRecord(ProceedingJoinPoint joinPoint) throws Throwable {
        return recordProcessingTimer.record(() -> {
            try {
                Object result = joinPoint.proceed();
                recordCreationCounter.increment();
                return result;
            } catch (Throwable t) {
                registry.counter("api.records.failed", "operation", "create").increment();
                throw t;
            }
        });
    }

    @Around("execution(* com.example.ecsforgate.service.RecordService.getRecord*(..))")  
    public Object measureGetRecord(ProceedingJoinPoint joinPoint) throws Throwable {
        return recordProcessingTimer.record(() -> {
            try {
                Object result = joinPoint.proceed();
                recordRetrievalCounter.increment();
                return result;
            } catch (Throwable t) {
                registry.counter("api.records.failed", "operation", "retrieve").increment();
                throw t;
            }
        });
    }
}
```

**実装区分**: アプリケーション組み込み

## 12. 開発チームへの依頼事項

### 12.1 最低限必要な依頼事項

1. **Spring Boot Actuatorの組み込み**:
   - 依存関係: `org.springframework.boot:spring-boot-starter-actuator`
   - 依存関係: `io.micrometer:micrometer-registry-cloudwatch`
   - 依存関係: `org.springframework.cloud:spring-cloud-starter-aws`

2. **CloudWatch連携の設定**:
   ```yaml
   management:
     metrics:
       export:
         cloudwatch:
           namespace: ECSForgate-${spring.profiles.active:dev}
           batchSize: 20
           step: 1m
   ```

3. **healthエンドポイントの公開**:
   ```yaml
   management:
     endpoints:
       web:
         exposure:
           include: health
   ```

### 12.2 推奨依頼事項（より詳細なモニタリングのため）

1. **ビジネス指標の実装**:
   - 確認記録作成/取得/更新/削除のカウンター
   - 重要なビジネスプロセスの成功/失敗カウンター
   - 処理時間の計測（Timer）

2. **X-Ray分散トレーシングの組み込み**:
   - 依存関係: `com.amazonaws:aws-xray-recorder-sdk-spring`
   - X-Ray設定クラスの実装
   - トレースインターセプターの実装

## 13. 拡張計画

### 13.1 将来の拡張オプション

- **高度な可視化**: AWS Managed Grafana導入によるより高度なダッシュボード
- **異常検知**: Amazon DevOps Guruによる異常検知の導入
- **合成監視**: CloudWatch Syntheticsによるユーザー体験モニタリング
- **コンテナインサイト**: Container Insightsによる詳細なコンテナ監視
- **電話通知**: Amazon Connectによる重要アラートの電話通知
- **ビジネスメトリクス統合**: 技術指標とビジネス指標の統合ダッシュボード

### 13.2 継続的な改善計画

- **メトリクス最適化**: 継続的なメトリクス収集と可視化の改善
- **アラート閾値最適化**: 運用実績に基づく閾値の調整
- **X-Rayサンプリング最適化**: トレース品質とオーバーヘッドのバランス調整
- **ダッシュボード拡充**: ユーザーフィードバックに基づく改善
- **通知フローの最適化**: アラート疲れ防止と重要通知の確実な伝達
