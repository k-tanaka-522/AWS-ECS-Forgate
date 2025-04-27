# Secrets Managerシークレット設定手順


## 実行環境の前提条件

この手順書は以下の環境を前提としています：

### 実行環境
- ホストOS: Windows 10/11
- WSL: Ubuntu 22.04 LTS
- コマンドライン環境:
  - AWS CLI コマンド: WSL環境
  - Git コマンド: WSL環境
  - bashスクリプト (.sh): WSL環境
  - Docker コマンド: Windows環境（Docker Desktop）

### ツールのバージョン要件
- AWS CLI: バージョン2.x以上（WSL上にインストール済み）
- Git: バージョン2.x以上（WSL上にインストール済み）
- Docker: Docker Desktop for Windows 4.x以上（WSL2統合有効）

### 環境設定の確認

**WSL上でのAWS CLI確認:**
```bash
# WSL環境で実行
# WSLターミナルで実行
aws --version
aws sts get-caller-identity
```

**WSL上でのGit確認:**
```bash
# WSL環境で実行
# WSLターミナルで実行
git --version
```

**Windows上でのDocker確認:**
```bash
# WSL環境で実行
# Windows PowerShellまたはCMDで実行
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
- [RDS詳細設計書](/docs/002_設計/components/rds-design.md)
- [ECS Fargate詳細設計書](/docs/002_設計/components/ecs-design.md)
- [CI/CD詳細設計書](/docs/002_設計/components/cicd-design.md)

## 目的
本ドキュメントでは、AWS Secrets Managerを使用して、環境ごとのデータベース認証情報やGitHub Personal Access Tokenなどの機密情報を安全に管理する手順を説明します。また、Spring Bootアプリケーションとの連携設定についても説明します。

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
  - Secrets Manager作成権限：`secretsmanager:CreateSecret`
  - Secrets Manager更新権限：`secretsmanager:PutSecretValue`, `secretsmanager:UpdateSecret`
  - Secrets Managerタグ付け権限：`secretsmanager:TagResource`
  - IAMポリシー作成/アタッチ権限：`iam:CreatePolicy`, `iam:AttachRolePolicy`

- [ ] プロジェクトリポジトリのクローンがローカル環境にある
```bash
# WSL環境で実行
  # プロジェクトルートディレクトリに移動
  cd /mnt/c/dev2/ECSForgate
  # 確認
  ls -l
  ```

- [ ] GitHub Personal Access Token（PAT）が発行済み（CI/CD連携用）
  - GitHubのPersonal Access Tokenはメモしてありますか？
  - 必要な権限（`repo`と`admin:repo_hook`）が付与されていますか？
  - トークンの有効期限を確認しましたか？

- [ ] 必要なデータベース接続情報が準備されている
  - 各環境（dev/stg/prd）のホスト名、ポート、DB名、ユーザー名、パスワード

## 1. 環境別データベース認証情報の登録

作業を開始する前に、プロジェクトのルートディレクトリに移動していることを確認してください：

以下のコマンドをターミナルで実行してください：
```bash
# WSL環境で実行
cd /mnt/c/dev2/ECSForgate
pwd
# 出力例: /mnt/c/dev2/ECSForgate
```

AWS Secrets Managerを使用して、環境ごとのデータベース認証情報を安全に管理します。
以下の手順で各環境のシークレットを作成します。

### 1.1 AWSアカウントIDの取得

以下のコマンドをターミナルで実行してください：
```bash
# WSL環境で実行
# AWSアカウントIDを環境変数に設定
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "AWS Region: ${AWS_REGION}"
```

### 1.2 開発環境（dev）のシークレット登録

以下の内容の一時シェルスクリプト（create-dev-secrets.sh）を作成し、実行許可を付与してから実行してください：
```bash
# WSL環境で実行
#!/bin/bash
# RDSホスト名などの情報を確認
# 注意: 実際の環境の値に置き換えてください
AWS_REGION=$(aws configure get region)
DEV_DB_HOST="ecsforgate-db-dev.cluster-xyz.${AWS_REGION}.rds.amazonaws.com"
echo "開発環境のDBホスト: ${DEV_DB_HOST}"

# 開発環境のデータベース認証情報を登録
aws secretsmanager create-secret \
    --name dev/db/ecsforgate \
    --description "ECSForgate API 開発環境のデータベース接続情報" \
    --secret-string "{
        \"username\": \"ecsforgate_dev\",
        \"password\": \"$(openssl rand -base64 24)\",
        \"host\": \"${DEV_DB_HOST}\",
        \"port\": \"3306\",
        \"dbname\": \"ecsforgate_dev\"
    }"

# 【確認ポイント】
# 成功時の出力例：
# {
#     "ARN": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:dev/db/ecsforgate-Abcdef",
#     "Name": "dev/db/ecsforgate",
#     "VersionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# }

# シークレットへのタグ付け
aws secretsmanager tag-resource \
    --secret-id dev/db/ecsforgate \
    --tags Key=Environment,Value=dev Key=Project,Value=ECSForgate

# 【確認ポイント】
# タグ付け成功時は出力がありません。エラーがなければ成功です。
# タグが正しく設定されたか確認するには：
aws secretsmanager describe-secret --secret-id dev/db/ecsforgate --query "Tags"

# 【エラー対応】
# すでに同名のシークレットが存在する場合は以下のエラーが表示されます：
# An error occurred (ResourceExistsException) when calling the CreateSecret operation: The secret dev/db/ecsforgate already exists.
# この場合は、既存のシークレットを更新するか、別の名前で作成してください。
```

スクリプトを作成したら、以下のコマンドで実行許可を付与して実行します：
```bash
# WSL環境で実行
chmod +x create-dev-secrets.sh
./create-dev-secrets.sh
```

### 1.3 ステージング環境（stg）のシークレット登録

以下の内容の一時シェルスクリプト（create-stg-secrets.sh）を作成し、実行許可を付与してから実行してください：
```bash
# WSL環境で実行
#!/bin/bash
# ステージング環境のRDSホスト名
AWS_REGION=$(aws configure get region)
STG_DB_HOST="ecsforgate-db-stg.cluster-xyz.${AWS_REGION}.rds.amazonaws.com"
echo "ステージング環境のDBホスト: ${STG_DB_HOST}"

# ステージング環境のデータベース認証情報を登録
aws secretsmanager create-secret \
    --name stg/db/ecsforgate \
    --description "ECSForgate API ステージング環境のデータベース接続情報" \
    --secret-string "{
        \"username\": \"ecsforgate_stg\",
        \"password\": \"$(openssl rand -base64 28)\",
        \"host\": \"${STG_DB_HOST}\",
        \"port\": \"3306\",
        \"dbname\": \"ecsforgate_stg\"
    }"

# 【確認ポイント】
# 作成されたシークレットのARNとVersionIdが表示されることを確認します
# ARNの形式: arn:aws:secretsmanager:リージョン:アカウントID:secret:stg/db/ecsforgate-XXXXXX

# シークレットへのタグ付け
aws secretsmanager tag-resource \
    --secret-id stg/db/ecsforgate \
    --tags Key=Environment,Value=stg Key=Project,Value=ECSForgate

# 【確認ポイント】
# タグが正しく設定されたか確認
aws secretsmanager describe-secret --secret-id stg/db/ecsforgate --query "Tags"
```

スクリプトを作成したら、以下のコマンドで実行許可を付与して実行します：
```bash
# WSL環境で実行
chmod +x create-stg-secrets.sh
./create-stg-secrets.sh
```

### 1.4 本番環境（prd）のシークレット登録

以下の内容の一時シェルスクリプト（create-prd-secrets.sh）を作成し、実行許可を付与してから実行してください：
```bash
# WSL環境で実行
#!/bin/bash
# 本番環境のRDSホスト名
AWS_REGION=$(aws configure get region)
PRD_DB_HOST="ecsforgate-db-prd.cluster-xyz.${AWS_REGION}.rds.amazonaws.com"
echo "本番環境のDBホスト: ${PRD_DB_HOST}"

# 本番環境用の特に強固なパスワードを生成（32文字）
# 注意: 本番環境のパスワードはさらに厳格な管理が必要です
PRD_PASSWORD=$(openssl rand -base64 32)

# 本番環境のデータベース認証情報を登録
aws secretsmanager create-secret \
    --name prd/db/ecsforgate \
    --description "ECSForgate API 本番環境のデータベース接続情報" \
    --secret-string "{
        \"username\": \"ecsforgate_prd\",
        \"password\": \"${PRD_PASSWORD}\",
        \"host\": \"${PRD_DB_HOST}\",
        \"port\": \"3306\",
        \"dbname\": \"ecsforgate_prd\"
    }"

# 【確認ポイント】
# 作成されたシークレットのARNとVersionIdが表示されることを確認します

# シークレットへのタグ付け
aws secretsmanager tag-resource \
    --secret-id prd/db/ecsforgate \
    --tags Key=Environment,Value=prd Key=Project,Value=ECSForgate Key=Confidentiality,Value=High

# 【確認ポイント】
# タグが正しく設定されたか確認
aws secretsmanager describe-secret --secret-id prd/db/ecsforgate --query "Tags"
```

スクリプトを作成したら、以下のコマンドで実行許可を付与して実行します：
```bash
# WSL環境で実行
chmod +x create-prd-secrets.sh
./create-prd-secrets.sh
```

### 1.5 パスワード強度に関するガイドライン

上記のコマンドでは、openssl rand を使用して強力なランダムパスワードを生成していますが、実際の運用では以下の点にも注意してください：

1. **パスワード強度のガイドライン**:
   - 最低16文字以上（本番環境では24文字以上を推奨）
   - 大文字、小文字、数字、特殊記号をすべて含む
   - 辞書に載っている単語を含まない
   - 予測可能なパターンを使用しない

2. **環境別のパスワード管理**:
   - 各環境（dev/stg/prd）ごとに異なるパスワードを使用
   - 本番環境のパスワードはさらに厳重に管理
   - パスワードのローテーション計画を策定（後述）

3. **パスワードの共有と管理**:
   - 生成したパスワードは必要に応じて安全な方法で関係者と共有
   - パスワードのバックアップは暗号化して安全に保管
   - パスワード管理ツールの使用を検討

各環境のシークレットを作成した後、全てのシークレットが正しく作成されたことを確認します：

以下のコマンドをターミナルで実行してください：
```bash
# WSL環境で実行
# プロジェクト関連のシークレットをすべて一覧表示
aws secretsmanager list-secrets --filter Key=tag-key,Values=Project --filter-value ECSForgate
```

## 2. GitHub Personal Access Token登録

CI/CDパイプラインがGitHubリポジトリにアクセスするためのトークンを登録します。

### 2.1 GitHubトークンのセキュアな準備

あらかじめGitHubから発行済みのPersonal Access Tokenを準備し、安全に管理します。
絶対にコード内やリポジトリ内に平文のトークンを保存しないでください。

以下のコマンドをターミナルで実行してください（トークンを入力する前に周囲に人がいないか確認してください）：
```bash
# WSL環境で実行
# 環境変数にGitHubトークンを設定（トークンを直接コマンドラインに入力しないこと）
# この方法はセキュリティ上のリスクがあるため、本番環境では避けてください
read -s -p "GitHubトークンを入力してください: " GITHUB_TOKEN
echo

# トークンの先頭部分のみ表示して確認（最初の4文字のみ表示）
if [[ $GITHUB_TOKEN == ghp_* ]]; then
  echo "トークン形式が正しいです: ghp_***...（最初の4文字のみ表示）"
else
  echo "トークン形式が不正です。GitHubのPATは通常 'ghp_' で始まります。"
  exit 1
fi
```

### 2.2 Secrets Managerへのトークン登録

以下の内容の一時シェルスクリプト（register-github-token.sh）を作成し、実行許可を付与してから実行してください：
```bash
# WSL環境で実行
#!/bin/bash
# 環境変数にGitHubトークンがセットされていることを確認
if [ -z "$GITHUB_TOKEN" ]; then
  echo "エラー: GITHUB_TOKEN環境変数が設定されていません"
  echo "先に「read -s -p \"GitHubトークンを入力してください: \" GITHUB_TOKEN」を実行してください"
  exit 1
fi

# GitHubトークンの登録
# 注意: --secret-stringの値は必ず変数を使って指定し、履歴に残さないこと
aws secretsmanager create-secret \
    --name github/token \
    --description "GitHub Personal Access Token for ECSForgate CI/CD" \
    --secret-string "{\"token\":\"$GITHUB_TOKEN\"}"

# 【確認ポイント】
# 成功時の出力例：
# {
#     "ARN": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:github/token-Abcdef",
#     "Name": "github/token",
#     "VersionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# }

# 【エラー対応】
# すでに同名のシークレットが存在する場合は以下のエラーが表示されます：
# An error occurred (ResourceExistsException) when calling the CreateSecret operation: The secret github/token already exists.
# この場合は、既存のシークレットを更新する方法を検討してください：
# aws secretsmanager update-secret --secret-id github/token --secret-string "{\"token\":\"$GITHUB_TOKEN\"}"

# シークレットへのタグ付け
aws secretsmanager tag-resource \
    --secret-id github/token \
    --tags Key=Project,Value=ECSForgate Key=Service,Value=CICD Key=Confidentiality,Value=High

# タグが正しく設定されたか確認
aws secretsmanager describe-secret --secret-id github/token --query "Tags"

# 環境変数からトークンを削除（セキュリティ対策）
unset GITHUB_TOKEN
```

スクリプトを作成したら、以下のコマンドで実行許可を付与して実行します：
```bash
# WSL環境で実行
chmod +x register-github-token.sh
./register-github-token.sh
```

### 2.3 トークンの有効期限と管理

GitHub Personal Access Tokenには有効期限を設定することが推奨されています。以下は有効期限に関する重要な考慮事項です：

1. **有効期限の設定**:
   - GitHubでトークンを作成する際に適切な有効期限を設定（30日〜90日が推奨）
   - 期限切れ前に必ず更新プロセスを計画

2. **ローテーション計画**:
   - トークンの定期的なローテーションスケジュールを作成
   - ローテーション手順の文書化と関係者への周知
   - ローテーション時のダウンタイム最小化の計画

3. **アクセス権限の管理**:
   - トークンに必要最小限の権限のみを付与
   - 権限の見直しと必要に応じた調整
   - 不要になったトークンの即時無効化

## 3. シークレットの確認

登録したすべてのシークレットが正しく作成されたことを確認します。

### 3.1 シークレット一覧の確認

以下のコマンドをターミナルで実行してください：
```bash
# WSL環境で実行
# シークレットの一覧表示（プロジェクトでタグ付けされたもの）
aws secretsmanager list-secrets --filter Key=tag-key,Values=Project --filter-value ECSForgate

# 【確認ポイント】
# - 必要なすべてのシークレットが表示されるか
#   - dev/db/ecsforgate
#   - stg/db/ecsforgate
#   - prd/db/ecsforgate
#   - github/token
# - タグ、ARN、作成日などの情報が正しいか

# 環境ごとのシークレット一覧（例：dev環境）
aws secretsmanager list-secrets --filter Key=tag-key,Values=Environment --filter-value dev

# シークレットの総数確認
aws secretsmanager list-secrets --query "length(SecretList)"
```

### 3.2 特定シークレットの詳細確認

以下のコマンドをターミナルで実行してください：
```bash
# WSL環境で実行
# 特定のシークレットの詳細を表示（機密情報は含まれない）
aws secretsmanager describe-secret --secret-id dev/db/ecsforgate

# 【確認ポイント】
# - ARNが正しいFormat（arn:aws:secretsmanager:リージョン:アカウントID:secret:dev/db/ecsforgate-xxxxx）
# - 作成日が最近の日付
# - タグが正しく設定されている（KeyとValueのペア）
# - LastChangedDateが最新

# JSON出力を整形して見やすく表示
aws secretsmanager describe-secret --secret-id dev/db/ecsforgate --output json | jq
# jqがインストールされていない場合は、以下も利用可能
aws secretsmanager describe-secret --secret-id dev/db/ecsforgate --output yaml-stream
```

### 3.3 シークレット値の確認（注意：機密情報が表示されます）

以下のコマンドをターミナルで実行するときは、安全な環境であることを確認してください：
```bash
# WSL環境で実行
# 特定のシークレットの値を取得（実際の機密情報が表示されるので注意）
# 本コマンドは、安全な環境でのみ実行してください
aws secretsmanager get-secret-value --secret-id dev/db/ecsforgate

# 【注意事項】
# - このコマンドを実行すると実際のシークレット値（パスワードなど）が表示されます
# - コマンド履歴に残る可能性があるため、必要な場合のみ実行してください
# - 共有端末での実行は避け、確認後にコマンド履歴をクリアすることを推奨します
# - 特に本番環境のシークレットは確認の必要がない限り表示しないでください

# シークレット値の検証（値を表示せずに存在確認のみ）
aws secretsmanager get-secret-value --secret-id dev/db/ecsforgate --query "ARN" --output text
```

### 3.4 必要に応じたシークレットの更新

シークレットの内容を更新する必要がある場合は、以下の手順で行います。

update-secret.jsonファイルを作成してください：
```json
{
    "username": "ecsforgate_dev",
    "password": "新しいパスワード",
    "host": "ecsforgate-db-dev.cluster-xyz.ap-northeast-1.rds.amazonaws.com",
    "port": "3306",
    "dbname": "ecsforgate_dev"
}
```

ファイルを作成したら、以下のコマンドをターミナルで実行してください：
```bash
# WSL環境で実行
# シークレットの更新
aws secretsmanager update-secret \
    --secret-id dev/db/ecsforgate \
    --secret-string file://update-secret.json

# 更新ファイルの削除（セキュリティ対策）
rm update-secret.json

# 【注意事項】
# - パスワードなどの機密情報をファイルに書く場合は、作業後に確実に削除してください
# - 可能な限り一時ファイルを作成せずに直接コマンドで更新することを推奨します
```

## 4. Spring Bootアプリケーションのセットアップ

Spring Boot側でAWS Secrets Managerと連携するための設定を行います。

### 4.1. build.gradleへの依存関係追加

Spring BootアプリケーションがSecrets Managerを利用するための依存関係を追加します。

build.gradleファイルに以下の内容を追加してください：
```groovy
dependencies {
    // 既存の依存関係
    
    // AWS Secrets Manager連携用
    implementation 'org.springframework.cloud:spring-cloud-starter-aws-secrets-manager-config:2.2.6.RELEASE'
    implementation 'com.amazonaws:aws-java-sdk-secretsmanager:1.12.261'
}
```

### 4.2. bootstrap.ymlの作成

Secrets Managerから設定を読み込むためのbootstrap.ymlファイルを作成します。

src/main/resources/bootstrap.ymlファイルを作成し、以下の内容を追加してください：
```yaml
# src/main/resources/bootstrap.yml
spring:
  application:
    name: ecsforgate-api
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:local}
  cloud:
    aws:
      secretsmanager:
        name: ${spring.profiles.active}/db/ecsforgate
        enabled: true
        fail-fast: false  # 開発環境ではfalseに設定
        region: ap-northeast-1
        prefix: /config
        default-context: application
        profile-separator: _
      region:
        auto: false
        static: ap-northeast-1
```

### 4.3. 機密情報の参照方法

アプリケーション内で機密情報を参照するためのコードを作成します。

DatabaseConfig.javaファイルを作成し、以下の内容を追加してください：
```java
// データソース設定の例
@Configuration
public class DatabaseConfig {
    
    @Value("${spring.datasource.username}")
    private String username;
    
    @Value("${spring.datasource.password}")
    private String password;
    
    @Value("${spring.datasource.url}")
    private String url;
    
    @Bean
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(url);
        config.setUsername(username);
        config.setPassword(password);
        config.setDriverClassName("com.mysql.cj.jdbc.Driver");
        return new HikariDataSource(config);
    }
}
```

### 4.4. プロファイル別の設定

環境ごとに設定を切り替えるための設定ファイルを作成します。

src/main/resources/application-local.ymlファイルを作成し、以下の内容を追加してください：
```yaml
# src/main/resources/application-local.yml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/ecsforgate_local
    username: root
    password: password
```

src/main/resources/application-dev.ymlファイルを作成し、以下の内容を追加してください：
```yaml
# src/main/resources/application-dev.yml
spring:
  datasource:
    url: jdbc:mysql://${host}:${port}/${dbname}
```

src/main/resources/application-stg.ymlファイルを作成し、以下の内容を追加してください：
```yaml
# src/main/resources/application-stg.yml
spring:
  datasource:
    url: jdbc:mysql://${host}:${port}/${dbname}
```

src/main/resources/application-prd.ymlファイルを作成し、以下の内容を追加してください：
```yaml
# src/main/resources/application-prd.yml
spring:
  datasource:
    url: jdbc:mysql://${host}:${port}/${dbname}
```

## 5. IAMロールの設定

ECS TaskがSecrets ManagerにアクセスできるようにするためのIAMロールを設定します。

### 5.1 IAMポリシーの作成

以下の内容の一時ファイル（secrets-manager-policy.json）を作成してください：
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": [
                "arn:aws:secretsmanager:*:*:secret:dev/db/ecsforgate*",
                "arn:aws:secretsmanager:*:*:secret:stg/db/ecsforgate*",
                "arn:aws:secretsmanager:*:*:secret:prd/db/ecsforgate*",
                "arn:aws:secretsmanager:*:*:secret:github/token*"
            ]
        }
    ]
}
```

ファイルを作成したら、以下のコマンドをターミナルで実行してください：
```bash
# WSL環境で実行
# プロジェクトルートディレクトリに移動
cd /mnt/c/dev2/ECSForgate
pwd
# 出力例: /mnt/c/dev2/ECSForgate

# ポリシーファイルの内容確認
cat secrets-manager-policy.json

# 【確認ポイント】
# - ポリシーが正しいJSON形式か
# - 4つのリソース（dev/db/ecsforgate*, stg/db/ecsforgate*, prd/db/ecsforgate*, github/token*）が含まれているか
# - 必要最小限のアクション（GetSecretValue, DescribeSecret）のみ許可されているか

# ポリシーの作成
aws iam create-policy \
    --policy-name ECSForgateSecretsManagerAccess \
    --policy-document file://secrets-manager-policy.json

# 【確認ポイント】
# 成功時の出力例：
# {
#     "Policy": {
#         "PolicyName": "ECSForgateSecretsManagerAccess",
#         "PolicyId": "ANPAXXXXXXXXXXXXXXXX",
#         "Arn": "arn:aws:iam::123456789012:policy/ECSForgateSecretsManagerAccess",
#         "Path": "/",
#         "DefaultVersionId": "v1",
#         "AttachmentCount": 0,
#         "PermissionsBoundaryUsageCount": 0,
#         "IsAttachable": true,
#         "CreateDate": "2025-04-28T10:00:00+00:00",
#         "UpdateDate": "2025-04-28T10:00:00+00:00"
#     }
# }

# 【エラー対応】
# すでに同名のポリシーが存在する場合は以下のエラーが表示されます：
# An error occurred (EntityAlreadyExists) when calling the CreatePolicy operation: Policy with name ECSForgateSecretsManagerAccess already exists.
# この場合は、既存のポリシーを更新する方法を検討してください：
# aws iam create-policy-version --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/ECSForgateSecretsManagerAccess --policy-document file://secrets-manager-policy.json --set-as-default
```

### 5.2 既存ロールの確認

以下のコマンドをターミナルで実行してください：
```bash
# WSL環境で実行
# ECSタスク実行ロールが存在するか確認
aws iam list-roles --query "Roles[?contains(RoleName, 'ecsforgate') && contains(RoleName, 'execution')]"

# 【確認ポイント】
# - 以下のようなECSタスク実行ロールが一覧に表示されるか確認
#   - ecsforgate-task-execution-role
#   - ecsTaskExecutionRole-ecsforgate
#   - またはプロジェクト命名規則に沿った名前

# タスク実行ロール名を環境変数に設定（実際のロール名を使用）
TASK_EXECUTION_ROLE="ecsforgate-task-execution-role"
echo "使用するタスク実行ロール: ${TASK_EXECUTION_ROLE}"

# ロールの詳細情報を取得
aws iam get-role --role-name ${TASK_EXECUTION_ROLE}

# ロールにアタッチされた既存のポリシーを確認
aws iam list-attached-role-policies --role-name ${TASK_EXECUTION_ROLE}

# 【確認ポイント】
# - タスク実行ロールに既に「AmazonECSTaskExecutionRolePolicy」がアタッチされているか確認
# - Secrets Managerポリシーがまだアタッチされていないことを確認
```

### 5.3 ポリシーのアタッチ

以下の内容の一時シェルスクリプト（attach-policy.sh）を作成し、実行許可を付与してから実行してください：
```bash
# WSL環境で実行
#!/bin/bash
# AWSアカウントIDの確認（まだ設定されていない場合）
if [ -z "$AWS_ACCOUNT_ID" ]; then
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  AWS_REGION=$(aws configure get region)
  echo "AWS Account ID: ${AWS_
