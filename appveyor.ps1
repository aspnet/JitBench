Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

Set-Location "$(Split-Path $script:MyInvocation.MyCommand.Path -Parent)"

Write-Host -ForegroundColor Green "Installing latest dotnet"
.\Dotnet-Install.ps1 -SharedRuntime -InstallDir .dotnet -Channel master -Architecture x64
.\Dotnet-Install.ps1 -InstallDir .dotnet -Channel master -Architecture x64

Write-Host -ForegroundColor Green "Creating package store"
.\AspNet-GenerateStore.ps1 -InstallDir .store -Architecture x64 -Runtime win7-x64

Write-Host -ForegroundColor Green "Restoring MusicStore"
Set-Location src\MusicStore
dotnet restore

Write-Host -ForegroundColor Green "Publishing MusicStore"
dotnet publish -c Release -f netcoreapp3.0 --manifest $env:JITBENCH_ASPNET_MANIFEST

Write-Host -ForegroundColor Green "Running MusicStore"
Set-Location bin\Release\netcoreapp3.0\publish
dotnet .\MusicStore.dll | Tee-Object -Variable output

if (-not ($output.Contains("ASP.NET loaded from store")))
{
    Write-Host -ForegroundColor Yellow "ASP.NET was not loaded from the store. This is a bug."
    throw "ASP.NET was not loaded from the store. This is a bug."
}

Write-Host -ForegroundColor Green "Success"
