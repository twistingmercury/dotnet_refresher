using Microsoft.EntityFrameworkCore;
using Orders.DataAccess.DTOs;
using Orders.DataAccess;
using Orders.Models;

namespace Orders.Handlers;

public interface IOrderHandler
{
    Task<OrderResponse?> GetOrderAsync(Guid orderId, CancellationToken cancellationToken);

    Task<OrderResponse?> CreateOrderAsync(
        CreateOrderRequest createRequest, CancellationToken cancellationToken = default);

    Task DeleteOrderAsync(Guid orderId, CancellationToken cancellationToken = default);
}

public class OrderHandler(OrderDbContext dbContext) : IOrderHandler
{
    public async Task<OrderResponse?> GetOrderAsync(Guid orderId, CancellationToken cancellationToken)
    {
        var order = await dbContext.Orders
            .AsNoTracking()
            .SingleOrDefaultAsync(o => o.OrderId == orderId, cancellationToken);

        if (order is null) return null;

        var details = await dbContext.Details
            .AsNoTracking()
            .Where(detail => detail.OrderId == orderId)
            .OrderBy(detail => detail.LineNumber)
            .Select(detail => new OrderLineItem(
                detail.ProductName,
                detail.Qty))
            .ToListAsync(cancellationToken);

        return new OrderResponse(
            order.OrderId,
            order.CustomerName,
            details);
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
            timestamp,
            details);

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