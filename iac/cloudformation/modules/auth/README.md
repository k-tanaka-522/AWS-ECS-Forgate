# 認証モジュール

Amazon Cognitoを使用したユーザー認証基盤を管理します。

## 構成

- Cognito User Pool
  - ユーザープール
  - アプリクライアント
  - ドメイン設定
- IAM
  - Cognitoアクセス用ロール
  - ポリシー

## 環境差分

各環境で異なる設定：

```
dev:
  password_policy:
    minimum_length: 8
    require_numbers: true
    require_symbols: false
  session_timeout: 24h
  domain_prefix: dev-escforgate

stg:
  password_policy:
    minimum_length: 8
    require_numbers: true
    require_symbols: true
  session_timeout: 24h
  domain_prefix: stg-escforgate

prd:
  password_policy:
    minimum_length: 12
    require_numbers: true
    require_symbols: true
  session_timeout: 12h
  domain_prefix: escforgate
```

## パラメータ

| パラメータ名 | 説明 | デフォルト値 |
|------------|------|------------|
| Environment | 環境名 (dev/stg/prd) | dev |
| DomainPrefix | Cognitoドメインプレフィックス | dev-escforgate |
| SessionTimeout | セッションタイムアウト時間 | 24h |
| PasswordMinLength | パスワード最小長 | 8 |
| RequireSymbols | 記号必須 | false |

## 出力値

| 出力名 | 説明 | 用途 |
|--------|------|------|
| UserPoolId | Cognito User Pool ID | アプリケーション設定用 |
| UserPoolClientId | アプリクライアントID | アプリケーション設定用 |
| UserPoolDomain | CognitoドメインURL | ログインページURL用 |

## 認証フロー

1. ユーザー登録
   - メールアドレスによる登録
   - メール確認コード検証
   - 初期パスワード設定

2. ログイン
   - ユーザー名/パスワード認証
   - MFA（オプション）
   - JWTトークン発行

3. パスワードポリシー
   - 最小長
   - 文字種の組み合わせ
   - 有効期限
   - 履歴管理

## セキュリティ設定

1. アカウントロック
   - ログイン試行回数制限
   - 一時ロック期間

2. MFA設定
   - SMS
   - TOTP

3. パスワードポリシー
   - 複雑性要件
   - 定期変更

## カスタマイズ

1. メール通知
   - 登録確認
   - パスワードリセット
   - MFAコード

2. UIカスタマイズ
   - ロゴ
   - CSS
   - 言語設定

## トリガー設定

Lambda関数との連携：

1. サインアップ前
   - カスタムバリデーション
   - ブラックリストチェック

2. サインアップ後
   - ユーザー属性の自動設定
   - 外部システム連携

3. 認証前後
   - カスタム認証
   - ログ記録

## 監視設定

CloudWatchメトリクス：
- サインアップ数
- サインイン数
- サインイン失敗数
- MFA成功/失敗数
