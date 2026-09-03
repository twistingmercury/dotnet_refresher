namespace Orders.DataAccess.DTOs;

public sealed record OrderDto(
    Guid OrderId,
    string CustomerName,
    DateTimeOffset CreatedDate,
    DateTimeOffset UpdatedDate,
    IReadOnlyList<OrderDetailDto> Details);

public sealed record OrderDetailDto(
    Guid OrderId,
    int LineNumber,
    string ProductName,
    int Qty,
    DateTimeOffset CreatedDate,
    DateTimeOffset UpdatedDate);