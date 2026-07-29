using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ResourceAssignmentsController : ControllerBase
    {
        private readonly IResourceAssignmentService _service;
        private readonly IProjectAuthorizationService _authorizationService;

        public ResourceAssignmentsController(
            IResourceAssignmentService service,
            IProjectAuthorizationService authorizationService)
        {
            _service = service;
            _authorizationService = authorizationService;
        }

        [HttpPost]
        public async Task<ActionResult<ResourceAssignmentReadDto>> Create(
            ResourceAssignmentCreateDto dto)
        {
            if (!await _authorizationService.CanEditTaskAsync(dto.TaskId))
                return Forbid();

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

        [HttpGet("task/{taskId:int}")]
        public async Task<ActionResult<IEnumerable<ResourceAssignmentReadDto>>>
            GetByTaskId(int taskId)
        {
            if (!await _authorizationService.CanReadTaskAsync(taskId))
                return NotFound($"Tâche avec l'id {taskId} introuvable.");

            try
            {
                return Ok(await _service.GetByTaskIdAsync(taskId));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpGet("project/{projectId:int}")]
        public async Task<ActionResult<IEnumerable<ResourceAssignmentReadDto>>>
            GetByProjectId(int projectId)
        {
            if (!await _authorizationService.CanReadProjectAsync(projectId))
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            try
            {
                return Ok(await _service.GetByProjectIdAsync(projectId));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPut("{id:int}")]
        public async Task<ActionResult<ResourceAssignmentReadDto>> Update(
            int id,
            ResourceAssignmentUpdateDto dto)
        {
            if (!await _authorizationService.CanEditAssignmentAsync(id))
            {
                return NotFound(
                    $"Assignation avec l'id {id} introuvable ou accès insuffisant.");
            }

            // L'assignation peut changer de tâche : on vérifie aussi la
            // destination demandée par le DTO.
            if (!await _authorizationService.CanEditTaskAsync(dto.TaskId))
                return Forbid();

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

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            if (!await _authorizationService.CanEditAssignmentAsync(id))
            {
                return NotFound(
                    $"Assignation avec l'id {id} introuvable ou accès insuffisant.");
            }

            try
            {
                var deleted = await _service.DeleteAsync(id);

                if (!deleted)
                    return NotFound($"Assignation avec l'id {id} introuvable.");

                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}