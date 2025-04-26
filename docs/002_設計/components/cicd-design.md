# CI/CD詳細設計書

## 1. 概要

### 1.1 目的と責任範囲
本ドキュメントでは、ECSForgateプロジェクトにおけるCI/CD（継続的インテグレーション/継続的デリバリー）パイプラインの詳細設計を定義します。CI/CDパイプラインはアプリケーションのビルド、テスト、デプロイを自動化し、高品質なソフトウェアの迅速かつ安全なデリバリーを実現します。

> **注意**: CI/CDパイプラインの具体的な実装手順については、`iac/cloudformation/README.md`を参照してください。このREADMEファイルには、GitHubトークンのSecrets Managerへの保存方法、CI/CDパイプラインのデプロイ手順、およびWebhook設定の確認方法などが詳細に記載されています。

### 1.2 設計のポイント
- GitHub（ソースリポジトリ）とAWSネイティブサービス（CodePipeline、CodeBuild、CloudFormation）を組み合わせたCI/CD環境の構築
- 環境（開発・ステージング・本番）ごとに最適化されたデプロイプロセス
- 自動テストと品質ゲートによる品質確保
- セキュアなシークレット管理とIAM連携
- ロールバック戦略を含めた安全なデプロイフロー

## 2. CI/CDアーキテクチャの概要

### 2.1 全体アーキテクチャ図

```
┌──────────┐     ┌───────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────┐
│          │     │               │     │                 │     │                 │     │             │
│  GitHub  │────▶│ CodePipeline  │────▶│  CodeBuild      │────▶│  AWS ECR        │────▶│  ECS Fargate │
│          │     │               │     │                 │     │                 │     │             │
└──────────┘     └───────────────┘     └─────────────────┘     └─────────────────┘     └─────────────┘
      │                  │                      │                      │                     │
      │                  │                      │                      │                     │
      │                  ▼                      │                      │                     │
      │          ┌───────────────┐              │                      │                     │
      │          │               │              │                      │                     │
      └─────────▶│  CodeBuild    │              │                      │                     │
                 │  (セキュリティスキャン) │              │                      │                     │
                 │               │              │                      │                     │
                 └───────────────┘              │                      │                     │
                                                │                      │                     │
                                                ▼                      ▼                     ▼
                                        ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
                                        │                 │   │                 │   │                 │
                                        │  CloudFormation │──▶│  CodeDeploy     │──▶│  CloudWatch     │
                                        │                 │   │                 │   │                 │
                                        └─────────────────┘   └─────────────────┘   └─────────────────┘
```

### 2.2 主要コンポーネント

| コンポーネント | 役割 |
|--------------|------|
| GitHub | ソースコード管理、バージョン管理、コードレビュー |
| AWS CodePipeline | CI/CDパイプラインのオーケストレーション |
| AWS CodeBuild | ビルド・テスト環境の提供、アプリケーションビルド |
| AWS CodeDeploy | アプリケーションのデプロイ自動化 |
| AWS ECR | Dockerイメージレジストリ |
| AWS CloudFormation | インフラストラクチャのコード管理とデプロイ |
| AWS ECS Fargate | コンテナ実行環境 |
| AWS CloudWatch | デプロイ監視とロギング |

## 3. リポジトリ構成とブランチ戦略

### 3.1 リポジトリ構成

プロジェクトはGitHubの単一リポジトリ（モノリポ）で管理し、以下のディレクトリ構造を採用します：

```
/
├── app/                      # アプリケーションコード
│   ├── api/                  # APIアプリケーション
│   │   ├── src/              # ソースコード
│   │   ├── build.gradle      # ビルド設定
│   │   └── Dockerfile        # コンテナイメージ定義
│   └── README.md             # アプリケーションドキュメント
├── docs/                     # プロジェクトドキュメント
│   ├── 001_要件定義/          # 要件定義ドキュメント
│   ├── 002_設計/             # 設計ドキュメント
│   └── handover.md           # 引継ぎドキュメント
├── iac/                      # Infrastructure as Code
│   ├── cloudformation/       # CloudFormationテンプレート
│   │   ├── templates/        # サービス別テンプレート
│   │   ├── config/           # 環境別設定
│   │   └── scripts/          # デプロイスクリプト
│   └── README.md             # IaCドキュメント
├── scripts/                  # デプロイライフサイクルスクリプト
├── buildspec.yml             # CodeBuild定義ファイル
├── appspec.yml               # CodeDeploy定義ファイル
├── taskdef.json              # ECSタスク定義
├── .gitignore                # Git除外ファイル設定
└── README.md                 # プロジェクト概要
```

### 3.2 ブランチ戦略

GitFlowをベースとした以下のブランチ戦略を採用します：

| ブランチ | 用途 | 環境 | 保護設定 |
|---------|------|------|----------|
| main | 本番リリース用 | 本番環境 | 保護あり（PR必須、承認必須、CI合格必須） |
| develop | 開発統合用 | 開発環境 | 保護あり（PR必須、CI合格必須） |
| feature/* | 新機能開発用 | なし | なし |
| release/* | リリース準備用 | ステージング環境 | 保護あり（PR必須） |
| hotfix/* | 緊急修正用 | 本番環境(修正後) | なし |

### 3.3 プルリクエスト（PR）フロー

1. 開発者が `feature/*` ブランチを `develop` から作成し機能実装
2. 実装完了後、`develop` へのPRを作成
3. GitHubのプルリクエスト機能でコードレビュー
4. GitHub Actionsトリガーによりビルド、テスト、セキュリティスキャンを実施
5. すべてのチェックが通った後、`develop` にマージ
6. リリース準備時、`release/*` ブランチを `develop` から作成
7. `release/*` ブランチでの統合テスト後、`main` へのPRを作成
8. 最終承認後、`main` にマージし本番リリース

### 3.4 GitHubリポジトリ設定

#### 3.4.1 ブランチ保護ルール

以下のブランチ保護ルールを設定します：

- **main**:
  - PRによるマージ必須
  - 承認レビュー必須（最低1件）
  - ステータスチェック（CI）必須
  - 管理者による強制プッシュの禁止

- **develop**:
  - PRによるマージ必須
  - ステータスチェック（CI）必須

- **release/**:
  - PRによるマージ必須

#### 3.4.2 Webhookの設定

CI/CDパイプラインを自動的に起動するためのWebhookを設定します：

- **トリガーイベント**: プッシュイベント
- **ブランチフィルター**:
  - `main` → 本番環境パイプライン
  - `develop` → 開発環境パイプライン
  - `release/*` → ステージング環境パイプライン

## 4. CI（継続的インテグレーション）設計

### 4.1 ビルドプロセス

#### 4.1.1 CodeBuildプロジェクト設定

| 環境 | プロジェクト名 | ビルド環境 | 特徴 |
|-----|--------------|------------|------|
| 開発環境 | ecsforgate-dev-build | カスタムECRイメージ (Ubuntu 22.04ベース) | 標準テストスイート |
| ステージング環境 | ecsforgate-stg-build | カスタムECRイメージ (Ubuntu 22.04ベース) | 拡張テストスイート |
| 本番環境 | ecsforgate-prd-build | カスタムECRイメージ (Ubuntu 22.04ベース) | 本番デプロイ前の最終検証 |

#### 4.1.2 カスタムビルドイメージ戦略

内部マイクロサービスの安定性を確保し、AWSのマネージドイメージが将来的にサポート終了した場合のリスクを軽減するため、以下のカスタムビルドイメージ戦略を採用します：

1. **Ubuntu 22.04ベースのカスタムビルドイメージ**
   - ECSコンテナイメージと同じUbuntu 22.04ベースを使用してビルド環境の一貫性を確保
   - 必要なビルドツール（JDK 11, Docker, AWS CLI等）を固定バージョンでインストール
   - プライベートECRリポジトリに保存し、CodeBuildから参照

2. **バージョン管理とタグ戦略**
   - セマンティックバージョニングによる明示的バージョン管理（例：`1.0.0`）
   - 明示的なバージョンタグの使用（`latest`タグ不使用）
   - 四半期ごとのセキュリティアップデート適用（計画的なパッチ管理）

3. **ビルドイメージのDockerfile例**
```dockerfile
FROM ubuntu:22.04

# 環境変数
ENV JAVA_VERSION="11.0.16"
ENV GRADLE_VERSION="7.4.2"
ENV NODE_VERSION="16.15.1"
ENV AWS_CLI_VERSION="2.7.9"

# 基本パッケージのインストール
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    build-essential \
    ca-certificates \
    software-properties-common \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Java 11のインストール
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk \
    && rm -rf /var/lib/apt/lists/*

# Gradleのインストール
RUN wget -q https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -O /tmp/gradle.zip \
    && unzip -d /opt /tmp/gradle.zip \
    && ln -s /opt/gradle-${GRADLE_VERSION} /opt/gradle \
    && rm /tmp/gradle.zip

# AWS CLIのインストール
RUN curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# Dockerのインストール
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io \
    && rm -rf /var/lib/apt/lists/*

# 環境変数の設定
ENV PATH="/opt/gradle/bin:${PATH}"

# ワーキングディレクトリの設定
WORKDIR /build

# エントリポイントの設定
ENTRYPOINT ["/bin/bash", "-c"]
```

4. **ECRへのビルドイメージのプッシュと管理**
```bash
# ビルドイメージをビルドしECRにプッシュする例
aws ecr create-repository --repository-name ecsforgate-build-image
aws ecr get-login-password | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker build -t $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/ecsforgate-build-image:1.0.0 .
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/ecsforgate-build-image:1.0.0
```

#### 4.1.3 ECRイメージ凍結戦略とCI/CD連携

##### 4.1.3.1 ECRイメージ管理の責任分担

| 責任領域 | 担当システム | 管理方法 | 更新頻度 |
|---------|--------------|----------|----------|
| ベースイメージの構築・凍結 | 手動プロセス | 検証後に明示的な凍結タグ付与 | 四半期ごと |
| アプリケーションイメージのビルド | CI/CDパイプライン | 自動ビルド・タグ付け | コード変更時 |
| 本番リリースイメージの凍結 | CI/CD + 手動承認 | リリース承認後に凍結タグ付与 | リリース時 |

##### 4.1.3.2 CI/CDパイプラインにおけるイメージ凍結の実装

1. **ベースイメージ参照の実装**
   - buildspec.ymlでは凍結済みベースイメージを参照するように設定
   ```yaml
   environment_variables:
     BASE_IMAGE_TAG: base-2025-Q2-frozen
   ```

   - Dockerfileの修正例
   ```dockerfile
   # 凍結済みベースイメージの使用
   FROM ${ECR_REPO}/ecsforgate-base:${BASE_IMAGE_TAG}
   
   # アプリケーションのみをコピー
   COPY app.jar /app/app.jar
   ```

2. **環境別のイメージビルド設定**
   - 開発環境（develop ブランチ）
     ```yaml
     commands:
       - export IMAGE_TAG=dev-${COMMIT_HASH}-$(date +%Y%m%d)
       - docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} .
       - docker push ${REPOSITORY_URI}:${IMAGE_TAG}
     ```

   - ステージング環境（release/* ブランチ）
     ```yaml
     commands:
       - export VERSION=$(echo ${CODEBUILD_WEBHOOK_HEAD_REF} | sed 's/refs\/heads\/release\///')
       - export IMAGE_TAG=stg-rc-${VERSION}
       - docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} .
       - docker push ${REPOSITORY_URI}:${IMAGE_TAG}
     ```

   - 本番環境（main ブランチ）
     ```yaml
     commands:
       - export VERSION=$(cat version.txt)
       - export IMAGE_TAG=prd-candidate-${VERSION}
       - docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} .
       - docker push ${REPOSITORY_URI}:${IMAGE_TAG}
     ```

3. **イメージ凍結プロセスの自動化**
   - 本番リリース後の凍結タグ付与スクリプト
   ```bash
   #!/bin/bash
   # 本番環境デプロイ成功後に実行
   VERSION=$(cat version.txt)
   REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ecsforgate-api
   
   # 本番用セマンティックバージョンタグの付与
   aws ecr batch-get-image --repository-name ecsforgate-api --image-ids imageTag=prd-candidate-${VERSION} --query 'images[].imageManifest' --output text | aws ecr put-image --repository-name ecsforgate-api --image-tag ${VERSION} --image-manifest "${MANIFEST}"
   
   # 凍結タグの付与（イミュータビリティ有効の場合は削除保護も設定）
   aws ecr batch-get-image --repository-name ecsforgate-api --image-ids imageTag=${VERSION} --query 'images[].imageManifest' --output text | aws ecr put-image --repository-name ecsforgate-api --image-tag ${VERSION}-frozen --image-manifest "${MANIFEST}"
   
   # タグ付け成功の確認
   aws ecr describe-images --repository-name ecsforgate-api --image-ids imageTag=${VERSION}-frozen
   ```

##### 4.1.3.3 凍結イメージを使ったロールバック戦略

1. **イメージタグの履歴管理**
   - リリースごとに凍結イメージのバージョンと関連情報をデータベースまたはS3に記録
   - 各リリースのメタデータ（リリース日時、コミットハッシュ、関連するチケット/PR番号）の保存

2. **ロールバックデプロイ設定**
   - ロールバック用のCodeBuildプロジェクト設定
   ```yaml
   RollbackProject:
     Type: AWS::CodeBuild::Project
     Properties:
       Name: ecsforgate-rollback
       Environment:
         Type: LINUX_CONTAINER
         ComputeType: BUILD_GENERAL1_SMALL
         Image: aws/codebuild/amazonlinux2-x86_64-standard:3.0
       ServiceRole: !Ref CodeBuildServiceRole
       Source:
         Type: NO_SOURCE
         BuildSpec: |
           version: 0.2
           phases:
             pre_build:
               commands:
                 - echo Rollback to version $TARGET_VERSION
                 - aws ecs update-service --cluster ecsforgate-prd-cluster --service ecsforgate-api-prd-service --task-definition ecsforgate-api-prd:$TARGET_VERSION --force-new-deployment
             build:
               commands:
                 - echo Waiting for deployment to complete...
                 - aws ecs wait services-stable --cluster ecsforgate-prd-cluster --services ecsforgate-api-prd-service
             post_build:
               commands:
                 - echo Rollback completed successfully
   ```

3. **凍結イメージを使ったロールバック手順**
   - 手動ロールバックの場合
     ```bash
     # 例：バージョン1.0.0にロールバック
     aws ecs update-service \
       --cluster ecsforgate-prd-cluster \
       --service ecsforgate-api-prd-service \
       --task-definition $(aws ecs describe-task-definition \
         --task-definition ecsforgate-api-prd \
         --query 'taskDefinition.taskDefinitionArn' \
         --output text | sed 's/:[0-9]*$//' \
       ):$(aws ecs list-task-definitions \
         --family-prefix ecsforgate-api-prd \
         --query 'taskDefinitionArns[]' \
         --output text | grep "1\.0\.0-frozen" | tail -1 | cut -d':' -f2) \
       --force-new-deployment
     ```

   - 緊急時のロールバックボタン（AWS Lambda関数経由）も準備

#### 4.1.4 buildspec.yml定義

環境ごとにカスタマイズされた buildspec.yml を用意し、イメージ凍結戦略を適切に実装します。

##### 開発環境（dev）用 buildspec.yml

```yaml
version: 0.2

env:
  variables:
    BASE_IMAGE_REPO: "ecsforgate-base"
    BASE_IMAGE_TAG: "base-2025-Q2-frozen"
    APP_IMAGE_REPO: "ecsforgate-api"

phases:
  install:
    runtime-versions:
      java: corretto11
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - BASE_IMAGE_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$BASE_IMAGE_REPO:$BASE_IMAGE_TAG
      - APP_REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$APP_IMAGE_REPO
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - BUILD_DATE=$(date +%Y%m%d)
      - IMAGE_TAG=dev-${COMMIT_HASH}-${BUILD_DATE}
      - echo Using base image $BASE_IMAGE_URI
      - echo Building application image $APP_REPOSITORY_URI:$IMAGE_TAG
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Java application...
      - cd app/api
      - ./gradlew clean build
      - echo Building the Docker image with frozen base image...
      - sed -i "s|\${BASE_IMAGE}|$BASE_IMAGE_URI|g" Dockerfile
      - docker build -t $APP_REPOSITORY_URI:$IMAGE_TAG .
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Running tests...
      - cd app/api
      - ./gradlew test
      - echo Pushing the Docker image...
      - docker push $APP_REPOSITORY_URI:$IMAGE_TAG
      - echo Writing artifacts...
      - cd $CODEBUILD_SRC_DIR
      - aws cloudformation package --template-file iac/cloudformation/templates/ecs.yaml --s3-bucket $ARTIFACT_BUCKET --s3-prefix $ENVIRONMENT --output-template-file ecs-packaged.yaml
      - sed -i "s|<IMAGE_URI>|$APP_REPOSITORY_URI:$IMAGE_TAG|g" taskdef.json
      - echo Build and push completed for development environment image $APP_REPOSITORY_URI:$IMAGE_TAG

artifacts:
  files:
    - appspec.yml
    - taskdef.json
    - ecs-packaged.yaml
    - iac/cloudformation/config/$ENVIRONMENT/parameters.json
  discard-paths: no

cache:
  paths:
    - '/root/.gradle/caches/**/*'
    - '/root/.gradle/wrapper/**/*'
```

##### ステージング環境（stg）用 buildspec.yml

```yaml
version: 0.2

env:
  variables:
    BASE_IMAGE_REPO: "ecsforgate-base"
    BASE_IMAGE_TAG: "base-2025-Q2-frozen"
    APP_IMAGE_REPO: "ecsforgate-api"

phases:
  install:
    runtime-versions:
      java: corretto11
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - BASE_IMAGE_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$BASE_IMAGE_REPO:$BASE_IMAGE_TAG
      - APP_REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$APP_IMAGE_REPO
      # リリースブランチ名からバージョンを抽出（例：release/1.2.0 → 1.2.0）
      - VERSION=$(echo $CODEBUILD_WEBHOOK_HEAD_REF | sed 's/refs\/heads\/release\///')
      - IMAGE_TAG=stg-rc-${VERSION}
      - echo Using base image $BASE_IMAGE_URI
      - echo Building release candidate image $APP_REPOSITORY_URI:$IMAGE_TAG
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Java application...
      - cd app/api
      - ./gradlew clean build
      - echo Building the Docker image with frozen base image...
      - sed -i "s|\${BASE_IMAGE}|$BASE_IMAGE_URI|g" Dockerfile
      - docker build -t $APP_REPOSITORY_URI:$IMAGE_TAG .
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Running extended tests...
      - cd app/api
      - ./gradlew test integrationTest
      - echo Pushing the Docker image...
      - docker push $APP_REPOSITORY_URI:$IMAGE_TAG
      - echo Writing artifacts...
      - cd $CODEBUILD_SRC_DIR
      - aws cloudformation package --template-file iac/cloudformation/templates/ecs.yaml --s3-bucket $ARTIFACT_BUCKET --s3-prefix $ENVIRONMENT --output-template-file ecs-packaged.yaml
      - sed -i "s|<IMAGE_URI>|$APP_REPOSITORY_URI:$IMAGE_TAG|g" taskdef.json
      - echo Build and push completed for staging environment image $APP_REPOSITORY_URI:$IMAGE_TAG
      # バージョン情報をファイルに保存（本番環境デプロイで使用）
      - echo $VERSION > version.txt

artifacts:
  files:
    - appspec.yml
    - taskdef.json
    - ecs-packaged.yaml
    - iac/cloudformation/config/$ENVIRONMENT/parameters.json
    - version.txt
  discard-paths: no

cache:
  paths:
    - '/root/.gradle/caches/**/*'
    - '/root/.gradle/wrapper/**/*'
```

##### 本番環境（prd）用 buildspec.yml

```yaml
version: 0.2

env:
  variables:
    BASE_IMAGE_REPO: "ecsforgate-base"
    BASE_IMAGE_TAG: "base-2025-Q2-frozen"
    APP_IMAGE_REPO: "ecsforgate-api"

phases:
  install:
    runtime-versions:
      java: corretto11
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - BASE_IMAGE_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$BASE_IMAGE_REPO:$BASE_IMAGE_TAG
      - APP_REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$APP_IMAGE_REPO
      # バージョン情報の取得（version.txtファイルから）
      - VERSION=$(cat version.txt)
      - CANDIDATE_IMAGE_TAG=prd-candidate-${VERSION}
      - echo Using base image $BASE_IMAGE_URI
      - echo Building production candidate image $APP_REPOSITORY_URI:$CANDIDATE_IMAGE_TAG
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Java application...
      - cd app/api
      - ./gradlew clean build
      - echo Building the Docker image with frozen base image...
      - sed -i "s|\${BASE_IMAGE}|$BASE_IMAGE_URI|g" Dockerfile
      - docker build -t $APP_REPOSITORY_URI:$CANDIDATE_IMAGE_TAG .
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Running full test suite...
      - cd app/api
      - ./gradlew test integrationTest performanceTest securityTest
      - echo Pushing the Docker image...
      - docker push $APP_REPOSITORY_URI:$CANDIDATE_IMAGE_TAG
      # 承認フローを通過後に実行されるポスト承認スクリプトを作成（凍結タグ付与用）
      - cd $CODEBUILD_SRC_DIR
      - mkdir -p scripts
      - |
        cat > scripts/post_approval.sh << 'EOL'
        #!/bin/bash
        VERSION=$(cat version.txt)
        REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/ecsforgate-api
        CANDIDATE_IMAGE_TAG=prd-candidate-${VERSION}
        
        # イメージマニフェストを取得
        MANIFEST=$(aws ecr batch-get-image --repository-name ecsforgate-api --image-ids imageTag=${CANDIDATE_IMAGE_TAG} --query 'images[].imageManifest' --output text)
        
        # 本番用セマンティックバージョンタグの付与
        aws ecr put-image --repository-name ecsforgate-api --image-tag ${VERSION} --image-manifest "${MANIFEST}"
        
        # デプロイ完了後に凍結タグ付与用のスクリプトを準備
        cat > scripts/freeze_image.sh << 'EOF'
        #!/bin/bash
        VERSION=$(cat version.txt)
        REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/ecsforgate-api
        
        # イメージマニフェストを取得
        MANIFEST=$(aws ecr batch-get-image --repository-name ecsforgate-api --image-ids imageTag=${VERSION} --query 'images[].imageManifest' --output text)
        
        # 凍結タグの付与（イミュータビリティ有効の場合は削除保護も設定）
        aws ecr put-image --repository-name ecsforgate-api --image-tag ${VERSION}-frozen --image-manifest "${MANIFEST}"
        
        # タグ付け成功の確認
        aws ecr describe-images --repository-name ecsforgate-api --image-ids imageTag=${VERSION}-frozen
        EOF
        
        chmod +x scripts/freeze_image.sh
        EOL
      - chmod +x scripts/post_approval.sh
      - echo Writing artifacts...
      - aws cloudformation package --template-file iac/cloudformation/templates/ecs.yaml --s3-bucket $ARTIFACT_BUCKET --s3-prefix $ENVIRONMENT --output-template-file ecs-packaged.yaml
      - sed -i "s|<IMAGE_URI>|$APP_REPOSITORY_URI:$CANDIDATE_IMAGE_TAG|g" taskdef.json
      - echo Build and push completed for production candidate image $APP_REPOSITORY_URI:$CANDIDATE_IMAGE_TAG

artifacts:
  files:
    - appspec.yml
    - taskdef.json
    - ecs-packaged.yaml
    - iac/cloudformation/config/$ENVIRONMENT/parameters.json
    - version.txt
    - scripts/post_approval.sh
    - scripts/freeze_image.sh
  discard-paths: no

cache:
  paths:
    - '/root/.gradle/caches/**/*'
    - '/root/.gradle/wrapper/**/*'
```

### 4.2 テスト戦略

#### 4.2.1 テスト階層

以下の自動テストを実装します：

| テストタイプ | 説明 | ツール | タイミング |
|------------|------|-------|----------|
| 単体テスト | クラスやメソッドレベルの機能検証 | JUnit 5, Mockito | ビルド時に毎回実行 |
| 統合テスト | DBやAPIを含めた統合機能検証 | Spring Boot Test, Testcontainers | ビルド時に毎回実行 |
| APIテスト | APIエンドポイントの機能検証 | REST Assured | ビルド時に毎回実行 |
| セキュリティスキャン | コードの脆弱性スキャン | OWASP Dependency Check | 毎日実行 |
| インフラテスト | CFnテンプレートの検証 | cfn-lint, cfn-nag | IaC変更時に実行 |

#### 4.2.2 テスト用CodeBuildプロジェクト

インフラテスト用の専用CodeBuildプロジェクトを設定します：

```yaml
# CloudFormationの一部としてのCodeBuildプロジェクト定義
CFnValidationProject:
  Type: AWS::CodeBuild::Project
  Properties:
    Name: ecsforgate-cfn-validation
    Description: Validate CloudFormation templates
    ServiceRole: !Ref CodeBuildServiceRole
    Artifacts:
      Type: NO_ARTIFACTS
    Environment:
      Type: LINUX_CONTAINER
      ComputeType: BUILD_GENERAL1_SMALL
      Image: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/ecsforgate-build-image:1.0.0
    Source:
      Type: GITHUB
      Location: https://github.com/owner/ecsforgate.git
      BuildSpec: |
        version: 0.2
        phases:
          install:
            runtime-versions:
              python: 3.9
            commands:
              - pip install cfn-lint cfn-nag
          build:
            commands:
              - echo Validating CloudFormation templates...
              - cfn-lint iac/cloudformation/templates/*.yaml
              - cfn_nag_scan --input-path iac/cloudformation/templates
        reports:
          cfn-lint:
            files:
              - cfn-lint-report.json
            base-directory: $CODEBUILD_SRC_DIR
            file-format: JSON
```

### 4.3 コード品質とセキュリティチェック

#### 4.3.1 静的コード解析

以下の静的解析ツールを使用します：

| ツール | 目的 | 実行タイミング |
|-------|------|--------------|
| SonarQube | コード品質、バグ、脆弱性、技術的負債の検出 | 毎ビルド |
| SpotBugs | Javaコード内のバグパターン検出 | 毎ビルド |
| Checkstyle | コーディング規約準拠チェック | 毎ビルド |
| OWASP Dependency Check | 依存ライブラリの脆弱性スキャン | 毎日/毎ビルド |

#### 4.3.2 セキュリティスキャン用CodeBuildプロジェクト

```yaml
# CloudFormationの一部としてのCodeBuildプロジェクト定義
SecurityScanProject:
  Type: AWS::CodeBuild::Project
  Properties:
    Name: ecsforgate-security-scan
    Description: Security scan for the application
    ServiceRole: !Ref CodeBuildServiceRole
    Artifacts:
      Type: NO_ARTIFACTS
    Environment:
      Type: LINUX_CONTAINER
      ComputeType: BUILD_GENERAL1_SMALL
      Image: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/ecsforgate-build-image:1.0.0
    Source:
      Type: GITHUB
      Location: https://github.com/owner/ecsforgate.git
      BuildSpec: |
        version: 0.2
        phases:
          install:
            runtime-versions:
              java: corretto11
          build:
            commands:
              - echo Running security scans...
              - cd app/api
              - ./gradlew dependencyCheckAnalyze
        reports:
          dependency-check:
            files:
              - build/reports/dependency-check-report.xml
            base-directory: app/api
            file-format: JUNITXML
        artifacts:
          files:
            - app/api/build/reports/dependency-check-report.html
          name: security-scan-reports
```

## 5. CD（継続的デリバリー）設計

### 5.1 CodePipelineの設計

#### 5.1.1 パイプライン構成（環境別）

| ステージ | 開発環境 | ステージング環境 | 本番環境 |
|---------|---------|---------------|---------| 
| Source | GitHub (develop) | GitHub (release/*) | GitHub (main) |
| Build | CodeBuild (ecsforgate-dev-build) | CodeBuild (ecsforgate-stg-build) | CodeBuild (ecsforgate-prd-build) |
| Test | 基本テスト | 拡張テスト + セキュリティスキャン | 拡張テスト + セキュリティスキャン |
| Approval | 不要 | オプション（QA承認） | 必須（本番承認者） |
| Deploy | CloudFormation + CodeDeploy | CloudFormation + CodeDeploy | CloudFormation + CodeDeploy |

#### 5.1.2 環境別パイプライン定義

開発環境用パイプライン：

```yaml
# CloudFormationの一部としてのCodePipeline定義
DevPipeline:
  Type: AWS::CodePipeline::Pipeline
  Properties:
    Name: ecsforgate-dev-pipeline
    RoleArn: !GetAtt CodePipelineServiceRole.Arn
    ArtifactStore:
      Type: S3
      Location: !Ref ArtifactBucket
    Stages:
      - Name: Source
        Actions:
          - Name: Source
            ActionTypeId:
              Category: Source
              Owner: ThirdParty
              Provider: GitHub
              Version: 1
            Configuration:
              Owner: owner
              Repo: ecsforgate
              Branch: develop
              OAuthToken: ${GitHubToken}
            OutputArtifacts:
              - Name: SourceCode
      - Name: Build
        Actions:
          - Name: BuildAndTest
            ActionTypeId:
              Category: Build
              Owner: AWS
              Provider: CodeBuild
              Version: 1
            Configuration:
              ProjectName: ecsforgate-dev-build
              EnvironmentVariables: '[{"name":"ENVIRONMENT","value":"dev"},{"name":"AWS_ACCOUNT_ID","value":"#{AccountId}"}]'
            InputArtifacts:
              - Name: SourceCode
            OutputArtifacts:
              - Name: BuildOutput
      - Name: Deploy
        Actions:
          - Name: DeployInfrastructure
            ActionTypeId:
              Category: Deploy
              Owner: AWS
              Provider: CloudFormation
              Version: 1
            Configuration:
              ActionMode: CREATE_UPDATE
              StackName: ecsforgate-dev
              TemplatePath: BuildOutput::ecs-packaged.yaml
              TemplateConfiguration: BuildOutput::iac/cloudformation/config/dev/parameters.json
              Capabilities: CAPABILITY_IAM,CAPABILITY_AUTO_EXPAND
              RoleArn: !GetAtt CloudFormationServiceRole.Arn
            InputArtifacts:
              - Name: BuildOutput
          - Name: DeployApplication
            ActionTypeId:
              Category: Deploy
              Owner: AWS
              Provider: CodeDeployToECS
              Version: 1
            Configuration:
              ApplicationName: ecsforgate-dev-app
              DeploymentGroupName: ecsforgate-dev-dg
              TaskDefinitionTemplateArtifact: BuildOutput
              TaskDefinitionTemplatePath: taskdef.json
              AppSpecTemplateArtifact: BuildOutput
              AppSpecTemplatePath: appspec.yml
            InputArtifacts:
              - Name: BuildOutput
```

ステージング環境・本番環境用のパイプラインも同様の構造で、環境名とブランチ名、承認ステップを調整して定義します。

### 5.2 デプロイ戦略

#### 5.2.1 環境別デプロイ方式

| 環境 | デプロイ方式 | ロールバック | 承認フロー |
|-----|------------|-----------|-----------| 
| 開発環境 | ローリング更新 | 自動 | 不要 |
| ステージング環境 | ブルー/グリーン | 自動 | オプション（QA） |
| 本番環境 | ブルー/グリーン | 自動 | 必須（運用管理者） |

#### 5.2.2 CodeDeploy設定（ブルー/グリーンデプロイ）

```yaml
# CloudFormationの一部としてのCodeDeploy定義
CodeDeployApplication:
  Type: AWS::CodeDeploy::Application
  Properties:
    ApplicationName: ecsforgate-prd-app
    ComputePlatform: ECS

DeploymentGroup:
  Type: AWS::CodeDeploy::DeploymentGroup
  Properties:
    ApplicationName: !Ref CodeDeployApplication
    DeploymentGroupName: ecsforgate-prd-dg
    DeploymentConfigName: CodeDeployDefault.ECSAllAtOnce
    ServiceRoleArn: !GetAtt CodeDeployServiceRole.Arn
    BlueGreenDeploymentConfiguration:
      DeploymentReadyOption:
        ActionOnTimeout: CONTINUE_DEPLOYMENT
        WaitTimeInMinutes: 0
      TerminateBlueInstancesOnDeploymentSuccess:
        Action: TERMINATE
        TerminationWaitTimeInMinutes: 5
    ECSServices:
      - ClusterName: ecsforgate-prd-cluster
        ServiceName: ecsforgate-api-prd-service
    DeploymentStyle:
      DeploymentType: BLUE_GREEN
      DeploymentOption: WITH_TRAFFIC_CONTROL
    LoadBalancerInfo:
      TargetGroupPairInfoList:
        - ProdTrafficRoute:
            ListenerArns:
              - !Ref ProdListener
          TargetGroups:
            - Name: !Ref BlueTargetGroup
            - Name: !Ref GreenTargetGroup
```

#### 5.2.3 appspec.yml定義

```yaml
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: api-container
          ContainerPort: 8080
        PlatformVersion: LATEST

Hooks:
  - BeforeInstall: 
      - Location: scripts/before_install.sh
        Timeout: 300
        RulesEvaluationMode: ANY 
  - AfterInstall:
      - Location: scripts/after_install.sh
        Timeout: 300
  - AfterAllowTestTraffic:
      - Location: scripts/run_tests.sh
        Timeout: 300
  - BeforeAllowTraffic:
      - Location: scripts/before_traffic.sh
        Timeout: 300
  - AfterAllowTraffic:
      - Location: scripts/after_traffic.sh
        Timeout: 300
```

### 5.3 ロールバック戦略

#### 5.3.1 自動ロールバックトリガー

以下の条件でロールバックを自動的に実行します：

1. デプロイ後のヘルスチェック失敗
2. アラーム監視による異常検知
3. デプロイタイムアウト
4. CodeDeployによる検証テスト失敗

#### 5.3.2 手動ロールバック手順

1. AWS Management Consoleからロールバックの実行
2. 前バージョンタスク定義の再デプロイ
3. CloudFormationスタックのロールバック

#### 5.3.3 アラームベースロールバック設定

```yaml
# CloudFormationの一部としての自動ロールバックアラーム設定
DeploymentAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: ecsforgate-prd-deployment-alarm
    ComparisonOperator: GreaterThanThreshold
    EvaluationPeriods: 1
    MetricName: 5XXError
    Namespace: AWS/ApplicationELB
    Period: 60
    Statistic: Sum
    Threshold: 5
    AlarmDescription: Alarm if too many 5XX errors are detected after deployment
    Dimensions:
      - Name: LoadBalancer
        Value: !GetAtt ApplicationLoadBalancer.LoadBalancerFullName
    TreatMissingData: notBreaching
```

## 6. IAMロールとポリシー設計

### 6.1 CI/CDサービスロール

以下のサービスロールを作成します：

| ロール名 | 用途 | 主要権限 |
|---------|------|---------|
| CodePipelineServiceRole | パイプライン実行用 | S3, CodeBuild, CodeDeploy, CloudFormation |
| CodeBuildServiceRole | ビルド/テスト実行用 | ECR, S3, CloudWatch, SecretsManager |
| CodeDeployServiceRole | デプロイ実行用 | ECS, EC2, ELB, CloudWatch |
| CloudFormationServiceRole | インフラデプロイ用 | IAM, VPC, ECS, RDS, CloudWatch など |

### 6.2 ポリシー設定例

CodeBuildサービスロールのポリシー例：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::${ArtifactBucket}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:ecsforgate/*"
      ]
    }
  ]
}
```

## 7. シークレット管理

### 7.1 シークレット種別と保存場所

| シークレット種別 | 保存場所 | アクセス方法 |
|--------------|---------|------------|
| データベース認証情報 | AWS Secrets Manager | ECS TaskロールがGetSecretValue権限を保有 |
| APIキー・認証情報 | AWS Secrets Manager | CodeBuildがビルド時にアクセス |
| CI/CD環境変数 | CodeBuild環境変数 (暗号化) | ビルド時に自動展開 |

### 7.2 シークレットローテーション設定

- **データベース認証情報**: 90日ごとに自動ローテーション
- **APIキー・認証情報**: 180日ごとに手動ローテーション

### 7.3 シークレットアクセス例（buildspec.yml内）

```yaml
phases:
  pre_build:
    commands:
      - echo Fetching secrets...
      - export DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ecsforgate/$ENVIRONMENT/db-password --query SecretString --output text)
```

## 8. モニタリングと通知

### 8.1 パイプライン実行監視

| 監視項目 | 監視方法 | 通知先 |
|---------|---------|-------|
| パイプライン実行状態 | CloudWatch Events | SNS→メール/Slack |
| ビルド成功/失敗 | CloudWatch Events | SNS→メール/Slack |
| デプロイ成功/失敗 | CloudWatch Events | SNS→メール/Slack |

### 8.2 CloudWatch通知設定

```yaml
# CloudFormationの一部としてのCloudWatch Events設定
PipelineStateChangeRule:
  Type: AWS::Events::Rule
  Properties:
    Name: ecsforgate-pipeline-state-change
    Description: Capture pipeline state changes
    EventPattern:
      source:
        - aws.codepipeline
      detail-type:
        - CodePipeline Pipeline Execution State Change
      detail:
        pipeline:
          - ecsforgate-dev-pipeline
          - ecsforgate-stg-pipeline
          - ecsforgate-prd-pipeline
        state:
          - FAILED
          - SUCCEEDED
    State: ENABLED
    Targets:
      - Arn: !Ref NotificationTopic
        Id: PipelineNotification
```

### 8.3 Slack通知設定

Lambda関数とSlack Webhookを使用してCI/CD通知をSlackに送信する設定を行います：

```yaml
# CloudFormationの一部としてのSlack通知Lambda設定
SlackNotificationFunction:
  Type: AWS::Lambda::Function
  Properties:
    FunctionName: ecsforgate-slack-notification
    Handler: index.handler
    Runtime: nodejs14.x
    Code:
      ZipFile: |
        const https = require('https');
        const url = require('url');
        
        exports.handler = async (event) => {
          const webhookUrl = process.env.SLACK_WEBHOOK_URL;
          const message = JSON.stringify({
            text: `CI/CD Pipeline Update: ${event.detail.pipeline} ${event.detail.state}`,
            attachments: [
              {
                color: event.detail.state === 'SUCCEEDED' ? 'good' : 'danger',
                fields: [
                  {
                    title: 'Pipeline',
                    value: event.detail.pipeline,
                    short: true
                  },
                  {
                    title: 'State',
                    value: event.detail.state,
                    short: true
                  },
                  {
                    title: 'Time',
                    value: new Date(event.time).toLocaleString(),
                    short: true
                  }
                ]
              }
            ]
          });
        
          const options = url.parse(webhookUrl);
          options.method = 'POST';
          options.headers = {
            'Content-Type': 'application/json',
            'Content-Length': message.length
          };
        
          return new Promise((resolve, reject) => {
            const req = https.request(options, (res) => {
              res.on('data', () => {});
              res.on('end', () => {
                resolve({
                  statusCode: res.statusCode,
                  body: 'Message sent'
                });
              });
            });
            
            req.on('error', (error) => {
              reject(error);
            });
            
            req.write(message);
            req.end();
          });
        };
    Environment:
      Variables:
        SLACK_WEBHOOK_URL: !Ref SlackWebhookUrl
    Role: !GetAtt LambdaExecutionRole.Arn
    Timeout: 30
```

## 9. 環境差分

環境ごとの主な差分は以下の通りです：

| 設定項目 | 開発環境（dev） | ステージング環境（stg） | 本番環境（prd） |
|---------|--------------|-------------------|--------------| 
| コードブランチ | develop | release/* | main |
| デプロイ頻度 | 随時（複数回/日） | 計画的（週次） | 計画的（月次） |
| デプロイ方式 | ローリング更新 | ブルー/グリーン | ブルー/グリーン |
| 承認ステップ | なし | オプション | 必須 |
| テスト範囲 | 基本テストのみ | 拡張テスト | 拡張テスト + 負荷テスト |
| ロールバック | 自動 | 自動 | 自動 + 手動オプション |
| 通知 | 失敗時のみ | 成功/失敗 | すべてのステージ |

## 10. CloudFormationリソース定義

CI/CD構成のためのCloudFormationリソースタイプと主要パラメータを以下に示します：

### 10.1 主要リソースタイプ
- **AWS::CodePipeline::Webhook**: GitHubリポジトリとの連携を定義
- **AWS::CodeBuild::Project**: ビルドプロジェクトを定義
- **AWS::CodeDeploy::Application**: デプロイアプリケーションを定義
- **AWS::CodeDeploy::DeploymentGroup**: デプロイグループを定義
- **AWS::CodePipeline::Pipeline**: パイプラインを定義
- **AWS::IAM::Role**: CI/CDサービスロールを定義
- **AWS::SNS::Topic**: 通知トピックを定義
- **AWS::Events::Rule**: イベントルールを定義

### 10.2 主要パラメータ例

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

  BranchName:
    Type: String
    Default: develop
    Description: デプロイ対象のブランチ名

  ApprovalRequired:
    Type: String
    Default: false
    AllowedValues:
      - true
      - false
    Description: デプロイ前の承認ステップが必要かどうか

  NotificationEmail:
    Type: String
    Description: 通知先メールアドレス

  SlackWebhookUrl:
    Type: String
    NoEcho: true
    Description: Slack通知用WebhookのURL
```

## 11. 考慮すべきリスクと対策

| リスク | 影響度 | 対策 |
|-------|-------|------|
| パイプライン障害 | 高 | 細かいステージ分割、エラー通知、手動再実行オプション |
| デプロイ失敗 | 高 | 自動ロールバック、ヘルスチェック、段階的トラフィック移行 |
| シークレット漏洩 | 高 | Secrets Manager使用、最小権限の原則、監査ログ |
| テスト不足 | 中 | テスト自動化、カバレッジ計測、環境別検証 |
| リソースアクセス権限不足 | 中 | 十分な権限を持つサービスロール設定、テスト環境での検証 |
| 長時間ビルド | 中 | キャッシュ活用、段階的ビルド、並列実行 |

## 12. 設計検証方法

本CI/CD設計の妥当性を確認するために、以下の検証を実施します：

1. **小規模検証**: シンプルなアプリケーション変更による一連のパイプライン実行
2. **障害シミュレーション**: 意図的なビルド/テスト/デプロイ失敗によるロールバック動作の確認
3. **権限検証**: 最小権限の原則に基づくIAMロール設定の有効性確認
4. **環境間の独立性**: 各環境のパイプラインが相互に影響しないことの確認
5. **通知機能**: アラートと通知の適切な配信確認

## 13. 運用考慮点

### 13.1 通常運用時の考慮点
- パイプライン実行状況の定期確認
- ECRイメージの定期クリーンアップ
- S3アーティファクトバケットの最適化
- 承認依頼の適時処理

### 13.2 障害発生時の考慮点
- パイプライン障害の迅速な切り分けと対応
- 環境復旧手順の実行
- 関係者への適切な情報共有

### 13.3 メンテナンス時の考慮点
- CodeBuildランタイム環境の定期アップデート
- IAMポリシーの定期レビューと最適化
- パイプライン設定の定期的な見直しと改善

## 14. パフォーマンスチューニング

### 14.1 ビルドパフォーマンス最適化
- キャッシュ戦略の最適化（依存関係、Docker層）
- ビルドステップの並列処理
- 必要最小限のアーティファクト生成

### 14.2 パイプライン実行時間の最適化
- 適切なビルドコンピューティングタイプの選択
- テスト実行の効率化（並列テスト、選択的テスト実行）
- 不要なステップの除去

### 14.3 デプロイ速度の最適化
- デプロイロールアウト設定の調整
- ヘルスチェックの適切な構成
- リソースプロビジョニングの最適化

## 15. AWS Well-Architected Framework対応

設計は、AWSのWell-Architected Frameworkの5つの柱に準拠しています：

### 15.1 運用上の優秀性
- 完全自動化されたCI/CDパイプライン
- 環境ごとの最適化されたプロセス
- 包括的な監視とアラート設定

### 15.2 セキュリティ
- 最小権限の原則に基づくIAMロール設定
- Secrets Managerによる認証情報管理
- ビルトインのセキュリティスキャン

### 15.3 信頼性
- 自動ロールバックメカニズム
- 段階的デプロイとヘルスチェック
- 環境間の独立性確保

### 15.4 パフォーマンス効率
- 適切なコンピューティングリソースの選択
- キャッシュ戦略の最適化
- 並列処理の活用

### 15.5 コスト最適化
- 必要時のみリソースを使用
- 適切なインスタンスタイプの選択
- 使用量ベースのスケーリング