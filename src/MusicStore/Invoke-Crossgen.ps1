# Runs crossgen.exe on a published application.
#
# Will look for crossgen.exe in pwd/.crossgen

param(
    [string]$crossgen_path = $null, 
    [string]$runtime = "win7-x64",
    [string]$sdk_version = "1.1.0-preview1-001100-00")

$ErrorActionPreference = "Stop"

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

$sdk_path = "C:\Program Files\dotnet\shared\Microsoft.NETCore.App\$sdk_version"
if (-not (Test-Path $sdk_path))
{
    throw "Could not find sdk at " + $sdk_path
}

$sdk_dir = get-item $sdk_path
$crossgen_exe = get-item $crossgen_path

Write-Host -ForegroundColor Green "Using crossgen.exe at $crossgen_path and shared framework at $sdk_dir"

if ($runtime -eq "win7-x64")
{
    $app_paths = @((Get-Item ".").FullName, (Get-Item ".\runtimes\win\lib\netstandard1.3").FullName)
}
else
{
    throw "This script doesn't know what paths to use for runtime $runtime"
}

function Invoke-Crossgen-Core($crossgen_exe, $item, $sdk_dir, $app_paths)
{
    $item_dir = $item.DirectoryName
    $out = Join-Path ($item_dir) ([io.path]::ChangeExtension($item.Name, ".ni.dll"))

    $args = @()
    $args += "/Platform_Assemblies_Paths"
    $args += """$item_dir"";" +  """$sdk_dir"""

    $app_path_arg = ""
    for ($i = 0; $i -lt $app_paths.Length; $i++)
    { 
        $app_path_arg += """" + $app_paths[$i] + """"

        if ($i -lt ($app_paths.Length - 1))
        {
            $app_path_arg += ";"
        }
    }

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
    foreach ($file in Get-ChildItem $app_path -Filter *.dll | where { -not ($_.Name -eq "MusicStore.dll") })
    {
        Invoke-Crossgen-Core $crossgen_path $file $sdk_dir $app_paths
    }
}

