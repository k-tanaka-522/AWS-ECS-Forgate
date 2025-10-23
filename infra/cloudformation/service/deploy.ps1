# ==============================================================================
# Service Account - CloudFormation Deployment Script (PowerShell)
# ==============================================================================

# Usage: .\deploy.ps1 -Environment dev [-Stack all]
# Example: .\deploy.ps1 -Environment dev
# Example: .\deploy.ps1 -Environment dev -Stack network

param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
    [ValidateSet("all", "network", "database", "compute", "monitoring")]
    [string]$Stack = "all"
)

$ErrorActionPreference = "Stop"
$ProjectName = "sample-app"
$AwsRegion = "ap-northeast-1"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Service Account Deployment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment"
Write-Host "Stack to deploy: $Stack"
Write-Host "Region: $AwsRegion"
Write-Host ""

# Check AWS CLI authentication
Write-Host "[0/4] Checking AWS authentication..." -ForegroundColor Yellow
$AwsAccountId = aws sts get-caller-identity --query Account --output text
Write-Host "  AWS Account ID: $AwsAccountId" -ForegroundColor Green
Write-Host ""

# Function to deploy a stack
function Deploy-Stack {
    param(
        [string]$StackType
    )

    $StackName = "$ProjectName-$Environment-service-$StackType"

    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Deploying $StackType stack..." -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    # Read parameters from JSON file
    $ParamsJson = Get-Content "parameters\$Environment.json" | ConvertFrom-Json
    $StackParams = $ParamsJson.$StackType

    if ($null -eq $StackParams) {
        Write-Host "  No parameters found for stack: $StackType" -ForegroundColor Red
        exit 1
    }

    # Convert parameters to CloudFormation format
    $ParamOverrides = @()
    foreach ($param in $StackParams) {
        $ParamOverrides += "$($param.ParameterKey)=$($param.ParameterValue)"
    }
    $ParamOverridesString = $ParamOverrides -join " "

    # Deploy stack
    aws cloudformation deploy `
        --stack-name $StackName `
        --template-file "stacks\$StackType\main.yaml" `
        --parameter-overrides $ParamOverridesString `
        --capabilities CAPABILITY_IAM `
        --region $AwsRegion `
        --no-fail-on-empty-changeset

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Stack deployment failed" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "$StackType stack deployment completed" -ForegroundColor Green
    Write-Host ""

    # Get stack outputs
    Write-Host "Stack outputs:"
    aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $AwsRegion `
        --query 'Stacks[0].Outputs' `
        --output table

    Write-Host ""
}

# Deploy stacks in order
if ($Stack -eq "all" -or $Stack -eq "network") {
    Write-Host "[1/4] Deploying Network stack..." -ForegroundColor Yellow
    Deploy-Stack -StackType "network"
}

if ($Stack -eq "all" -or $Stack -eq "database") {
    Write-Host "[2/4] Deploying Database stack..." -ForegroundColor Yellow
    Deploy-Stack -StackType "database"

    # Wait for RDS to be available
    Write-Host "Waiting for RDS instance to be available (this may take 15-20 minutes)..." -ForegroundColor Yellow
    $DbStackName = "$ProjectName-$Environment-service-database"

    aws cloudformation wait stack-create-complete `
        --stack-name $DbStackName `
        --region $AwsRegion 2>$null

    if ($LASTEXITCODE -ne 0) {
        aws cloudformation wait stack-update-complete `
            --stack-name $DbStackName `
            --region $AwsRegion 2>$null
    }

    Write-Host ""
    Write-Host "IMPORTANT: Initialize the database schema before deploying compute stack!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Run the following SQL on your RDS instance:"
    Write-Host ""
    Write-Host "CREATE TABLE users ("
    Write-Host "  id SERIAL PRIMARY KEY,"
    Write-Host "  username VARCHAR(100) NOT NULL UNIQUE,"
    Write-Host "  email VARCHAR(255) NOT NULL UNIQUE,"
    Write-Host "  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
    Write-Host "  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
    Write-Host ");"
    Write-Host ""
    Write-Host "CREATE TABLE stats ("
    Write-Host "  id SERIAL PRIMARY KEY,"
    Write-Host "  metric_name VARCHAR(100) NOT NULL,"
    Write-Host "  metric_value NUMERIC NOT NULL,"
    Write-Host "  recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
    Write-Host ");"
    Write-Host ""
    Write-Host "CREATE INDEX idx_stats_metric_name ON stats(metric_name);"
    Write-Host "CREATE INDEX idx_stats_recorded_at ON stats(recorded_at);"
    Write-Host "CREATE INDEX idx_users_created_at ON users(created_at);"
    Write-Host ""
    Read-Host "Press Enter after you have initialized the database"
}

if ($Stack -eq "all" -or $Stack -eq "compute") {
    Write-Host "[3/4] Deploying Compute stack..." -ForegroundColor Yellow

    # Check if Docker images are available in ECR
    Write-Host "Make sure Docker images are pushed to ECR before deploying compute stack!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Required ECR repositories:"
    Write-Host "  - sample-app/public:latest"
    Write-Host "  - sample-app/admin:latest"
    Write-Host "  - sample-app/batch:latest"
    Write-Host ""
    $Response = Read-Host "Have you pushed all Docker images to ECR? (y/n)"

    if ($Response -notmatch "^[Yy]$") {
        Write-Host "Skipping compute stack deployment. Please push Docker images first." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To push images, run:"
        Write-Host "  cd ..\..\..\app"
        Write-Host "  .\build-and-push.ps1 -Environment $Environment"
        Write-Host ""
        exit 0
    }

    Deploy-Stack -StackType "compute"
}

if ($Stack -eq "all" -or $Stack -eq "monitoring") {
    Write-Host "[4/4] Deploying Monitoring stack..." -ForegroundColor Yellow
    Deploy-Stack -StackType "monitoring"
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Service Account deployment completed!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Get ALB DNS name if compute stack was deployed
if ($Stack -eq "all" -or $Stack -eq "compute") {
    $ComputeStackName = "$ProjectName-$Environment-service-compute"
    $AlbDns = aws cloudformation describe-stacks `
        --stack-name $ComputeStackName `
        --region $AwsRegion `
        --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' `
        --output text 2>$null

    if ($AlbDns) {
        Write-Host "Application URLs:"
        Write-Host "  Public Web: http://$AlbDns"
        Write-Host "  Health Check: http://$AlbDns/health"
        Write-Host ""
    }
}

Write-Host "Next steps:"
Write-Host "1. Test application endpoints"
Write-Host "2. Check CloudWatch Dashboard"
Write-Host "3. Review CloudWatch Alarms"
Write-Host ""
