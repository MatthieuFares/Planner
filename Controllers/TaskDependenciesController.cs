using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Dependencies;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TaskDependenciesController : ControllerBase
    {
        private readonly ITaskDependencyService _taskDependencyService;
        private readonly ITaskSchedulingService _taskSchedulingService;

        public TaskDependenciesController(ITaskDependencyService taskDependencyService, ITaskSchedulingService taskSchedulingService)
        {
            _taskDependencyService = taskDependencyService;
            _taskSchedulingService = taskSchedulingService;
        }

        [HttpGet("task/{taskId}")]
        public async Task<ActionResult<IEnumerable<TaskDependencyReadDto>>> GetByTask(int taskId)
        {
            var dependencies = await _taskDependencyService.GetByTaskIdAsync(taskId);
            return Ok(dependencies);
        }

        [HttpPost]
        public async Task<IActionResult> AddDependency(TaskDependencyCreateDto dto)
        {
            try
            {
                await _taskDependencyService.AddDependencyAsync(dto);
                return Ok("Dépendance créée avec succès.");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, TaskDependencyUpdateDto dto)
        {
            var updated = await _taskDependencyService.UpdateAsync(id, dto);

            if (!updated)
                return NotFound("Dépendance introuvable ou invalide.");
            await _taskSchedulingService.RecalculateTaskDatesAsync(dto.SuccessorId);
            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var result = await _taskDependencyService.DeleteAsync(id);

            if (!result)
                return NotFound($"Dépendance avec l'id {id} introuvable.");

            return NoContent();
        }
    }
}