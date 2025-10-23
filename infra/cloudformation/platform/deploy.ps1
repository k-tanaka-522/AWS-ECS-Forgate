# ==============================================================================
# Platform Account - CloudFormation Deployment Script (PowerShell)
# ==============================================================================

# Usage: .\deploy.ps1 -Environment dev
# Example: .\deploy.ps1 -Environment dev

param(
    [Parameter(Mandatory=$true)]
    [string]$Environment
)

$ErrorActionPreference = "Stop"
$ProjectName = "sample-app"
$AwsRegion = "ap-northeast-1"
$BucketName = "$ProjectName-$Environment-cfn-templates"
$StackName = "$ProjectName-$Environment-platform"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Platform Account Deployment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment"
Write-Host "Stack Name: $StackName"
Write-Host "Region: $AwsRegion"
Write-Host ""

# Check AWS CLI authentication
Write-Host "[1/5] Checking AWS authentication..." -ForegroundColor Yellow
$AwsAccountId = aws sts get-caller-identity --query Account --output text
Write-Host "  AWS Account ID: $AwsAccountId" -ForegroundColor Green
Write-Host ""

# Create S3 bucket for nested templates (if not exists)
Write-Host "[2/5] Creating S3 bucket for nested templates..." -ForegroundColor Yellow
$BucketExists = aws s3 ls "s3://$BucketName" 2>$null
if ($BucketExists) {
    Write-Host "  Bucket already exists: $BucketName" -ForegroundColor Green
} else {
    aws s3 mb "s3://$BucketName" --region $AwsRegion
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Bucket created: $BucketName" -ForegroundColor Green
    } else {
        Write-Host "  Failed to create bucket" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Upload nested templates to S3
Write-Host "[3/5] Uploading nested templates to S3..." -ForegroundColor Yellow
aws s3 cp nested\network.yaml "s3://$BucketName/platform/nested/network.yaml"
Write-Host "  Uploaded: nested\network.yaml" -ForegroundColor Green

aws s3 cp nested\connectivity.yaml "s3://$BucketName/platform/nested/connectivity.yaml"
Write-Host "  Uploaded: nested\connectivity.yaml" -ForegroundColor Green
Write-Host ""

# Deploy CloudFormation stack
Write-Host "[4/5] Deploying CloudFormation stack..." -ForegroundColor Yellow
aws cloudformation deploy `
    --stack-name $StackName `
    --template-file stacks\main\stack.yaml `
    --parameter-overrides "file://parameters\$Environment.json" `
    --capabilities CAPABILITY_IAM `
    --region $AwsRegion `
    --no-fail-on-empty-changeset

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Stack deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Get stack outputs
Write-Host "[5/5] Retrieving stack outputs..." -ForegroundColor Yellow
aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $AwsRegion `
    --query 'Stacks[0].Outputs' `
    --output table

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Platform Account deployment completed!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Note the Transit Gateway ID from the outputs above"
Write-Host "2. Update Service Account parameters file with the Transit Gateway ID"
Write-Host "3. Deploy Service Account infrastructure"
Write-Host ""
