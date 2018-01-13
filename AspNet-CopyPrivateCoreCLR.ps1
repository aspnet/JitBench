[cmdletbinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $BinDirPath,
    [string] $InstallDir = "<auto>")

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

if($InstallDir -eq "<auto>")
{
    $InstallDir = "$(Split-Path $MyInvocation.MyCommand.Path -Parent)\.dotnet"
}

$FramworkVersion = $env:JITBENCH_FRAMEWORK_VERSION
$TargetPath = "$InstallDir\shared\Microsoft.NETCore.App\$FramworkVersion"

function Copy-Private-File {
    Param($FileName)
    if(-not (Test-Path $TargetPath\$FileName.original))
    {
        Write-Host "copy $TargetPath\$FileName $TargetPath\$FileName.original"
        copy $TargetPath\$FileName $TargetPath\$FileName.original
    }
    Write-Host "copy $BinDirPath\$FileName $TargetPath\$FileName"
    copy $BinDirPath\$FileName $TargetPath\$FileName 
}

Copy-Private-File -FileName "coreclr.dll"
Copy-Private-File -FileName "clrjit.dll"
Copy-Private-File -FileName "mscordaccore.dll"
Copy-Private-File -FileName "mscordbi.dll"
Copy-Private-File -FileName "sos.dll"
Copy-Private-File -FileName "sos.NETCore.dll"
Copy-Private-File -FileName "clretwrc.dll"
Copy-Private-File -FileName "System.Private.CoreLib.dll"
Copy-Private-File -FileName "mscorrc.debug.dll"
Copy-Private-File -FileName "mscorrc.dll"