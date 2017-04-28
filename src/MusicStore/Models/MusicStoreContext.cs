using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;

namespace MusicStore.Models
{
    public class ApplicationUser : IdentityUser { }

    public class MusicStoreContext : IdentityDbContext<ApplicationUser>
    {
        public MusicStoreContext(DbContextOptions<MusicStoreContext> options)
            : base(options)
        {
        }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);
            
            builder.Entity<Album>().Property(a => a.Price).ForSqlServerHasColumnType("money");
            builder.Entity<Order>().Property(o => o.Total).ForSqlServerHasColumnType("money");
            builder.Entity<OrderDetail>().Property(o => o.UnitPrice).ForSqlServerHasColumnType("money");
        }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            base.OnConfiguring(optionsBuilder);

            // Suppresses a warning about DbContext.Genres.Select(g => g.Name).Take(9).ToListAsync()
            optionsBuilder.ConfigureWarnings(w => w.Ignore(CoreEventId.QueryModelCompiling));
        }

        public DbSet<Album> Albums { get; set; }
        public DbSet<Artist> Artists { get; set; }
        public DbSet<Order> Orders { get; set; }
        public DbSet<Genre> Genres { get; set; }
        public DbSet<CartItem> CartItems { get; set; }
        public DbSet<OrderDetail> OrderDetails { get; set; }
    }
}
