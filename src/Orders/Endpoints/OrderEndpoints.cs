using Microsoft.AspNetCore.Http.HttpResults;
using Orders.Handlers;
using Orders.Models;

namespace Orders.Endpoints;

public static class OrderEndpoints
{
    public static IEndpointRouteBuilder MapOrderEvents(this IEndpointRouteBuilder endpoints)
    {
        var groups = endpoints
            .MapGroup("/orders")
            .WithTags("Orders");

        groups.MapGet("/get/{id:guid}", GetOrderAsync);
        groups.MapPost("/create", CreateOrderAsync);
        groups.MapDelete("/delete/{id:guid}", DeleteOrderAsync);

        return endpoints;
    }

    public static async Task<Results<Ok<OrderResponse>, BadRequest, NotFound, ProblemHttpResult>> GetOrderAsync(
        Guid id, IOrderHandler handler, CancellationToken cancellationToken = default)
    {
        if (id == Guid.Empty) return TypedResults.BadRequest();

        var response = await handler.GetOrderAsync(id, cancellationToken);

        if (response is null) return TypedResults.NotFound();

        return TypedResults.Ok(response);
    }

    public static async Task<Results<Created<OrderResponse>, BadRequest, ProblemHttpResult>> CreateOrderAsync(
        CreateOrderRequest createRequest, IOrderHandler handler, CancellationToken cancellationToken = default)
    {
        if (createRequest.Items.Count == 0) return TypedResults.BadRequest();

        var response = await handler.CreateOrderAsync(createRequest, cancellationToken);

        if (response is null) return TypedResults.Problem(statusCode: StatusCodes.Status502BadGateway);

        return TypedResults.Created(
            $"/orders/get/{response.OrderId}",
            response);
    }

    public static async Task<Results<NoContent, BadRequest, ProblemHttpResult>> DeleteOrderAsync(
        Guid id, IOrderHandler handler, CancellationToken cancellationToken = default)
    {
        return TypedResults.Problem(
            statusCode: StatusCodes.Status501NotImplemented,
            title: "GetOrderAsync not implemented");
    }
}