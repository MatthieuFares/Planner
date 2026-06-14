using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Gantt;
using PlannerAPI.Models;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class GanttController : ControllerBase
    {
        private readonly AppDbContext _context;

        public GanttController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<IEnumerable<GanttTaskDto>>> GetProjectGantt(int projectId)
        {
            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            var tasks = await _context.Tasks
                .AsNoTracking()
                .Where(t => t.ProjectId == projectId)
                .Include(t => t.Predecessors)
                .Include(t => t.ResourceAssignments)
                    .ThenInclude(ra => ra.Resource)
                .Include(t => t.ResourceAssignments)
                    .ThenInclude(ra => ra.ResourceGroup)
                .OrderBy(t => t.StartDate)
                .ThenBy(t => t.Id)
                .ToListAsync();

            var result = tasks.Select(t => new GanttTaskDto
            {
                Id = t.Id,
                Title = t.Title,

                StartDate = t.StartDate,
                EndDate = t.EndDate,
                Duration = t.Duration,

                IsDone = t.IsDone,
                IsCritical = t.IsCritical,
                ProgressPercent = t.ProgressPercent,

                ActualDuration = t.ActualDuration,
                AssignedResourcesCount = t.AssignedResourcesCount,
                WorkloadHours = t.WorkloadHours,

                EarlyStart = t.EarlyStart,
                EarlyFinish = t.EarlyFinish,
                LateStart = t.LateStart,
                LateFinish = t.LateFinish,
                TotalFloat = t.TotalFloat,

                ResourceAssignments = t.ResourceAssignments
                    .OrderBy(ra => ra.Resource?.Name ?? ra.ResourceGroup?.Name ?? string.Empty)
                    .Select(MapResourceAssignment)
                    .ToList(),

                Dependencies = t.Predecessors
                    .OrderBy(d => d.PredecessorId)
                    .Select(MapDependency)
                    .ToList()
            });

            return Ok(result);
        }

        [HttpGet("project/{projectId}/structured")]
        public async Task<ActionResult<GanttStructuredProjectDto>> GetStructuredProjectGantt(int projectId)
        {
            var project = await _context.Projects
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == projectId);

            if (project == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            var items = await _context.PlanningItems
                .AsNoTracking()
                .Include(i => i.Task)
                    .ThenInclude(t => t!.Predecessors)
                .Include(i => i.Task)
                    .ThenInclude(t => t!.ResourceAssignments)
                        .ThenInclude(ra => ra.Resource)
                .Include(i => i.Task)
                    .ThenInclude(t => t!.ResourceAssignments)
                        .ThenInclude(ra => ra.ResourceGroup)
                .Where(i => i.ProjectId == projectId)
                .OrderBy(i => i.WbsCode)
                .ThenBy(i => i.SortOrder)
                .ThenBy(i => i.Id)
                .ToListAsync();

            var result = new GanttStructuredProjectDto
            {
                ProjectId = project.Id,
                ProjectName = project.Name,
                ClientName = project.ClientName,
                ProjectCode = project.ProjectCode,
                ProjectStartDate = project.StartDate,
                ProjectEndDate = project.EndDate,
                Items = items.Select(item => MapPlanningItem(item, items)).ToList()
            };

            return Ok(result);
        }

        private static GanttPlanningItemDto MapPlanningItem(
            PlanningItem item,
            List<PlanningItem> projectItems)
        {
            return new GanttPlanningItemDto
            {
                Id = item.Id,
                ProjectId = item.ProjectId,
                ParentId = item.ParentId,
                Name = item.Name,
                Type = item.Type.ToString(),
                SortOrder = item.SortOrder,
                WbsCode = item.WbsCode,
                Level = GetLevel(item, projectItems),
                TaskId = item.TaskId,
                Task = item.Task == null
                    ? null
                    : MapTaskDetails(item.Task)
            };
        }

        private static GanttTaskDetailsDto MapTaskDetails(PlannerTask task)
        {
            return new GanttTaskDetailsDto
            {
                Id = task.Id,
                Title = task.Title,

                StartDate = task.StartDate,
                EndDate = task.EndDate,
                Duration = task.Duration,

                IsDone = task.IsDone,
                IsCritical = task.IsCritical,
                ProgressPercent = task.ProgressPercent,

                ActualDuration = task.ActualDuration,
                AssignedResourcesCount = task.AssignedResourcesCount,
                WorkloadHours = task.WorkloadHours,

                EarlyStart = task.EarlyStart,
                EarlyFinish = task.EarlyFinish,
                LateStart = task.LateStart,
                LateFinish = task.LateFinish,
                TotalFloat = task.TotalFloat,

                ResourceAssignments = task.ResourceAssignments
                    .OrderBy(ra => ra.Resource?.Name ?? ra.ResourceGroup?.Name ?? string.Empty)
                    .Select(MapResourceAssignment)
                    .ToList(),

                Dependencies = task.Predecessors
                    .OrderBy(d => d.PredecessorId)
                    .Select(MapDependency)
                    .ToList()
            };
        }

        private static GanttDependencyDto MapDependency(TaskDependency dependency)
        {
            return new GanttDependencyDto
            {
                Id = dependency.Id,
                PredecessorId = dependency.PredecessorId,
                SuccessorId = dependency.SuccessorId,
                Type = dependency.Type,
                OffsetDays = dependency.OffsetDays
            };
        }

        private static GanttResourceAssignmentDto MapResourceAssignment(ResourceAssignment assignment)
        {
            return new GanttResourceAssignmentDto
            {
                AssignmentId = assignment.Id,

                ResourceId = assignment.ResourceId,
                ResourceName = assignment.Resource?.Name,
                ResourceType = assignment.Resource?.Type,

                ResourceGroupId = assignment.ResourceGroupId,
                ResourceGroupName = assignment.ResourceGroup?.Name,

                WorkloadHours = assignment.WorkloadHours,
                AllocationPercent = assignment.AllocationPercent
            };
        }

        private static int GetLevel(
            PlanningItem item,
            List<PlanningItem> projectItems)
        {
            var level = 0;
            var currentParentId = item.ParentId;
            var visited = new HashSet<int>();

            while (currentParentId.HasValue)
            {
                if (!visited.Add(currentParentId.Value))
                    break;

                var parent = projectItems
                    .FirstOrDefault(i => i.Id == currentParentId.Value);

                if (parent == null)
                    break;

                level++;
                currentParentId = parent.ParentId;
            }

            return level;
        }
    }
}