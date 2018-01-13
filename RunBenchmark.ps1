[cmdletbinding()]
param(
    [string] $AspNetVersion = "<auto>",
    [string] $FrameworkVersion = "<auto>",
    [string] $TargetFrameworkMoniker = "<auto>",
    [string] $FrameworkSdkVersion = "<auto>",
    [string] $Architecture = "x64",
    [string] $Rid = "win7-x64",
    [switch] $PrecompiledViews,
    [string] $PrivateCoreCLRBinDirPath,
    [switch] $SetupOnly,
    [switch] $WhatIf)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ScriptDir = $(Split-Path $MyInvocation.MyCommand.Path -Parent)
. "$ScriptDir\AspNet-Shared.ps1"

function Run-Cmd
{
    Param($Cmd)
    if($WhatIf -ne $true)
    {
        Write-Host -ForegroundColor Green $Cmd
        Invoke-Expression $Cmd
        Write-Host ""
    }
    else
    {
        Write-Host $Cmd
    }
}

Write-Host -ForegroundColor Green " ***** Step 1 - Set Versions *******"
$cmd = "cd $ScriptDir"
Run-Cmd $cmd

$cmd = ".\AspNet-SetVersions.ps1"
if($AspNetVersion -ne "<auto>")
{
    $cmd += " -AspNetVersion $AspNetVersion"
}
if($FrameworkVersion -ne "<auto>")
{
    $cmd += " -FrameworkVersion $FrameworkVersion"
}
if($TargetFrameworkMoniker -ne "<auto>")
{
    $cmd += " -TargetFrameworkMoniker $TargetFrameworkMoniker"
}
if($FrameworkSdkVersion -ne "<auto>")
{
    $cmd += " -FrameworkSdkVersion $FrameworkSdkVersion"
}
Run-Cmd $cmd
$vars = Calculate-Versions -AspNetVersion $AspNetVersion -FrameworkVersion $FrameworkVersion -TargetFrameworkMoniker $TargetFrameworkMoniker -FrameworkSdkVersion $FrameworkSdkVersion
Write-Host ""


Write-Host -ForegroundColor Green " ***** Step 2 - Setup Dotnet Runtime and SDK *******"
$cmd = ".\DotNet-Install.ps1 -SharedRuntime -InstallDir .dotnet -Channel master -Version " + $vars.Item("JITBENCH_FRAMEWORK_VERSION") + " -Architecture " + $Architecture
Run-Cmd $cmd

$cmd = ".\DotNet-Install.ps1 -InstallDir .dotnet -Channel master -Version " + $vars.Item("JITBENCH_FRAMEWORK_SDK_VERSION") + " -Architecture " + $Architecture
Run-Cmd $cmd

if($PrivateCoreCLRBinDirPath -ne "")
{
    $cmd = ".\AspNet-CopyPrivateCoreCLR.ps1 -BinDirPath $PrivateCoreCLRBinDirPath"
    Run-Cmd $cmd
}


Write-Host ""


Write-Host -ForegroundColor Green " ***** Step 3 - Generate Store *******"
#Workaround for SDK bug 1682
$cmd = "cp ./CreateStore/bugfix_sdk_1682/Microsoft.NET.ComposeStore.targets .dotnet/sdk/" + $vars.Item("JITBENCH_FRAMEWORK_SDK_VERSION") + "/Sdks/Microsoft.NET.Sdk/build/Microsoft.NET.ComposeStore.targets"
Run-Cmd $cmd

$cmd = ".\AspNet-GenerateStore.ps1 -InstallDir .store -Architecture $Architecture -Runtime $Rid"
Run-Cmd $cmd
$InstallDir = "$ScriptDir\.store"
$ManifestPath = [System.IO.Path]::Combine($InstallDir, $Architecture, $vars.Item("JITBENCH_TARGET_FRAMEWORK_MONIKER"), "artifact.xml")
Write-Host ""


Write-Host -ForegroundColor Green " ***** Step 4 - Restore MusicStore *******"
$cmd = "cd src\MusicStore"
Run-Cmd $cmd

$cmd = "dotnet restore"
Run-Cmd $cmd
Write-Host ""


Write-Host -ForegroundColor Green " ***** Step 5 - Publish MusicStore *******"

#Publish doesn't clean the results of old publishing before doing the new one. If you switch back and forth between
#precompiled views the stale precompilation results will still be there. I assume asp.net uses them if they are present
#though I haven't confirmed.
$pathToPublishDir = "bin\Release\" + $vars.Item("JITBENCH_TARGET_FRAMEWORK_MONIKER") + "\publish"
if(Test-Path $pathToPublishDir)
{
    $cmd = "rm -r " + $pathToPublishDir
    Run-Cmd $cmd
}

$cmd = "dotnet publish -c Release -f " + $vars.Item("JITBENCH_TARGET_FRAMEWORK_MONIKER") + " --manifest " + $ManifestPath
if($PrecompiledViews -eq $true)
{
    $cmd += " /p:MvcRazorCompileOnPublish=true"
}
else
{
    $cmd += " /p:MvcRazorCompileOnPublish=false"
}
Run-Cmd $cmd
Write-Host ""


Write-Host -ForegroundColor Green " ***** Step 6 - Run MusicStore *******"
if($SetupOnly -eq $true)
{
    Write-Host "-SetupOnly flag was passed, skipping execution"
}
else
{
    $cmd = "cd " + $pathToPublishDir
    Run-Cmd $cmd

    $cmd = "dotnet MusicStore.dll"
    Run-Cmd $cmd
}
Write-Host ""


. cd $ScriptDir
