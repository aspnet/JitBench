using System;
using System.IO;
using JitBench;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace MusicStore
{
    public static class Program
    {
        public static void Main(string[] args)
        {
            var jitBench = JitBenchHelper.Start();

            var config = new ConfigurationBuilder()
                .AddCommandLine(Array.Empty<string>())
                .AddEnvironmentVariables(prefix: "ASPNETCORE_")
                .Build();

            var builder = new WebHostBuilder()
                .UseContentRoot(Directory.GetCurrentDirectory())
                .UseConfiguration(config)
                .UseIISIntegration()
                .UseStartup("MusicStore")
                .ConfigureLogging(factory =>
                {
                    factory.AddConsole();
                    factory.AddFilter((provider,category, level) => level >= LogLevel.Warning);
                })
                .UseKestrel();

            var host = builder.Build();

            host.Start();

            jitBench.LogStartup();

            jitBench.PerformHttpRequests("http://localhost:5000", args, 
                threshholds: new int[] { 100, 250, 500, 750, 1000, 1500, 2000, 3000, 5000, 10000 });
            
            jitBench.VerifyLibraryLocation();
        }
    }
}
