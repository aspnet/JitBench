using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
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
                    int[] threshholds = new int[] { 100, 250, 500, 750, 1000, 1500, 2000, 3000, 5000, 10000 };
                    double totalTimeMs = serverStartupTime + firstRequestTime;
                    int totalRequests = 1;
                    Console.WriteLine("========== Steady State Performance ==========");
                    Console.WriteLine();
                    Console.WriteLine("  Requests    Aggregate Time(ms)    Req/s   Req Min(ms)   Req Mean(ms)   Req Median(ms)   Req Max(ms)   SEM(%)");
                    Console.WriteLine("-----------   ------------------   ------   -----------   ------------   --------------   -----------   ------");

                    for (int i = 0; i < threshholds.Length; i++)
                    {
                        int iterationRequests = threshholds[i] - totalRequests;
                        eventSource.RequestBatchBegin(i, iterationRequests);
                        MeasureThroughput(client, iterationRequests, out double batchTotalTimeMs, out double minRequestTime, out double meanRequestTimeMs, out double medianRequestTimeMs, out double maxRequestTime,  out double standardErrorMs);
                        eventSource.RequestBatchEnd(i, iterationRequests, (int)batchTotalTimeMs, minRequestTime, meanRequestTimeMs, medianRequestTimeMs, maxRequestTime, standardErrorMs);
                        totalTimeMs += batchTotalTimeMs;
                        Console.WriteLine("{0,5:D}-{1,5:D}   {2,18:D}   {3,5:F}   {4,11:F}   {5,12:F}   {6,14:F}   {7,11:F}   {8,6:F}",
                                           totalRequests + 1, totalRequests + iterationRequests, (int)totalTimeMs, 1000.0/meanRequestTimeMs, minRequestTime, meanRequestTimeMs, medianRequestTimeMs, maxRequestTime, standardErrorMs*100.0/meanRequestTimeMs);
                        totalRequests += iterationRequests;
                    }

                    Console.WriteLine();
                    Console.WriteLine("Tip: If you only care about startup performance, use the -skipSteadyState argument to skip these measurements");
                }

            }

            
            VerifyLibraryLocation();
        }

       
        

        private static void MeasureThroughput(HttpClient client, int countRequests, out double batchTotalTimeMs, out double minRequestTimeMs, out double meanRequestTimeMs, out double medianRequestTimeMs, out double maxRequestTimeMs, out double standardErrorMs)
        {
            double[] requestTimes = new double[countRequests];
            var requestTime = Stopwatch.StartNew();
            
            for (int i = 0; i < countRequests; i++)
            {
                requestTime.Restart();
                var response = client.GetAsync("http://localhost:5000").Result;
                requestTime.Stop();

                requestTimes[i] = requestTime.ElapsedTicks * 1000.0 / Stopwatch.Frequency;
            }

            Array.Sort(requestTimes);
            batchTotalTimeMs = requestTimes.Sum();
            minRequestTimeMs = requestTimes[0];
            medianRequestTimeMs = requestTimes[countRequests / 2];
            meanRequestTimeMs = batchTotalTimeMs / countRequests;
            maxRequestTimeMs = requestTimes[countRequests - 1];
            double meanRequestTimeMsCopy = meanRequestTimeMs; // can't refer to out value inside the lambda
            double sampleStandardDeviation = Math.Sqrt(requestTimes.Select(x => (x - meanRequestTimeMsCopy) * (x - meanRequestTimeMsCopy)).Sum()/(countRequests-1));
            standardErrorMs = sampleStandardDeviation / Math.Sqrt(countRequests);
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
