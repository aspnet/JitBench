using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Reflection;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace MusicStore
{
    public static class Program
    {
        public static void Main(string[] args)
        {
            var totalTime = Stopwatch.StartNew();

            var config = new ConfigurationBuilder()
                .AddCommandLine(args)
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

            totalTime.Stop();
            var serverStartupTime = totalTime.ElapsedMilliseconds;
            Console.WriteLine("Server started in {0}ms", serverStartupTime);
            Console.WriteLine();

            using (var client = new HttpClient())
            {
                Console.WriteLine("Starting request to http://localhost:5000");
                var requestTime = Stopwatch.StartNew();
                var response = client.GetAsync("http://localhost:5000").Result;
                response.EnsureSuccessStatusCode(); // Crash immediately if something is broken
                requestTime.Stop();
                var firstRequestTime = requestTime.ElapsedMilliseconds;

                Console.WriteLine("Response: {0}", response.StatusCode);
                Console.WriteLine("Request took {0}ms", firstRequestTime);
                Console.WriteLine();
                Console.WriteLine("Cold start time (server start + first request time): {0}ms", serverStartupTime + firstRequestTime);
                Console.WriteLine();
                Console.WriteLine();
                
                var minRequestTime = long.MaxValue;
                var maxRequestTime = long.MinValue;
                var averageRequestTime = 0.0;

                Console.WriteLine("Running 100 requests");
                for (var i = 1; i <= 100; i++)
                {
                    requestTime.Restart();
                    response = client.GetAsync("http://localhost:5000").Result;
                    requestTime.Stop();

                    var requestTimeElapsed = requestTime.ElapsedMilliseconds;
                    if (requestTimeElapsed < minRequestTime)
                    {
                        minRequestTime = requestTimeElapsed;
                    }

                    if (requestTimeElapsed > maxRequestTime)
                    {
                        maxRequestTime = requestTimeElapsed;
                    }

                    // Rolling average of request times
                    averageRequestTime = (averageRequestTime * ((i - 1.0) / i)) + (requestTimeElapsed * (1.0 / i));
                }

                Console.WriteLine("Steadystate min response time: {0}ms", minRequestTime);
                Console.WriteLine("Steadystate max response time: {0}ms", maxRequestTime);
                Console.WriteLine("Steadystate average response time: {0}ms", (int)averageRequestTime);
            }

            Console.WriteLine();

            VerifyLibraryLocation();
        }

        private static void VerifyLibraryLocation()
        {
            var hosting = typeof(WebHostBuilder).GetTypeInfo().Assembly.Location;
            var musicStore = typeof(Program).GetTypeInfo().Assembly.Location;

            if (Path.GetDirectoryName(hosting) == Path.GetDirectoryName(musicStore))
            {
                Console.WriteLine("ASP.NET loaded from bin. This is a bug if you wanted crossgen");
                Console.WriteLine("ASP.NET loaded from bin. This is a bug if you wanted crossgen");
                Console.WriteLine("ASP.NET loaded from bin. This is a bug if you wanted crossgen");
            }
            else
            {
                Console.WriteLine("ASP.NET loaded from store");
            }
        }
    }
}
