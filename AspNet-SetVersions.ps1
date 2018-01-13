[cmdletbinding()]
param(
    [string] $AspNetVersion = "<auto>",
    [string] $FrameworkVersion = "<auto>",
    [string] $TargetFrameworkMoniker = "<auto>",
    [string] $FrameworkSdkVersion = "<auto>",
    [switch] $Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

. "$(Split-Path $MyInvocation.MyCommand.Path -Parent)\AspNet-Shared.ps1"

$GlobalJsonPath = "$(Split-Path $MyInvocation.MyCommand.Path -Parent)\global.json"
$versions = Calculate-Versions -AspNetVersion $AspNetVersion -FrameworkVersion $FrameworkVersion -TargetFrameworkMoniker $TargetFrameworkMoniker -FrameworkSdkVersion $FrameworkSdkVersion

if($Clean -eq $true)
{
    foreach ($kvp in $versions.GetEnumerator())
    {
        Write-Host "Unsetting" $kvp.Key
        [System.Environment]::SetEnvironmentVariable($kvp.Key, "")
    }
    Write-Host "Deleting $GlobalJsonPath"
    if(Test-Path $GlobalJsonPath)
    {
        rm $GlobalJsonPath
    }
    return
}
Else
{
    foreach ($kvp in $versions.GetEnumerator())
    {
        Write-Host "Setting" $kvp.Key "to" $kvp.Value
        [System.Environment]::SetEnvironmentVariable($kvp.Key, $kvp.Value)
    }

    $FrameworkSdkVersion = $versions["JITBENCH_FRAMEWORK_SDK_VERSION"]
    Write-Host "Writing $GlobalJsonPath"
    $ConfigText = "{
    `"sdk`": 
    {
        `"version`": `"$FrameworkSdkVersion`"
    }
}"
    Out-File -FilePath $GlobalJsonPath -InputObject $ConfigText -Encoding ASCII
}
