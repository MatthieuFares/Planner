using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ProjectWarningService : IProjectWarningService
    {
        private readonly AppDbContext _context;

        public ProjectWarningService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<ProjectWarningDto>?> GetWarningsAsync(int projectId)
        {
            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return null;

            var warnings = new List<ProjectWarningDto>();

            var tasks = await _context.Tasks
                .Where(t => t.ProjectId == projectId)
                .Include(t => t.ResourceAssignments)
                    .ThenInclude(ra => ra.Resource)
                .Include(t => t.Predecessors)
                .Include(t => t.Successors)
                .ToListAsync();

            foreach (var task in tasks)
            {
                if (!task.StartDate.HasValue || !task.EndDate.HasValue)
                {
                    warnings.Add(new ProjectWarningDto
                    {
                        Type = "MissingDates",
                        Severity = "High",
                        TaskId = task.Id,
                        TaskTitle = task.Title,
                        Message = $"La tâche '{task.Title}' n'a pas de dates complètes."
                    });
                }

                if (task.IsCritical)
                {
                    warnings.Add(new ProjectWarningDto
                    {
                        Type = "CriticalTask",
                        Severity = "Info",
                        TaskId = task.Id,
                        TaskTitle = task.Title,
                        Message = $"La tâche '{task.Title}' est sur le chemin critique."
                    });
                }

                if ((task.WorkloadHours ?? 0) > 0 && !task.ResourceAssignments.Any())
                {
                    warnings.Add(new ProjectWarningDto
                    {
                        Type = "WorkloadWithoutAssignment",
                        Severity = "Medium",
                        TaskId = task.Id,
                        TaskTitle = task.Title,
                        Message = $"La tâche '{task.Title}' a une charge prévue mais aucune ressource assignée."
                    });
                }

                var assignedHours = task.ResourceAssignments.Sum(ra => ra.WorkloadHours);

                if (task.ResourceAssignments.Any() && task.WorkloadHours.HasValue)
                {
                    var difference = Math.Abs(assignedHours - task.WorkloadHours.Value);

                    if (difference > 0.01m)
                    {
                        warnings.Add(new ProjectWarningDto
                        {
                            Type = "WorkloadMismatch",
                            Severity = "Medium",
                            TaskId = task.Id,
                            TaskTitle = task.Title,
                            Message = $"La tâche '{task.Title}' a {task.WorkloadHours.Value}h prévues mais {assignedHours}h assignées."
                        });
                    }
                }

                if (!task.Predecessors.Any() && !task.Successors.Any())
                {
                    warnings.Add(new ProjectWarningDto
                    {
                        Type = "IsolatedTask",
                        Severity = "Low",
                        TaskId = task.Id,
                        TaskTitle = task.Title,
                        Message = $"La tâche '{task.Title}' n'a aucune dépendance."
                    });
                }
            }

            var assignments = await _context.ResourceAssignments
                .Include(a => a.Resource)
                .Include(a => a.Task)
                .Where(a => a.Task != null && a.Task.ProjectId == projectId)
                .ToListAsync();

            var resourceGroups = assignments
                .Where(a => a.Resource != null)
                .GroupBy(a => a.ResourceId);

            foreach (var group in resourceGroups)
            {
                var resource = group.First().Resource!;
                var assignedHours = group.Sum(a => a.WorkloadHours);

                if (resource.CapacityHoursPerWeek.HasValue &&
                    resource.CapacityHoursPerWeek.Value > 0 &&
                    assignedHours > resource.CapacityHoursPerWeek.Value)
                {
                    warnings.Add(new ProjectWarningDto
                    {
                        Type = "ResourceOverload",
                        Severity = "High",
                        ResourceId = resource.Id,
                        ResourceName = resource.Name,
                        Message = $"La ressource '{resource.Name}' est surchargée : {assignedHours}h assignées pour {resource.CapacityHoursPerWeek.Value}h de capacité."
                    });
                }
            }

            return warnings;
        }
    }
}