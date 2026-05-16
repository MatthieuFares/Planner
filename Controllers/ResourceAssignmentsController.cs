using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ResourceAssignmentsController : ControllerBase
    {
        private readonly IResourceAssignmentService _assignmentService;

        public ResourceAssignmentsController(IResourceAssignmentService assignmentService)
        {
            _assignmentService = assignmentService;
        }

        [HttpPost]
        public async Task<ActionResult<ResourceAssignmentReadDto>> Create(ResourceAssignmentCreateDto dto)
        {
            var result = await _assignmentService.CreateAsync(dto);

            return Ok(result);
        }

        [HttpGet("task/{taskId}")]
        public async Task<ActionResult<IEnumerable<ResourceAssignmentReadDto>>> GetByTask(int taskId)
        {
            var result = await _assignmentService.GetByTaskIdAsync(taskId);

            return Ok(result);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, ResourceAssignmentUpdateDto dto)
        {
            var updated = await _assignmentService.UpdateAsync(id, dto);

            if (!updated)
                return NotFound();

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _assignmentService.DeleteAsync(id);

            if (!deleted)
                return NotFound();

            return NoContent();
        }
    }
}