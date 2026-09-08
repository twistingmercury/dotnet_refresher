
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace Orders.DataAccess.DTOs;

[Table("orders")]
public sealed record OrderDto(
    [property: Key, Column("order_id")] Guid OrderId,
    [property: Column("customer_name")] string CustomerName,
    [property: Column("created_date")] DateTimeOffset CreatedDate,
    [property: Column("updated_date")] DateTimeOffset UpdatedDate)
{
    [ForeignKey(nameof(OrderDetailDto.OrderId))]
    public ICollection<OrderDetailDto> Details { get; init; }
        = new List<OrderDetailDto>();
}

[Table("order_details")]
[PrimaryKey(nameof(OrderId), nameof(LineNumber))]
public sealed record OrderDetailDto(
    [property: Column("order_id")] Guid OrderId,
    [property: Column("line_number")] int LineNumber,
    [property: Column("product_name")] string ProductName,
    [property: Column("qty")] int Qty,
    [property: Column("created_date")] DateTimeOffset CreatedDate,
    [property: Column("updated_date")] DateTimeOffset UpdatedDate);