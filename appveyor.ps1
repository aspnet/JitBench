Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

Set-Location "$(Split-Path $script:MyInvocation.MyCommand.Path -Parent)"

Write-Host -ForegroundColor Green "Demo branch not configured to CI anything"
Write-Host -ForegroundColor Green "Success"