# Shared VPC CloudFormation Stack Deploy Script
# Usage: .\deploy.ps1

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Shared VPC Stack Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$StackName = "careapp-poc-shared-network"
$TemplateFile = "network.yaml"
$ParametersFile = "parameters-poc.json"
$Region = "ap-northeast-1"

Write-Host "Stack Name: $StackName" -ForegroundColor Yellow
Write-Host "Template: $TemplateFile" -ForegroundColor Yellow
Write-Host "Parameters: $ParametersFile" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Deploy stack (validation is done automatically)
Write-Host "[1/2] Deploying CloudFormation stack..." -ForegroundColor Green
aws cloudformation deploy `
    --template-file $TemplateFile `
    --stack-name $StackName `
    --parameter-overrides file://$ParametersFile `
    --capabilities CAPABILITY_NAMED_IAM `
    --region $Region `
    --no-cli-pager

if ($LASTEXITCODE -ne 0) {
    Write-Host "Stack deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Stack deployment completed!" -ForegroundColor Green
Write-Host ""

# Show stack outputs
Write-Host "[2/2] Stack Outputs:" -ForegroundColor Green
aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --query 'Stacks[0].Outputs' `
    --output table

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
