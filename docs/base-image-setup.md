# ベースイメージ構築およびECRリポジトリ設定手順

## 1. ECRリポジトリの作成

ベースイメージ用のリポジトリを作成します。

```bash
# AWS CLI設定の確認
aws configure list

# ベースイメージ用のECRリポジトリ作成
aws ecr create-repository \
    --repository-name ecsforgate-base \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability IMMUTABLE

# アプリケーションイメージ用のECRリポジトリ作成（まだ作成されていない場合）
aws ecr create-repository \
    --repository-name ecsforgate-api \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability IMMUTABLE

# リポジトリの確認
aws ecr describe-repositories
```

## 2. ベースイメージの構築とプッシュ

ベースイメージを構築し、ECRにプッシュします。

```bash
# 環境変数の設定
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ecsforgate-base
IMAGE_TAG=base-2025-Q2-frozen

# ECRへのログイン
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# ベースイメージのビルド
docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} -f base-dockerfile .

# ベースイメージのプッシュ
docker push ${REPOSITORY_URI}:${IMAGE_TAG}

# イメージの確認
aws ecr describe-images --repository-name ecsforgate-base
```

## 3. ECRイミュータビリティ設定の確認

タグの変更を防止するイミュータビリティ設定を確認します。

```bash
# ベースイメージリポジトリの設定確認
aws ecr describe-repositories --repository-names ecsforgate-base --query 'repositories[0].imageTagMutability'

# アプリケーションイメージリポジトリの設定確認
aws ecr describe-repositories --repository-names ecsforgate-api --query 'repositories[0].imageTagMutability'

# 必要に応じてイミュータビリティ設定を変更
aws ecr put-image-tag-mutability \
    --repository-name ecsforgate-base \
    --image-tag-mutability IMMUTABLE

aws ecr put-image-tag-mutability \
    --repository-name ecsforgate-api \
    --image-tag-mutability IMMUTABLE
```

## 4. ライフサイクルポリシーの設定

古いイメージを自動的に削除するためのライフサイクルポリシーを設定します（オプション）。
ただし、凍結されたベースイメージは長期保持が必要なため、対象外とします。

```bash
# ベースイメージのライフサイクルポリシー（frozen タグ以外の古いイメージを削除）
cat > base-lifecycle-policy.json << 'EOF'
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep frozen images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["base-", "frozen"],
                "countType": "imageCountMoreThan",
                "countNumber": 100
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Expire untagged images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 14
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF

# アプリケーションイメージのライフサイクルポリシー
cat > app-lifecycle-policy.json << 'EOF'
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep frozen production images",
            "selection": {
                "tagStatus": "tagged",
                "tagPatternList": ["*-frozen"],
                "countType": "imageCountMoreThan",
                "countNumber": 100
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Keep semantic versioned production images",
            "selection": {
                "tagStatus": "tagged",
                "tagPatternList": ["[0-9].[0-9].[0-9]"],
                "countType": "imageCountMoreThan",
                "countNumber": 20
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 3,
            "description": "Limit development images to 30",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["dev-"],
                "countType": "imageCountMoreThan",
                "countNumber": 30
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 4,
            "description": "Limit staging images to 10",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["stg-"],
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 5,
            "description": "Expire untagged images older than 7 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 7
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF

# ライフサイクルポリシーの適用
aws ecr put-lifecycle-policy \
    --repository-name ecsforgate-base \
    --lifecycle-policy-text file://base-lifecycle-policy.json

aws ecr put-lifecycle-policy \
    --repository-name ecsforgate-api \
    --lifecycle-policy-text file://app-lifecycle-policy.json
```

## 5. 四半期ごとの更新手順

ベースイメージの四半期ごとの更新は以下の手順で行います：

1. 新しいベースイメージ用のDockerfileを作成（前回のDockerfileを元に、セキュリティパッチと依存関係を更新）
2. 新しいタグ（例：base-2025-Q3-frozen）でイメージをビルド
3. テスト環境でイメージの動作確認
4. 新しいイメージをECRにプッシュ
5. アプリケーションのbuildspec.ymlファイルを更新して新しいベースイメージを参照
6. 更新されたbuildspec.ymlファイルをコミットしてCI/CDパイプラインを通じてアプリケーションを再ビルド

このプロセスにより、セキュリティパッチを含む最新のベースイメージを使用しながら、アプリケーションの安定性と再現性を確保できます。
