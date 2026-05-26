using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Tasks;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TasksController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ITaskService _taskService;
        private readonly ITaskSchedulingService _taskSchedulingService;

        public TasksController(AppDbContext context, ITaskService taskService, ITaskSchedulingService taskSchedulingService)
        {
            _context = context;
            _taskService = taskService;
            _taskSchedulingService = taskSchedulingService;
        }

        // GET ALL
        [HttpGet]
        public async Task<ActionResult<IEnumerable<TaskReadDto>>> GetTasks()
        {
            var tasks = await _context.Tasks
                .Select(t => new TaskReadDto
                {
                    Id = t.Id,
                    Title = t.Title,
                    Description = t.Description,
                    IsDone = t.IsDone,
                    ProjectId = t.ProjectId,
                    StartDate = t.StartDate,
                    EndDate = t.EndDate,
                    Duration = t.Duration,
                    ActualDuration = t.ActualDuration,
                    AssignedResourcesCount = t.AssignedResourcesCount,
                    WorkloadHours = t.WorkloadHours,
                    IsCritical = t.IsCritical,
                    EarlyStart = t.EarlyStart,
                    EarlyFinish = t.EarlyFinish,
                    LateStart = t.LateStart,
                    LateFinish = t.LateFinish,
                    TotalFloat = t.TotalFloat,
                    ProgressPercent = t.ProgressPercent,
                })
                .ToListAsync();

            return Ok(tasks);
        }

        // GET BY ID
        [HttpGet("{id}")]
        public async Task<ActionResult<TaskReadDto>> GetTaskById(int id)
        {
            var taskItem = await _context.Tasks.FindAsync(id);

            if (taskItem == null)
                return NotFound();

            var dto = new TaskReadDto
            {
                Id = taskItem.Id,
                Title = taskItem.Title,
                Description = taskItem.Description,
                IsDone = taskItem.IsDone,
                ProjectId = taskItem.ProjectId,
                StartDate = taskItem.StartDate,
                EndDate = taskItem.EndDate,
                Duration = taskItem.Duration,
                ActualDuration = taskItem.ActualDuration,
                AssignedResourcesCount = taskItem.AssignedResourcesCount,
                WorkloadHours = taskItem.WorkloadHours,
                IsCritical = taskItem.IsCritical,
                EarlyStart = taskItem.EarlyStart,
                EarlyFinish = taskItem.EarlyFinish,
                LateStart = taskItem.LateStart,
                LateFinish = taskItem.LateFinish,
                TotalFloat = taskItem.TotalFloat,
                ProgressPercent = taskItem.ProgressPercent,
            };

            return Ok(dto);
        }

        // CREATE
        [HttpPost]
        public async Task<ActionResult<TaskReadDto>> CreateTask(TaskCreateDto dto)
        {
            var result = await _taskService.CreateTaskAsync(dto);

            if (result == null)
                return NotFound($"Projet avec l'id {dto.ProjectId} introuvable.");

            return CreatedAtAction(nameof(GetTaskById), new { id = result.Id }, result);
        }

        // UPDATE
        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateTask(int id, TaskUpdateDto dto)
        {
            var taskItem = await _context.Tasks.FindAsync(id);

            if (taskItem == null)
                return NotFound();

            var projectExists = await _context.Projects.AnyAsync(p => p.Id == dto.ProjectId);

            if (!projectExists)
                return NotFound($"Projet avec l'id {dto.ProjectId} introuvable.");

            taskItem.Title = dto.Title;
            taskItem.Description = dto.Description;
            taskItem.ProjectId = dto.ProjectId;
            taskItem.StartDate = dto.StartDate;
            taskItem.EndDate = dto.EndDate;
            taskItem.Duration = dto.Duration;
            taskItem.ActualDuration = dto.ActualDuration;
            taskItem.AssignedResourcesCount = dto.AssignedResourcesCount;
            taskItem.WorkloadHours = dto.WorkloadHours;
            taskItem.ProgressPercent = dto.ProgressPercent;
            
            taskItem.IsDone = dto.ProgressPercent >= 100;
            await _context.SaveChangesAsync();
            await _taskSchedulingService.RecalculateTaskDatesAsync(taskItem.Id);

            return NoContent();
        }

        // DELETE
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteTask(int id)
        {
            var taskItem = await _context.Tasks.FindAsync(id);

            if (taskItem == null)
                return NotFound();

            _context.Tasks.Remove(taskItem);
            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}