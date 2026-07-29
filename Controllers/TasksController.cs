using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Tasks;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class TasksController : ControllerBase
    {
        private readonly ITaskService _taskService;
        private readonly IProjectAuthorizationService _authorizationService;

        public TasksController(
            ITaskService taskService,
            IProjectAuthorizationService authorizationService)
        {
            _taskService = taskService;
            _authorizationService = authorizationService;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<TaskReadDto>>> GetTasks()
        {
            var tasks = await _taskService.GetAllAsync();

            // GET /api/Tasks est conservé pour compatibilité,
            // mais ne renvoie désormais que les tâches accessibles
            // à l'utilisateur connecté.
            var accessibleTasks = new List<TaskReadDto>();

            foreach (var task in tasks)
            {
                if (await _authorizationService.CanReadTaskAsync(task.Id))
                {
                    accessibleTasks.Add(task);
                }
            }

            return Ok(accessibleTasks);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<TaskReadDto>> GetTaskById(int id)
        {
            if (!await _authorizationService.CanReadTaskAsync(id))
            {
                return NotFound(
                    $"Tâche avec l'id {id} introuvable.");
            }

            var task = await _taskService.GetByIdAsync(id);

            if (task == null)
            {
                return NotFound(
                    $"Tâche avec l'id {id} introuvable.");
            }

            return Ok(task);
        }

        [HttpPost]
        public async Task<ActionResult<TaskReadDto>> CreateTask(
            TaskCreateDto dto)
        {
            if (!await _authorizationService
                    .CanEditPlanningAsync(dto.ProjectId))
            {
                return Forbid();
            }

            var result = await _taskService.CreateTaskAsync(dto);

            if (result == null)
            {
                return NotFound(
                    $"Projet avec l'id {dto.ProjectId} introuvable.");
            }

            return CreatedAtAction(
                nameof(GetTaskById),
                new { id = result.Id },
                result
            );
        }

        [HttpPut("{id}")]
        public async Task<ActionResult<TaskReadDto>> UpdateTask(
            int id,
            TaskUpdateDto dto)
        {
            try
            {
                // On vérifie d'abord la tâche existante.
                if (!await _authorizationService.CanEditTaskAsync(id))
                {
                    return NotFound(
                        $"Tâche avec l'id {id} introuvable ou accès insuffisant.");
                }

                // Empêche de déplacer une tâche vers un projet
                // sur lequel l'utilisateur n'a pas les droits d'édition.
                if (!await _authorizationService
                        .CanEditPlanningAsync(dto.ProjectId))
                {
                    return Forbid();
                }

                var result =
                    await _taskService.UpdateTaskAsync(id, dto);

                if (result == null)
                {
                    return NotFound(
                        $"Tâche avec l'id {id} introuvable ou projet avec l'id {dto.ProjectId} introuvable."
                    );
                }

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteTask(int id)
        {
            try
            {
                if (!await _authorizationService.CanEditTaskAsync(id))
                {
                    return NotFound(
                        $"Tâche avec l'id {id} introuvable ou accès insuffisant.");
                }

                var deleted =
                    await _taskService.DeleteTaskAsync(id);

                if (!deleted)
                {
                    return NotFound(
                        $"Tâche avec l'id {id} introuvable.");
                }

                return Ok("Tâche supprimée avec succès.");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}