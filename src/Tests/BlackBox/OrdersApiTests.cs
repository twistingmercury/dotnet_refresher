using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;

namespace Orders.Tests.BlackBox;

public sealed class OrdersApiTests(OrdersApiFixture fixture) : IClassFixture<OrdersApiFixture>
{
    [Fact]
    public async Task CreateOrder_CanReadItFromLocationAndFindItInTheList()
    {
        var customerName = $"black-box-{Guid.NewGuid():N}";
        LineItem[] items = [new("Notebook", 2), new("Pencil", 5)];

        using var createResponse = await fixture.Client.PostAsJsonAsync(
            "/orders/create", new { customerName, items });
        await AssertStatusAsync(HttpStatusCode.Created, createResponse);
        var created = await ReadOrderAsync(createResponse);
        Assert.NotEqual(Guid.Empty, created.OrderId);
        AssertOrderContents(customerName, items, created);

        Assert.NotNull(createResponse.Headers.Location);
        var location = new Uri(fixture.Client.BaseAddress!, createResponse.Headers.Location);
        Assert.Equal(fixture.Client.BaseAddress!.Authority, location.Authority);
        Assert.Equal($"/orders/get/{created.OrderId}", location.AbsolutePath);

        using var getResponse = await fixture.Client.GetAsync(location);
        await AssertStatusAsync(HttpStatusCode.OK, getResponse);
        var retrieved = await ReadOrderAsync(getResponse);
        Assert.Equal(created.OrderId, retrieved.OrderId);
        AssertOrderContents(customerName, items, retrieved);

        using var listResponse = await fixture.Client.GetAsync("/orders/get");
        await AssertStatusAsync(HttpStatusCode.OK, listResponse);
        var orders = await listResponse.Content.ReadFromJsonAsync<OrderDocument[]>();
        Assert.NotNull(orders);
        var listed = Assert.Single(orders, order => order.OrderId == created.OrderId);
        AssertOrderContents(customerName, items, listed);
    }

    [Fact]
    public async Task GetOrder_UnknownId_ReturnsNotFound()
    {
        using var response = await fixture.Client.GetAsync($"/orders/get/{Guid.NewGuid()}");
        await AssertStatusAsync(HttpStatusCode.NotFound, response);
    }

    [Theory]
    [InlineData("00000000-0000-0000-0000-000000000000", HttpStatusCode.BadRequest)]
    [InlineData("not-a-guid", HttpStatusCode.NotFound)]
    public async Task GetOrder_InvalidId_ReturnsExpectedStatus(string id, HttpStatusCode expected)
    {
        using var response = await fixture.Client.GetAsync($"/orders/get/{id}");
        await AssertStatusAsync(expected, response);
    }

    [Fact]
    public async Task CreateOrder_EmptyItems_ReturnsBadRequest()
    {
        using var response = await fixture.Client.PostAsJsonAsync(
            "/orders/create", new { customerName = $"black-box-{Guid.NewGuid():N}", items = Array.Empty<LineItem>() });
        await AssertStatusAsync(HttpStatusCode.BadRequest, response);
    }

    [Fact]
    public async Task CreateOrder_InvalidJson_ReturnsBadRequest()
    {
        using var content = new StringContent("{", Encoding.UTF8, "application/json");
        using var response = await fixture.Client.PostAsync("/orders/create", content);
        await AssertStatusAsync(HttpStatusCode.BadRequest, response);
    }

    [Fact]
    public async Task OpenApi_DescribesOrderOperationsAndJsonContracts()
    {
        using var response = await fixture.Client.GetAsync("/openapi/v1.json");
        await AssertStatusAsync(HttpStatusCode.OK, response);
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var root = document.RootElement;
        Assert.StartsWith("3.", root.GetProperty("openapi").GetString());

        var paths = root.GetProperty("paths");
        var list = paths.GetProperty("/orders/get").GetProperty("get");
        var get = paths.GetProperty("/orders/get/{id}").GetProperty("get");
        var create = paths.GetProperty("/orders/create").GetProperty("post");
        Assert.True(list.GetProperty("responses").TryGetProperty("200", out _));
        Assert.True(get.GetProperty("responses").TryGetProperty("200", out _));
        Assert.True(get.GetProperty("responses").TryGetProperty("404", out _));
        Assert.True(create.GetProperty("responses").TryGetProperty("201", out _));

        var requestSchema = ResolveSchema(root, create.GetProperty("requestBody")
            .GetProperty("content").GetProperty("application/json").GetProperty("schema"));
        Assert.True(requestSchema.GetProperty("properties").TryGetProperty("customerName", out _));
        Assert.Equal("array", requestSchema.GetProperty("properties").GetProperty("items")
            .GetProperty("type").GetString());

        var responseSchema = ResolveSchema(root, get.GetProperty("responses").GetProperty("200")
            .GetProperty("content").GetProperty("application/json").GetProperty("schema"));
        Assert.Equal("uuid", responseSchema.GetProperty("properties").GetProperty("orderId")
            .GetProperty("format").GetString());
        Assert.True(responseSchema.GetProperty("properties").TryGetProperty("customerName", out _));
        Assert.Equal("array", responseSchema.GetProperty("properties").GetProperty("items")
            .GetProperty("type").GetString());
    }

    private static JsonElement ResolveSchema(JsonElement root, JsonElement schema)
    {
        if (!schema.TryGetProperty("$ref", out var reference))
        {
            return schema;
        }

        const string prefix = "#/components/schemas/";
        var path = reference.GetString();
        Assert.NotNull(path);
        Assert.StartsWith(prefix, path);
        return root.GetProperty("components").GetProperty("schemas").GetProperty(path[prefix.Length..]);
    }

    private static async Task AssertStatusAsync(HttpStatusCode expected, HttpResponseMessage response)
    {
        var body = await response.Content.ReadAsStringAsync();
        Assert.True(response.StatusCode == expected,
            $"{response.RequestMessage?.Method} {response.RequestMessage?.RequestUri}: " +
            $"expected {(int)expected}, received {(int)response.StatusCode} {response.ReasonPhrase}. Body: {body}");
    }

    private static async Task<OrderDocument> ReadOrderAsync(HttpResponseMessage response)
    {
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
        var order = await response.Content.ReadFromJsonAsync<OrderDocument>();
        Assert.NotNull(order);
        return order;
    }

    private static void AssertOrderContents(string customerName, LineItem[] expectedItems, OrderDocument actual)
    {
        Assert.Equal(customerName, actual.CustomerName);
        Assert.NotNull(actual.Items);
        Assert.Equal(expectedItems.OrderBy(item => item.ProductName).ThenBy(item => item.Qty),
            actual.Items.OrderBy(item => item.ProductName).ThenBy(item => item.Qty));
    }

    public sealed record LineItem(string ProductName, int Qty);

    public sealed record OrderDocument(Guid OrderId, string CustomerName, LineItem[] Items);
}
