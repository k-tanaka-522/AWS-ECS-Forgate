# ロードバランサーモジュール

Application Load BalancerとTarget Groupを管理します。

## 構成

- Application Load Balancer
  - インターネット向けALB
  - アイドルタイムアウト設定
  - セキュリティグループ設定
- Target Group
  - ヘルスチェック設定
  - IPターゲットタイプ
- SSL/TLS証明書
  - ACM証明書
  - DNS検証
- リスナー
  - HTTPSリスナー（443）
  - HTTPリスナー（80→443リダイレクト）

## 環境差分

各環境で異なる設定：

```
dev:
  domain: dev.tk-niigata.com
  idle_timeout: 60
  health_check:
    interval: 30
    timeout: 5
    healthy: 2
    unhealthy: 3

stg:
  domain: stg.tk-niigata.com
  idle_timeout: 60
  health_check:
    interval: 30
    timeout: 5
    healthy: 2
    unhealthy: 3

prd:
  domain: tk-niigata.com
  idle_timeout: 60
  health_check:
    interval: 30
    timeout: 5
    healthy: 2
    unhealthy: 3
```

## パラメータ

| パラメータ名 | 説明 | デフォルト値 |
|------------|------|------------|
| Environment | 環境名 (dev/stg/prd) | dev |
| DomainName | ベースドメイン名 | tk-niigata.com |
| ContainerPort | コンテナポート | 3000 |

## 出力値

| 出力名 | 説明 | 用途 |
|--------|------|------|
| LoadBalancerArn | ALBのARN | ECSサービスでの参照用 |
| LoadBalancerDNS | ALBのDNS名 | DNS設定用 |
| TargetGroupArn | ターゲットグループのARN | ECSサービスでの参照用 |

## 依存関係

このモジュールは以下のモジュールに依存します：

- networkモジュール
  - VPC ID
  - パブリックサブネット ID
  - セキュリティグループ ID

## セキュリティ設定

1. リスナー設定
   - HTTPS (443): フォワード
   - HTTP (80): HTTPSへリダイレクト

2. SSL/TLS設定
   - ACM証明書使用
   - セキュリティポリシー: ELBSecurityPolicy-2016-08

3. セキュリティグループ
   - インバウンド: 80, 443
   - アウトバウンド: すべて許可

## 監視設定

CloudWatchメトリクス：
- リクエスト数
- レイテンシー
- ヘルスチェック
- エラーレート

## デプロイ時の注意点

1. SSL証明書のDNS検証が必要
2. ターゲットグループのヘルスチェック設定確認
3. セキュリティグループのルール確認
4. リスナールールの設定確認
