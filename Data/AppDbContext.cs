using Microsoft.EntityFrameworkCore;
using PlannerAPI.Models;

namespace PlannerAPI.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<Project> Projects => Set<Project>();
    public DbSet<TaskItem> Tasks => Set<TaskItem>();
    public DbSet<Dependency> Dependencies => Set<Dependency>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Dependency>()
            .HasOne(d => d.Predecessor)
            .WithMany(t => t.Successors)
            .HasForeignKey(d => d.PredecessorId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Dependency>()
            .HasOne(d => d.Successor)
            .WithMany(t => t.Predecessors)
            .HasForeignKey(d => d.SuccessorId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}