# WSL環境で実行
#!/bin/bash
# 環境変数の設定
# 前のステップで設定した変数が残っていない場合は再度設定
if [ -z "$AWS_ACCOUNT_ID" ]; then
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
fi
if [ -z "$AWS_REGION" ]; then
  AWS_REGION=$(aws configure get region)
fi
REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ecsforgate-base
IMAGE_TAG=base-2025-Q2-frozen

echo "ビルドするイメージ: ${REPOSITORY_URI}:${IMAGE_TAG}"

# ECRへのログイン（24時間有効）
echo "ECRへログインしています..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# 【確認ポイント】
# 成功時の出力: Login Succeeded
# 失敗時: 認証情報の誤りやネットワークエラーなどのメッセージが表示

# ベースイメージのビルド
echo "ベースイメージをビルドしています..."
docker build -t ${REPOSITORY_URI}:${IMAGE_TAG} -f base-dockerfile .

# 【確認ポイント】
# - ビルドが成功したか（最後に "Successfully built xxxx" と表示される）
# - 各ステップでエラーがないか
# - ビルドが完了したら以下のコマンドでイメージを確認
docker images | grep ecsforgate-base

# ベースイメージのプッシュ（初回は時間がかかるため辛抱強く待つ）
echo "ベースイメージをECRにプッシュしています..."
docker push ${REPOSITORY_URI}:${IMAGE_TAG}

# 【確認ポイント】
# - プッシュが完了すると「latest: digest: sha256:xxxx size: yyyy」のような表示がされる
# - エラーが発生した場合は権限の問題やネットワークの問題を確認

# イメージの確認
echo "ECRにプッシュされたイメージを確認しています..."
aws ecr describe-images --repository-name ecsforgate-base

# 【確認ポイント】
# - imageTagsに「base-2025-Q2-frozen」が含まれていること
# - imageScanStatusがcompletedであること（scanOnPush=trueの場合）
# - エラーがある場合は以下のコマンドでイメージの詳細情報を取得
# aws ecr describe-images --repository-name ecsforgate-base --image-ids imageTag=${IMAGE_TAG}
