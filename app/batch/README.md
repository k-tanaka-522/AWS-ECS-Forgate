# CareApp Batch Service

データ変換・連携バッチ処理

## 概要

定期的なデータ処理や外部システムとの連携を行うバッチサービス

## ジョブ一覧

### 1. データ変換ジョブ
```bash
npm run job:transform
```

### 2. データインポートジョブ
```bash
npm run job:import
```

## 実行方法

- ECS Fargate タスクとして実行
- CloudWatch Events（EventBridge）でスケジュール実行
