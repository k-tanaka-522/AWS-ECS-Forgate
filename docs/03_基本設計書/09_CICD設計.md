# 09. CI/CD設計

[← 前へ: 08_アプリケーション設計](08_アプリケーション設計.md) | [目次](00_目次.md) | [次へ: 10_非機能要件対応 →](10_非機能要件対応.md)

---

## 9.1 CI/CD全体フロー

```
Developer
    ↓ (git push)
GitHub Repository
    ↓ (trigger)
┌────────────────────────────────────────────────────┐
│ GitHub Actions Workflows                           │
├────────────────────────────────────────────────────┤
│ 1. PR Validation (pr-validation.yml)              │
│    - Lint, Test                                    │
│    - CloudFormation Validation                    │
│    - Docker Build Test                             │
├────────────────────────────────────────────────────┤
│ 2. Infrastructure Deploy (infrastructure.yml)     │
│    - CloudFormation Change Sets                   │
│    - Stack Deploy (Network/Database/Compute)      │
├────────────────────────────────────────────────────┤
│ 3. Application Deploy (application.yml)           │
│    - Docker Build                                  │
│    - ECR Push                                      │
│    - ECS Service Update                            │
└────────────────────────────────────────────────────┘
    ↓
AWS Environment
```

---

## 9.2 GitHub Actions Workflows設計

### 9.2.1 PR Validation Workflow

**ファイル名**: `.github/workflows/pr-validation.yml`

**トリガー**:
```yaml
on:
  pull_request:
    branches: [main]
```

**ジョブ構成**:
| ジョブ名 | 処理内容 | 実行時間 |
|---------|---------|---------|
| lint | ESLint実行（将来） | 〜1分 |
| test | Jest実行（将来） | 〜2分 |
| cloudformation-validate | CloudFormationテンプレート検証 | 〜3分 |
| docker-build | Dockerイメージビルドテスト（プッシュなし） | 〜5分 |

**CloudFormation検証処理**:
```yaml
- name: Validate CloudFormation Templates
  run: |
    for template in infra/cloudformation/**/*.yaml; do
      echo "Validating ${template}..."
      aws cloudformation validate-template \
        --template-body file://${template} \
        --region ap-northeast-1
    done
```

### 9.2.2 Infrastructure Deploy Workflow

**ファイル名**: `.github/workflows/infrastructure.yml`

**トリガー**:
```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - prod
      action:
        description: 'Action to perform'
        required: true
        type: choice
        options:
          - create
          - update
          - delete
```

**デプロイ順序**:
1. **Platform Account**: platform-stack（Network, Connectivity）
2. **Service Account**:
   1. service-network-stack
   2. service-database-stack
   3. service-compute-stack
   4. service-monitoring-stack

**Change Sets使用（Dry-Run）**:
```yaml
- name: Create Change Set
  run: |
    aws cloudformation create-change-set \
      --stack-name sample-app-dev-network \
      --template-body file://infra/cloudformation/service/stacks/network/main.yaml \
      --parameters file://infra/cloudformation/service/parameters/dev.json \
      --change-set-name deploy-$(date +%Y%m%d%H%M%S) \
      --capabilities CAPABILITY_NAMED_IAM

- name: Describe Change Set
  run: |
    aws cloudformation describe-change-set \
      --stack-name sample-app-dev-network \
      --change-set-name deploy-$(date +%Y%m%d%H%M%S)

- name: Execute Change Set
  run: |
    aws cloudformation execute-change-set \
      --stack-name sample-app-dev-network \
      --change-set-name deploy-$(date +%Y%m%d%H%M%S)
```

### 9.2.3 Application Deploy Workflow

**ファイル名**: `.github/workflows/application.yml`

**トリガー**:
```yaml
on:
  push:
    branches: [main]
    paths:
      - 'app/**'
  workflow_dispatch:
```

**ジョブ構成**:
| ステップ | 処理内容 | 実行時間 |
|---------|---------|---------|
| Build Docker Images | 3サービスのイメージビルド | 〜3分 |
| Push to ECR | ECRへのプッシュ | 〜2分 |
| Update ECS Task Definition | 新Task Definition登録 | 〜1分 |
| Update ECS Service | ECS Serviceデプロイ | 〜3分 |

**マトリックスビルド**:
```yaml
strategy:
  matrix:
    service: [public, admin, batch]

steps:
  - name: Build Docker Image
    run: |
      docker build -t sample-app/${{ matrix.service }}:${{ github.sha }} \
        app/${{ matrix.service }}/

  - name: Push to ECR
    run: |
      aws ecr get-login-password --region ap-northeast-1 | \
        docker login --username AWS --password-stdin \
        ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com

      docker tag sample-app/${{ matrix.service }}:${{ github.sha }} \
        ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/sample-app/${{ matrix.service }}:${{ github.sha }}

      docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/sample-app/${{ matrix.service }}:${{ github.sha }}

      docker tag sample-app/${{ matrix.service }}:${{ github.sha }} \
        ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/sample-app/${{ matrix.service }}:latest

      docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/sample-app/${{ matrix.service }}:latest
```

---

## 9.3 デプロイ戦略

### 9.3.1 Rolling Update（ECS）

**設定**:
| 項目 | 設定値 | 説明 |
|------|--------|------|
| Deployment Type | Rolling Update | 段階的な更新 |
| Min Healthy Percent | 50% | 最低1タスク稼働維持 |
| Max Percent | 200% | 最大4タスク同時起動 |

**デプロイフロー**:
```
Current: Task1, Task2 (old version)
    ↓
Deploy: Task3 (new version) 起動
    ↓
Health Check: Task3 healthy確認
    ↓
Drain: Task1 停止
    ↓
Deploy: Task4 (new version) 起動
    ↓
Health Check: Task4 healthy確認
    ↓
Drain: Task2 停止
    ↓
Complete: Task3, Task4 (new version) 稼働
```

### 9.3.2 Blue/Green Deploy（将来実装）

**メリット**:
- 即座にロールバック可能
- ダウンタイムゼロ
- 本番トラフィックでテスト可能

**実装方法**:
- AWS CodeDeploy使用
- ALB Target Group切り替え

---

## 9.4 ロールバック戦略

### 9.4.1 アプリケーションロールバック

**手動ロールバック**:
```bash
# 1. 前バージョンのTask Definition ARN確認
aws ecs describe-services \
  --cluster sample-app-cluster \
  --services public-web-service

# 2. 前バージョンにロールバック
aws ecs update-service \
  --cluster sample-app-cluster \
  --service public-web-service \
  --task-definition sample-app-public:前バージョン番号
```

**自動ロールバック（将来実装）**:
- CloudWatch Alarms連携
- デプロイ後5分以内にAlarm発火 → 自動ロールバック

### 9.4.2 インフラロールバック

**CloudFormation Rollback**:
```bash
# Change Set実行失敗時、自動ロールバック
aws cloudformation cancel-update-stack \
  --stack-name sample-app-dev-compute
```

**Stack削除防止**:
```yaml
DeletionPolicy: Retain    # RDS等の重要リソース
```

---

## 9.5 環境管理

### 9.5.1 環境構成

| 環境 | AWS Account | ブランチ | デプロイトリガー |
|------|------------|---------|---------------|
| dev | Service Account（987654321098） | main | Pushで自動デプロイ |
| prod | 別Account（将来） | release/* | Manual Approval |

### 9.5.2 環境差分管理

**Parameters File**:
```
infra/cloudformation/service/parameters/
├── dev.json      # 開発環境パラメータ
└── prod.json     # 本番環境パラメータ（将来）
```

**dev.json**:
```json
{
  "network": [
    { "ParameterKey": "Environment", "ParameterValue": "dev" },
    { "ParameterKey": "ServiceVPCCIDR", "ParameterValue": "10.1.0.0/16" }
  ],
  "database": [
    { "ParameterKey": "DBInstanceClass", "ParameterValue": "db.t3.medium" }
  ]
}
```

**prod.json（将来）**:
```json
{
  "network": [
    { "ParameterKey": "Environment", "ParameterValue": "prod" },
    { "ParameterKey": "ServiceVPCCIDR", "ParameterValue": "10.2.0.0/16" }
  ],
  "database": [
    { "ParameterKey": "DBInstanceClass", "ParameterValue": "db.r6g.xlarge" }
  ]
}
```

---

## 9.6 Secrets管理

### 9.6.1 GitHub Secrets

| Secret名 | 用途 | 設定方法 |
|---------|------|---------|
| AWS_ACCOUNT_ID | AWSアカウントID | GitHub Repository Settings |
| PLATFORM_AWS_ACCESS_KEY_ID | Platform Account認証 | IAM User作成 |
| PLATFORM_AWS_SECRET_ACCESS_KEY | Platform Account認証 | IAM User作成 |
| SERVICE_AWS_ACCESS_KEY_ID | Service Account認証 | IAM User作成 |
| SERVICE_AWS_SECRET_ACCESS_KEY | Service Account認証 | IAM User作成 |

### 9.6.2 OIDC認証（推奨・将来実装）

**メリット**:
- IAM User不要
- Secrets Rotation不要
- より安全

**設定例**:
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::987654321098:role/GitHubActionsDeploymentRole
    aws-region: ap-northeast-1
```

---

## 9.7 テスト自動化（将来実装）

### 9.7.1 ユニットテスト

**Framework**: Jest

**実行タイミング**: PR作成時

**カバレッジ目標**: 80%以上

### 9.7.2 統合テスト

**ツール**: Supertest

**テスト内容**:
- API Endpoint疎通確認
- DB接続確認
- エラーハンドリング確認

### 9.7.3 E2Eテスト（将来実装）

**ツール**: Playwright

**テスト内容**:
- Public Web画面操作
- Admin Dashboard画面操作

---

## 9.8 デプロイ通知

### 9.8.1 Slack通知（将来実装）

**通知タイミング**:
- デプロイ開始時
- デプロイ成功時
- デプロイ失敗時

**通知内容**:
```
✅ Deployment Successful

Environment: dev
Service: public-web
Version: abc123def
Deployed by: @developer
Duration: 3m 25s
```

---

**次へ**: [10_非機能要件対応](10_非機能要件対応.md)
