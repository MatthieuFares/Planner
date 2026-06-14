using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ProjectSummaryService : IProjectSummaryService
    {
        private readonly AppDbContext _context;

        public ProjectSummaryService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<ProjectSummaryDto?> GetSummaryAsync(int projectId)
        {
            var project = await _context.Projects
                .FirstOrDefaultAsync(p => p.Id == projectId);

            if (project == null)
                return null;

            var tasks = await _context.Tasks
                .Where(t => t.ProjectId == projectId)
                .ToListAsync();

            var taskIds = tasks
                .Select(t => t.Id)
                .ToList();

            var assignments = await _context.ResourceAssignments
                .Include(a => a.Resource)
                .Where(a => taskIds.Contains(a.TaskId))
                .ToListAsync();

            var dependencyCount = await _context.TaskDependencies
                .CountAsync(d =>
                    taskIds.Contains(d.PredecessorId) ||
                    taskIds.Contains(d.SuccessorId)
                );

            var datedStartTasks = tasks
                .Where(t => t.StartDate.HasValue)
                .ToList();

            var datedEndTasks = tasks
                .Where(t => t.EndDate.HasValue)
                .ToList();

            DateTime? projectStart = datedStartTasks.Any()
                ? datedStartTasks.Min(t => t.StartDate)
                : project.StartDate;

            DateTime? projectEnd = datedEndTasks.Any()
                ? datedEndTasks.Max(t => t.EndDate)
                : project.EndDate;

            int? projectDurationDays = null;

            if (projectStart.HasValue && projectEnd.HasValue)
            {
                projectDurationDays = (projectEnd.Value.Date - projectStart.Value.Date).Days + 1;
            }

            var globalProgressPercent = tasks.Any()
                ? (int)Math.Round(tasks.Average(t => t.ProgressPercent))
                : 0;

            var usedResourceIds = assignments
                .Where(a => a.ResourceId.HasValue)
                .Select(a => a.ResourceId!.Value)
                .Distinct()
                .ToList();

            var resourceGroupCount = await _context.ResourceGroupMembers
                .Where(m => usedResourceIds.Contains(m.ResourceId))
                .Select(m => m.ResourceGroupId)
                .Distinct()
                .CountAsync();

            var resourceStats = assignments
                .Where(a => a.Resource != null)
                .GroupBy(a => a.ResourceId)
                .Select(g =>
                {
                    var resource = g.First().Resource!;
                    var assignedHours = g.Sum(a => a.WorkloadHours);

                    decimal? utilizationPercent = null;

                    if (resource.CapacityHoursPerWeek.HasValue &&
                        resource.CapacityHoursPerWeek.Value > 0)
                    {
                        utilizationPercent =
                            assignedHours / resource.CapacityHoursPerWeek.Value * 100;
                    }

                    return new
                    {
                        ResourceId = resource.Id,
                        AssignedHours = assignedHours,
                        EstimatedCost = resource.CostPerHour.HasValue
                            ? assignedHours * resource.CostPerHour.Value
                            : 0,
                        IsOverloaded = utilizationPercent.HasValue &&
                            utilizationPercent > 100
                    };
                })
                .ToList();

            return new ProjectSummaryDto
            {
                ProjectId = project.Id,
                ProjectName = project.Name,

                ProjectStart = projectStart,
                ProjectEnd = projectEnd,
                ProjectDurationDays = projectDurationDays,

                TaskCount = tasks.Count,
                CompletedTaskCount = tasks.Count(t => t.IsDone),
                GlobalProgressPercent = globalProgressPercent,

                CriticalTaskCount = tasks.Count(t => t.IsCritical),
                NonCriticalTaskCount = tasks.Count(t => !t.IsCritical),

                DependencyCount = dependencyCount,

                ResourceCount = resourceStats.Count,
                ResourceGroupCount = resourceGroupCount,

                TotalWorkloadHours = resourceStats.Sum(r => r.AssignedHours),
                EstimatedCost = resourceStats.Sum(r => r.EstimatedCost),

                OverloadedResourceCount = resourceStats.Count(r => r.IsOverloaded)
            };
        }
    }
}