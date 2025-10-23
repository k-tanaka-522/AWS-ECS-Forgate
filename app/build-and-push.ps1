# ==============================================================================
# Build and Push Docker Images to ECR (PowerShell)
# ==============================================================================

# Usage: .\build-and-push.ps1 -Environment dev [-Service all]
# Example: .\build-and-push.ps1 -Environment dev
# Example: .\build-and-push.ps1 -Environment dev -Service public

param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
    [ValidateSet("all", "public", "admin", "batch")]
    [string]$Service = "all"
)

$ErrorActionPreference = "Stop"
$AwsRegion = "ap-northeast-1"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Docker Build and Push to ECR" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment"
Write-Host "Service: $Service"
Write-Host "Region: $AwsRegion"
Write-Host ""

# Check AWS CLI authentication
Write-Host "[1/4] Checking AWS authentication..." -ForegroundColor Yellow
$AwsAccountId = aws sts get-caller-identity --query Account --output text
Write-Host "  AWS Account ID: $AwsAccountId" -ForegroundColor Green
Write-Host ""

# Login to ECR
Write-Host "[2/4] Logging in to Amazon ECR..." -ForegroundColor Yellow
$LoginPassword = aws ecr get-login-password --region $AwsRegion
$LoginPassword | docker login --username AWS --password-stdin "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ECR login failed" -ForegroundColor Red
    exit 1
}

Write-Host "  ECR login successful" -ForegroundColor Green
Write-Host ""

# Function to build and push a service
function Build-And-Push {
    param(
        [string]$ServiceName
    )

    $Dockerfile = "$ServiceName\Dockerfile"
    $EcrRepo = "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com/sample-app/$ServiceName"
    $ImageTag = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { "latest" }

    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Building and pushing: $ServiceName" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    # Check if Dockerfile exists
    if (-not (Test-Path $Dockerfile)) {
        Write-Host "  Dockerfile not found: $Dockerfile" -ForegroundColor Red
        exit 1
    }

    # Build Docker image
    Write-Host "  Building Docker image..." -ForegroundColor Yellow
    docker build `
        -t "sample-app-${ServiceName}:${ImageTag}" `
        -t "sample-app-${ServiceName}:latest" `
        -f $Dockerfile `
        .

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Build failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "  Build completed" -ForegroundColor Green
    Write-Host ""

    # Tag for ECR
    Write-Host "  Tagging image for ECR..." -ForegroundColor Yellow
    docker tag "sample-app-${ServiceName}:${ImageTag}" "${EcrRepo}:${ImageTag}"
    docker tag "sample-app-${ServiceName}:latest" "${EcrRepo}:latest"

    Write-Host "  Tagging completed" -ForegroundColor Green
    Write-Host ""

    # Push to ECR
    Write-Host "  Pushing to ECR..." -ForegroundColor Yellow
    docker push "${EcrRepo}:${ImageTag}"
    docker push "${EcrRepo}:latest"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Push failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "  Push completed: ${EcrRepo}:${ImageTag}" -ForegroundColor Green
    Write-Host "  Push completed: ${EcrRepo}:latest" -ForegroundColor Green
    Write-Host ""
}

# Build and push services
Write-Host "[3/4] Building and pushing Docker images..." -ForegroundColor Yellow
Write-Host ""

if ($Service -eq "all" -or $Service -eq "public") {
    Build-And-Push -ServiceName "public"
}

if ($Service -eq "all" -or $Service -eq "admin") {
    Build-And-Push -ServiceName "admin"
}

if ($Service -eq "all" -or $Service -eq "batch") {
    Build-And-Push -ServiceName "batch"
}

# List all images in ECR
Write-Host "[4/4] Listing ECR images..." -ForegroundColor Yellow
Write-Host ""

if ($Service -eq "all" -or $Service -eq "public") {
    Write-Host "Public Web Service images:"
    aws ecr describe-images `
        --repository-name sample-app/public `
        --region $AwsRegion `
        --query 'imageDetails[*].[imageTags[0],imagePushedAt]' `
        --output table 2>$null
    Write-Host ""
}

if ($Service -eq "all" -or $Service -eq "admin") {
    Write-Host "Admin Service images:"
    aws ecr describe-images `
        --repository-name sample-app/admin `
        --region $AwsRegion `
        --query 'imageDetails[*].[imageTags[0],imagePushedAt]' `
        --output table 2>$null
    Write-Host ""
}

if ($Service -eq "all" -or $Service -eq "batch") {
    Write-Host "Batch Service images:"
    aws ecr describe-images `
        --repository-name sample-app/batch `
        --region $AwsRegion `
        --query 'imageDetails[*].[imageTags[0],imagePushedAt]' `
        --output table 2>$null
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Build and push completed!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Deploy or update ECS services to use the new images"
Write-Host "2. Run: cd ..\infra\cloudformation\service; .\deploy.ps1 -Environment $Environment -Stack compute"
Write-Host ""
