# CloudFormation トラブルシューティング

## ECS/ALB構築の問題

### 現象
- computeスタックのデプロイが失敗
- エラー: `The target group with targetGroupArn ... does not have an associated load balancer.`

### 調査手順
1. 依存関係の確認
   - ALB → TargetGroup → ECSサービス の順で作成が必要
   - DependsOn設定を追加するも解決せず
   ```yaml
   Service:
     DependsOn: 
       - LoadBalancer
       - TargetGroup
       - ListenerHTTP
   ```

2. 切り分け調査
   - ALB関連リソースを分離
   - ECSのみの構成で動作確認中（2025/2/23）

### 現在の対応状況
1. リソースの分離
   - compute.yamlからALB関連リソースを削除
   ```yaml
   # 削除したリソース
   - LoadBalancer
   - TargetGroup
   - ListenerHTTP
   - Certificate
   ```

   - ECSサービスの設定変更
   ```yaml
   Service:
     NetworkConfiguration:
       AwsvpcConfiguration:
         AssignPublicIp: ENABLED  # パブリックIP付与
   ```

2. 次のステップ
   - ECS単体の動作確認後
   - ALB用の別スタック作成を検討
   - 段階的なリソース追加を計画

### 教訓
- リソース間の依存関係を慎重に管理
- 問題の切り分けのため、最小構成からの段階的な構築が有効
- スタック分割による責務の分離を検討

### 参考情報
- [AWS ECSサービスのベストプラクティス](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/service-best-practices.html)
- [CloudFormationのDependsOn属性](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-attribute-dependson.html)
