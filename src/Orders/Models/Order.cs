namespace Orders.Models;

/// <summary>
///     Represents a request for a specific order.
/// </summary>
/// <param name="OrderId">The ID of the order to be returned.</param>
public sealed record GetOrderRequest(Guid OrderId);

/// <summary>
///     Represents an order that is to be placed.
/// </summary>
/// <param name="CustomerName">The name of the customer placing the order.</param>
/// <param name="Items">The line items to be ordered.</param>
public sealed record CreateOrderRequest(string CustomerName, IReadOnlyList<OrderLineItem> Items);

/// <summary>
///     Represents a request to delete an order.
/// </summary>
/// <param name="OrderId">The ID of the order to be deleted</param>
public sealed record DeleteOrderRequest(Guid OrderId);

/// <summary>
///     Represents the results of a request to return an order.
/// </summary>
/// <param name="OrderId">The order ID.</param>
/// <param name="CustomerName">The custom who made the order.</param>
/// <param name="Items">The line items of the order.</param>
public sealed record OrderResponse(Guid OrderId, string CustomerName, IReadOnlyList<OrderLineItem> Items);

/// <summary>
///     Represents an order line item.
/// </summary>
/// <param name="ProductName">The product being ordered.</param>
/// <param name="Qty">The quantity to be ordered.</param>
public sealed record OrderLineItem(string ProductName, int Qty);