# 次回セッション引継ぎ事項

## 📅 前回セッション（2025-10-04）の作業内容

### 実施したこと
- ✅ プロジェクト状態の確認（/status, /init コマンド実行）
- ✅ 実装内容のレビュー完了
  - CloudFormation テンプレート（App VPC）
  - Hello ECS デモアプリ（Node.js + PostgreSQL）
  - Dockerfile
  - デプロイスクリプト
- ✅ デプロイテスト計画の策定
- ✅ App VPC スタックのデプロイ試行
- ✅ 問題発見：ECS Service のヘルスチェック失敗
- ✅ コスト節約のため全スタック削除
  - App VPC スタック削除完了
  - Shared VPC スタック削除完了（月額$150節約）

### 発見した問題

#### 🔴 ECS Service がヘルスチェックに失敗
**症状:**
- ECS タスクが起動
- ALB にターゲット登録
- その後、ヘルスチェック失敗で登録解除
- 再起動を繰り返す

**推定原因:**
1. アプリケーションが `/health` エンドポイントで正常に応答していない
2. データベース接続に失敗している可能性
3. コンテナイメージの問題（公開イメージを使用中）

**ログ確認できなかった:**
- CloudWatch Logs にログが出力されていなかった

---

## 🎯 次回セッションでやるべきこと

### ステップ1: アプリケーションのローカルテスト（最優先）

#### 1-1. Dockerイメージのビルドとローカル実行

```bash
cd app

# イメージビルド
docker build -t careapp/hello-ecs:latest .

# ローカルでテスト実行（DB接続なし）
docker run -p 3000:3000 \
  -e NODE_ENV=development \
  -e DB_HOST=dummy \
  -e DB_PORT=5432 \
  -e DB_NAME=careapp \
  -e DB_USER=postgres \
  -e DB_PASSWORD=dummy \
  careapp/hello-ecs:latest
```

#### 1-2. ヘルスチェックエンドポイント確認

```bash
# 別ターミナルで
curl http://localhost:3000/health

# 期待される結果: {"status":"healthy"}
```

#### 1-3. アプリケーション修正が必要な場合

**問題の可能性:**
- `app/src/index.js` のDB接続エラーハンドリング
- `/health` エンドポイントがDB接続に依存している可能性

**修正案:**
```javascript
// /health エンドポイントをDB非依存にする
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

// DB接続チェックは別エンドポイントに
app.get('/health/db', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'healthy', db: 'connected' });
  } catch (error) {
    res.status(500).json({ status: 'unhealthy', db: 'disconnected' });
  }
});
```

---

### ステップ2: 段階的デプロイ戦略

#### 2-1. VPC + RDS のみデプロイ（ECSなし）

**目的:** ネットワーク基盤とRDSが正常に構築できるか確認

**方法:**
- `infra/app/main.yaml` から ECS関連リソースを一時的にコメントアウト
- または、別ファイル `main-network-only.yaml` を作成

**コメントアウトするリソース:**
```yaml
# ECSCluster
# ECSTaskExecutionRole
# ECSTaskRole
# ECSLogGroup
# ECSTaskDefinition
# ECSService
```

**デプロイコマンド:**
```bash
cd infra/app

aws cloudformation create-stack \
  --stack-name careapp-poc-network \
  --template-body file://main-network-only.yaml \
  --parameters file://parameters-poc.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

**確認項目:**
- VPC作成成功
- NAT Gateway作成成功
- ALB作成成功
- RDS作成成功（15分）
- RDSエンドポイントに接続可能か

#### 2-2. RDS初期化テスト

```bash
# RDS Endpointを取得
RDS_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name careapp-poc-network \
  --query 'Stacks[0].Outputs[?OutputKey==`RDSEndpoint`].OutputValue' \
  --output text \
  --region ap-northeast-1)

echo "RDS Endpoint: $RDS_ENDPOINT"

# ローカルからpsqlで接続テスト（VPN経由または踏み台経由）
psql -h $RDS_ENDPOINT -U postgres -d careapp -c "SELECT version();"
```

#### 2-3. ECRリポジトリ作成とイメージプッシュ

```bash
# ECRリポジトリ作成
aws ecr create-repository \
  --repository-name careapp/hello-ecs \
  --region ap-northeast-1

# ECRログイン
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com

# イメージビルド（修正後）
cd app
docker build -t careapp/hello-ecs:latest .

# タグ付け
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/careapp/hello-ecs"
docker tag careapp/hello-ecs:latest ${ECR_URI}:latest

# プッシュ
docker push ${ECR_URI}:latest
```

#### 2-4. ECS追加デプロイ

ネットワーク基盤が正常なら、ECSリソースを追加：

```bash
# parameters-poc.json の ContainerImage を ECR URIに変更
# "ParameterValue": "<account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/careapp/hello-ecs:latest"

# スタック更新（ECS追加）
aws cloudformation update-stack \
  --stack-name careapp-poc-network \
  --template-body file://main.yaml \
  --parameters file://parameters-poc.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

---

### ステップ3: デプロイ監視とトラブルシューティング

#### 3-1. CloudFormation進捗監視

```bash
# スタックステータス確認
watch -n 30 'aws cloudformation describe-stacks \
  --stack-name careapp-poc-network \
  --query "Stacks[0].StackStatus" \
  --output text \
  --region ap-northeast-1'

# 最新イベント確認
aws cloudformation describe-stack-events \
  --stack-name careapp-poc-network \
  --max-items 10 \
  --query 'StackEvents[].[Timestamp,LogicalResourceId,ResourceStatus]' \
  --output table \
  --region ap-northeast-1
```

#### 3-2. ECS Service 監視

```bash
# ECS Service ステータス
aws ecs describe-services \
  --cluster careapp-poc-cluster \
  --services careapp-poc-service \
  --region ap-northeast-1 \
  --query 'services[0].[serviceName,status,runningCount,desiredCount]' \
  --output table

# ECS Service イベントログ
aws ecs describe-services \
  --cluster careapp-poc-cluster \
  --services careapp-poc-service \
  --region ap-northeast-1 \
  --query 'services[0].events[0:5].[createdAt,message]' \
  --output table
```

#### 3-3. ECS タスク監視

```bash
# タスク一覧取得
aws ecs list-tasks \
  --cluster careapp-poc-cluster \
  --service-name careapp-poc-service \
  --region ap-northeast-1

# タスク詳細確認
TASK_ARN=$(aws ecs list-tasks \
  --cluster careapp-poc-cluster \
  --service-name careapp-poc-service \
  --query 'taskArns[0]' \
  --output text \
  --region ap-northeast-1)

aws ecs describe-tasks \
  --cluster careapp-poc-cluster \
  --tasks $TASK_ARN \
  --region ap-northeast-1 \
  --query 'tasks[0].[lastStatus,healthStatus,containers[0].lastStatus]' \
  --output table
```

#### 3-4. CloudWatch Logs 確認

```bash
# ログストリーム確認
aws logs describe-log-streams \
  --log-group-name /ecs/careapp-poc \
  --order-by LastEventTime \
  --descending \
  --max-items 5 \
  --region ap-northeast-1

# ログテール（リアルタイム）
aws logs tail /ecs/careapp-poc --follow --region ap-northeast-1
```

#### 3-5. ALB ターゲットヘルス確認

```bash
# ターゲットグループARN取得
TG_ARN=$(aws elbv2 describe-target-groups \
  --names careapp-poc-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text \
  --region ap-northeast-1)

# ヘルスステータス確認
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region ap-northeast-1 \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table
```

---

## 🔍 調査が必要な項目

### アプリケーション側
- [ ] `/health` エンドポイントがDB接続に依存していないか
- [ ] データベース接続エラー時のハンドリング
- [ ] 環境変数が正しく渡されているか
- [ ] コンテナ起動時のログ出力

### インフラ側
- [ ] セキュリティグループ設定（ECS → RDS）
- [ ] RDSエンドポイントの到達性
- [ ] ALB ヘルスチェック設定（パス、タイムアウト）
- [ ] ECS タスク定義の環境変数

---

## 📝 レビューで指摘された改善点（バックログ）

### セキュリティ
- [ ] DBパスワードをAWS Secrets Managerに移行
- [ ] ECS環境変数を `Secrets` に変更（現在は `Environment`）

### 高可用性
- [ ] RDS Multi-AZ有効化（本番環境）
- [ ] NAT Gateway Multi-AZ構成（本番環境）

### その他
- [ ] HTTPS対応（ACM証明書 + ALBリスナー）
- [ ] Auto Scaling設定
- [ ] CloudWatch Alarms設定

---

## 📂 プロジェクト構成（現在）

```
sampleAWS/
├── .claude/                    # AI開発ファシリテーター設定
├── .claude-state/              # プロジェクト状態（削除済みスタック情報あり）
├── app/                        # Hello ECS デモアプリ
│   ├── src/
│   │   └── index.js           # ← 修正が必要な可能性
│   ├── db/
│   │   └── init.sql
│   ├── package.json
│   └── Dockerfile
├── infra/
│   ├── shared/                 # Shared VPC（削除済み）
│   └── app/                    # App VPC
│       ├── main.yaml          # ← ECS部分の修正が必要
│       ├── parameters-poc.json
│       └── deploy.ps1
├── docs/                       # 設計ドキュメント
├── DEPLOYMENT.md              # デプロイ手順書
├── NEXT_SESSION.md            # ← このファイル
└── README.md
```

---

## 🎯 次回セッションの目標

1. **ローカルでDockerイメージをビルド・テスト成功**
2. **アプリケーション修正（必要なら）**
3. **ネットワーク基盤（VPC+RDS）のみデプロイ成功**
4. **ECRにイメージをプッシュ**
5. **ECSを追加してデプロイ成功**
6. **ブラウザでHello ECS画面表示**

---

## 💡 追加アイデア

### CI/CD自動化（余裕があれば）
- GitHub Actionsワークフロー作成
- main push時に自動デプロイ

### モニタリング強化
- CloudWatch Dashboard作成
- アラーム設定（CPU、メモリ、エラー率）

---

**作成日:** 2025-10-04
**次回セッション開始時:** このファイルを確認してから作業を開始してください。

お疲れ様でした！🎉
