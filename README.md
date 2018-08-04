
# Tiered Compilation Testing Demo

In .Net Core 2.1 we added a new preview feature called Tiered Compilation that helps improve startup times and steady state performance. This page shows how to test out
 the feature quickly, either on your own applications or on a sample ASP.NET MusicStore application.



# Part 1 - Running an experiment


## 1.1: Download the .Net Core 2.1 SDK

Pick an installer from <https://www.microsoft.com/net/download> that matches your OS. I am using Windows x64 here.


## 1.2: Get source for the application you want to test

I'll be using the MusicStore test app but you can use any .Net Core app that runs on 2.1. At a command prompt that has git:

    F:\github>git clone https://github.com/aspnet/JitBench
    F:\github>cd JitBench
    F:\github\JitBench>git checkout tiered_compilation_demo

## 1.3: Confirm you are using the right version of the .Net Core SDK

    F:\github\JitBench>dotnet --version
    2.1.300

If you see a different version you may have installed a more recent daily build or your app has a global.json targetting a different version of the SDK.
You can explicitly direct dotnet to use the 2.1 RTM version of the SDK by creating global.json in the current directory with this text:

    {
        "sdk":
        {
            "version": "2.1.300"
        }
    }

## 1.4: Build and publish the application

    F:\github\JitBench>cd src\MusicStore
    F:\github\JitBench\src\MusicStore>dotnet publish -c Release

## 1.5: Run the app without tiered compilation enabled

    F:\github\JitBench\src\MusicStore>cd bin\Release\netcoreapp2.1\publish\
    F:\github\JitBench\src\MusicStore\bin\Release\netcoreapp2.1\publish>dotnet MusicStore.dll

Test app output. This output is specific to the MusicStore test app, your apps invariably have different output:

    ============= Startup Performance ============

    Server start (ms):   856
    1st Request (ms):    559
    Total (ms):         1415



    ========== Steady State Performance ==========

      Requests    Aggregate Time(ms)    Req/s   Req Min(ms)   Req Mean(ms)   Req Median(ms)   Req Max(ms)   SEM(%)
    -----------   ------------------   ------   -----------   ------------   --------------   -----------   ------
        2-  100                 1672   385.08          2.14           2.60             2.34         11.73     5.09
      101-  250                 2024   425.75          2.07           2.35             2.30          3.98     0.85
      251-  500                 2631   412.01          1.93           2.43             2.30         14.38     2.17
      501-  750                 3190   446.61          2.01           2.24             2.20          3.89     0.65
      751- 1000                 3901   351.85          2.05           2.84             2.54          5.07     1.23
     1001- 1500                 5255   369.16          2.04           2.71             2.47         17.16     1.43
     1501- 2000                 6531   392.05          1.88           2.55             2.34          5.96     1.22
     2001- 3000                 8901   421.94          1.87           2.37             2.21         10.54     0.81

## 1.6: Run the app with tiered compilation enabled

There are several options for turning on tiered compilation:
1) Setting an environment variable 'set COMPlus_TieredCompilation=1' (windows), 'export COMPlus_TieredCompilation=1' (Linux). 
2) Setting the app config property in the application's runtimeconfig.json "System.Runtime.TieredCompilation" : true ([Example](https://github.com/aspnet/JitBench/blob/tiered_compilation_demo/example_runtimeconfig/MusicStore.runtimeconfig.json#L10)).
 This file is located adjacent to the application binary in your build or publish directory.
3) Setting an MSBuild property in the application's project file \<TieredCompilation>true\</TieredCompilation> ([Example](https://github.com/dotnet/core/blob/e9e6c91206a5dc327dcb41a46219e13a8a6e66d6/samples/dotnetsay/dotnetsay.csproj#L21)).
 This causes the build to auto-generate a runtimeconfig.json with System.Runtime.TieredCompilation set to true.
Known issue: In the 2.1 SDK the MSBuild TieredCompilation property doesn't correctly update the runtimeconfig.json during an incremental rebuild, use a one time clean build to work around this if you have just changed the property value.

I find the environment variable easiest to work with for performance measurements whereas the app config or MSBuild property are more natural if you want to ship an application with tiered compilation enabled, but any option can work.

    F:\github\JitBench\src\MusicStore\bin\Release\netcoreapp2.1\publish>set COMPlus_TieredCompilation=1
    F:\github\JitBench\src\MusicStore\bin\Release\netcoreapp2.1\publish>dotnet MusicStore.dll

    ============= Startup Performance ============

    Server start (ms):   819
    1st Request (ms):    452
    Total (ms):         1271



    ========== Steady State Performance ==========

      Requests    Aggregate Time(ms)    Req/s   Req Min(ms)   Req Mean(ms)   Req Median(ms)   Req Max(ms)   SEM(%)
    -----------   ------------------   ------   -----------   ------------   --------------   -----------   ------
        2-  100                 1655   257.26          2.64           3.89             3.07         12.49     4.63
      101-  250                 2052   377.73          2.20           2.65             2.59          4.50     0.96
      251-  500                 2613   446.14          1.65           2.24             2.12         14.53     2.38
      501-  750                 3006   636.52          1.23           1.57             1.44          3.41     1.52
      751- 1000                 3412   615.70          1.36           1.62             1.58          2.90     0.88
     1001- 1500                 4189   643.32          1.15           1.55             1.51          9.72     1.22
     1501- 2000                 4955   652.77          1.24           1.53             1.49          4.01     0.56
     2001- 3000                 6446   670.40          1.18           1.49             1.48          2.69     0.29

## 1.7 Comparing performance

The MusicStore test application uses System.Diagnostics.StopWatch and console output to quickly log some numbers for startup or steady-state performance, but ultimately you will have to decide what performance metrics are most important to your application.
You can also use a profiler such as [PerfView](https://github.com/Microsoft/perfview/blob/master/documentation/Downloading.md) to collect before and after traces for comparison instead of adding instrumentation. 
I won't repeat the wealth of general benchmarking and statistical analysis advice available around the web (as well as within the PerfView User's guide), but a few common issues to look out for:


- Run your test application several times before paying any heed to the measurements. The first few runs will likely warm up various caches and the performance differences these caches cause will confound your results. Alternatively
you can measure the very first launch of the application after booting the machine with nothing cached but now you need to power the cycle the machine and follow the exact same startup sequence between each measurement to
keep it consistent.
- Measure the same thing many times, then average.
- Try to minimize the number of other applications, services, and network activity running on the machine. If you must have activity as part of the test environment try to keep it constant throughout the test period.
- After you have measured, sanity check the measurement distribution and make sure averages aren't being unduly influenced by a few outliers.

# Part 2 - Exploring the application behavior

## Is tiered compilation working?

If your benchmarks change dramatically like the example above it is easy to see that tiered compilation is working, but if there is no change you might wonder whether tiered compilation benefits your scenario
or there was a mistake turning it on. One easy way to check is by using [PerfView](https://github.com/Microsoft/perfview/blob/master/documentation/Downloading.md). Make sure to get at least PerfView version 
2.0.15 that has support for visualizing tiered compilation information. You want to [collect a machine-wide trace](https://channel9.msdn.com/Series/PerfView-Tutorial/PerfView-Tutorial-11-Data-Collection-for-Server-Scenarios)
that includes the execution of your test app as shown in step 1.6 above. By default the collector uses a circular buffer with a 500MB capacity and the demo app generates a lot of events which may exceed that.
Using PerfView's GUI I increased the limit to 1000MB to avoid losing any data. Once collection is complete open the JitStats view within the Advanced Group in the tree view control:

![MainScreen](./images/PerfView_MainScreen.jpg)

In the JitStats view there are several indications that confirm tiered compilation was operating:

![JitStats1](./images/PerfView_JitStats1.jpg)


Known issues:


- PerfView analysis will only detect tiered compilation is in use when background compilations occur in the trace. In very short running applications its possible that tiered compilation
is enabled but not enough code is run to trigger any method to perform a background recompile. In this case PerfView will incorrectly report tiered compilation is disabled because there is no evidence of it in the trace.

- It is possible for PerfView to lose data in the circular buffer even if the UI does not show that it filled up. Usually this can be easily spotted because most of the jit events will be missing, and the problem can be avoided by making the buffer larger or not tracing as long. If all the trace events for tiered compilation are lost then PerfView will incorrectly indicate the feature was disabled.


Both of these issues should be improved in the future.


## Exploring JIT behavior

Using the same PerfView trace collected above, there is an 'Individual JIT Events' section of the JitStats report which shows every time the JIT was invoked, which method it was compiling, and what triggered the compilation. By looking
for methods with the 'TC' (Tiered Compilation) trigger you can determine all methods which were ever recompiled:

![JitStats2](./images/PerfView_JitStats2.jpg)





## Is tiered compilation living up to its potential?

If the trace shows tiered compilation is running but the performance hasn't improved you might wonder if tiered compilation isn't running as well as it should be. Although a full analysis would require some non-trivial analysis of the .NET runtime, there are
some simple tests anyone can run to determine the overhead tiered compilation adds relative to having the JIT generate code as fast as possible or having the JIT generate its best code.

### Startup

Set the environment variable COMPlus\_JitMinOpts=1 to make the JIT create code as quickly as possible* and then run your application again, comparing its startup performance against startup with tiered compilation enabled.
Ideally tiered compilation should give startup performance equal or just slighly worse than this COMPlus\_JitMinOpts configuration which accounts for some extra bookkeeping overhead that tiered compilation must do. If tiered
 compilation is significantly slower than COMPlus\_JitMinOpts something may be amiss and I'd love to hear about it. On the other hand if tiered compilation is significantly faster it probably means your startup test is spending
a lot of time running code rather than jit compiling it. You should try to pick a leaner definition of startup that will execute less code.

*If we are being technical JitMinOpts tells the JIT not to optimize which isn't always the same thing as creating code as fast as possible. Some optimizations actually make compilation faster too! However for the current
JIT implementation COMPlus\_JitMinOpts=1 is a very good approximation of generating jitted code as quickly possible.

### Steady-state

To test steady-state performance now set COMPlus\_ReadyToRun=0. This disables using code that is precompiled within (most) framework images and instead forces the JIT to create code for all of the methods. The code created by
the JIT at runtime is more optimized than what can be statically compiled in the images. This results in a very slow startup because so much JIT compilation is occuring, but once complete the steady-state performance should
be high. Compare this steady-state performance to steady-state performance of tiered compilation. Ideally tiered compilation should give performance equal or slightly worse than the COMPlus\_ReadyToRun=0 performance. If tiered
compilation is substantially worse I'd love to hear about it, and if it is substantially better there is probably something fishy with the measurement.


# Run into trouble?

I hope your experiments run smoothly, but if not or you have questions please let me know. File an issue in this repo or at github.com/dotnet/coreclr and mention me, @noahfalk.






