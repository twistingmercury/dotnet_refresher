using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Http.HttpResults;
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

        groups.MapPost("/create", CreateOrderAscync);

        groups.MapDelete("/delete/{id:guid}", DeleteOrderAsync);

        return endpoints;
    }

    public static async Task<Results<Ok<GetOrderResponse>, NotFound, ProblemHttpResult>> GetOrderAsync(GetOrderRequest orderRequest)
    {
        return TypedResults.Problem(
            statusCode: StatusCodes.Status501NotImplemented,
            title: "GetOrderAsync not implemented");
    }

    public static async Task<IResult> CreateOrderAscync(CreateOrderRequest createRequest)
    {
        return TypedResults.Problem(
            statusCode: StatusCodes.Status501NotImplemented,
            title: "GetOrderAsync not implemented");
    }

    public static async Task<IResult> DeleteOrderAsync(DeleteOrderRequest deleteRequest)
    {
        return TypedResults.Problem(
            statusCode: StatusCodes.Status501NotImplemented,
            title: "GetOrderAsync not implemented");
    }
}
