
# JitBench

A repository for aspnet workloads suitable for testing the JIT.

Right now there is only one workload app here, at `src/MusicStore`

## Important

This branch is for testing of the **latest builds** of ASP.NET Core and .NET Core. This is somewhat unstable and may break from time to time. Use one of the other branches for a stable experience.

The instructions here assume that you need to test latest builds and may need to substitute private builds of CoreCLR to do so. Everything here is hardcoded to win7-x64.

## Instructions for JIT testing:

### Step 0:

Clone the JitBench Repo

`git clone <JitBench repo>`

`cd JitBench`

### Step 1:

Get the newest dotnet Shared Runtime as 'repo local' 

**Windows**

`.\Dotnet-Install.ps1 -SharedRuntime -InstallDir .dotnet -Channel master -Architecture x64`

`.\Dotnet-Install.ps1 -InstallDir .dotnet -Channel master -Architecture x64`

**OSX**

`./dotnet-install.sh -sharedruntime -runtimeid osx.10.12-x64 -installdir .dotnet -channel master -architecture x64` 

`source ./dotnet-install.sh -installdir .dotnet -channel master -architecture x64`

**Linux**

`./dotnet-install.sh -sharedruntime -runtimeid linux-x64 -installdir .dotnet -channel master -architecture x64` 

`source ./dotnet-install.sh -installdir .dotnet -channel master -architecture x64`


You need to run **both** of these commands in this particular order. This will grab the latest shared runtime and SDK and copy them to `<JitBench>\.dotnet`. Note you need to `source` the second script so that it can update your `$PATH`.

You should also have this version of `dotnet` on your path at this point. `dotnet --info` will print the version and it should match what you see in the output of the above commands.

### Step 2:

Modify the shared framework (if necessary).

If you need to use a private build of the JIT or other CoreCLR components, now is a good time to update the shared framework with your bits. Copy any binaries you need to use into the shared framework in `<JitBench>\.dotnet\shared\Microsoft.NETCore.App\<version>`. The version should match the version that downloaded in step 1.

### Step 3a:

Generate Crossgen/R2R binaries locally

**Windows**

`.\AspNet-GenerateStore.ps1 -InstallDir .store -Architecture x64 -Runtime win7-x64`

**OSX**

`source ./aspnet-generatestore.sh -i .store --arch x64 -r osx.10.12-x64`

This will generate new crossgen/R2R images locally using the same shared framework version

This step will also set some environment variables that affect the behavior of the subsequent commands. You'll see in the console output some of the information about the environment variables that were set.

This step assumes the latest version of ASP.NET and the shared framework. Use the `-AspNetVersion` and `-FrameworkVersion` parameters to override these.

### Step 3b: (Alternative)

Install the ASP.NET binaries

`.\AspNet-Install.ps1 -InstallDir .aspnet -Architecture x64`

This will retrieve a zip of pre-optimized ASP.NET binaries and extract them for use with the MusicStore application. This may take a few minutes.

This step will also set some environment variables that affect the behavior of the subsequent commands. You'll see in the console output some of the information about the environment variables that were set.

This step assumes the latest version of ASP.NET and the shared framework. Use the `-AspNetVersion` and `-FrameworkVersion` parameters to override these.

### Step 4:

Restore dependency packages

`cd src\MusicStore`

`dotnet restore`

You should see that all of the ASP.NET dependencies that get restored during this stage have the same version number as the output of step 3. 

### Step 5: 

Build/publish MusicStore

**Windows**

`dotnet publish -c Release -f netcoreapp2.0 --manifest $env:JITBENCH_ASPNET_MANIFEST` (powershell)
OR
`dotnet publish -c Release -f netcoreapp2.0 --manifest %JITBENCH_ASPNET_MANIFEST%` (cmd)

**OSX**

`dotnet publish -c Release -f netcoreapp2.0 --manifest $JITBENCH_ASPNET_MANIFEST`

This will publish the app to `bin\Release\netcoreapp2.0\publish`. You should only see the `MusicStore.dll` and a few other project related assest here if you passed the `--manifest` argument.

### Step 6:

Run the app

`cd bin\Release\netcoreapp2.0\publish`

`dotnet MusicStore.dll`

You should see console output like:
```
Server started in 1723ms

Starting request to http://localhost:5000
Response: OK
Request took 3014ms

Cold start time (server start + first request time): 4737ms


Running 100 requests
Steadystate min response time: 4ms
Steadystate max response time: 15ms
Steadystate average response time: 4ms
```

## FAQ

### What about x86?

You can do x86! Just substitute `x86` for `x64` in step 1 and step 3.

You need to do a `git clean -xdf` and start over at step 1 if you are switching architectures.

### Things are failing what do I do?

Do a `git clean -xdf` and get back to a clean state. Then start over at step 1. 

If you still have a problem, open an issue on this repo. Opening an issue here is the best way to get a quick response.

### Powershell Errors

The scripts in this repo use powershell. If you're not a powershell user you will have to do some first-time setup on your machine.

Open powershell as admin and run `Set-ExecutionPolicy Unrestricted`, accept the prompt. By default powershell does not allow you to run scripts :-1:

### What is Microsoft.AspNetCore.All

This is a meta-package that contains all of the ASP.NET libraries. This is the easiest way to just pull in the whole platform as a reference. We expect that this will be the common way to build applications in ASP.NET going forward.

### What is Build.RuntimeStore?

This is a big zip file of pre-optimized ASP.NET libraries. This is the best way for us to test the JIT because this is very close to what customers will use for local development or on a shared host like Azure in 2.0.0. Think of it like an add-on to the shared framework. Read the Explanation section below for a description of how this is wired up.

### About MusicStore

MusicStore is a good sample of what a typical but *small* customer app would look like for a browser-based LOB app or public website. Notably it uses auth, logging, databases, ORM, caching, and dynamic view content. It's a good representation of the concerns a typical production app needs to address.

We've modified the app to start up the server and perform a single HTTP request with timing information. Then it will perform 100 requests (single threaded) and print some statistics. We feel like this is a good benchmark for both server cold start and local development cold start, and is suitable for iterating on quickly due to the ease of running.

## Explanation (what does this do?)

For an intro to dotnet CLI I suggest referring to their [docs](https://docs.microsoft.com/en-us/dotnet/articles/core/tools/index). We'll describe some of the steps here, but you should refer to the CLI docs as the primary source of information about CLI. If you have issues with the CLI please log them [here](https://github.com/dotnet/cli/issues).

### Step 3a: `.\AspNet-GenerateStore.ps1 -InstallDir .store -Architecture x64 -Runtime win7-x64`

This uses `dotnet store` to generate an optimized package store under `.store`. If you want to get an updated set of ASP.NET libraries, start at this step.

-------------------

This command will also output some messages about environment variables that it sets. Here's a quick guide:

```
Setting JITBENCH_ASPNET_VERSION to 2.0.0-preview1-24493
```

This means that the latest build of ASP.NET available at this time is `2.0.0-preview1-24493`. This environment variable will 'pin' the versions of the ASP.NET dependencies in the `.csproj` to match exactly the binaries that we just pulled down. There's no magic here, look at the `.csproj` to see how this works.

```
Setting JITBENCH_FRAMEWORK_VERSION to 2.0.0-preview2-002062-00
```

This means that the version of the shared framework that was selected was `2.0.0-preview2-002062-00`. This environment variable will 'pin' the versions of the shared framework in the `.csproj` to match exactly the binaries that we just pulled down. There's no magic here, look at the `.csproj` to see how this works.

```
Setting JITBENCH_ASPNET_MANIFEST to D:\k\JitBench\.aspnet\AspNet.win-2.0.0-preview1-24493\x86\netcoreapp2.0\artifact.xml
```

This file `artifact.xml` is a listing of all of the packages that are included in the payload. If you look in this directory, you'll find a hierarchy that's very similar to a NuGet package hive. This environment variable will be used later by publishing to filter the set of packages that are copied to the publish output.

```
Setting DOTNET_SHARED_STORE to D:\k\JitBench\.aspnet\AspNet.win-2.0.0-preview1-24493
```

This variable is probed by the `dotnet` host as an additional set of packages that the runtime can use. Note that the binaries here will only be used if they *match* and if they *are not present in 'bin'*. That's why the two other environment variables are important! See [here](https://github.com/dotnet/core-setup/blob/master/Documentation/design-docs/DotNetCore-SharedPackageStore.md) for a more thorough description.

### Step 3b: `.\AspNet-Install.ps1 -InstallDir .aspnet -Architecture x64`

This downloads pre-optimized ASP.NET binaries and unzips them under `.aspnet`. If you want to get an updated set of ASP.NET libraries, start at this step.

-------------------

This command will also set the same environment variables as step 3a.

### Step 4: `dotnet restore`

This will restore package and runtime dependencies. In general we already have these on the machine, we just need to update the generated files.

This step will use the environment variables `JITBENCH_ASPNET_VERSION` and `JITBENCH_FRAMEWORK_VERSION` to pin the version of the ASP.NET libraries and shared framework based on Step 3.

### Step 5: `dotnet publish -c Release -f netcoreapp20 --manifest $env:JITBENCH_ASPNET_MANIFEST`

This will build and publish the application in the `Release` configuration and targeting `netcoreapp20` as the target framework. `netcoreapp20` is what we refer to as the *shared framework*.

The `--manifest` argument specifies a list of binaries that are already present in a 'shared' location. Now this 'shared' location was created by step 2, and the list of files is stored in the `JITBENCH_ASPNET_MANIFEST` environment variable. Since these binaries weren't copied to the publish output, they will be loaded instead from `DOTNET_SHARED_STORE`. See [here](https://github.com/dotnet/core-setup/blob/master/Documentation/design-docs/DotNetCore-SharedPackageStore.md) for a more thorough description.

### Step 6: `dotnet MusicStore.dll`

Runs the app. We're using the *shared framework* so the actual `.exe` that runs here is `dotnet.exe`. The app itself is a `.dll` with a `Main(...)` method. It's **very important** that you do this with `pwd` set to the publish folder. The app will use the `pwd` to determine where view templates are located.
