using System;
using System.Diagnostics;
using System.Diagnostics.Tracing;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Reflection;
using Microsoft.AspNetCore.Hosting;

namespace JitBench
{
    [EventSource(Name = "MusicStore")]
    public class MusicStoreEventSource : EventSource
    {
        [Event(1)]
        public void ServerStartupBegin()
        {
            WriteEvent(1);
        }

        [Event(2)]
        public void ServerStartupEnd(int serverStartMs)
        {
            WriteEvent(2, serverStartMs);
        }

        [Event(3)]
        public void FirstRequestBegin()
        {
            WriteEvent(3);
        }

        [Event(4)]
        public void FirstRequestEnd(int firstRequestMs)
        {
            WriteEvent(4, firstRequestMs);
        }

        [Event(5)]
        public void RequestBatchBegin(int batchNumber, int requestCount)
        {
            WriteEvent(5, batchNumber, requestCount);
        }

        [Event(6)]
        public void RequestBatchEnd(int batchNumber, int requestCount, int batchTimeMs, double minRequestTimeMs, double meanRequestTimeMs, double medianRequestTimeMs, double maxRequestTimeMs, double standardErrorMs)
        {
            WriteEvent(6, batchNumber, requestCount, batchTimeMs, minRequestTimeMs, meanRequestTimeMs, medianRequestTimeMs, maxRequestTimeMs, standardErrorMs);
        }
    }

    public class JitBenchHelper
    {
        readonly Stopwatch totalTime;
        readonly MusicStoreEventSource eventSource;
        int serverStartupTime;

        private JitBenchHelper(Stopwatch stopwatch)
        {
            totalTime = stopwatch;
            eventSource = new MusicStoreEventSource();
            eventSource.ServerStartupBegin();
        }

        public static JitBenchHelper Start() => new JitBenchHelper(Stopwatch.StartNew());

        public void LogStartup()
        {
            totalTime.Stop();
            serverStartupTime = (int)totalTime.ElapsedMilliseconds;
            eventSource.ServerStartupEnd(serverStartupTime);
        }

        public void PerformHttpRequests(string url, string[] args, int[] threshholds)
        {
            using (var client = new HttpClient())
            {
                var requestTime = Stopwatch.StartNew();
                eventSource.FirstRequestBegin();
                var response = client.GetAsync(url).Result;
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
                        MeasureThroughput(client, url, iterationRequests, out double batchTotalTimeMs, out double minRequestTime, out double meanRequestTimeMs, out double medianRequestTimeMs, out double maxRequestTime, out double standardErrorMs);
                        eventSource.RequestBatchEnd(i, iterationRequests, (int)batchTotalTimeMs, minRequestTime, meanRequestTimeMs, medianRequestTimeMs, maxRequestTime, standardErrorMs);
                        totalTimeMs += batchTotalTimeMs;
                        Console.WriteLine("{0,5:D}-{1,5:D}   {2,18:D}   {3,5:F}   {4,11:F}   {5,12:F}   {6,14:F}   {7,11:F}   {8,6:F}",
                                           totalRequests + 1, totalRequests + iterationRequests, (int)totalTimeMs, 1000.0 / meanRequestTimeMs, minRequestTime, meanRequestTimeMs, medianRequestTimeMs, maxRequestTime, standardErrorMs * 100.0 / meanRequestTimeMs);
                        totalRequests += iterationRequests;
                    }

                    Console.WriteLine();
                    Console.WriteLine("Tip: If you only care about startup performance, use the -skipSteadyState argument to skip these measurements");
                }
            }
        }

        private static void MeasureThroughput(HttpClient client, string url, int countRequests, out double batchTotalTimeMs, out double minRequestTimeMs, out double meanRequestTimeMs, out double medianRequestTimeMs, out double maxRequestTimeMs, out double standardErrorMs)
        {
            double[] requestTimes = new double[countRequests];
            var requestTime = Stopwatch.StartNew();

            for (int i = 0; i < countRequests; i++)
            {
                requestTime.Restart();
                var response = client.GetAsync(url).Result;
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
            double sampleStandardDeviation = Math.Sqrt(requestTimes.Select(x => (x - meanRequestTimeMsCopy) * (x - meanRequestTimeMsCopy)).Sum() / (countRequests - 1));
            standardErrorMs = sampleStandardDeviation / Math.Sqrt(countRequests);
        }

        public void VerifyLibraryLocation()
        {
            var hosting = typeof(WebHostBuilder).GetTypeInfo().Assembly.Location;
            var musicStore = typeof(JitBenchHelper).GetTypeInfo().Assembly.Location;

            if (Path.GetDirectoryName(hosting) == Path.GetDirectoryName(musicStore))
            {
                Console.WriteLine("ASP.NET loaded from bin. This is a bug if you wanted crossgen");
                Console.WriteLine("ASP.NET loaded from bin. This is a bug if you wanted crossgen");
                Console.WriteLine("ASP.NET loaded from bin. This is a bug if you wanted crossgen");
            }
        }
    }
}