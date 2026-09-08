using Orders.DataAccess;
using Orders.Endpoints;
using Microsoft.EntityFrameworkCore;
using Orders.Handlers;
using Scalar.AspNetCore;

namespace Orders;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);
        builder.Services.AddOpenApi();

        var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

        builder.Services.AddDbContextPool<OrderDbContext>(options =>
            options.UseNpgsql(connectionString));

        builder.Services.AddScoped<IOrderHandler, OrderHandler>();

        var app = builder.Build();
        app.MapOpenApi();
        app.UseSwaggerUI(options =>
        {
            options.SwaggerEndpoint("/openapi/v1.json", "v1");
        });

        app.MapOrderEvents();

        app.Run();
    }
}