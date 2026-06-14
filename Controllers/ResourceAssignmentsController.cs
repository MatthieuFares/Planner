using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ResourceAssignmentsController : ControllerBase
    {
        private readonly IResourceAssignmentService _service;

        public ResourceAssignmentsController(IResourceAssignmentService service)
        {
            _service = service;
        }

        [HttpPost]
        public async Task<ActionResult<ResourceAssignmentReadDto>> Create(ResourceAssignmentCreateDto dto)
        {
            try
            {
                var assignment = await _service.CreateAsync(dto);

                return CreatedAtAction(
                    nameof(GetByTaskId),
                    new { taskId = assignment.TaskId },
                    assignment
                );
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpGet("task/{taskId}")]
        public async Task<ActionResult<IEnumerable<ResourceAssignmentReadDto>>> GetByTaskId(int taskId)
        {
            try
            {
                var assignments = await _service.GetByTaskIdAsync(taskId);

                return Ok(assignments);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPut("{id}")]
        public async Task<ActionResult<ResourceAssignmentReadDto>> Update(
            int id,
            ResourceAssignmentUpdateDto dto)
        {
            try
            {
                var assignment = await _service.UpdateAsync(id, dto);

                if (assignment == null)
                    return NotFound($"Assignation avec l'id {id} introuvable.");

                return Ok(assignment);
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
                var deleted = await _service.DeleteAsync(id);

                if (!deleted)
                    return NotFound($"Assignation avec l'id {id} introuvable.");

                return Ok("Assignation supprimée avec succès.");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}