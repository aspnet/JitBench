[cmdletbinding()]
param(
    [string] $InstallDir = "<auto>",
    [string] $Architecture = "x64",
    [string] $Framework = "netcoreapp2.0",
    [string] $FrameworkVersion = "<auto>",
    [string] $Platform = "win",
    [string] $Package = "Build.RuntimeStore",
    [string] $Feed = "https://dotnet.myget.org/F/aspnetcore-dev/api/v3/index.json")

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

. "$(Split-Path $MyInvocation.MyCommand.Path -Parent)\AspNet-Shared.ps1"

# Create the installation directory and normalize to a fully qualified path
$InstallDir = New-InstallDirectory -Directory $InstallDir -Default ".aspnet" -Clean -Create

function Get-AspNetPackage()
{
    $nuget = Get-NuGet $InstallDir
    
    Write-Host -ForegroundColor Green "Getting the ASP.NET package $Package. This may take a few minutes..."

    & "$nuget" "install", "$Package", "-Source", "$Feed", "-OutputDirectory", "$InstallDir", "-PreRelease" | Write-Host
    if ($LastExitCode -ne 0)
    {
        throw "NuGet install of $Package failed."
    }
    
    $versions = @(Get-ChildItem $InstallDir -Filter ($Package + '*') | Sort-Object Name | ForEach-Object { $_.Name.Substring($Package.Length + 1) })

    foreach ($version in $versions)
    {
        Write-Host -ForegroundColor Green "Found version: $version"
    }
    
    Write-Host -ForegroundColor Green "Choosing version: $($versions[-1])"
    return $versions[-1]
}

function Get-AspNetBinaries([string] $Version)
{
    $directory = Join-Path $InstallDir "$Package.$Version"
    if (-not (Test-Path $directory))
    {
        throw "Cannot find package at $directory"
    }
    
    $zip = Join-Path $directory "$Package.$Platform-$($Version.Substring($Version.IndexOf('-') + 1)).zip"
    if (-not (Test-Path $zip))
    {
        throw "Cannot find zip at $zip"
    }

    $destination = Join-Path $InstallDir "AspNet.$Platform-$Version"
    if (-not (Test-Path $destination))
    {
        Write-Host -ForegroundColor Green "Extracting $zip"
        
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
            
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $destination)
        
        Write-Host -ForegroundColor Green "Extracted to $destination"
    }
    
    return $destination
}

$PackageVersion = Get-AspNetPackage
$BinariesDirectory = Get-AspNetBinaries -Version $PackageVersion
$Manifest = [System.IO.Path]::Combine($BinariesDirectory, $Architecture, $Framework, 'artifact.xml')

if ($FrameworkVersion -eq "<auto>")
{
    $FrameworkVersion = Get-FrameworkVersion
}

Write-Host -ForegroundColor Green "Setting JITBENCH_ASPNET_VERSION to $PackageVersion"
$env:JITBENCH_ASPNET_VERSION = $PackageVersion

Write-Host -ForegroundColor Green "Setting JITBENCH_FRAMEWORK_VERSION to $FrameworkVersion"
$env:JITBENCH_FRAMEWORK_VERSION = $FrameworkVersion

Write-Host -ForegroundColor Green "Setting JITBENCH_ASPNET_MANIFEST to $Manifest"
$env:JITBENCH_ASPNET_MANIFEST = $Manifest

Write-Host -ForegroundColor Green "Setting DOTNET_SHARED_STORE to $BinariesDirectory"
$env:DOTNET_SHARED_STORE = $BinariesDirectory