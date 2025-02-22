# CloudFormation デプロイに関するナレッジ

## 1. デプロイ時間の目安

### 一般的なリソースのデプロイ時間
- **VPC/サブネット**: 3-5分
- **RDS**: 15-20分
- **ALB**: 5-10分
- **ACM証明書（DNS検証）**: 10-30分
- **ECSクラスター**: 2-3分
- **ECSサービス**: 5-15分

### 全体のデプロイ時間
- 新規環境の場合: 30-60分程度
- 更新の場合: 10-30分程度（変更内容による）

## 2. よくあるエラーと対処方法

### ROLLBACK_COMPLETE状態のスタック
- **症状**: スタックがROLLBACK_COMPLETE状態になり、更新できない
- **原因**: 
  - リソースの作成失敗
  - 依存リソースの不備
  - パラメータの誤り
- **対処**:
  1. スタックを完全に削除
  2. エラーの原因を特定・修正
  3. スタックを再作成

### リソースのタイムアウト
- **症状**: "Resource timed out waiting for completion"
- **原因**:
  - 依存リソースの準備不足
  - ヘルスチェック失敗
  - ネットワーク設定の問題
- **対処**:
  1. CloudWatchログで詳細確認
  2. 依存リソースの状態確認
  3. ヘルスチェック設定の見直し
  4. セキュリティグループ、NACLの確認

### 証明書検証の失敗
- **症状**: ACM証明書の検証が完了しない
- **原因**:
  - DNS設定の不備
  - Route 53レコードの未作成
- **対処**:
  1. DNS設定の確認
  2. CNAME レコードの手動作成
  3. 必要に応じてDNSキャッシュのTTL確認

## 3. デプロイ戦略のベストプラクティス

### スタックの分割
- **推奨構成**:
  1. ネットワークスタック（VPC、サブネット）
  2. データベーススタック（RDS）
  3. 認証スタック（Cognito）
  4. コンピュートスタック（ECS、ALB）

### デプロイ順序
1. 基盤となるネットワークリソース
2. データストア（RDS、DynamoDB等）
3. 認証・認可システム
4. アプリケーションリソース

### パラメータ管理
- 環境別のパラメータファイル作成
- 機密情報はSecretsManagerで管理
- 環境変数は適切にスコープ分け

## 4. トラブルシューティング手順

### 1. CloudFormationイベントの確認
```bash
aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'
```

### 2. CloudWatchログの確認
```bash
aws logs get-log-events \
  --log-group-name /aws/ecs/<cluster-name> \
  --log-stream-name <log-stream-name>
```

### 3. ECSサービスの状態確認
```bash
aws ecs describe-services \
  --cluster <cluster-name> \
  --services <service-name>
```

### 4. ALBヘルスチェック確認
```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

## 5. パフォーマンス最適化

### デプロイ時間の短縮
- 依存関係の最小化
- 並列デプロイ可能なリソースの特定
- 適切なタイムアウト設定

### リソース作成の効率化
- 必要最小限のリソース作成
- 適切なキャパシティ設定
- Auto Scalingの活用

## 6. セキュリティ考慮事項

### IAMロール設定
- 最小権限の原則に従う
- 適切なポリシーの設定
- 定期的な権限見直し

### 暗号化設定
- 転送中の暗号化（HTTPS）
- 保存時の暗号化（KMS）
- 証明書の自動更新

### ネットワークセキュリティ
- セキュリティグループの適切な設定
- NACLによる追加のセキュリティレイヤー
- VPCエンドポイントの活用

## 7. VPCエンドポイントの設定

### セキュリティグループの設定
- **インバウンドルール**:
  - プライベートサブネットのCIDRまたはECSタスクのセキュリティグループからの443ポートアクセスを許可
  - 必要最小限のアクセス許可
- **アウトバウンドルール**:
  - デフォルトで全て許可または特定のセキュリティグループに制限

### ECSタスクのセキュリティグループ設定
- **インバウンドルール**:
  - ALBからのアプリケーションポートへのアクセスを許可
- **アウトバウンドルール**:
  - VPCエンドポイントへの443ポートアクセスを許可
  - インターネットアクセスが必要な場合は追加で設定

### よくある問題と対処方法
- **接続タイムアウト**:
  - セキュリティグループの相互参照確認
  - ルートテーブルの設定確認
  - DNSホスト名とDNSサポートが有効か確認
- **権限エラー**:
  - IAMロールのポリシー確認
  - エンドポイントポリシーの確認

## 8. SecretsManagerの設定

### シークレットの命名規則
- **推奨形式**: `<環境>/<アプリケーション名>/<用途>-<ランダムサフィックス>`
- **例**:
  - dev/wordpress/db-password-abc123
  - prd/wordpress/api-key-xyz789

### IAMロールの設定
- **タスク実行ロール**:
```yaml
  TaskExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      Policies:
        - PolicyName: SecretsAccess
          PolicyDocument:
            Statement:
              - Effect: Allow
                Action: secretsmanager:GetSecretValue
                Resource:
                  - !Sub arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:${Environment}/${AppName}/*
```

### タスク定義でのシークレット参照
```yaml
  TaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      ContainerDefinitions:
        - Secrets:
            - Name: DB_PASSWORD
              ValueFrom: !Sub arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:${Environment}/${AppName}/db-password-xxx
```

### トラブルシューティング
- シークレットARNの完全一致確認
- IAMロールのポリシー範囲確認
- VPCエンドポイントの接続確認
