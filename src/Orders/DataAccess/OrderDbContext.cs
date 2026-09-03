using Microsoft.EntityFrameworkCore;
using Orders.DataAccess.DTOs;

namespace Orders.DataAccess;

public class OrderDbContext(DbContextOptions<OrderDbContext> options) : DbContext(options)
{
    public DbSet<OrderDto> Orders => Set<OrderDto>();

    public DbSet<OrderDetailDto> Details => Set<OrderDetailDto>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
    }
}