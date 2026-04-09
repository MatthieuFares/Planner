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
        public async Task<IActionResult> AddDependency(TaskDependencyCreateDto dto)
        {
            await _taskDependencyService.AddDependencyAsync(dto);
            return Ok();
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, TaskDependencyUpdateDto dto)
        {
            var updated = await _taskDependencyService.UpdateAsync(id, dto);

            if (!updated)
                return NotFound("Dépendance introuvable ou invalide.");

            return NoContent();
        }
    }
}