using Microsoft.EntityFrameworkCore;
using PlannerAPI.Models;

namespace PlannerAPI.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }

        public DbSet<Project> Projects => Set<Project>();
        public DbSet<PlannerTask> Tasks => Set<PlannerTask>();
        public DbSet<TaskDependency> TaskDependencies => Set<TaskDependency>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<PlannerTask>().ToTable("PlannerTasks");

            // Project -> PlannerTasks (cascade delete OK)
            modelBuilder.Entity<PlannerTask>()
                .HasOne(t => t.Project)
                .WithMany(p => p.Tasks)
                .HasForeignKey(t => t.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);

            // TaskDependency -> Successor
            modelBuilder.Entity<TaskDependency>()
                .HasOne(td => td.Successor)
                .WithMany(t => t.Predecessors)
                .HasForeignKey(td => td.SuccessorId)
                .OnDelete(DeleteBehavior.Restrict);

            // TaskDependency -> Predecessor
            modelBuilder.Entity<TaskDependency>()
                .HasOne(td => td.Predecessor)
                .WithMany(t => t.Successors)
                .HasForeignKey(td => td.PredecessorId)
                .OnDelete(DeleteBehavior.Restrict);

            // éviter doublons DB
            modelBuilder.Entity<TaskDependency>()
                .HasIndex(td => new { td.PredecessorId, td.SuccessorId, td.Type })
                .IsUnique();
        }
    }
}