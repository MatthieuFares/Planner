using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Dependencies;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class TaskDependenciesController : ControllerBase
    {
        private readonly ITaskDependencyService _taskDependencyService;
        private readonly IProjectAuthorizationService _authorizationService;

        public TaskDependenciesController(
            ITaskDependencyService taskDependencyService,
            IProjectAuthorizationService authorizationService)
        {
            _taskDependencyService = taskDependencyService;
            _authorizationService = authorizationService;
        }

        [HttpGet("task/{taskId}")]
        public async Task<ActionResult<IEnumerable<TaskDependencyReadDto>>>
            GetByTask(int taskId)
        {
            if (!await _authorizationService.CanReadTaskAsync(taskId))
            {
                return NotFound(
                    $"Tâche avec l'id {taskId} introuvable.");
            }

            var dependencies =
                await _taskDependencyService.GetByTaskIdAsync(taskId);

            return Ok(dependencies);
        }

        [HttpPost]
        public async Task<ActionResult<TaskDependencyReadDto>>
            AddDependency(TaskDependencyCreateDto dto)
        {
            try
            {
                var canEditPredecessor =
                    await _authorizationService
                        .CanEditTaskAsync(dto.PredecessorId);

                var canEditSuccessor =
                    await _authorizationService
                        .CanEditTaskAsync(dto.SuccessorId);

                if (!canEditPredecessor || !canEditSuccessor)
                {
                    return Forbid();
                }

                var dependency =
                    await _taskDependencyService
                        .AddDependencyAsync(dto);

                return Ok(dependency);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPut("{id}")]
        public async Task<ActionResult<TaskDependencyReadDto>>
            Update(
                int id,
                TaskDependencyUpdateDto dto)
        {
            try
            {
                // Vérifie d'abord la dépendance existante.
                if (!await _authorizationService
                        .CanEditDependencyAsync(id))
                {
                    return NotFound(
                        $"Dépendance avec l'id {id} introuvable ou accès insuffisant.");
                }

                // Puis les deux tâches cibles du nouvel état.
                // Cela empêche de déplacer une dépendance vers un autre
                // projet auquel l'utilisateur n'a pas accès.
                var canEditPredecessor =
                    await _authorizationService
                        .CanEditTaskAsync(dto.PredecessorId);

                var canEditSuccessor =
                    await _authorizationService
                        .CanEditTaskAsync(dto.SuccessorId);

                if (!canEditPredecessor || !canEditSuccessor)
                {
                    return Forbid();
                }

                var dependency =
                    await _taskDependencyService
                        .UpdateAsync(id, dto);

                if (dependency == null)
                {
                    return NotFound(
                        $"Dépendance avec l'id {id} introuvable.");
                }

                return Ok(dependency);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                if (!await _authorizationService
                        .CanEditDependencyAsync(id))
                {
                    return NotFound(
                        $"Dépendance avec l'id {id} introuvable ou accès insuffisant.");
                }

                var deleted =
                    await _taskDependencyService.DeleteAsync(id);

                if (!deleted)
                {
                    return NotFound(
                        $"Dépendance avec l'id {id} introuvable.");
                }

                return Ok("Dépendance supprimée avec succès.");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}