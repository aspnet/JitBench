# Shared functions used by various scripts

# Creates a directory if it doesn't exist, returns the fully qualified path
function New-InstallDirectory(
    [string] $Directory,
    [string] $Default,
    [switch] $Clean = $false,
    [switch] $Create = $false)
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference="Stop"
    $ProgressPreference="SilentlyContinue"

    if (-not $Directory)
    {
        throw "Directory is required. Use <auto> to generate a default."
    }

    if (-not $Default)
    {
        throw "Default is required."
    }

    if ($Directory -eq "<auto>")
    {
        $Directory = Join-Path "$(Split-Path $script:MyInvocation.MyCommand.Path -Parent)" $Default
    }

    if ($Clean -and (Test-Path $Directory))
    {
        Remove-Item $Directory -Recurse -Force | Out-Null
    }

    if ($Create -and (-not (Test-Path $Directory)))
    {
        New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    }

    $Directory = [System.IO.Path]::Combine($pwd, $Directory)
    return $Directory
}

# Finds the latests installed shared framework
function Get-FrameworkVersion()
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference="Stop"
    $ProgressPreference="SilentlyContinue"

    Write-Host -ForegroundColor Green "Autodetecting .NET version"

    $dotnet = [System.IO.Path]::GetDirectoryName((Get-Command dotnet).Path)
    $shared_framework_root = [System.IO.Path]::Combine($dotnet, "shared\Microsoft.NETCore.App")

    $versions = @(Get-ChildItem $shared_framework_root | Sort-Object Name)

    foreach ($version in $versions)
    {
        Write-Host -ForegroundColor Green "Found version: $version"
    }
    
    Write-Host -ForegroundColor Green "Choosing version: $($versions[-1])"
    return $version[-1]
}

function Get-LatestAspNetVersion([string] $InstallDir)
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference="Stop"
    $ProgressPreference="SilentlyContinue"

    if (-not $InstallDir)
    {
        throw "InstallDir is required. Use <auto> to generate a default."
    }

    $InstallDir = New-InstallDirectory -Directory $InstallDir -Default ".packages" -Create

    $project = "$(Split-Path $script:MyInvocation.MyCommand.Path -Parent)\GetLatestAspNetVersion.proj"

    Write-Host -ForegroundColor Green "Autodetecting ASP.NET version"
    & "dotnet" "restore", "$project", "--packages", "$InstallDir" | Write-Host
    if ($LastExitCode -ne 0)
    {
        throw "dotnet restore failed."
    }

    $version = Get-LatestPackageVersion -PackagesRoot $InstallDir -Package "microsoft.aspnetcore.all"
    return $version
}

function Get-LatestPackageVersion(
    [string] $PackagesRoot,
    [string] $Package)
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference="Stop"
    $ProgressPreference="SilentlyContinue"

    if (-not $PackagesRoot)
    {
        throw "PackagesRoot is required."
    }

    if (-not $Package)
    {
        throw "Package is required."
    }

    $package_dir = Join-Path $PackagesRoot $Package
    if (-not (Test-Path $package_dir))
    {
        throw "$Package not found."
    }

    $versions = @(Get-ChildItem $package_dir | Sort-Object Name)

    foreach ($version in $versions)
    {
        Write-Host -ForegroundColor Green "Found version: $version"
    }
    
    Write-Host -ForegroundColor Green "Choosing version: $($versions[-1])"
    return $versions[-1]
}

# Downloads NuGet.exe
function Get-NuGet(
    [string] $InstallDir,
    [string] $Url = "https://dist.nuget.org/win-x86-commandline/v4.1.0/NuGet.exe")
{
    Set-StrictMode -Version Latest
    $ErrorActionPreference="Stop"
    $ProgressPreference="SilentlyContinue"

    if (-not $InstallDir)
    {
        throw "InstallDir is required."
    }

    if (-not (Test-Path $InstallDir))
    {
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    }

    $nuget = Join-Path $InstallDir "NuGet.exe"

    if (-not (Test-Path $nuget))
    {
        Write-Host -ForegroundColor Green "Getting NuGet from $Url"

        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($Url, $nuget)
    }
    
    return $nuget
}

