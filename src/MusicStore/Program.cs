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
            MusicStoreEventSource eventSource = new MusicStoreEventSource();
            eventSource.ServerStartupBegin();

            var config = new ConfigurationBuilder()
                .AddCommandLine(new string[0]) 
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
            int serverStartupTime = (int)totalTime.ElapsedMilliseconds;
            eventSource.ServerStartupEnd(serverStartupTime);





            using (var client = new HttpClient())
            {
                var requestTime = Stopwatch.StartNew();
                eventSource.FirstRequestBegin();
                var response = client.GetAsync("http://localhost:5000").Result;
                response.EnsureSuccessStatusCode(); // Crash immediately if something is broken
                requestTime.Stop();
                int firstRequestTime = (int)requestTime.ElapsedMilliseconds;
                eventSource.FirstRequestEnd(firstRequestTime);

                Console.WriteLine("============= Startup Performance ============");
                Console.WriteLine();
                Console.WriteLine("Server start (ms): {0,5}", serverStartupTime);
                Console.WriteLine("1st Request (ms):  {0,5}", firstRequestTime);
                Console.WriteLine("Total (ms):        {0,5}", serverStartupTime + firstRequestTime);
                Console.WriteLine();
                Console.WriteLine();
                Console.WriteLine();

                if (args.Length == 0 || args[0] != "-skipSteadyState")
                {
                    int[] threshholds = new int[] { 500, 1000, 1500, 2000, 10000 };
                    double totalTimeMs = 0;
                    int totalRequests = 0;
                    Console.WriteLine("========== Steady State Performance ==========");
                    Console.WriteLine();
                    Console.WriteLine("  Requests    Aggregate Time(ms)    Req/s   Request Min(ms)   Request Max(ms)");
                    Console.WriteLine("-----------   ------------------   ------   ---------------   ---------------");

                    for (int i = 0; i < threshholds.Length; i++)
                    {
                        int iterationRequests = threshholds[i] - totalRequests;
                        eventSource.RequestBatchBegin(i, iterationRequests);
                        MeasureThroughput(client, iterationRequests, out double msRequired, out double minRequestTime, out double maxRequestTime, out double requestPerSec);
                        eventSource.RequestBatchEnd(i, iterationRequests, (int)msRequired, minRequestTime, maxRequestTime);
                        totalTimeMs += msRequired;
                        Console.WriteLine("{0,5:D}-{1,5:D}   {2,18:D}   {3,5:F}   {4,15:F}   {5,15:F}",
                                           totalRequests + 1, totalRequests + iterationRequests, (int)totalTimeMs, requestPerSec, minRequestTime, maxRequestTime);
                        totalRequests += iterationRequests;
                    }

                    Console.WriteLine();
                    Console.WriteLine("Tip: If you only care about startup performance, use the -skipSteadyState argument to skip these measurements");
                }

            }

            
            VerifyLibraryLocation();
        }

       
        

        private static void MeasureThroughput(HttpClient client, int countRequests, out double msRequired, out double minRequestTime, out double maxRequestTime, out double requestPerSec)
        {
            var requestGroupTimer = Stopwatch.StartNew();
            var requestTime = Stopwatch.StartNew();
            minRequestTime = long.MaxValue;
            maxRequestTime = long.MinValue;

            for (int i = 1; i <= countRequests; i++)
            {
                requestTime.Restart();
                var response = client.GetAsync("http://localhost:5000").Result;
                requestTime.Stop();

                var requestTimeElapsed = requestTime.ElapsedTicks*1000.0/Stopwatch.Frequency;
                if (requestTimeElapsed < minRequestTime)
                {
                    minRequestTime = requestTimeElapsed;
                }

                if (requestTimeElapsed > maxRequestTime)
                {
                    maxRequestTime = requestTimeElapsed;
                }
            }

             msRequired = requestGroupTimer.ElapsedTicks*1000.0/Stopwatch.Frequency;
             requestPerSec = countRequests*1000/msRequired;
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
        }
    }
}
