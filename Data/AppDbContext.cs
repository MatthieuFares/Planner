using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.Models;

namespace PlannerAPI.Data
{
    public class AppDbContext : IdentityDbContext<AppUser, IdentityRole, string>
    {
        public AppDbContext(
            DbContextOptions<AppDbContext> options)
            : base(options)
        {
        }

        public DbSet<Project> Projects => Set<Project>();
        public DbSet<ProjectMember> ProjectMembers => Set<ProjectMember>();
        public DbSet<PlannerTask> Tasks => Set<PlannerTask>();
        public DbSet<TaskDependency> TaskDependencies =>
            Set<TaskDependency>();

        public DbSet<Resource> Resources => Set<Resource>();
        public DbSet<ResourceAssignment> ResourceAssignments =>
            Set<ResourceAssignment>();
        public DbSet<ResourceGroup> ResourceGroups =>
            Set<ResourceGroup>();
        public DbSet<ResourceGroupMember> ResourceGroupMembers =>
            Set<ResourceGroupMember>();

        public DbSet<PlanningItem> PlanningItems =>
            Set<PlanningItem>();

        public DbSet<ProjectCalendar> ProjectCalendars =>
            Set<ProjectCalendar>();
        public DbSet<ProjectCalendarException> ProjectCalendarExceptions =>
            Set<ProjectCalendarException>();
        public DbSet<ProjectCalendarPeriod> ProjectCalendarPeriods =>
            Set<ProjectCalendarPeriod>();

        public DbSet<ProjectBaseline> ProjectBaselines =>
            Set<ProjectBaseline>();
        public DbSet<ProjectBaselineTask> ProjectBaselineTasks =>
            Set<ProjectBaselineTask>();

        public DbSet<PlanningVersion> PlanningVersions =>
            Set<PlanningVersion>();
        public DbSet<PlanningVersionTask> PlanningVersionTasks =>
            Set<PlanningVersionTask>();
        public DbSet<PlanningVersionItem> PlanningVersionItems =>
            Set<PlanningVersionItem>();
        public DbSet<PlanningVersionDependency> PlanningVersionDependencies =>
            Set<PlanningVersionDependency>();
        public DbSet<PlanningVersionAssignment> PlanningVersionAssignments =>
            Set<PlanningVersionAssignment>();
        public DbSet<PlanningVersionCalendar> PlanningVersionCalendars =>
            Set<PlanningVersionCalendar>();
        public DbSet<PlanningVersionCalendarException>
            PlanningVersionCalendarExceptions =>
                Set<PlanningVersionCalendarException>();
        public DbSet<PlanningVersionCalendarPeriod>
            PlanningVersionCalendarPeriods =>
                Set<PlanningVersionCalendarPeriod>();

        protected override void OnModelCreating(
            ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<PlannerTask>()
                .ToTable("PlannerTasks");

            modelBuilder.Entity<PlannerTask>()
                .Property(t => t.WorkloadHours)
                .HasPrecision(18, 2);

            // =========================================================
            // Project ownership / members
            // =========================================================

            // Project -> Owner (Identity user)
            modelBuilder.Entity<Project>()
                .HasOne(p => p.Owner)
                .WithMany()
                .HasForeignKey(p => p.OwnerUserId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Project>()
                .HasIndex(p => p.OwnerUserId);

            // ProjectMember -> Project
            modelBuilder.Entity<ProjectMember>()
                .HasOne(pm => pm.Project)
                .WithMany(p => p.Members)
                .HasForeignKey(pm => pm.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);

            // ProjectMember -> Identity user
            modelBuilder.Entity<ProjectMember>()
                .HasOne(pm => pm.User)
                .WithMany()
                .HasForeignKey(pm => pm.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            // Un utilisateur ne peut avoir qu'un seul rôle par projet.
            modelBuilder.Entity<ProjectMember>()
                .HasIndex(pm => new
                {
                    pm.ProjectId,
                    pm.UserId
                })
                .IsUnique();

            // Stocker les rôles en texte évite qu'un changement d'ordre
            // dans l'enum modifie silencieusement leur signification.
            modelBuilder.Entity<ProjectMember>()
                .Property(pm => pm.Role)
                .HasConversion<string>()
                .HasMaxLength(20);

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

            modelBuilder.Entity<TaskDependency>()
                .HasIndex(td => new
                {
                    td.PredecessorId,
                    td.SuccessorId,
                    td.Type
                })
                .IsUnique();

            modelBuilder.Entity<Resource>()
                .Property(r => r.CapacityHoursPerWeek)
                .HasPrecision(18, 2);

            modelBuilder.Entity<Resource>()
                .Property(r => r.CostPerHour)
                .HasPrecision(18, 2);

            // ResourceAssignment -> PlannerTask
            modelBuilder.Entity<ResourceAssignment>()
                .HasOne(ra => ra.Task)
                .WithMany(t => t.ResourceAssignments)
                .HasForeignKey(ra => ra.TaskId)
                .OnDelete(DeleteBehavior.Cascade);

            // ResourceAssignment -> Resource
            modelBuilder.Entity<ResourceAssignment>()
                .HasOne(ra => ra.Resource)
                .WithMany(r => r.Assignments)
                .HasForeignKey(ra => ra.ResourceId)
                .OnDelete(DeleteBehavior.Restrict);

            // ResourceAssignment -> ResourceGroup
            modelBuilder.Entity<ResourceAssignment>()
                .HasOne(ra => ra.ResourceGroup)
                .WithMany()
                .HasForeignKey(ra => ra.ResourceGroupId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<ResourceAssignment>()
                .Property(ra => ra.WorkloadHours)
                .HasPrecision(18, 2);

            // ResourceGroupMember -> ResourceGroup
            modelBuilder.Entity<ResourceGroupMember>()
                .HasOne(rgm => rgm.ResourceGroup)
                .WithMany(rg => rg.Members)
                .HasForeignKey(rgm => rgm.ResourceGroupId)
                .OnDelete(DeleteBehavior.Cascade);

            // ResourceGroupMember -> Resource
            modelBuilder.Entity<ResourceGroupMember>()
                .HasOne(rgm => rgm.Resource)
                .WithMany()
                .HasForeignKey(rgm => rgm.ResourceId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<ResourceGroupMember>()
                .HasIndex(rgm => new
                {
                    rgm.ResourceGroupId,
                    rgm.ResourceId
                })
                .IsUnique();

            // Project -> PlanningItems
            modelBuilder.Entity<PlanningItem>()
                .HasOne(pi => pi.Project)
                .WithMany()
                .HasForeignKey(pi => pi.ProjectId)
                .OnDelete(DeleteBehavior.NoAction);

            // PlanningItem -> Parent / Children
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

            modelBuilder.Entity<PlanningItem>()
                .HasIndex(pi => new
                {
                    pi.ProjectId,
                    pi.ParentId,
                    pi.SortOrder
                });

            modelBuilder.Entity<PlanningItem>()
                .HasIndex(pi => pi.TaskId)
                .IsUnique()
                .HasFilter("[TaskId] IS NOT NULL");

            // Project -> ProjectCalendar
            modelBuilder.Entity<ProjectCalendar>()
                .HasOne(c => c.Project)
                .WithOne(p => p.Calendar)
                .HasForeignKey<ProjectCalendar>(
                    c => c.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProjectCalendar>()
                .HasIndex(c => c.ProjectId)
                .IsUnique();

            // ProjectCalendar -> Exceptions
            modelBuilder.Entity<ProjectCalendarException>()
                .HasOne(e => e.ProjectCalendar)
                .WithMany(c => c.Exceptions)
                .HasForeignKey(e => e.ProjectCalendarId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProjectCalendarException>()
                .HasIndex(e => new
                {
                    e.ProjectCalendarId,
                    e.Date
                })
                .IsUnique();

            // ProjectCalendar -> Periods
            modelBuilder.Entity<ProjectCalendarPeriod>()
                .HasOne(p => p.ProjectCalendar)
                .WithMany(c => c.Periods)
                .HasForeignKey(p => p.ProjectCalendarId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProjectCalendarPeriod>()
                .HasIndex(p => new
                {
                    p.ProjectCalendarId,
                    p.StartDate,
                    p.EndDate
                });

            modelBuilder.Entity<ProjectCalendarPeriod>()
                .Property(p => p.Label)
                .HasMaxLength(150);

            // Project -> Baselines
            modelBuilder.Entity<ProjectBaseline>()
                .HasOne(b => b.Project)
                .WithMany(p => p.Baselines)
                .HasForeignKey(b => b.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProjectBaseline>()
                .HasIndex(b => new
                {
                    b.ProjectId,
                    b.Name
                });

            // ProjectBaseline -> Tasks
            modelBuilder.Entity<ProjectBaselineTask>()
                .HasOne(t => t.ProjectBaseline)
                .WithMany(b => b.Tasks)
                .HasForeignKey(t => t.ProjectBaselineId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProjectBaselineTask>()
                .HasIndex(t => new
                {
                    t.ProjectBaselineId,
                    t.TaskId
                });

            // =========================================================
            // Planning versions
            // =========================================================

            // Project -> PlanningVersions
            modelBuilder.Entity<PlanningVersion>()
                .HasOne(v => v.Project)
                .WithMany()
                .HasForeignKey(v => v.ProjectId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PlanningVersion>()
                .HasIndex(v => new
                {
                    v.ProjectId,
                    v.VersionNumber
                })
                .IsUnique();

            modelBuilder.Entity<PlanningVersion>()
                .HasIndex(v => new
                {
                    v.ProjectId,
                    v.CreatedAt
                });

            // PlanningVersion -> Tasks
            modelBuilder.Entity<PlanningVersionTask>()
                .HasOne(t => t.PlanningVersion)
                .WithMany(v => v.Tasks)
                .HasForeignKey(t => t.PlanningVersionId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PlanningVersionTask>()
                .HasIndex(t => new
                {
                    t.PlanningVersionId,
                    t.OriginalTaskId
                })
                .IsUnique();

            modelBuilder.Entity<PlanningVersionTask>()
                .Property(t => t.WorkloadHours)
                .HasPrecision(18, 2);

            // PlanningVersion -> Items
            modelBuilder.Entity<PlanningVersionItem>()
                .HasOne(i => i.PlanningVersion)
                .WithMany(v => v.Items)
                .HasForeignKey(i => i.PlanningVersionId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PlanningVersionItem>()
                .HasIndex(i => new
                {
                    i.PlanningVersionId,
                    i.OriginalPlanningItemId
                })
                .IsUnique();

            modelBuilder.Entity<PlanningVersionItem>()
                .HasIndex(i => new
                {
                    i.PlanningVersionId,
                    i.OriginalParentId,
                    i.SortOrder
                });

            // PlanningVersion -> Dependencies
            modelBuilder.Entity<PlanningVersionDependency>()
                .HasOne(d => d.PlanningVersion)
                .WithMany(v => v.Dependencies)
                .HasForeignKey(d => d.PlanningVersionId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PlanningVersionDependency>()
                .HasIndex(d => new
                {
                    d.PlanningVersionId,
                    d.OriginalDependencyId
                })
                .IsUnique();

            modelBuilder.Entity<PlanningVersionDependency>()
                .HasIndex(d => new
                {
                    d.PlanningVersionId,
                    d.OriginalPredecessorTaskId,
                    d.OriginalSuccessorTaskId,
                    d.Type
                });

            // PlanningVersion -> Assignments
            modelBuilder.Entity<PlanningVersionAssignment>()
                .HasOne(a => a.PlanningVersion)
                .WithMany(v => v.Assignments)
                .HasForeignKey(a => a.PlanningVersionId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PlanningVersionAssignment>()
                .HasIndex(a => new
                {
                    a.PlanningVersionId,
                    a.OriginalAssignmentId
                })
                .IsUnique();

            modelBuilder.Entity<PlanningVersionAssignment>()
                .Property(a => a.WorkloadHours)
                .HasPrecision(18, 2);

            // PlanningVersion -> Calendar
            modelBuilder.Entity<PlanningVersionCalendar>()
                .HasOne(c => c.PlanningVersion)
                .WithOne(v => v.Calendar)
                .HasForeignKey<PlanningVersionCalendar>(
                    c => c.PlanningVersionId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PlanningVersionCalendar>()
                .HasIndex(c => c.PlanningVersionId)
                .IsUnique();

            // PlanningVersionCalendar -> Exceptions
            modelBuilder.Entity<PlanningVersionCalendarException>()
                .HasOne(e => e.PlanningVersionCalendar)
                .WithMany(c => c.Exceptions)
                .HasForeignKey(e => e.PlanningVersionCalendarId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PlanningVersionCalendarException>()
                .HasIndex(e => new
                {
                    e.PlanningVersionCalendarId,
                    e.Date
                })
                .IsUnique();

            // PlanningVersionCalendar -> Periods
            modelBuilder.Entity<PlanningVersionCalendarPeriod>()
                .HasOne(p => p.PlanningVersionCalendar)
                .WithMany(c => c.Periods)
                .HasForeignKey(p => p.PlanningVersionCalendarId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PlanningVersionCalendarPeriod>()
                .HasIndex(p => new
                {
                    p.PlanningVersionCalendarId,
                    p.StartDate,
                    p.EndDate
                });
        }
    }
}