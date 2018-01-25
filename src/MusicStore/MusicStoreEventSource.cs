using System.Diagnostics.Tracing;

[EventSource(Name="MusicStore")]
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