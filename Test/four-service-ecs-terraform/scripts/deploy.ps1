#Requires -Version 5.1
<#
.SYNOPSIS
  Safely deploys the four-service ECS test architecture with Terraform.
.DESCRIPTION
  Checks prerequisites, runs fmt/validate, produces a plan, and only applies
  after an explicit interactive confirmation. Stops on the first failure.
.PARAMETER SkipPlan
  Only run checks + init + validate, skip plan/apply.
#>
param(
    [switch]$SkipPlan
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

function Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

function Invoke-Terraform {
    # Runs terraform, streams output, and fails hard on non-zero exit.
    param([Parameter(ValueFromRemainingArguments)][string[]]$Args)
    terraform @Args
    if ($LASTEXITCODE -ne 0) { throw "terraform $($Args -join ' ') failed with exit code $LASTEXITCODE" }
}

Step "Checking tools"
foreach ($cmd in 'terraform', 'aws') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "$cmd is not installed or not on PATH. See README section 'Prerequisites'."
    }
}
terraform --version
aws --version

Step "Checking AWS identity"
aws sts get-caller-identity --output table
if ($LASTEXITCODE -ne 0) {
    throw "AWS credentials are not configured. Run 'aws configure' or set env vars first (see README)."
}

Step "Checking terraform.tfvars"
if (-not (Test-Path .\terraform.tfvars)) {
    Copy-Item .\terraform.tfvars.example .\terraform.tfvars
    Write-Warning "terraform.tfvars did not exist - created from example."
    Write-Warning "EDIT IT NOW: set allowed_admin_cidr to YOUR public IP in /32 form, then re-run."
    exit 1
}

if (Select-String -Path .\terraform.tfvars -Pattern '203\.0\.113\.10/32' -Quiet) {
    Write-Warning "allowed_admin_cidr is still the EXAMPLE placeholder 203.0.113.10/32."
    Write-Warning "Nothing you own will be able to reach the ALB. Set YOUR public IP:"
    Write-Warning '  (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim() + "/32"'
}

if (-not $env:TF_VAR_db_password -and
    -not (Select-String -Path .\terraform.tfvars -Pattern '^\s*db_password\s*=' -Quiet)) {
    throw "No db_password found. Set it with: `$env:TF_VAR_db_password = 'your-strong-password'"
}

Step "terraform fmt -recursive"
Invoke-Terraform fmt -recursive

Step "terraform init"
Invoke-Terraform init -input=false

Step "terraform validate"
Invoke-Terraform validate

if ($SkipPlan) {
    Write-Host "`nSkipPlan set - stopping after validate." -ForegroundColor Green
    exit 0
}

Step "terraform plan (saved to tfplan)"
Invoke-Terraform plan -out=tfplan -input=false

Write-Host "`nReview the plan above." -ForegroundColor Yellow
$answer = Read-Host "Type 'yes' to apply this plan and create real (billable) AWS resources"
if ($answer -ne 'yes') {
    Write-Host "Aborted - nothing was applied. tfplan file kept for reference."
    exit 0
}

Step "terraform apply"
Invoke-Terraform apply -input=false tfplan
Remove-Item .\tfplan -Force -ErrorAction SilentlyContinue

Step "Outputs"
Invoke-Terraform output
Write-Host "`nDeployment finished. Run scripts\test-services.ps1 to test the endpoints." -ForegroundColor Green
