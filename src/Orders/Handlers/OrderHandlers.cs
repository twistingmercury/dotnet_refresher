using Microsoft.EntityFrameworkCore;
using Orders.DataAccess.DTOs;
using Orders.DataAccess;
using Orders.Models;

namespace Orders.Handlers;

public interface IOrderHandler
{
    Task<OrderResponse[]> GetAllOrdersAsync();

    Task<OrderResponse?> GetOrderAsync(Guid orderId, CancellationToken cancellationToken);

    Task<OrderResponse?> CreateOrderAsync(
        CreateOrderRequest createRequest, CancellationToken cancellationToken = default);

    Task DeleteOrderAsync(Guid orderId, CancellationToken cancellationToken = default);
}


public class OrderHandler(OrderDbContext dbContext) : IOrderHandler
{

    public async Task<OrderResponse[]> GetAllOrdersAsync()
    {
        var orders = await dbContext.Orders
        .AsNoTracking()
        .Include(order => order.Details)
        .ToArrayAsync();

        return orders.Select(order => new OrderResponse(
          order.OrderId,
          order.CustomerName,
          order.Details.Select(detail => new OrderLineItem(
              detail.ProductName,
              detail.Qty))
              .ToArray()))
          .ToArray();
    }

    public async Task<OrderResponse?> GetOrderAsync(Guid orderId, CancellationToken cancellationToken)
    {
        var order = await dbContext.Orders
            .AsNoTracking()
            .Include(order => order.Details)
            .SingleOrDefaultAsync(o => o.OrderId == orderId, cancellationToken);

        if (order is null) return null;

        return new OrderResponse(
            order.OrderId,
            order.CustomerName,
            order.Details.Select(detail => new OrderLineItem(
              detail.ProductName,
              detail.Qty))
              .ToArray());
    }

    public async Task<OrderResponse?> CreateOrderAsync(
        CreateOrderRequest createRequest, CancellationToken cancellationToken = default)
    {
        var orderId = Guid.NewGuid();
        var timestamp = DateTimeOffset.UtcNow;

        var details = createRequest.Items
            .Select((item, index) => new OrderDetailDto(
                orderId,
                index + 1,
                item.ProductName,
                item.Qty,
                timestamp,
                timestamp))
            .ToArray();

        var order = new OrderDto(
            orderId,
            createRequest.CustomerName,
            timestamp,
            timestamp)
        {
            Details = details.ToList()
        };

        dbContext.Orders.Add(order);
        dbContext.Details.AddRange(details);

        await dbContext.SaveChangesAsync(cancellationToken);

        return new OrderResponse(
            order.OrderId,
            order.CustomerName,
            details.Select(detail => new OrderLineItem(
                    detail.ProductName,
                    detail.Qty))
                .ToArray());
    }

    public async Task DeleteOrderAsync(Guid orderId, CancellationToken cancellationToken = default)
    {
        _ = await dbContext.Orders
            .Where(order => order.OrderId == orderId)
            .ExecuteDeleteAsync(cancellationToken);
    }
}
