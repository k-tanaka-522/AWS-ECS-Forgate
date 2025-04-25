# ログ管理設計書

## 1. 概要

### 1.1 目的と責任範囲
本ドキュメントでは、ECSForgateプロジェクトにおけるログ管理に関する設計を定義します。この設計は、すべてのコンポーネント（VPC、RDS、ECS Fargate、ALB、API Gateway）から出力されるログの収集、保存、分析、アラートに関する方針と実装詳細を規定し、一貫性のあるログ管理体制の実現を担います。

### 1.2 設計のポイント
- 統一されたログ形式と集中管理によるトレーサビリティの確保
- 適切なログレベル設定による必要な情報の取得と不要なログの抑制
- 構造化ログによる効率的な検索と分析
- 環境ごとに適切な保持期間とポリシーの定義
- FISC安全対策基準に準拠したセキュリティ対策の実装

## 2. ログ収集アーキテクチャ

下図は、ECSForgateシステムにおけるログ収集アーキテクチャの概要を示しています：

```
+-----------------+    +------------------+    +------------------+
| ECS Fargateタスク |    | ALB              |    | API Gateway      |
| (アプリケーション) |    | (アクセスログ)    |    | (APIアクセスログ) |
+-----------------+    +------------------+    +------------------+
        |                      |                      |
        v                      v                      v
+----------------------------------------------------------------------+
|                         CloudWatch Logs                              |
+----------------------------------------------------------------------+
        |                      |                      |
        v                      v                      v
+------------------+    +------------------+    +------------------+
| ログフィルタ       |    | メトリクスフィルタ  |    | Logs Insights    |
| (パターン検出)     |    | (メトリクス生成)    |    | (クエリ・分析)    |
+------------------+    +------------------+    +------------------+
        |                      |                      
        v                      v                      
+------------------+    +------------------+    
| CloudWatch Alarm |    | CloudWatch       |    
| (アラート設定)     |    | Dashboard        |    
+------------------+    +------------------+    
        |                      
        v                      
+------------------+    
| Amazon SNS       |    
| (通知)           |    
+------------------+    
```

## 3. ログ種別と設定

以下のログを収集・管理します：

| ログ種別 | ソース | ロググループ名 | 形式 | 保持期間 |
|---------|------|--------------|------|---------| 
| アプリケーションログ | ECS Fargate | /ecs/ecsforgate-api-{env} | JSON | 開発: 14日<br>ステージング: 30日<br>本番: 90日 |
| ALBアクセスログ | ALB | AWS::Logs::LogGroup:/aws/alb/ecsforgate-{env}-alb | テキスト | 開発: 14日<br>ステージング: 30日<br>本番: 90日 |
| API Gatewayアクセスログ | API Gateway | /aws/apigateway/ecsforgate-{env} | JSON | 開発: 14日<br>ステージング: 30日<br>本番: 90日 |
| VPCフローログ | VPC | /aws/vpc/flowlogs/ecsforgate-{env} | テキスト | 開発: 14日<br>ステージング: 30日<br>本番: 90日 |
| RDSログ | RDS | /aws/rds/instance/ecsforgate-{env}/postgresql | テキスト | 開発: 14日<br>ステージング: 30日<br>本番: 90日 |
| AWS CloudTrail | AWS API呼び出し | AWS制御 | JSON | 開発: 14日<br>ステージング: 30日<br>本番: 90日 |

## 4. アプリケーションログ設計

Spring Bootアプリケーションのログは以下の設計に基づいて実装します：

### 4.1 ログレベル設定

| 環境 | ルートレベル | アプリケーションレベル | Spring Frameworkレベル |
|-----|------------|---------------------|----------------------|
| 開発環境 | INFO | DEBUG | INFO |
| ステージング環境 | INFO | INFO | WARN |
| 本番環境 | WARN | INFO | ERROR |

### 4.2 構造化ログフォーマット

JSON形式の構造化ログを採用し、以下の情報を含めます：

```json
{
  "timestamp": "2025-04-26T10:00:00.000+09:00",
  "level": "INFO",
  "thread": "http-nio-8080-exec-1",
  "logger": "com.example.ecsforgate.controller.RecordController",
  "message": "Retrieved record with ID: 12345",
  "context": {
    "requestId": "req-uuid-12345",
    "userId": "user-1234",
    "method": "GET",
    "path": "/api/records/12345",
    "statusCode": 200,
    "responseTimeMs": 45
  },
  "exception": null
}
```

### 4.3 ログローテーション設定

CloudWatch Logsでは自動的に管理されますが、アプリケーション側でも以下のローテーション設定を実装します：

- 内部バッファサイズ: 8KB
- 非同期ログ送信: 有効
- バッチサイズ: 512イベント（最大）
- フラッシュ間隔: 1秒

## 5. ログ分析クエリ

CloudWatch Logs Insightsで効率的にログを分析するための主要なクエリパターンを定義します：

### 5.1 エラー率分析
```
filter level = "ERROR"
| stats count(*) as errorCount by bin(5m)
| sort errorCount desc
```

### 5.2 リクエスト完了時間分析
```
filter context.responseTimeMs > 0
| stats
    avg(context.responseTimeMs) as avgResponseTime,
    pct(context.responseTimeMs, 95) as p95ResponseTime,
    pct(context.responseTimeMs, 99) as p99ResponseTime
    by bin(5m)
| sort bin desc
```

### 5.3 APIエンドポイント利用状況
```
filter ispresent(context.path)
| stats count(*) as requestCount by context.path, context.method
| sort requestCount desc
```

## 6. ログ管理ポリシー

### 6.1 ログの暗号化

すべてのロググループはAWS KMSを使用して暗号化します：

| 環境 | 暗号化キー | ローテーション |
|-----|----------|-------------|
| 開発環境 | AWS管理KMSキー | AWS管理 |
| ステージング環境 | カスタマー管理KMSキー | 年次 |
| 本番環境 | カスタマー管理KMSキー | 年次 |

### 6.2 ログのエクスポート

本番環境のログはS3への長期アーカイブを実施します：

- **対象ログ**: すべての本番ログ
- **エクスポート頻度**: 日次
- **保存先**: ecsforgate-prd-logs-archive
- **保持期間**: 1年間
- **S3ライフサイクル**: 30日後Glacier移行、1年後削除

## 7. 環境差分

環境ごとのログ管理に関する主な差分は以下の通りです：

| 設定項目 | 開発環境（dev） | ステージング環境（stg） | 本番環境（prd） |
|---------|--------------|-------------------|--------------| 
| ログ保持期間 | 14日間 | 30日間 | 90日間 |
| ログ暗号化 | AWS管理キー | カスタマー管理キー | カスタマー管理キー |
| ログエクスポート | なし | なし | S3にアーカイブ（1年間） |
| アプリケーションログレベル | DEBUG | INFO | INFO |
| アラート通知 | メールのみ | メールのみ | メール + SMS |

## 8. CloudFormationリソース定義

ログ管理のためのCloudFormationリソースタイプと主要パラメータを以下に示します：

```yaml
Resources:
  # ロググループ定義
  ApplicationLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub "/ecs/ecsforgate-api-${EnvironmentName}"
      RetentionInDays: !FindInMap [EnvironmentMap, !Ref EnvironmentName, LogRetention]
      KmsKeyId: !If [UseCustomKey, !Ref LogsKmsKey, !Ref "AWS::NoValue"]

  # メトリクスフィルター
  ErrorMetricFilter:
    Type: AWS::Logs::MetricFilter
    Properties:
      LogGroupName: !Ref ApplicationLogGroup
      FilterPattern: "{ $.level = \"ERROR\" }"
      MetricTransformations:
        - MetricName: !Sub "ErrorCount-${EnvironmentName}"
          MetricNamespace: !Sub "ECSForgate/${EnvironmentName}"
          MetricValue: "1"
          DefaultValue: 0

  # アラーム定義
  ErrorCountAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "ECSForgate-${EnvironmentName}-ErrorRate"
      AlarmDescription: "Error rate exceeded threshold"
      MetricName: !Sub "ErrorCount-${EnvironmentName}"
      Namespace: !Sub "ECSForgate/${EnvironmentName}"
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 1
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref AlertSNSTopic
```

## 9. 考慮すべきリスクと対策

| リスク | 影響度 | 対策 |
|-------|-------|------|
| ログデータ量の急増 | 中 | ログレベルの適切な設定、フィルタリング、コスト監視 |
| ログストレージコストの増大 | 中 | 保持期間の最適化、不要なログのフィルタリング |
| 重要なエラーの見落とし | 高 | 適切なアラート設定、ダッシュボード可視化強化 |
| ログの整合性欠如 | 中 | 統一されたログフォーマットとフィールド定義の徹底 |
| 機密情報のログへの混入 | 高 | PII（個人識別情報）フィルタリング、暗号化の徹底 |

## 10. 運用手順

### 10.1 日次運用タスク

- **ログレビュー**: 重要なエラーログの確認（ERROR、特定のWARN）
- **アラート確認**: ログベースのアラート状態確認
- **ストレージ使用状況**: ログストレージの使用量と増加率の確認

### 10.2 週次運用タスク

- **異常パターン分析**: ログパターンの傾向分析とフィルター調整
- **クエリの最適化**: Logs Insightsクエリの見直しと改善
- **アラート設定レビュー**: 過検知/見逃しの確認と閾値調整

### 10.3 月次運用タスク

- **ログ分析レポート作成**: エラー傾向と重要イベントのサマリー作成
- **ログポリシー確認**: 保持期間とエクスポート設定の確認
- **クエリライブラリ更新**: 新たな分析ニーズに応じたクエリの追加

## 11. 拡張計画

### 11.1 将来の拡張オプション

- **集中ログ管理**: Amazon OpenSearch Service導入によるより高度な検索と分析
- **ログ異常検知**: 機械学習モデルを活用した異常検知の導入
- **リアルタイム分析**: Kinesis Data Streamsと連携したリアルタイムログ処理
- **セキュリティ分析の強化**: CloudWatch LogsとSecurityHubの連携

### 11.2 継続的な改善計画

- **ログパターン最適化**: 継続的なログパターンの分析と改善
- **構造化ログの拡充**: コンテキスト情報の追加によるトラブルシューティング効率化
- **クエリライブラリの拡充**: 一般的な調査シナリオに対応するクエリセットの充実
- **ビジュアライゼーションの改善**: ログデータのダッシュボード表示の最適化
