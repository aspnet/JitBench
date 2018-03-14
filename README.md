
# JitBench

![Build Status](https://travis-ci.org/aspnet/JitBench.svg?branch=rel/2.0.0)             

A repository for aspnet workloads suitable for testing the JIT.

Right now there are two workload apps here: `src/MusicStore` and `src/AllReady`

## Example benchmark usage with powershell

### First get the repo

    git clone <JitBench repo>
    cd JitBench

### Example 1: Test using 2.0 RTM versions of all .Net Core components

    .\RunBenchmark.ps1

Outputs:

	... lots of logging omitted, then at the bottom MusicStore runs ...

	Server started in 2847ms
	
	Starting request to http://localhost:5000
	Response: OK
	Request took 618ms
	
	Cold start time (server start + first request time): 3465ms
	
	
	Running 100 requests
	Steadystate min response time: 3ms
	Steadystate max response time: 8ms
	Steadystate average response time: 3ms
	
	ASP.NET loaded from store

### Example 2: Test with a custom version of the shared framework

    .\RunBenchmark.ps1 -FrameworkVersion 2.1.0-preview1-25818-02

This will automatically select an LKG version of the SDK capable of working with this version of the framework because 2.0.0 SDK won't work. In this case, SDK 2.2.0-preview1-007558 is selected and printed in the log. ASP.Net remains 2.0.0.

### Example 3: Test with a custom version of shared framework and a private build of CoreCLR

    .\RunBenchmark.ps1 -FrameworkVersion 2.1.0-preview1-25818-02 -CoreCLRPrivateBinDirPath F:\github\coreclr\bin\Product\Windows_NT.x64.Release\`

This will automatically copy and use the private CoreCLR and clrjit binaries from your build instead of using the ones downloaded in the shared framework.

**KNOWN ISSUE**: Building R2R images will NOT use the private binaries within crossgen, instead it uses binaries from the NuGet cache.

**RECOMMENDATION**: The CoreCLR repo has a dependencies.props file at its root and one of the properties inside is CoreClrPackageVersion. Picking that version of the shared framework helps to ensure your private bits are compatible with the other binaries that aren't being replaced.

### Example 4: See the commands that will be used to run the benchmark without actually running it

    .\RunBenchmark.ps1 -WhatIf

Outputs:

     ***** Step 1 - Set Versions *******
    cd F:\github\JitBench
    .\AspNet-SetVersions.ps1
    
     ***** Step 2 - Setup Dotnet Runtime and SDK *******
    .\DotNet-Install.ps1 -SharedRuntime -InstallDir .dotnet -Channel master -Version 2.0.0 -Architecture x64
    .\DotNet-Install.ps1 -InstallDir .dotnet -Channel master -Version 2.0.0 -Architecture x64
    
     ***** Step 3 - Generate Store *******
    cp ./CreateStore/bugfix_sdk_1682/Microsoft.NET.ComposeStore.targets .dotnet/sdk/2.0.0/Sdks/Microsoft.NET.Sdk/build/Microsoft.NET.ComposeStore.targets
    .\AspNet-GenerateStore.ps1 -InstallDir .store -Architecture x64 -Runtime win7-x64
    
     ***** Step 4 - Restore MusicStore *******
    cd src\MusicStore
    dotnet restore
    
     ***** Step 5 - Publish MusicStore *******
    rm -r bin\Release\netcoreapp2.0\publish
    dotnet publish -c Release -f netcoreapp2.0 --manifest F:\github\JitBench\.store\x64\netcoreapp2.0\artifact.xml /p:MvcRazorCompileOnPublish=false
    
     ***** Step 6 - Run MusicStore *******
    cd bin\Release\netcoreapp2.0\publish
    dotnet MusicStore.dll

IMPORTANT: .\AspNet-SetVersions.ps1 sets environment variables and writes files that the other commands rely on to work. If you start running the commands manually, make sure the environment is set up first.

### Example 5: Run the benchmark with Precompiled Views enabled

    .\RunBenchmark.ps1 -PrecompiledViews

By default precompiled views are not used. See the View Compilation section below for more info.

### Example 6: Do all the benchmark preparation steps, but don't run MusicStore

    .\RunBenchmark.ps1 -SetupOnly

This runs steps 1-5 in the -WhatIf output from above. You can now run dotnet MusicStore.dll manually (perhaps in a loop or with ETW collection turned on). 



## Other things you can do

### Use AllReady app

MusicStore is the default app being executed with `RunBenchmark.ps1`. If you want to try the `AllReady` app you need to provide one extra arguments to the script:

`-App AllReady`

### View Compilation

MVC can pre-compile the view files on publish. 

To do this change up your *step 5* publish command

`dotnet publish -c Release -f netcoreapp2.0 --manifest $env:JITBENCH_ASPNET_MANIFEST /p:MvcRazorCompileOnPublish=true` (powershell)

After doing a publish this way you shouldn't have a `Views` folder in the publish output. 

----

This is interesting to do because view compilation at runtime eats up about 50% our startup time. So by excluding it we measure a much different subset of the application. 

Compile on publish is the default for publishing for new applications. We expect most users to use runtime compilation for local inner-loop and publish-time compilation for production. 

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

### About AllReady

"allReady is an open-source solution focused on increasing awareness, efficiency and impact of preparedness campaigns as they are delivered by humanitarian and disaster response organizations in local communities. http://www.htbox.org/projects/allready"

It's a real-world web app which uses some of the most popular libraries like `MediatR`, `Autofac`, `Hangfire`, `EntityFrameworkCore`, `Newtonsoft.Json` and `WindowsAzure.Storage`. 
The benchmark does exactly the same job the MusicStore benchmark does. Our goal is to have a real-world web application scenario to optimize and test the performance for real workloads.

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

### Step 5: `dotnet publish -c Release -f netcoreapp2.0 --manifest $env:JITBENCH_ASPNET_MANIFEST`

This will build and publish the application in the `Release` configuration and targeting `netcoreapp2.0` as the target framework. `netcoreapp2.0` is what we refer to as the *shared framework*.

The `--manifest` argument specifies a list of binaries that are already present in a 'shared' location. Now this 'shared' location was created by step 2, and the list of files is stored in the `JITBENCH_ASPNET_MANIFEST` environment variable. Since these binaries weren't copied to the publish output, they will be loaded instead from `DOTNET_SHARED_STORE`. See [here](https://github.com/dotnet/core-setup/blob/master/Documentation/design-docs/DotNetCore-SharedPackageStore.md) for a more thorough description.

### Step 6: `dotnet MusicStore.dll`

Runs the app. We're using the *shared framework* so the actual `.exe` that runs here is `dotnet.exe`. The app itself is a `.dll` with a `Main(...)` method. It's **very important** that you do this with `pwd` set to the publish folder. The app will use the `pwd` to determine where view templates are located.
