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

$platform = "win7-x64"

$coreclrpackage = "runtime.$platform.Microsoft.NETCore.Runtime.CoreCLR"
$coreclrversion = "1.1.0-preview1-24608-01"

$clrjitpackage = "runtime.$platform.Microsoft.NETCore.Jit"
$clrjitversion = "1.1.0-preview1-24608-01"


Write-Host -ForegroundColor Green "Getting NuGet.exe"

$nugeturl = "https://dist.nuget.org/win-x86-commandline/v3.4.4/NuGet.exe"
$nugetfeed = "https://api.nuget.org/v3/index.json"
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