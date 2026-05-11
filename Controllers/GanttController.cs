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
            var projectExists = await _context.Projects.AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            var tasks = await _context.Tasks
                .Where(t => t.ProjectId == projectId)
                .Include(t => t.Predecessors)
                .OrderBy(t => t.StartDate)
                .Select(t => new GanttTaskDto
                {
                    Id = t.Id,
                    Title = t.Title,
                    StartDate = t.StartDate,
                    EndDate = t.EndDate,
                    Duration = t.Duration,
                    IsDone = t.IsDone,
                    IsCritical = t.IsCritical,
                    ActualDuration = t.ActualDuration,
                    AssignedResourcesCount = t.AssignedResourcesCount,
                    WorkloadHours = t.WorkloadHours,

                    Dependencies = t.Predecessors.Select(d => new GanttDependencyDto
                    {
                        Id = d.Id,
                        PredecessorId = d.PredecessorId,
                        SuccessorId = d.SuccessorId,
                        Type = d.Type.ToString(),
                        OffsetDays = d.OffsetDays
                    }).ToList()
                })
                .ToListAsync();

            return Ok(tasks);
        }
    }
}