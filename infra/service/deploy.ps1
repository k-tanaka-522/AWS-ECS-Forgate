# CareApp Service Infrastructure Deployment Script
# Usage: .\deploy.ps1 [-DryRun] [-SkipMonitoring]

param(
    [switch]$DryRun = $false,
    [switch]$SkipMonitoring = $false
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$REGION = "ap-northeast-1"
$PROFILE = "default"

# Stack names
$NETWORK_STACK = "CareApp-POC-Network"
$DATABASE_STACK = "CareApp-POC-Database"
$COMPUTE_STACK = "CareApp-POC-Compute"
$MONITORING_STACK = "CareApp-POC-Monitoring"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CareApp Service Infrastructure Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN MODE] Validating templates only" -ForegroundColor Yellow
    Write-Host ""
}

# Function to validate template
function Validate-Template {
    param($TemplatePath, $StackName)
    Write-Host "Validating: $StackName" -ForegroundColor Yellow
    aws cloudformation validate-template --template-body file://$TemplatePath --region $REGION --no-cli-pager
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Template validation failed: $StackName" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Template valid: $StackName" -ForegroundColor Green
    Write-Host ""
}

# Function to deploy stack
function Deploy-Stack {
    param($StackName, $TemplatePath, $ParametersPath)
    if ($DryRun) {
        Write-Host "[DRY RUN] Would deploy: $StackName" -ForegroundColor Cyan
        return
    }
    Write-Host "Deploying: $StackName" -ForegroundColor Cyan
    aws cloudformation deploy --template-file $TemplatePath --stack-name $StackName --parameter-overrides file://$ParametersPath --capabilities CAPABILITY_NAMED_IAM --region $REGION --no-cli-pager
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to deploy: $StackName" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Successfully deployed: $StackName" -ForegroundColor Green
    Write-Host ""
}

# Step 1: Validate all templates
Write-Host "Step 1: Validating Templates" -ForegroundColor Cyan
Validate-Template "01-network.yaml" $NETWORK_STACK
Validate-Template "02-database.yaml" $DATABASE_STACK
Validate-Template "03-compute.yaml" $COMPUTE_STACK
Validate-Template "04-monitoring.yaml" $MONITORING_STACK

if ($DryRun) {
    Write-Host "DRY RUN COMPLETED - All templates valid" -ForegroundColor Green
    exit 0
}

# Step 2-5: Deploy stacks
Write-Host "Step 2: Deploying Network Stack" -ForegroundColor Cyan
Deploy-Stack $NETWORK_STACK "01-network.yaml" "parameters-network-poc.json"

Write-Host "Step 3: Deploying Database Stack" -ForegroundColor Cyan
Deploy-Stack $DATABASE_STACK "02-database.yaml" "parameters-database-poc.json"

Write-Host "Step 4: Deploying Compute Stack" -ForegroundColor Cyan
Deploy-Stack $COMPUTE_STACK "03-compute.yaml" "parameters-compute-poc.json"

if (-not $SkipMonitoring) {
    Write-Host "Step 5: Deploying Monitoring Stack" -ForegroundColor Cyan
    Deploy-Stack $MONITORING_STACK "04-monitoring.yaml" "parameters-monitoring-poc.json"
}

# Get outputs
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$albDns = aws cloudformation describe-stacks --stack-name $COMPUTE_STACK --query "Stacks[0].Outputs[?OutputKey=='ALBDNSName'].OutputValue" --output text --region $REGION --no-cli-pager
Write-Host "Access URL: http://$albDns" -ForegroundColor Cyan
