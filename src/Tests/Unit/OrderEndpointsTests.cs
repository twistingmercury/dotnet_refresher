using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Orders.Endpoints;
using Orders.Handlers;
using Orders.Models;

namespace Orders.Tests.Unit;

public class OrderEndpointsTests
{
    [Fact]
    public async Task GetOrderAsync_EmptyId_ReturnsBadRequestWithoutCallingHandler()
    {
        var handler = new StubOrderHandler();

        var result = await OrderEndpoints.GetOrderAsync(Guid.Empty, handler);

        Assert.IsType<BadRequest>(result.Result);
    }

    [Fact]
    public async Task GetOrderAsync_OrderDoesNotExist_ReturnsNotFound()
    {
        var handler = new StubOrderHandler
        {
            GetOrder = (_, _) => Task.FromResult<OrderResponse?>(null)
        };

        var result = await OrderEndpoints.GetOrderAsync(Guid.NewGuid(), handler);

        Assert.IsType<NotFound>(result.Result);
    }

    [Fact]
    public async Task GetOrderAsync_OrderExists_PassesIdAndTokenAndReturnsOrder()
    {
        var orderId = Guid.NewGuid();
        var response = new OrderResponse(orderId, "Ada Lovelace", [new("Keyboard", 2)]);
        using var cancellation = new CancellationTokenSource();
        var calls = 0;
        var handler = new StubOrderHandler
        {
            GetOrder = (id, token) =>
            {
                calls++;
                Assert.Equal(orderId, id);
                Assert.Equal(cancellation.Token, token);
                return Task.FromResult<OrderResponse?>(response);
            }
        };

        var result = await OrderEndpoints.GetOrderAsync(orderId, handler, cancellation.Token);

        var ok = Assert.IsType<Ok<OrderResponse>>(result.Result);
        Assert.Same(response, ok.Value);
        Assert.Equal(1, calls);
    }

    [Fact]
    public async Task CreateOrderAsync_EmptyItems_ReturnsBadRequestWithoutCallingHandler()
    {
        var request = new CreateOrderRequest("Ada Lovelace", []);
        var handler = new StubOrderHandler();

        var result = await OrderEndpoints.CreateOrderAsync(request, handler);

        Assert.IsType<BadRequest>(result.Result);
    }

    [Fact]
    public async Task CreateOrderAsync_HandlerReturnsNull_ReturnsBadGateway()
    {
        var request = new CreateOrderRequest("Ada Lovelace", [new("Keyboard", 2)]);
        var handler = new StubOrderHandler
        {
            CreateOrder = (_, _) => Task.FromResult<OrderResponse?>(null)
        };

        var result = await OrderEndpoints.CreateOrderAsync(request, handler);

        var problem = Assert.IsType<ProblemHttpResult>(result.Result);
        Assert.Equal(StatusCodes.Status502BadGateway, problem.StatusCode);
        Assert.Equal(StatusCodes.Status502BadGateway, problem.ProblemDetails.Status);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(3)]
    public async Task CreateOrderAsync_ValidItems_PassesRequestAndTokenAndReturnsCreatedOrder(int itemCount)
    {
        var items = Enumerable.Range(1, itemCount)
            .Select(index => new OrderLineItem($"Product {index}", index))
            .ToArray();
        var request = new CreateOrderRequest("Ada Lovelace", items);
        var response = new OrderResponse(Guid.NewGuid(), request.CustomerName, items);
        using var cancellation = new CancellationTokenSource();
        var calls = 0;
        var handler = new StubOrderHandler
        {
            CreateOrder = (receivedRequest, token) =>
            {
                calls++;
                Assert.Same(request, receivedRequest);
                Assert.Equal(cancellation.Token, token);
                return Task.FromResult<OrderResponse?>(response);
            }
        };

        var result = await OrderEndpoints.CreateOrderAsync(request, handler, cancellation.Token);

        var created = Assert.IsType<Created<OrderResponse>>(result.Result);
        Assert.Equal($"/orders/get/{response.OrderId}", created.Location);
        Assert.Same(response, created.Value);
        Assert.Equal(1, calls);
    }

    [Fact]
    public async Task GetOrderAsync_HandlerCanceled_PropagatesCancellation()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var handler = new StubOrderHandler
        {
            GetOrder = (_, token) => Task.FromCanceled<OrderResponse?>(token)
        };

        var exception = await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            OrderEndpoints.GetOrderAsync(Guid.NewGuid(), handler, cancellation.Token));

        Assert.Equal(cancellation.Token, exception.CancellationToken);
    }

    [Fact]
    public async Task CreateOrderAsync_HandlerCanceled_PropagatesCancellation()
    {
        var request = new CreateOrderRequest("Ada Lovelace", [new("Keyboard", 2)]);
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var handler = new StubOrderHandler
        {
            CreateOrder = (_, token) => Task.FromCanceled<OrderResponse?>(token)
        };

        var exception = await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            OrderEndpoints.CreateOrderAsync(request, handler, cancellation.Token));

        Assert.Equal(cancellation.Token, exception.CancellationToken);
    }

    // Unconfigured methods throw so validation tests also catch unexpected handler calls.
    private sealed class StubOrderHandler : IOrderHandler
    {
        public Func<Guid, CancellationToken, Task<OrderResponse?>> GetOrder { get; init; } =
            (_, _) => throw new InvalidOperationException("Unexpected GetOrderAsync call.");

        public Func<CreateOrderRequest, CancellationToken, Task<OrderResponse?>> CreateOrder { get; init; } =
            (_, _) => throw new InvalidOperationException("Unexpected CreateOrderAsync call.");

        public Task<OrderResponse?> GetOrderAsync(Guid orderId, CancellationToken cancellationToken) =>
            GetOrder(orderId, cancellationToken);

        public Task<OrderResponse?> CreateOrderAsync(
            CreateOrderRequest createRequest, CancellationToken cancellationToken = default) =>
            CreateOrder(createRequest, cancellationToken);

        public Task DeleteOrderAsync(Guid orderId, CancellationToken cancellationToken = default) =>
            throw new InvalidOperationException("Unexpected DeleteOrderAsync call.");
    }
}
