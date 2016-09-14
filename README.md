
# JitBench

A repository for aspnet workloads suitable for testing the JIT.

Right now there is only one workload app here, at `src/MusicStore`

If you need to grant access to this repository for someone, please contact @eilon and @rynowak.

## Instructions for JIT testing:

**Step 0:** 

Download and install the dotnet CLI - https://www.microsoft.com/net/core

You should have `dotnet` on your path at this point. `dotnet --info` will print the version.

**Step 1:**

Clone the JitBench Repo

`git clone <JitBench repo>`

`cd JitBench`

**Step 2:**

Restore dependency packages 

`cd src\MusicStore`

`dotnet restore`

**Step 3:** 

Build/publish MusicStore

`dotnet publish -c Release -f netcoreapp10`

**Step 4:** 

Run crossgen on the publish output

`cd bin\Release\netcoreapp1.0\publish`

`.\Invoke-Crossgen.ps1` (powershell) or `powershell.exe .\Invoke-Crossgen.ps1` (cmd)

**Step 5:**

Run the app

`dotnet MusicStore.dll`

## Limitations

Our scripts **assume** the `win7-x64` platform, and CoreCLR version `1.0.2`. There's work underway to add `dotnet crossgen` as a full-fledged command in the CLI, so any work we do to enhance these scripts beyond what's necessary will be thrown away soon. We're building crossgen support into the product, and we'll want to dogfood that as soon as it's available.

## Powershell Errors

The scripts in this repo use powershell. If you're not a powershell user you will have to do some first-time setup on your machine.

Open powershell as admin and run `Set-ExecutionPolicy Unrestricted`, accept the prompt. By default powershell does not allow you to run scripts :-1:

## About MusicStore

MusicStore is a good sample of what a typical but *small* customer app would look like for a browser-based LOB app or public website. Notably it uses auth, logging, databases, ORM, caching, and dynamic view content. It's a good representation of the concerns a typical production app needs to address.

We've modified the app to start up the server and perform a single HTTP request before shutting down. This will print some timing information to the console. We feel like this is a good benchmark for both server cold start and local development cold start, and is suitable for iterating on quickly due to the ease of running.

## Explanation (what does this do?)

For an intro to dotnet CLI I suggest referring to their [docs](https://docs.microsoft.com/en-us/dotnet/articles/core/tools/index). We'll describe some of the steps here, but you should refer to the CLI docs as the primary source of information about CLI. If you have issues with the CLI please log them [here](https://github.com/dotnet/cli/issues).

### Step 3: `dotnet restore`

This downloads dependency packages from NuGet and installs them to `%USERPROFILE%\.nuget\packages`. The restore step changes *which* versions of dependencies are going to be used for compilation and runtime.

If you make any changes that affect dependencies, re-run `dotnet restore`.

### Step 4: `dotnet publish -c Release -f netcoreapp10`

This will build and publish the application in the `Release` configuration and targeting `netcoreapp10` as the target framework. `netcoreapp10` is what we refer to as the *shared framework*. At runtime, this will use the CoreCLR and CoreFx libraries from `C:\Program Files\dotnet\shared\Microsoft.NETCore.App\<version>`. The MusicStore app currently targets 1.0.0.

Additionally, this step will run a script to download the `crossgen.exe` and JIT binaries from NuGet. This is hooked up using a `prepublish` even in the `project.json` file. If you look at the publish output, you'll see a folder called `crossgen` which contains these binaries.

### Step 5: `Invoke-Crossgen.ps1`

This script does its best to run `crossgen.exe` on the binaries that will be used at runtime. This will eventually become part of the CLI. Doing this in a non-hardcoded way requires some pretty deep knowledge of the CLI/CoreHost, so we're making a lot of assumptions for now.

### Step 6: `dotnet MusicStore.dll`

Runs the app. We're using the *shared framework* so the actual `.exe` that runs here is `dotnet.exe`. The app itself is a `.dll` with a `Main(...)` method.