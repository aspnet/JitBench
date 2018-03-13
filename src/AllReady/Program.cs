using Microsoft.AspNetCore;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using JitBench;
using System;

namespace AllReady
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var jitBench = JitBenchHelper.Start();

            var config = new ConfigurationBuilder()
               .AddCommandLine(Array.Empty<string>())
               .AddEnvironmentVariables(prefix: "ASPNETCORE_")
               .Build();

            BuildWebHost(args, config).Start();

            jitBench.LogStartup();

            jitBench.PerformHttpRequests("http://localhost:5000", args, 
                threshholds: new int[] { 100, 250, 500, 750, 1000, 1500, 2000 });

            jitBench.VerifyLibraryLocation();
        }

        public static IWebHost BuildWebHost(string[] args, IConfigurationRoot configRoot) =>
            WebHost.CreateDefaultBuilder(args)
                .UseConfiguration(configRoot)
                .ConfigureAppConfiguration((ctx, config) => config.SetBasePath(ctx.HostingEnvironment.ContentRootPath).AddJsonFile("version.json"))
                .UseStartup<Startup>()
                .ConfigureLogging(factory =>
                {
                    factory.AddConsole();
                    factory.AddFilter((category, level) => level >= LogLevel.Warning);
                })
                .Build();
    }
}
