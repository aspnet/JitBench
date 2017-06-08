[cmdletbinding()]
param(
    [string] $InstallDir = "<auto>",
    [string] $AspNetVersion = "2.0.0-preview1-final",
    [string] $Framework = "netcoreapp2.0",
    [string] $FrameworkVersion = "<auto>",
    [string] $Architecture = "x64",
    [string] $Runtime = "win7-x64")

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

. "$(Split-Path $MyInvocation.MyCommand.Path -Parent)\AspNet-Shared.ps1"

# Create the installation directory and normalize to a fully qualified path
$InstallDir = New-InstallDirectory -Directory $InstallDir -Default ".store" -Clean -Create

# Blow away .temp - this will be used as a working directory by dotnet store, but it's
# bad at cleaning up after itself.
$temp = New-InstallDirectory -Directory "<auto>" -Default ".temp" -Clean

if ($FrameworkVersion -eq "<auto>")
{
    $FrameworkVersion = Get-FrameworkVersion
}

if ($AspNetVersion -eq "<auto>")
{
    $AspNetVersion = Get-LatestAspNetVersion -InstallDir "<auto>"
}

# These environment variables are used by CreateStore.proj
$env:JITBENCH_ASPNET_VERSION = $AspNetVersion
$env:JITBENCH_FRAMEWORK_VERSION = $FrameworkVersion

Write-Host -ForegroundColor Green "Running dotnet store"
& "dotnet" "store", "--manifest", ".\CreateStore.proj", "-f", "$Framework", "-r" "$Runtime" "--framework-version", "$FrameworkVersion", "-w", $temp, "-o", "$InstallDir", "--skip-symbols"
if ($LastExitCode -ne 0)
{
    throw "dotnet store failed."
}

$BinariesDirectory = $InstallDir
$Manifest = [System.IO.Path]::Combine($InstallDir, $Architecture, $Framework, 'artifact.xml')

Write-Host -ForegroundColor Green "Setting JITBENCH_ASPNET_VERSION to $AspNetVersion"
$env:JITBENCH_ASPNET_VERSION = $AspNetVersion

Write-Host -ForegroundColor Green "Setting JITBENCH_FRAMEWORK_VERSION to $FrameworkVersion"
$env:JITBENCH_FRAMEWORK_VERSION = $FrameworkVersion

Write-Host -ForegroundColor Green "Setting JITBENCH_ASPNET_MANIFEST to $Manifest"
$env:JITBENCH_ASPNET_MANIFEST = $Manifest

Write-Host -ForegroundColor Green "Setting DOTNET_SHARED_STORE to $BinariesDirectory"
$env:DOTNET_SHARED_STORE = $BinariesDirectory