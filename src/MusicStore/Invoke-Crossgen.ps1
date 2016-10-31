# Runs crossgen.exe on a published application.
#
# Will look for crossgen.exe in pwd/.crossgen

param(
    [string]$crossgen_path = $null, 
    [string]$runtime = "win7-x64",
    [string]$sdk_version = "1.1.0-preview1-001100-00",
    [string]$sdk_path = $null)

$ErrorActionPreference = "Stop"

$lib_paths = @()

$excludes = @("MusicStore.dll", "Microsoft.AspNetCore.Diagnostics.dll", "Microsoft.AspNetCore.Hosting.Abstractions.dll", "Microsoft.AspNetCore.Diagnostics.EntityFrameworkCore.dll", "Microsoft.AspNetCore.Hosting.dll", "Microsoft.AspNetCore.WebUtilities.dll", "Microsoft.DiaSymReader.Native.amd64.dll", "Microsoft.DiaSymReader.Native.x86.dll")

$dotnet_dir = (Get-Item (Get-Command dotnet).Path).Directory
$config = (Get-Content MusicStore.runtimeconfig.json) | ConvertFrom-Json
$shared_fx_version = $config.runtimeOptions.framework.version
$shared_fx_path = [io.path]::combine($dotnet_dir, "shared\Microsoft.NETCore.App", $shared_fx_version)

if (-not $crossgen_path)
{
    $crossgen_path = ".\.crossgen\crossgen.exe"
}

if (Test-Path $crossgen_path -PathType Container)
{
    # $crossgen_path is a directory
    $crossgen_path = Join-Path $crossgen_path "crossgen.exe"
}

if (-not (Test-Path $crossgen_path))
{
    throw "Could not find crossgen at" + $crossgen_path
}

if (-not (Test-Path $shared_fx_path))
{
    throw "Could not find shared framework at " + $shared_fx_path
}

$shared_fx_dir = get-item $shared_fx_path
$crossgen_exe = get-item $crossgen_path

Write-Host -ForegroundColor Green "Using crossgen.exe at $crossgen_path and shared framework at $shared_fx_dir"

# These are the folders that have bin-deployed assemblies
$app_paths = @((Get-Item ".").FullName)

if ($runtime -eq "win7-x64")
{
    $app_paths += (Get-Item ".\runtimes\win\lib\netstandard1.3").FullName
}
else
{
    throw "This script doesn't know what paths to use for runtime $runtime"
}

function join([string] $p, $collection)
{
    for ($i = 0; $i -lt $collection.Length; $i++)
    { 
        $p += """" + $collection[$i] + """"

        if ($i -lt ($collection.Length - 1))
        {
            $p += ";"
        }
    }
    
    return $p
}

function Invoke-Crossgen-Core($crossgen_exe, $item, $shared_fx_dir, $app_paths)
{
    $item_dir = $item.DirectoryName
    $out = Join-Path ($item_dir) ([io.path]::ChangeExtension($item.Name, ".ni.dll"))

    $args = @()
    $args += "/Platform_Assemblies_Paths"
    $args += """$shared_fx_dir"""

    $app_path_arg = join "" ($app_paths + $lib_paths)
    
    $args += "/App_Paths"
    $args += $app_path_arg

    $args += "/out"
    $args += """$out"""
    $args += """" + $item.FullName + """"

    Write-Host "Running $crossgen_exe $args"

    & $crossgen_exe $args
    
    if ($LastExitCode -ne 0)
    {
        throw "crossgen.exe failed."
    }

    Move-Item $out $item.FullName -Force

    Write-Host ""
}

foreach ($app_path in $app_paths)
{
    foreach ($file in Get-ChildItem $app_path -Filter *.dll | where { -not ($excludes.Contains($_.Name)) })
    {
        Invoke-Crossgen-Core $crossgen_path $file $shared_fx_dir $app_paths
    }
}