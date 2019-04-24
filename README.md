
# JitBench

A repository for aspnet workloads suitable for testing the JIT.

Right now there is only one workload app here, at `src/MusicStore`

## Branches

This repo uses branches that target various releases for comparison purposes. Please make sure to follow the instructions in the readme for that particular branch that you are using.

| Branch             | ASP.NET version  | Status                                                                                                                        |
|--------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------|
| master             | Latest           | [![Build Status](https://travis-ci.org/aspnet/JitBench.svg?branch=master)](https://travis-ci.org/aspnet/JitBench)             |
| rel/2.0.0          | 2.0.0            | [![Build Status](https://travis-ci.org/aspnet/JitBench.svg?branch=rel/2.0.0)](https://travis-ci.org/aspnet/JitBench)          |

## Instructions for JIT testing:

### Step 0:

Clone the JitBench Repo

`git clone <JitBench repo>`

`cd JitBench`

### Step 1:

Get the newest dotnet as 'repo local' 

**Windows**

`.\Dotnet-Install.ps1 -InstallDir .dotnet -Channel master -Architecture x64`

**OSX**

`source ./dotnet-install.sh -installdir .dotnet -channel master -architecture x64`

**Linux**

`source ./dotnet-install.sh -installdir .dotnet -channel master -architecture x64`


You need to run **both** of these commands in this particular order. This will grab the latest shared runtime and SDK and copy them to `<JitBench>\.dotnet`. Note you need to `source` the script so that it can update your `$PATH`.

You should also have this version of `dotnet` on your path at this point. `dotnet --info` will print the version and it should match what you see in the output of the above commands.

### Step 2:

Modify the shared framework (if necessary).

If you need to use a private build of the JIT or other CoreCLR components, now is a good time to update the shared framework with your bits. Copy any binaries you need to use into the shared framework in `<JitBench>\.dotnet\shared\Microsoft.NETCore.App\<version>`. The version should match the version that downloaded in step 1.

### Step 3:

Go to the MusicStore directory

`cd src/MusicStore`

### Step 3: 

Build/publish MusicStore

**Windows**

`dotnet publish -c Release -f netcoreapp3.0` got(powershell)

OR

`dotnet publish -c Release -f netcoreapp3.0` (cmd)

**OSX**

`dotnet publish -c Release -f netcoreapp3.0`

This will publish the app to `bin\Release\netcoreapp3.0\publish`.

### Step 6:

Run the app

`cd bin\Release\netcoreapp3.0\publish`

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

### What are these warnings like the following?

> C:\git\aspnet\JitBench\src\MusicStore\MusicStore.csproj : warning NU1605: Detected package downgrade: Microsoft.NETCore.Platforms from 3.0.0-preview6.19223.9 to 3.0.0-preview6.19223.2. Reference the package directly from the project to select a different version.

These warnings are due the to fact that we're using packages that don't ship in the shared framework (EF, Auth stuff). There's no really good way to correlate the versions of these packages with what's in the shared framework.

### Things are failing what do I do?

Do a `git clean -xdf` and get back to a clean state. Then start over at step 1. 

If you still have a problem, open an issue on this repo. Opening an issue here is the best way to get a quick response.

### Powershell Errors

The scripts in this repo use powershell. If you're not a powershell user you will have to do some first-time setup on your machine.

Open powershell as admin and run `Set-ExecutionPolicy Unrestricted`, accept the prompt. By default powershell does not allow you to run scripts :-1:

### What is Microsoft.AspNetCore.App

This is a meta-package that contains all of the ASP.NET libraries. This is the easiest way to just pull in the whole platform as a reference. We expect that this will be the common way to build applications in ASP.NET going forward.

### About MusicStore

MusicStore is a good sample of what a typical but *small* customer app would look like for a browser-based LOB app or public website. Notably it uses auth, logging, databases, ORM, caching, and dynamic view content. It's a good representation of the concerns a typical production app needs to address.

We've modified the app to start up the server and perform a single HTTP request with timing information. Then it will perform 100 requests (single threaded) and print some statistics. We feel like this is a good benchmark for both server cold start and local development cold start, and is suitable for iterating on quickly due to the ease of running.

## Explanation (what does this do?)

For an intro to dotnet CLI I suggest referring to their [docs](https://docs.microsoft.com/en-us/dotnet/articles/core/tools/index). We'll describe some of the steps here, but you should refer to the CLI docs as the primary source of information about CLI. If you have issues with the CLI please log them [here](https://github.com/dotnet/cli/issues).

### Step 6: `dotnet MusicStore.dll`

Runs the app. We're using the *shared framework* so the actual `.exe` that runs here is `dotnet.exe`. The app itself is a `.dll` with a `Main(...)` method. It's **very important** that you do this with `pwd` set to the publish folder. The app will use the `pwd` to determine where view templates are located.
