#Requires -Version 5.1
<#
.SYNOPSIS
  Tests the public sample endpoints behind the ALB.
.DESCRIPTION
  Reads Terraform outputs, then calls / (frontend), /api/ and /bl/ and checks
  the response content. MQTT needs a WebSockets-capable client - see README.
#>
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$alb = terraform output -raw alb_dns_name
if (-not $alb) { throw "Could not read alb_dns_name output - run terraform apply first." }
$base = "http://$alb"

$passed = 0
$failed = 0

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Expected
    )
    try {
        $resp = Invoke-WebRequest -Uri $Url -TimeoutSec 15 -UseBasicParsing
        if ($resp.StatusCode -eq 200 -and $resp.Content -match $Expected) {
            Write-Host "[PASS] $Name ($Url) -> HTTP $($resp.StatusCode), matched '$Expected'" -ForegroundColor Green
            return $true
        }
        Write-Host "[FAIL] $Name ($Url) -> HTTP $($resp.StatusCode), body did not match '$Expected'" -ForegroundColor Red
        return $false
    } catch {
        Write-Host "[FAIL] $Name ($Url) -> $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "Testing endpoints on $base`n"

if (Test-Endpoint 'Frontend' "$base/" 'Welcome to nginx') { $passed++ } else { $failed++ }

# echo-server returns a JSON echo including its environment; SERVICE_NAME
# distinguishes api from bl.
if (Test-Endpoint 'API' "$base/api/" 'api') { $passed++ } else { $failed++ }
if (Test-Endpoint 'BL'  "$base/bl/"  'bl')  { $passed++ } else { $failed++ }

Write-Host "`n--- ALB target health ---"
try {
    $tgs = aws elbv2 describe-target-groups --output json | ConvertFrom-Json
    foreach ($tg in ($tgs.TargetGroups | Where-Object { $_.TargetGroupName -like 'four-svc*' })) {
        $health = aws elbv2 describe-target-health --target-group-arn $tg.TargetGroupArn --output json | ConvertFrom-Json
        foreach ($t in $health.TargetHealthDescriptions) {
            Write-Host ("{0}  {1}:{2}  {3}" -f $tg.TargetGroupName, $t.Target.Id, $t.Target.Port, $t.TargetHealth.State)
        }
    }
} catch {
    Write-Warning "Could not query target health (needs AWS creds + elbv2 perms): $($_.Exception.Message)"
}

Write-Host "`n--- ECS service status ---"
$cluster = terraform output -raw ecs_cluster_name
aws ecs list-services --cluster $cluster --output table

Write-Host "`nMQTT WebSockets endpoint (test with an MQTT.js client): ws://$alb/mqtt"
Write-Host "Native MQTT TCP/1883 is internal-only - see README 'Testing MQTT'."

Write-Host "`nResult: $passed passed, $failed failed."
if ($failed -gt 0) { exit 1 }
