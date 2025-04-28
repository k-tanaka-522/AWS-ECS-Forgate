# ECRベースイメージ作成手順


## 実行環境の前提条件

この手順書は以下の環境を前提としています：

### 実行環境
- ホストOS: Windows 10/11
- WSL: Ubuntu 22.04 LTS
- コマンドライン環境:
  - AWS CLI コマンド: WSL環境およびWindows環境の両方に設定済み
  - Git コマンド: WSL環境
  - bashスクリプト (.sh): WSL環境
  - Docker コマンド: Windows環境（Docker Desktop）

### ツールのバージョン要件
- AWS CLI: バージョン2.x以上（WSLおよびWindows環境の両方にインストール済み）
- Git: バージョン2.x以上（WSL上にインストール済み）
- Docker: Docker Desktop for Windows 4.x以上（WSL2統合有効）

### 環境設定の確認

**WSL上でのAWS CLI確認:**
```bash
# WSL環境で実行
aws --version
aws sts get-caller-identity
```

**Windows上でのAWS CLI確認:**
```powershell
# Windows PowerShell環境で実行
aws --version
aws sts get-caller-identity
```

**WSL上でのGit確認:**
```bash
# WSL環境で実行
git --version
```

**Windows上でのDocker確認:**
```powershell
# Windows PowerShell環境で実行
docker --version
docker run --rm hello-world
```

### ファイルパスの注意事項

コマンドの実行環境に応じてパスの表記が異なります：
- WSL環境でのプロジェクトパス: `/mnt/c/dev2/ECSForgate/`
- Windows環境でのプロジェクトパス: `C:\dev2\ECSForgate\`

この手順書のコマンド例はすべてWSL環境のパス表記を前提としています。Windows環境で実行する場合は適宜パスを変換してください。

### 操作環境の切り替え

各コマンドを実行する際は、適切な環境（WSLまたはWindows）に切り替えてください。

- WSL環境への切り替え: Windows PowerShellから `wsl` コマンドを実行
- Windows環境への切り替え: WSLで `exit` コマンドを実行してWSLを終了
## 関連設計書
- [ECS Fargate詳細設計書](/docs/002_設計/components/ecs-design.md)

## 目的
本ドキュメントでは、ECS Fargate設計書に基づいたベースイメージの構築とECRリポジトリへの登録手順を説明します。
ベースイメージは四半期ごとに更新され、セキュリティパッチを適用したUbuntu 22.04ベースのイメージとして管理されます。

## 前提条件チェックリスト
以下の前提条件を確認してから作業を開始してください：

- [ ] AWS CLIがインストールされている（バージョン2.0以上推奨）
```bash
# WSL環境で実行
  aws --version
  # 出力例: aws-cli/2.9.19 Python/3.9.11 Linux/5.10.16.3-microsoft-standard-WSL2 exe/x86_64.ubuntu.22 prompt/off
  ```

- [ ] AWS CLIが適切な権限を持つIAMユーザーで設定済み
```bash
# WSL環境で実行
  aws sts get-caller-identity
  # 出力例：
  # {
  #     "UserId": "AIDAXXXXXXXXXXXXXX",
  #     "Account": "123456789012",
  #     "Arn": "arn:aws:iam::123456789012:user/username"
  # }
  ```

- [ ] 必要なIAM権限が付与されている
  - ECRリポジトリ作成権限：`ecr:CreateRepository`
  - ECRイメージプッシュ権限：`ecr:PutImage`, `ecr:InitiateLayerUpload`, 等
  - ECRリポジトリポリシー設定権限：`ecr:PutLifecyclePolicy`

- [ ] Dockerがインストールされている
```bash
# Windows環境（Docker Desktop）で実行
  docker --version
  # 出力例: Docker version 20.10.21, build baeda1f
  ```

- [ ] プロジェクトリポジトリのクローンがローカル環境にある
```bash
# WSL環境で実行
  # プロジェクトルートディレクトリに移動
  cd /mnt/c/dev2/ECSForgate
  # base-dockerfileが存在することを確認
  ls -l base-dockerfile
  ```

### 【実行環境: WSL】
## 1. ECRリポジトリの作成

作業を開始する前に、プロジェクトのルートディレクトリに移動していることを確認してください：

以下のコマンドをターミナルで順番に実行してください：
```bash
# WSL環境で実行
cd /mnt/c/dev2/ECSForgate
pwd
# 出力例: /mnt/c/dev2/ECSForgate
```

ベースイメージ用のリポジトリを作成します。

以下のコマンドをターミナルで順番に実行してください：
```bash
# WSL環境で実行
# AWS CLI設定の確認
aws configure list
# リージョンとアカウント情報が正しいことを確認

# AWSアカウントIDとリージョンを変数に格納（後続のコマンドで使用）
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "AWS Region: ${AWS_REGION}"

# ベースイメージ用のECRリポジトリ作成
aws ecr create-repository \
    --repository-name ecsforgate-base \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability IMMUTABLE

# 【確認ポイント】
# 成功時の出力例：
# {
#     "repository": {
#         "repositoryArn": "arn:aws:ecr:ap-northeast-1:123456789012:repository/ecsforgate-base",
#         "registryId": "123456789012",
#         "repositoryName": "ecsforgate-base",
#         "repositoryUri": "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/ecsforgate-base",
#         "createdAt": "2025-04-28T10:00:00.000000+09:00",
#         "imageTagMutability": "IMMUTABLE",
#         "imageScanningConfiguration": {
#             "scanOnPush": true
#         }
#     }
# }

# アプリケーションイメージ用のECRリポジトリ作成（まだ作成されていない場合）
aws ecr create-repository \
    --repository-name ecsforgate-api \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability IMMUTABLE

# 【エラー対応】
# リポジトリがすでに存在する場合は以下のエラーが表示されます：
# An error occurred (RepositoryAlreadyExistsException) when calling the CreateRepository operation: The repository with name 'ecsforgate-base' already exists in the registry with id '123456789012'
# この場合は問題ありませんので、次のステップに進んでください。

# リポジトリの確認
echo "作成したリポジトリを確認します..."
aws ecr describe-repositories --repository-names ecsforgate-base ecsforgate-api

# 【確認ポイント】
# - 両方のリポジトリが表示されること
# - imageTagMutabilityが"IMMUTABLE"であること
# - imageScanningConfigurationのscanOnPushがtrueであること
```

### 【実行環境: Windows + WSL】
## 2. ベースイメージの構築とプッシュ

ベースイメージを構築し、ECRにプッシュします。まず、base-dockerfileの内容を確認しましょう。

以下のコマンドをターミナルで実行してください：
```bash
# Windows環境（Docker Desktop）で実行
# base-dockerfileの内容確認
cat base-dockerfile
# 注意：Ubuntu 22.04ベース、Java 11ランタイムの構成になっていることを確認
```

環境変数を設定し、イメージをビルドしてプッシュします。

## 2. ベースイメージの構築とプッシュ

ここからは、WSL環境とWindows PowerShell環境を切り替えながら作業を進めます。
作業の流れは以下の通りです：

1. WSL環境：AWS認証情報を取得 → 
2. Windows PowerShell環境：Dockerイメージをビルド・プッシュ → 
3. WSL環境：イメージの確認

### 【手順1：WSL環境で実行】
#### 2.1 プロジェクトディレクトリへの移動

1. WSLターミナルを開きます（Windows検索で「WSL」と入力または PowerShellで「wsl」コマンドを実行）

2. 以下のコマンドをWSLターミナルに貼り付け、実行してプロジェクトディレクトリに移動します：

```bash
# プロジェクトディレクトリに移動
cd /mnt/c/dev2/ECSForgate
pwd
# 出力例: /mnt/c/dev2/ECSForgate
```

### 【手順2：Windows PowerShell環境で実行】
#### 2.2 PowerShellでDocker操作を実行する

1. Windows PowerShellを開きます（Windows検索で「PowerShell」と入力）

2. 以下のコマンドをPowerShellに貼り付けて実行します：

```powershell
# AWS CLIから情報を取得（AWS CLIが設定済みの前提）
$AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$AWS_REGION = aws configure get region
$REPOSITORY_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ecsforgate-base"
$IMAGE_TAG = "base-2025-Q2-frozen"

# 設定した情報を確認
Write-Host "================================================="
Write-Host "設定情報:"
Write-Host "AWS Account ID: $AWS_ACCOUNT_ID"
Write-Host "AWS Region: $AWS_REGION"
Write-Host "イメージURI: $REPOSITORY_URI"
Write-Host "イメージタグ: $IMAGE_TAG"
Write-Host "================================================="
```

3. 情報が正しいことを確認したら、以下のコマンドを実行してECRにログインします：

```powershell
# ECRへのログイン
Write-Host "ECRへログインしています..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
```

4. ログインが成功したら（「**Login Succeeded**」と表示される）、以下のコマンドを実行してビルドを行います：

```powershell
# プロジェクトディレクトリに移動
cd C:\dev2\ECSForgate

# base-dockerfileの内容確認
Write-Host "base-dockerfileの内容確認:"
Get-Content base-dockerfile | Select-Object -First 10

# ベースイメージのビルド
Write-Host "ベースイメージをビルドしています..."
docker build -t "${REPOSITORY_URI}:${IMAGE_TAG}" -f base-dockerfile .
```

5. ビルドが成功したら、以下のコマンドでイメージを確認します：

```powershell
# ビルドしたイメージの確認
Write-Host "ビルドしたイメージの確認:"
docker images | Select-String ecsforgate-base
```

6. イメージが表示されたら、以下のコマンドでECRにプッシュします：

```powershell
# ECRへのイメージプッシュ（時間がかかります）
Write-Host "ベースイメージをECRにプッシュしています..."
Write-Host "（初回は時間がかかりますので、辛抱強くお待ちください）"
docker push "${REPOSITORY_URI}:${IMAGE_TAG}"
```

7. プッシュが成功したら以下のような出力が表示されます：
```
The push refers to repository [123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/ecsforgate-base]
...
base-2025-Q2-frozen: digest: sha256:abcdef1234567890... size: 1234
```

### 【手順3：WSL環境に戻って実行】
#### 2.3 プッシュされたイメージの確認

1. WSLターミナルに戻ります（PowerShellからWSLに切り替えるには「wsl」コマンドを実行）

2. 以下のコマンドを実行して、イメージがECRに正しくプッシュされたか確認します：

```bash
# プロジェクトディレクトリに移動
cd /mnt/c/dev2/ECSForgate

# ECRのイメージを確認
echo "ECRにプッシュされたイメージを確認しています..."
aws ecr describe-images --repository-name ecsforgate-base
```

3. 出力に `"imageTags": [ "base-2025-Q2-frozen" ]` が含まれていれば成功です。

#### トラブルシューティング

**問題: ECRログインに失敗する場合**
- AWS CLIの認証情報が正しく設定されているか確認してください：`aws configure list`
- AWS CLIのバージョンが最新か確認してください：`aws --version`
- リージョンが正しいか確認してください

**問題: Dockerビルドに失敗する場合**
- Docker Desktopが起動しているか確認してください
- インターネット接続を確認してください
- base-dockerfileの構文に問題がないか確認してください

**問題: イメージのプッシュに失敗する場合**
- ECRリポジトリへのプッシュ権限があるか確認してください
- ネットワーク接続を確認してください
- ECRリポジトリが存在するか確認してください：`aws ecr describe-repositories`

ビルドやプッシュに失敗した場合は、以下の点を確認してください。

- AWS CLIの認証情報（AKID/SAK）が正しくセットアップされているか
- ECRリポジトリへのプッシュ権限があるか
- Dockerデーモンが起動しているか
- インターネット接続に問題がないか
- base-dockerfileの構文エラーがないか

### 【実行環境: WSL】
## 3. ECRイミュータビリティ設定の確認

タグの変更を防止するイミュータビリティ設定を確認します。

以下のコマンドをターミナルで順番に実行してください：
```bash
# WSL環境で実行
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

### 【実行環境: WSL】
## 4. ライフサイクルポリシーの設定

古いイメージを自動的に削除するためのライフサイクルポリシーを設定します（オプション）。
ただし、凍結されたベースイメージは長期保持が必要なため、対象外とします。

以下の内容のポリシーファイルを作成してください：

base-lifecycle-policy.jsonファイルを作成してください：
```json
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
```

app-lifecycle-policy.jsonファイルを作成してください：
```json
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
```

ポリシーファイルを作成したら、以下のコマンドをターミナルで実行してください：
```bash
# WSL環境で実行
# ライフサイクルポリシーの適用
aws ecr put-lifecycle-policy \
    --repository-name ecsforgate-base \
    --lifecycle-policy-text file://base-lifecycle-policy.json

aws ecr put-lifecycle-policy \
    --repository-name ecsforgate-api \
    --lifecycle-policy-text file://app-lifecycle-policy.json
```

### 【実行環境: Windows + WSL】
## 5. 四半期ごとの更新手順

ベースイメージは四半期ごとに更新し、セキュリティパッチを適用することを推奨しています。以下の詳細な手順で実施してください。

### 5.1 新しいベースイメージ用のDockerfileを作成

以下のコマンドをターミナルで実行してください：
```bash
# WSL環境で実行
# 前回のDockerfileをコピーして新しいバージョンを作成
cp base-dockerfile base-dockerfile.$(date +%Y%m%d)

# 新しいDockerfileを編集
nano base-dockerfile

# 主な更新箇所：
# 1. LABELのversion値とbuild.dateを更新
# 2. IMAGETAGの四半期表記を変更（例：2025-Q2 → 2025-Q3）
# 3. 必要に応じてJavaやUbuntuのバージョンを更新
```

### 5.2 新しいタグでイメージをビルド

以下の内容の一時シェルスクリプト（build-new-base-image.sh）を作成し、実行許可を付与してから実行してください：
```bash
# WSL環境で実行
#!/bin/bash
# 環境変数を設定
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ecsforgate-base
# 四半期を更新したタグを設定（例：Q2 → Q3）
IMAGE_TAG=base-2025-Q3-frozen

# ECRへのログイン
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# 新しいベースイメージをビルド
docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} -f base-dockerfile .
```

スクリプトを作成したら、以下のコマンドで実行許可を付与して実行します：
```bash
# WSL環境で実行
chmod +x build-new-base-image.sh
./build-new-base-image.sh
```

### 5.3 ベースイメージの検証

開発環境でベースイメージを使用してアプリケーションをビルドし、正常に動作することを確認します。

以下の内容の一時シェルスクリプト（test-base-image.sh）を作成し、実行許可を付与してから実行してください：
```bash
# WSL環境で実行
#!/bin/bash
# 環境変数の設定
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ecsforgate-base
IMAGE_TAG=base-2025-Q3-frozen

# 検証用にテストアプリケーションをビルド
cd /tmp
mkdir -p test-app
cd test-app

# テスト用のDockerfile作成
cat > Dockerfile << EOF
FROM ${REPOSITORY_URI}:${IMAGE_TAG}
COPY . /app
WORKDIR /app
RUN echo "Java version: " && java -version
CMD ["java", "-version"]
EOF

# テストイメージをビルド
docker build -t ecsforgate-test:latest .

# テストイメージを実行して動作確認
docker run --rm ecsforgate-test

# 確認ポイント：
# - Java 11が正しく動作すること
# - Ubuntu 22.04のコマンドが動作すること
# - タイムゾーンとロケールが日本語に設定されていること
```

スクリプトを作成したら、以下のコマンドで実行許可を付与して実行します：
```bash
# WSL環境で実行
chmod +x test-base-image.sh
./test-base-image.sh
```

### 5.4 新しいイメージをECRにプッシュ

検証が完了したら、イメージをECRにプッシュします。

以下のコマンドをターミナルで順番に実行してください：
```bash
# WSL環境で実行
# 環境変数の設定
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ecsforgate-base
IMAGE_TAG=base-2025-Q3-frozen

# イメージをプッシュ
docker push ${REPOSITORY_URI}:${IMAGE_TAG}

# プッシュされたイメージを確認
aws ecr describe-images --repository-name ecsforgate-base --query 'imageDetails[?contains(imageTags, `'"${IMAGE_TAG}"'`)]'
```

### 5.5 buildspec.ymlファイルの更新

各環境のbuildspec.ymlファイルを更新して、新しいベースイメージを参照するようにします。

以下のコマンドをターミナルで順番に実行してください：
```bash
# WSL環境で実行
# 開発環境のbuildspec更新
sed -i "s/BASE_IMAGE_TAG: \"base-2025-Q2-frozen\"/BASE_IMAGE_TAG: \"base-2025-Q3-frozen\"/" buildspec-dev.yml

# ステージング環境のbuildspec更新
sed -i "s/BASE_IMAGE_TAG: \"base-2025-Q2-frozen\"/BASE_IMAGE_TAG: \"base-2025-Q3-frozen\"/" buildspec-stg.yml

# 本番環境のbuildspec更新
sed -i "s/BASE_IMAGE_TAG: \"base-2025-Q2-frozen\"/BASE_IMAGE_TAG: \"base-2025-Q3-frozen\"/" buildspec-prd.yml

# 変更を確認
grep -r "BASE_IMAGE_TAG" buildspec-*.yml
```

### 5.6 変更をコミットしてCI/CDパイプラインでビルド

buildspecの変更をコミットし、CI/CDパイプラインを通じてアプリケーションを再ビルドします。

以下のコマンドをターミナルで順番に実行してください：
```bash
# WSL環境で実行
# 変更をコミット
git add buildspec-*.yml
git commit -m "Update base image to 2025-Q3-frozen"

# リモートリポジトリにプッシュ
git push origin develop

# CI/CDパイプラインの実行状況を確認
aws codepipeline get-pipeline-state --name ecsforgate-pipeline-dev
```

### 5.7 イメージ更新のタイミングと計画

ベースイメージ更新は以下のスケジュールで行うことを推奨します：

| 四半期 | 更新タイミング | イメージタグ |
|------|-------------|------------|
| Q1 | 1月第2週 | base-YYYY-Q1-frozen |
| Q2 | 4月第2週 | base-YYYY-Q2-frozen |
| Q3 | 7月第2週 | base-YYYY-Q3-frozen |
| Q4 | 10月第2週 | base-YYYY-Q4-frozen |

ベースイメージ更新後は、まず開発環境でアプリケーションをビルドしてテストし、問題がなければステージング環境、最後に本番環境の順に適用します。

このプロセスにより、セキュリティパッチを含む最新のベースイメージを使用しながら、アプリケーションの安定性と再現性を確保できます。

## 参考情報

- [AWS ECR ユーザーガイド](https://docs.aws.amazon.com/ja_jp/AmazonECR/latest/userguide/what-is-ecr.html)
- [Docker ビルドドキュメント](https://docs.docker.com/engine/reference/commandline/build/)
- [AWS CLIコマンドリファレンス - ECR](https://docs.aws.amazon.com/cli/latest/reference/ecr/index.html)
