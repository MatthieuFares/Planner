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
        public DbSet<Resource> Resources { get; set; }
        public DbSet<ResourceAssignment> ResourceAssignments { get; set; }

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

            modelBuilder.Entity<ResourceAssignment>()
                .HasOne(ra => ra.Task)
                .WithMany(t => t.ResourceAssignments)
                .HasForeignKey(ra => ra.TaskId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ResourceAssignment>()
                .HasOne(ra => ra.Resource)
                .WithMany(r => r.Assignments)
                .HasForeignKey(ra => ra.ResourceId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}