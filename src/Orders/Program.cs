using Orders.DataAccess;
using Orders.Endpoints;
using Microsoft.EntityFrameworkCore;
using Orders.Handlers;

namespace Orders;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

        builder.Services.AddDbContextPool<OrderDbContext>(options =>
            options.UseNpgsql(connectionString));

        builder.Services.AddScoped<IOrderHandler, OrderHandler>();

        var app = builder.Build();

        app.MapGet("/", () => "Hello World!");

        app.MapOrderEvents();

        app.Run();
    }
}