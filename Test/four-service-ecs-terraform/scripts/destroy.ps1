#Requires -Version 5.1
<#
.SYNOPSIS
  Destroys ALL resources created by this project after explicit confirmation.
#>
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "This will DESTROY every resource created by this Terraform project" -ForegroundColor Yellow
Write-Host "(ECS cluster + services + tasks, EC2 hosts, ALB, NAT GW, RDS, S3 bucket, ECR repos + images)."
$answer = Read-Host "Type 'destroy' to continue"
if ($answer -ne 'destroy') {
    Write-Host "Aborted."
    exit 0
}

terraform destroy -auto-approve=false

Write-Host "`nNote: S3 bucket must be empty to delete (versioning is on - delete all versions first if destroy fails)." -ForegroundColor Yellow
