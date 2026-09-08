using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Moq;
using Orders.Endpoints;
using Orders.Handlers;
using Orders.Models;

namespace Orders.Tests.Unit;

public class OrderEndpointsTests
{
    [Theory]
    [InlineData(0)]
    [InlineData(2)]
    public async Task GetAllOrdersAsync_ReturnsOrdersFromHandler(int orderCount)
    {
        var responses = Enumerable.Range(1, orderCount)
            .Select(index => new OrderResponse(
                Guid.NewGuid(), $"Customer {index}", [new($"Product {index}", index)]))
            .ToArray();
        var handler = new Mock<IOrderHandler>(MockBehavior.Strict);
        handler.Setup(value => value.GetAllOrdersAsync()).ReturnsAsync(responses);

        var result = await OrderEndpoints.GetAllOrdersAsync(handler.Object);

        var ok = Assert.IsType<Ok<OrderResponse[]>>(result.Result);
        Assert.Same(responses, ok.Value);
        handler.Verify(value => value.GetAllOrdersAsync(), Times.Once);
    }

    [Fact]
    public async Task GetAllOrdersAsync_HandlerFails_PropagatesException()
    {
        var expected = new InvalidOperationException("Unable to retrieve orders.");
        var handler = new Mock<IOrderHandler>(MockBehavior.Strict);
        handler.Setup(value => value.GetAllOrdersAsync()).ThrowsAsync(expected);

        var exception = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            OrderEndpoints.GetAllOrdersAsync(handler.Object));

        Assert.Same(expected, exception);
    }

    [Fact]
    public async Task GetAllOrdersAsync_HandlerCanceled_PropagatesCancellation()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var handler = new Mock<IOrderHandler>(MockBehavior.Strict);
        handler.Setup(value => value.GetAllOrdersAsync())
            .Returns(Task.FromCanceled<OrderResponse[]>(cancellation.Token));

        var exception = await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            OrderEndpoints.GetAllOrdersAsync(handler.Object));

        Assert.Equal(cancellation.Token, exception.CancellationToken);
    }

    [Fact]
    public async Task GetOrderAsync_EmptyId_ReturnsBadRequestWithoutCallingHandler()
    {
        var handler = new Mock<IOrderHandler>(MockBehavior.Strict);

        var result = await OrderEndpoints.GetOrderAsync(Guid.Empty, handler.Object);

        Assert.IsType<BadRequest>(result.Result);
        handler.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task GetOrderAsync_OrderDoesNotExist_ReturnsNotFound()
    {
        var orderId = Guid.NewGuid();
        var handler = new Mock<IOrderHandler>(MockBehavior.Strict);
        handler.Setup(value => value.GetOrderAsync(orderId, CancellationToken.None))
            .ReturnsAsync((OrderResponse?)null);

        var result = await OrderEndpoints.GetOrderAsync(orderId, handler.Object);

        Assert.IsType<NotFound>(result.Result);
        handler.Verify(value => value.GetOrderAsync(orderId, CancellationToken.None), Times.Once);
    }

    [Fact]
    public async Task GetOrderAsync_OrderExists_PassesIdAndTokenAndReturnsOrder()
    {
        var orderId = Guid.NewGuid();
        var response = new OrderResponse(orderId, "Ada Lovelace", [new("Keyboard", 2)]);
        using var cancellation = new CancellationTokenSource();
        var handler = new Mock<IOrderHandler>(MockBehavior.Strict);
        handler.Setup(value => value.GetOrderAsync(orderId, cancellation.Token))
            .ReturnsAsync(response);

        var result = await OrderEndpoints.GetOrderAsync(orderId, handler.Object, cancellation.Token);

        var ok = Assert.IsType<Ok<OrderResponse>>(result.Result);
        Assert.Same(response, ok.Value);
        handler.Verify(value => value.GetOrderAsync(orderId, cancellation.Token), Times.Once);
    }

    [Fact]
    public async Task CreateOrderAsync_EmptyItems_ReturnsBadRequestWithoutCallingHandler()
    {
        var request = new CreateOrderRequest("Ada Lovelace", []);
        var handler = new Mock<IOrderHandler>(MockBehavior.Strict);

        var result = await OrderEndpoints.CreateOrderAsync(request, handler.Object);

        Assert.IsType<BadRequest>(result.Result);
        handler.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task CreateOrderAsync_HandlerReturnsNull_ReturnsBadGateway()
    {
        var request = new CreateOrderRequest("Ada Lovelace", [new("Keyboard", 2)]);
        var handler = new Mock<IOrderHandler>(MockBehavior.Strict);
        handler.Setup(value => value.CreateOrderAsync(
                It.Is<CreateOrderRequest>(received => ReferenceEquals(request, received)),
                CancellationToken.None))
            .ReturnsAsync((OrderResponse?)null);

        var result = await OrderEndpoints.CreateOrderAsync(request, handler.Object);

        var problem = Assert.IsType<ProblemHttpResult>(result.Result);
        Assert.Equal(StatusCodes.Status502BadGateway, problem.StatusCode);
        Assert.Equal(StatusCodes.Status502BadGateway, problem.ProblemDetails.Status);
        handler.Verify(value => value.CreateOrderAsync(
            It.Is<CreateOrderRequest>(received => ReferenceEquals(request, received)),
            CancellationToken.None), Times.Once);
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
        var handler = new Mock<IOrderHandler>(MockBehavior.Strict);
        handler.Setup(value => value.CreateOrderAsync(
                It.Is<CreateOrderRequest>(received => ReferenceEquals(request, received)),
                cancellation.Token))
            .ReturnsAsync(response);

        var result = await OrderEndpoints.CreateOrderAsync(request, handler.Object, cancellation.Token);

        var created = Assert.IsType<Created<OrderResponse>>(result.Result);
        Assert.Equal($"/orders/get/{response.OrderId}", created.Location);
        Assert.Same(response, created.Value);
        handler.Verify(value => value.CreateOrderAsync(
            It.Is<CreateOrderRequest>(received => ReferenceEquals(request, received)),
            cancellation.Token), Times.Once);
    }

    [Fact]
    public async Task GetOrderAsync_HandlerCanceled_PropagatesCancellation()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var orderId = Guid.NewGuid();
        var handler = new Mock<IOrderHandler>(MockBehavior.Strict);
        handler.Setup(value => value.GetOrderAsync(orderId, cancellation.Token))
            .Returns(Task.FromCanceled<OrderResponse?>(cancellation.Token));

        var exception = await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            OrderEndpoints.GetOrderAsync(orderId, handler.Object, cancellation.Token));

        Assert.Equal(cancellation.Token, exception.CancellationToken);
    }

    [Fact]
    public async Task CreateOrderAsync_HandlerCanceled_PropagatesCancellation()
    {
        var request = new CreateOrderRequest("Ada Lovelace", [new("Keyboard", 2)]);
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var handler = new Mock<IOrderHandler>(MockBehavior.Strict);
        handler.Setup(value => value.CreateOrderAsync(
                It.Is<CreateOrderRequest>(received => ReferenceEquals(request, received)),
                cancellation.Token))
            .Returns(Task.FromCanceled<OrderResponse?>(cancellation.Token));

        var exception = await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            OrderEndpoints.CreateOrderAsync(request, handler.Object, cancellation.Token));

        Assert.Equal(cancellation.Token, exception.CancellationToken);
    }
}
