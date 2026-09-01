namespace Orders;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        builder.Services.AddOpenApi();

        var app = builder.Build();

        app.MapGet("/", () => "Hello World!");

        app.Run();
    }
}