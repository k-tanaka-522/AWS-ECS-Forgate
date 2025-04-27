# Secrets Managerシークレット設定手順

## 関連設計書
- [RDS詳細設計書](/docs/002_設計/components/rds-design.md)
- [ECS Fargate詳細設計書](/docs/002_設計/components/ecs-design.md)
- [CI/CD詳細設計書](/docs/002_設計/components/cicd-design.md)

## 目的
本ドキュメントでは、AWS Secrets Managerを使用して、環境ごとのデータベース認証情報やGitHub Personal Access Tokenなどの機密情報を安全に管理する手順を説明します。また、Spring Bootアプリケーションとの連携設定についても説明します。

## 前提条件
- AWS CLIがインストールされ、適切な権限を持つIAMユーザーで設定済み
- プロジェクトリポジトリのクローンがローカル環境にある
- GitHub Personal Access Tokenが発行済み（CI/CD連携用）

## 1. 環境別データベース認証情報の登録

AWS Secrets Managerを使用して、環境ごとのデータベース認証情報を安全に管理します。
以下の手順で各環境のシークレットを作成します。

### 開発環境（dev）のシークレット登録

```bash
# 開発環境のデータベース認証情報を登録
aws secretsmanager create-secret \
    --name dev/db/ecsforgate \
    --description "ECSForgate API 開発環境のデータベース接続情報" \
    --secret-string '{
        "username": "ecsforgate_dev",
        "password": "DevDB_Password123",
        "host": "ecsforgate-db-dev.cluster-xyz.ap-northeast-1.rds.amazonaws.com",
        "port": "3306",
        "dbname": "ecsforgate_dev"
    }'

# シークレットへのタグ付け
aws secretsmanager tag-resource \
    --secret-id dev/db/ecsforgate \
    --tags Key=Environment,Value=dev Key=Project,Value=ECSForgate
```

### ステージング環境（stg）のシークレット登録

```bash
# ステージング環境のデータベース認証情報を登録
aws secretsmanager create-secret \
    --name stg/db/ecsforgate \
    --description "ECSForgate API ステージング環境のデータベース接続情報" \
    --secret-string '{
        "username": "ecsforgate_stg",
        "password": "StgDB_Password456",
        "host": "ecsforgate-db-stg.cluster-xyz.ap-northeast-1.rds.amazonaws.com",
        "port": "3306",
        "dbname": "ecsforgate_stg"
    }'

# シークレットへのタグ付け
aws secretsmanager tag-resource \
    --secret-id stg/db/ecsforgate \
    --tags Key=Environment,Value=stg Key=Project,Value=ECSForgate
```

### 本番環境（prd）のシークレット登録

```bash
# 本番環境のデータベース認証情報を登録
aws secretsmanager create-secret \
    --name prd/db/ecsforgate \
    --description "ECSForgate API 本番環境のデータベース接続情報" \
    --secret-string '{
        "username": "ecsforgate_prd",
        "password": "PrdDB_Password789",
        "host": "ecsforgate-db-prd.cluster-xyz.ap-northeast-1.rds.amazonaws.com",
        "port": "3306",
        "dbname": "ecsforgate_prd"
    }'

# シークレットへのタグ付け
aws secretsmanager tag-resource \
    --secret-id prd/db/ecsforgate \
    --tags Key=Environment,Value=prd Key=Project,Value=ECSForgate
```

### 実際の環境では強力なパスワードを使用すること
上記のパスワードはサンプルです。実際の環境では、以下の条件を満たす強力なパスワードを使用してください：
- 最低16文字以上
- 大文字、小文字、数字、記号を含む
- 辞書に載っている単語を含まない
- 各環境で異なるパスワードを使用

## 2. GitHub Personal Access Token登録

CI/CDパイプラインがGitHubリポジトリにアクセスするためのトークンを登録します。

```bash
# GitHubトークンの登録
aws secretsmanager create-secret \
    --name github/token \
    --description "GitHub Personal Access Token for ECSForgate CI/CD" \
    --secret-string '{
        "token": "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    }'

# シークレットへのタグ付け
aws secretsmanager tag-resource \
    --secret-id github/token \
    --tags Key=Project,Value=ECSForgate Key=Service,Value=CICD
```

## 3. シークレットの確認

登録したシークレットを確認します。

```bash
# シークレットの一覧表示
aws secretsmanager list-secrets --filter Key=tag-key,Values=Project --filter-value ECSForgate

# 特定のシークレットの詳細を表示（機密情報は含まれない）
aws secretsmanager describe-secret --secret-id dev/db/ecsforgate

# 特定のシークレットの値を取得（実際の機密情報が表示されるので注意）
aws secretsmanager get-secret-value --secret-id dev/db/ecsforgate
```

## 4. Spring Bootアプリケーションのセットアップ

Spring Boot側でAWS Secrets Managerと連携するための設定を行います。

### 4.1. build.gradleへの依存関係追加

Spring BootアプリケーションがSecrets Managerを利用するための依存関係を追加します。

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

```yaml
# src/main/resources/application-local.yml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/ecsforgate_local
    username: root
    password: password
    
# src/main/resources/application-dev.yml
spring:
  datasource:
    url: jdbc:mysql://${host}:${port}/${dbname}
    
# src/main/resources/application-stg.yml
spring:
  datasource:
    url: jdbc:mysql://${host}:${port}/${dbname}
    
# src/main/resources/application-prd.yml
spring:
  datasource:
    url: jdbc:mysql://${host}:${port}/${dbname}
```

## 5. IAMロールの設定

ECS TaskがSecrets ManagerにアクセスできるようにするためのIAMロールを設定します。

```bash
# ECSタスク実行ロールのポリシー作成
cat > secrets-manager-policy.json << 'EOF'
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
                "arn:aws:secretsmanager:*:*:secret:prd/db/ecsforgate*"
            ]
        }
    ]
}
EOF

# ポリシーの作成
aws iam create-policy \
    --policy-name ECSForgateSecretsManagerAccess \
    --policy-document file://secrets-manager-policy.json

# ECSタスク実行ロールにポリシーをアタッチ（既存のロールがある場合）
aws iam attach-role-policy \
    --role-name ecsforgate-task-execution-role \
    --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/ECSForgateSecretsManagerAccess
```

## 6. シークレットのローテーション（オプション）

セキュリティのためにシークレットのローテーションを設定することをお勧めします。

```bash
# シークレットローテーションの設定
aws secretsmanager rotate-secret \
    --secret-id prd/db/ecsforgate \
    --rotation-lambda-arn arn:aws:lambda:ap-northeast-1:${AWS_ACCOUNT_ID}:function:SecretsManagerRotationFunction \
    --rotation-rules '{"AutomaticallyAfterDays": 90}'
```

## 注意事項

1. 実際のパスワードは、ここに記載されているものではなく、強力で一意なものを使用してください。
2. 開発環境では実際のAWS認証情報を使用せず、ローカル開発時にはファイルベースの設定を使用することも検討してください。
3. IAMポリシーは最小権限の原則に従って設定してください。
4. コード内でハードコードされた認証情報がないか定期的に確認してください。

## 参考情報

- [AWS Secrets Manager ユーザーガイド](https://docs.aws.amazon.com/ja_jp/secretsmanager/latest/userguide/intro.html)
- [Spring Cloud AWS ドキュメント](https://cloud.spring.io/spring-cloud-aws/reference/html/)
- [AWS CLI コマンドリファレンス - Secrets Manager](https://docs.aws.amazon.com/cli/latest/reference/secretsmanager/index.html)
- [Spring Boot 外部設定ドキュメント](https://docs.spring.io/spring-boot/docs/current/reference/html/spring-boot-features.html#boot-features-external-config)
