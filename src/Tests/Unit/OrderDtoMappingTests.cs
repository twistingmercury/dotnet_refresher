using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using Orders.DataAccess;
using Orders.DataAccess.DTOs;

namespace Orders.Tests.Unit;

public class OrderDtoMappingTests
{
    [Fact]
    public void Model_InitializesWithBindableDtoConstructors()
    {
        using var context = CreateContext();

        // Model initialization validates constructor binding without opening a connection.
        Assert.NotNull(context.Model.FindEntityType(typeof(OrderDto)));
        Assert.NotNull(context.Model.FindEntityType(typeof(OrderDetailDto)));
    }

    [Theory]
    [InlineData(typeof(OrderDto), "orders", nameof(OrderDto.OrderId), "order_id", "uuid")]
    [InlineData(typeof(OrderDto), "orders", nameof(OrderDto.CustomerName), "customer_name", "text")]
    [InlineData(typeof(OrderDto), "orders", nameof(OrderDto.CreatedDate), "created_date", "timestamp with time zone")]
    [InlineData(typeof(OrderDto), "orders", nameof(OrderDto.UpdatedDate), "updated_date", "timestamp with time zone")]
    [InlineData(typeof(OrderDetailDto), "order_details", nameof(OrderDetailDto.OrderId), "order_id", "uuid")]
    [InlineData(typeof(OrderDetailDto), "order_details", nameof(OrderDetailDto.LineNumber), "line_number", "integer")]
    [InlineData(typeof(OrderDetailDto), "order_details", nameof(OrderDetailDto.ProductName), "product_name", "text")]
    [InlineData(typeof(OrderDetailDto), "order_details", nameof(OrderDetailDto.Qty), "qty", "integer")]
    [InlineData(typeof(OrderDetailDto), "order_details", nameof(OrderDetailDto.CreatedDate), "created_date", "timestamp with time zone")]
    [InlineData(typeof(OrderDetailDto), "order_details", nameof(OrderDetailDto.UpdatedDate), "updated_date", "timestamp with time zone")]
    public void Model_MapsRequiredColumnsToPostgresSchema(
        Type dtoType, string tableName, string propertyName, string columnName, string columnType)
    {
        using var context = CreateContext();
        var entity = context.Model.FindEntityType(dtoType);
        Assert.NotNull(entity);
        var property = entity.FindProperty(propertyName);
        Assert.NotNull(property);

        Assert.Equal(tableName, entity.GetTableName());
        var table = StoreObjectIdentifier.Table(tableName, entity.GetSchema());
        Assert.Equal(columnName, property.GetColumnName(table));
        Assert.Equal(columnType, property.GetColumnType());
        Assert.False(property.IsNullable);
    }

    [Fact]
    public void Model_UsesOrderIdAsOrderPrimaryKey()
    {
        using var context = CreateContext();
        var entity = context.Model.FindEntityType(typeof(OrderDto));
        Assert.NotNull(entity);
        var key = entity.FindPrimaryKey();
        Assert.NotNull(key);

        Assert.Equal(nameof(OrderDto.OrderId), Assert.Single(key.Properties).Name);
    }

    [Fact]
    public void Model_UsesOrderIdAndLineNumberAsDetailPrimaryKey()
    {
        using var context = CreateContext();
        var entity = context.Model.FindEntityType(typeof(OrderDetailDto));
        Assert.NotNull(entity);
        var key = entity.FindPrimaryKey();
        Assert.NotNull(key);

        Assert.Equal(
            new[] { nameof(OrderDetailDto.OrderId), nameof(OrderDetailDto.LineNumber) },
            key.Properties.Select(property => property.Name));
    }

    [Fact]
    public void Model_MapsDetailsToRequiredOrderForeignKeyWithCascadeDelete()
    {
        using var context = CreateContext();
        var order = context.Model.FindEntityType(typeof(OrderDto));
        var detail = context.Model.FindEntityType(typeof(OrderDetailDto));
        Assert.NotNull(order);
        Assert.NotNull(detail);

        var foreignKey = Assert.Single(detail.GetForeignKeys());
        Assert.Same(order, foreignKey.PrincipalEntityType);
        Assert.Same(order.FindPrimaryKey(), foreignKey.PrincipalKey);
        Assert.Equal(nameof(OrderDetailDto.OrderId), Assert.Single(foreignKey.Properties).Name);
        Assert.True(foreignKey.IsRequired);
        Assert.False(foreignKey.IsUnique);
        Assert.Equal(DeleteBehavior.Cascade, foreignKey.DeleteBehavior);

        var navigation = order.FindNavigation(nameof(OrderDto.Details));
        Assert.NotNull(navigation);
        Assert.True(navigation.IsCollection);
        Assert.Same(foreignKey, navigation.ForeignKey);
        Assert.DoesNotContain(detail.GetProperties(), property => property.IsShadowProperty());
    }

    [Fact]
    public void AddOrder_TracksDetailsAndPopulatesTheirForeignKeys()
    {
        using var context = CreateContext();
        var timestamp = DateTimeOffset.UtcNow;
        var firstDetail = new OrderDetailDto(Guid.Empty, 1, "Keyboard", 2, timestamp, timestamp);
        var secondDetail = new OrderDetailDto(Guid.Empty, 2, "Mouse", 1, timestamp, timestamp);
        var order = new OrderDto(Guid.NewGuid(), "Ada Lovelace", timestamp, timestamp)
        {
            Details = [firstDetail, secondDetail]
        };

        context.Orders.Add(order);

        Assert.Equal(EntityState.Added, context.Entry(order).State);
        Assert.Equal(3, context.ChangeTracker.Entries().Count());
        Assert.All(order.Details, detail =>
        {
            Assert.Equal(order.OrderId, detail.OrderId);
            Assert.Equal(EntityState.Added, context.Entry(detail).State);
        });
        Assert.Equal(new[] { 1, 2 }, order.Details.Select(detail => detail.LineNumber));
    }

    [Fact]
    public void NewOrders_HaveIndependentMutableDetailsCollections()
    {
        var timestamp = DateTimeOffset.UtcNow;
        var first = new OrderDto(Guid.NewGuid(), "Ada Lovelace", timestamp, timestamp);
        var second = new OrderDto(Guid.NewGuid(), "Grace Hopper", timestamp, timestamp);
        var detail = new OrderDetailDto(first.OrderId, 1, "Keyboard", 2, timestamp, timestamp);

        Assert.Empty(first.Details);
        Assert.Empty(second.Details);
        Assert.NotSame(first.Details, second.Details);

        first.Details.Add(detail);

        Assert.Same(detail, Assert.Single(first.Details));
        Assert.Empty(second.Details);
    }

    private static OrderDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseNpgsql("Host=localhost;Database=orders_model_tests;Username=unused;Password=unused")
            .Options;

        return new OrderDbContext(options);
    }
}
