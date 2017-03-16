using System;
using System.Data.SqlClient;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Net.Http.Server;

namespace MusicStore
{
    public static class Program
    {
        public static void Main(string[] args)
        {
            // TODO: This is a workaround for https://github.com/dotnet/corefx/issues/17166
            // SQLClient does not connect to LocalDB without it
            AppContext.SetSwitch("System.Data.SqlClient.UseLegacyNetworkingOnWindows", true);
            
            var totalTime = Stopwatch.StartNew();

            var config = new ConfigurationBuilder()
                .AddCommandLine(args)
                .AddEnvironmentVariables(prefix: "ASPNETCORE_")
                .Build();

            var builder = new WebHostBuilder()
                .UseConfiguration(config)
                .UseIISIntegration()
                .UseContentRoot(Directory.GetCurrentDirectory())
                .UseStartup("MusicStore");

            if (string.Equals(builder.GetSetting("server"), "Microsoft.AspNetCore.Server.WebListener", System.StringComparison.Ordinal))
            {
                var environment = builder.GetSetting("environment") ??
                    Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");

                if (string.Equals(environment, "NtlmAuthentication", System.StringComparison.Ordinal))
                {
                    // Set up NTLM authentication for WebListener like below.
                    // For IIS and IISExpress: Use inetmgr to setup NTLM authentication on the application vDir or
                    // modify the applicationHost.config to enable NTLM.
                    builder.UseWebListener(options =>
                    {
                        options.Listener.AuthenticationManager.AuthenticationSchemes = AuthenticationSchemes.NTLM;
                    });
                }
                else
                {
                    builder.UseWebListener();
                }
            }
            else
            {
                builder.UseKestrel();
            }

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
                for(int i = 1; i <= 100; ++i)
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
        }
    }
}
