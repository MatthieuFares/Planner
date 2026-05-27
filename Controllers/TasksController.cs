using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Tasks;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TasksController : ControllerBase
    {
        private readonly ITaskService _taskService;

        public TasksController(ITaskService taskService)
        {
            _taskService = taskService;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<TaskReadDto>>> GetTasks()
        {
            var tasks = await _taskService.GetAllAsync();

            return Ok(tasks);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<TaskReadDto>> GetTaskById(int id)
        {
            var task = await _taskService.GetByIdAsync(id);

            if (task == null)
                return NotFound($"Tâche avec l'id {id} introuvable.");

            return Ok(task);
        }

        [HttpPost]
        public async Task<ActionResult<TaskReadDto>> CreateTask(TaskCreateDto dto)
        {
            var result = await _taskService.CreateTaskAsync(dto);

            if (result == null)
                return NotFound($"Projet avec l'id {dto.ProjectId} introuvable.");

            return CreatedAtAction(
                nameof(GetTaskById),
                new { id = result.Id },
                result
            );
        }

        [HttpPut("{id}")]
        public async Task<ActionResult<TaskReadDto>> UpdateTask(int id, TaskUpdateDto dto)
        {
            var result = await _taskService.UpdateTaskAsync(id, dto);

            if (result == null)
                return NotFound(
                    $"Tâche avec l'id {id} introuvable ou projet avec l'id {dto.ProjectId} introuvable."
                );

            return Ok(result);
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteTask(int id)
        {
            var deleted = await _taskService.DeleteTaskAsync(id);

            if (!deleted)
                return NotFound($"Tâche avec l'id {id} introuvable.");

            return Ok("Tâche supprimée avec succès.");
        }
    }
}