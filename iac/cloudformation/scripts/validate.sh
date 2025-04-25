#!/bin/bash
set -e

# 引数の解析
TEMPLATE_FILE=${1:-"$(pwd)/iac/cloudformation/templates/ecs.yaml"}
AWS_REGION=${2:-ap-northeast-1}  # デフォルトは東京リージョン

echo "Validating template: $TEMPLATE_FILE"
echo "Region: $AWS_REGION"

# テンプレートの存在確認
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: Template file not found: $TEMPLATE_FILE"
  exit 1
fi

# テンプレートの検証
echo "Validating CloudFormation template..."
aws cloudformation validate-template \
  --template-body file://$TEMPLATE_FILE \
  --region $AWS_REGION

if [ $? -eq 0 ]; then
  echo "Template validation passed!"
  
  # テンプレートのパラメータを表示
  echo "Template parameters:"
  aws cloudformation validate-template \
    --template-body file://$TEMPLATE_FILE \
    --query "Parameters" \
    --output table \
    --region $AWS_REGION
else
  echo "Template validation failed!"
  exit 1
fi

# cfn-lint がインストールされている場合は追加のチェックを実行
if command -v cfn-lint &> /dev/null; then
  echo "Running cfn-lint for additional checks..."
  cfn-lint -t $TEMPLATE_FILE
  
  if [ $? -eq 0 ]; then
    echo "cfn-lint checks passed!"
  else
    echo "cfn-lint checks found issues!"
    exit 1
  fi
else
  echo "cfn-lint not found, skipping additional checks."
  echo "Consider installing cfn-lint for more thorough validation: pip install cfn-lint"
fi

echo "All validation checks completed successfully!"
exit 0
