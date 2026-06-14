using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Gantt;

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
                    .Select(ra => new GanttResourceAssignmentDto
                    {
                        AssignmentId = ra.Id,

                        ResourceId = ra.ResourceId,
                        ResourceName = ra.Resource?.Name,
                        ResourceType = ra.Resource?.Type,

                        ResourceGroupId = ra.ResourceGroupId,
                        ResourceGroupName = ra.ResourceGroup?.Name,

                        WorkloadHours = ra.WorkloadHours,
                        AllocationPercent = ra.AllocationPercent
                    })
                    .ToList(),

                Dependencies = t.Predecessors
                    .OrderBy(d => d.PredecessorId)
                    .Select(d => new GanttDependencyDto
                    {
                        Id = d.Id,
                        PredecessorId = d.PredecessorId,
                        SuccessorId = d.SuccessorId,
                        Type = d.Type,
                        OffsetDays = d.OffsetDays
                    })
                    .ToList()
            });

            return Ok(result);
        }
    }
}