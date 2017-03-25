# Gets crossgen.exe
#
# Downloads NuGet.exe
# Installs crossgen.exe and clrjit.dll using NuGet
# Copies the files to $path

param([string]$path = ".")

$ErrorActionPreference = "Stop"

Write-Host -ForegroundColor Green "Installing crossgen.exe to $path"

if (-not (Test-Path $path))
{
    New-Item -Path $path -ItemType Directory -Force
}

function Get-CoreCLRVersion()
{
    if (-not (Test-Path $PSScriptRoot\obj\project.assets.json))
    {
        Write-Error "project.assets.json is missing. do a dotnet restore."
        exit
    }
    
    # ConvertFrom-Json can't be used here as it has an arbitrary size limit.
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
    $serializer = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 
    $serializer.MaxJsonLength  = 67108864
    
    $json = $serializer.DeserializeObject((Get-Content $PSScriptRoot\obj\project.assets.json -Raw))

    foreach ($name in $json["libraries"].Keys)
    {
        if ($name.StartsWith("Microsoft.NETCore.Platforms/"))
        {
            $version = $name.SubString("Microsoft.NETCore.Platforms/".Length)
            break
        }
    }
    
    return $version
}

$version = Get-CoreCLRVersion
Write-Host -ForegroundColor Green "autodetected CoreCLR version $version"

$platform = "win7-x64"

$coreclrpackage = "runtime.$platform.Microsoft.NETCore.Runtime.CoreCLR"
$coreclrversion = $version

$clrjitpackage = "runtime.$platform.Microsoft.NETCore.Jit"
$clrjitversion = $version

Write-Host -ForegroundColor Green "Getting NuGet.exe"

$nugeturl = "https://dist.nuget.org/win-x86-commandline/v3.4.4/NuGet.exe"
$nugetfeed = "https://dotnet.myget.org/F/dotnet-core/api/v3/index.json"
$nugetexepath = "$path\NuGet.exe"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($nugeturl, $nugetexepath)


Write-Host -ForegroundColor Green "Getting $coreclrpackage $coreclrversion"

& "$nugetexepath" "install", "$coreclrpackage", "-Source", "$nugetfeed", "-Version", "$coreclrversion", "-OutputDirectory", "$path"
if ($LastExitCode -ne 0) {
    throw "NuGet install of $coreclrpackage failed."
}

Copy-Item "$path\$coreclrpackage.$coreclrversion\tools\crossgen.exe" "$path\crossgen.exe" -Force
Remove-Item "$path\$coreclrpackage.$coreclrversion\" -recurse


Write-Host -ForegroundColor Green "Getting $clrjitpackage $clrjitversion"

& "$nugetexepath" "install", "$clrjitpackage", "-Source", "$nugetfeed", "-Version", "$clrjitversion", "-OutputDirectory", "$path"
if ($LastExitCode -ne 0) {
    throw "NuGet install of $clrjitpackage failed."
}

Copy-Item "$path\$clrjitpackage.$clrjitversion\runtimes\$platform\native\clrjit.dll" "$path\clrjit.dll" -Force
Remove-Item "$path\$clrjitpackage.$clrjitversion\" -recurse

Remove-Item "$path\NuGet.exe"

Write-Host -ForegroundColor Green "Success"