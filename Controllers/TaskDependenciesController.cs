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

        [HttpGet]
        public async Task<ActionResult<IEnumerable<TaskDependencyReadDto>>> GetAll()
        {
            var dependencies = await _taskDependencyService.GetAllAsync();
            return Ok(dependencies);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<TaskDependencyReadDto>> GetById(int id)
        {
            var dependency = await _taskDependencyService.GetByIdAsync(id);

            if (dependency == null)
                return NotFound();

            return Ok(dependency);
        }

        [HttpGet("task/{taskId}")]
        public async Task<ActionResult<IEnumerable<TaskDependencyReadDto>>> GetByTask(int taskId)
        {
            var dependencies = await _taskDependencyService.GetByTaskIdAsync(taskId);
            return Ok(dependencies);
        }

        [HttpPost]
        public async Task<ActionResult<TaskDependencyReadDto>> Create(TaskDependencyCreateDto dto)
        {
            var result = await _taskDependencyService.CreateAsync(dto);

            if (!result.Success)
            {
                if (result.Error == "Cette dépendance existe déjà.")
                    return Conflict(result.Error);

                if (result.Error == "Une tâche ne peut pas dépendre d'elle-même.")
                    return BadRequest(result.Error);

                return NotFound(result.Error);
            }

            return CreatedAtAction(nameof(GetById), new { id = result.Data!.Id }, result.Data);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, TaskDependencyUpdateDto dto)
        {
            var result = await _taskDependencyService.UpdateAsync(id, dto);

            if (!result.Success)
            {
                if (result.Error == "Dépendance introuvable.")
                    return NotFound(result.Error);

                if (result.Error == "Une tâche ne peut pas dépendre d'elle-même.")
                    return BadRequest(result.Error);

                if (result.Error == "Une dépendance identique existe déjà.")
                    return Conflict(result.Error);

                return NotFound(result.Error);
            }

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _taskDependencyService.DeleteAsync(id);

            if (!deleted)
                return NotFound();

            return NoContent();
        }
    }
}