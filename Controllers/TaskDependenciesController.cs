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

        public TaskDependenciesController(ITaskDependencyService taskDependencyService)
        {
            _taskDependencyService = taskDependencyService;
        }

        [HttpGet("task/{taskId}")]
        public async Task<ActionResult<IEnumerable<TaskDependencyReadDto>>> GetByTask(int taskId)
        {
            var dependencies = await _taskDependencyService.GetByTaskIdAsync(taskId);

            return Ok(dependencies);
        }

        [HttpPost]
        public async Task<ActionResult<TaskDependencyReadDto>> AddDependency(TaskDependencyCreateDto dto)
        {
            try
            {
                var dependency = await _taskDependencyService.AddDependencyAsync(dto);

                return Ok(dependency);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPut("{id}")]
        public async Task<ActionResult<TaskDependencyReadDto>> Update(int id, TaskDependencyUpdateDto dto)
        {
            try
            {
                var dependency = await _taskDependencyService.UpdateAsync(id, dto);

                if (dependency == null)
                    return NotFound($"Dépendance avec l'id {id} introuvable.");

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
                var deleted = await _taskDependencyService.DeleteAsync(id);

                if (!deleted)
                    return NotFound($"Dépendance avec l'id {id} introuvable.");

                return Ok("Dépendance supprimée avec succès.");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}