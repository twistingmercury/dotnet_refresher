using System.Diagnostics;

namespace Orders.Tests.BlackBox;

public sealed class OrdersApiFixture : IAsyncLifetime
{
    public HttpClient Client { get; } = new()
    {
        BaseAddress = new Uri(
            Environment.GetEnvironmentVariable("ORDERS_API_BASE_URL") ?? "http://localhost:3033"),
        Timeout = TimeSpan.FromSeconds(10)
    };

    public async Task InitializeAsync()
    {
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(60));
        var elapsed = Stopwatch.StartNew();
        var lastFailure = "No response received.";

        while (!deadline.IsCancellationRequested)
        {
            try
            {
                using var response = await Client.GetAsync("/orders/get", deadline.Token);
                if (response.IsSuccessStatusCode)
                {
                    return;
                }

                var body = await response.Content.ReadAsStringAsync(deadline.Token);
                lastFailure = $"HTTP {(int)response.StatusCode} {response.ReasonPhrase}: {body}";
            }
            catch (Exception exception) when (exception is HttpRequestException or OperationCanceledException)
            {
                lastFailure = exception.Message;
            }

            try
            {
                await Task.Delay(TimeSpan.FromSeconds(1), deadline.Token);
            }
            catch (OperationCanceledException) when (deadline.IsCancellationRequested)
            {
                break;
            }
        }

        Client.Dispose();
        throw new InvalidOperationException(
            $"Orders API at {Client.BaseAddress} was not ready after {elapsed.Elapsed.TotalSeconds:F1} seconds. " +
            $"GET /orders/get last failed with: {lastFailure}");
    }

    public Task DisposeAsync()
    {
        Client.Dispose();
        return Task.CompletedTask;
    }
}
