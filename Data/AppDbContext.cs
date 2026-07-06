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
        public DbSet<ResourceGroup> ResourceGroups { get; set; }
        public DbSet<ResourceGroupMember> ResourceGroupMembers { get; set; }
        public DbSet<PlanningItem> PlanningItems { get; set; }
        public DbSet<ProjectCalendar> ProjectCalendars { get; set; }
        public DbSet<ProjectCalendarException> ProjectCalendarExceptions { get; set; }
        public DbSet<ProjectBaseline> ProjectBaselines { get; set; }
        public DbSet<ProjectBaselineTask> ProjectBaselineTasks { get; set; }        

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<PlannerTask>().ToTable("PlannerTasks");

            // Project -> PlannerTasks
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

            // Éviter les doublons DB
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

            modelBuilder.Entity<ResourceAssignment>()
                .HasOne(ra => ra.ResourceGroup)
                .WithMany()
                .HasForeignKey(ra => ra.ResourceGroupId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<ResourceGroupMember>()
                .HasOne(rgm => rgm.ResourceGroup)
                .WithMany(rg => rg.Members)
                .HasForeignKey(rgm => rgm.ResourceGroupId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ResourceGroupMember>()
                .HasOne(rgm => rgm.Resource)
                .WithMany()
                .HasForeignKey(rgm => rgm.ResourceId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<ResourceGroupMember>()
                .HasIndex(rgm => new { rgm.ResourceGroupId, rgm.ResourceId })
                .IsUnique();

            // Project -> PlanningItems
            modelBuilder.Entity<PlanningItem>()
                .HasOne(pi => pi.Project)
                .WithMany()
                .HasForeignKey(pi => pi.ProjectId)
                .OnDelete(DeleteBehavior.NoAction);

            // PlanningItem -> Children
            modelBuilder.Entity<PlanningItem>()
                .HasOne(pi => pi.Parent)
                .WithMany(pi => pi.Children)
                .HasForeignKey(pi => pi.ParentId)
                .OnDelete(DeleteBehavior.Restrict);

            // PlanningItem -> PlannerTask
            modelBuilder.Entity<PlanningItem>()
                .HasOne(pi => pi.Task)
                .WithMany()
                .HasForeignKey(pi => pi.TaskId)
                .OnDelete(DeleteBehavior.SetNull);

            // Ordre stable dans la structure du projet
            modelBuilder.Entity<PlanningItem>()
                .HasIndex(pi => new { pi.ProjectId, pi.ParentId, pi.SortOrder });

            // Une tâche ne peut être liée qu'à une seule ligne de planning
            modelBuilder.Entity<PlanningItem>()
                .HasIndex(pi => pi.TaskId)
                .IsUnique()
                .HasFilter("[TaskId] IS NOT NULL");

            modelBuilder.Entity<ProjectCalendar>()
                .HasOne(c => c.Project)
                .WithOne(p => p.Calendar)
                .HasForeignKey<ProjectCalendar>(c => c.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProjectCalendar>()
                .HasIndex(c => c.ProjectId)
                .IsUnique();

            modelBuilder.Entity<ProjectCalendar>()
                .HasOne(c => c.Project)
                .WithOne(p => p.Calendar)
                .HasForeignKey<ProjectCalendar>(c => c.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProjectCalendar>()
                .HasIndex(c => c.ProjectId)
                .IsUnique();

            modelBuilder.Entity<ProjectCalendarException>()
                .HasOne(e => e.ProjectCalendar)
                .WithMany(c => c.Exceptions)
                .HasForeignKey(e => e.ProjectCalendarId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProjectCalendarException>()
                .HasIndex(e => new { e.ProjectCalendarId, e.Date })
                .IsUnique();

            modelBuilder.Entity<ProjectBaseline>()
                .HasOne(b => b.Project)
                .WithMany(p => p.Baselines)
                .HasForeignKey(b => b.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProjectBaseline>()
                .HasIndex(b => new { b.ProjectId, b.Name });

            modelBuilder.Entity<ProjectBaselineTask>()
                .HasOne(t => t.ProjectBaseline)
                .WithMany(b => b.Tasks)
                .HasForeignKey(t => t.ProjectBaselineId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProjectBaselineTask>()
                .HasIndex(t => new { t.ProjectBaselineId, t.TaskId });

                
        }
    }
}