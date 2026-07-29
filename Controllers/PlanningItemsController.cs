using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.PlanningItems;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class PlanningItemsController : ControllerBase
    {
        private readonly IPlanningItemService _planningItemService;
        private readonly IProjectAuthorizationService _authorizationService;

        public PlanningItemsController(
            IPlanningItemService planningItemService,
            IProjectAuthorizationService authorizationService)
        {
            _planningItemService = planningItemService;
            _authorizationService = authorizationService;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<IEnumerable<PlanningItemReadDto>>> GetByProject(int projectId)
        {
            if (!await _authorizationService.CanReadProjectAsync(projectId))
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            try
            {
                var items = await _planningItemService.GetByProjectIdAsync(projectId);
                return Ok(items);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<PlanningItemReadDto>> GetById(int id)
        {
            if (!await _authorizationService.CanReadPlanningItemAsync(id))
                return NotFound($"Élément de planning avec l'id {id} introuvable.");

            var item = await _planningItemService.GetByIdAsync(id);

            if (item == null)
                return NotFound($"Élément de planning avec l'id {id} introuvable.");

            return Ok(item);
        }

        [HttpPost]
        public async Task<ActionResult<PlanningItemReadDto>> Create(PlanningItemCreateDto dto)
        {
            if (!await _authorizationService.CanEditPlanningAsync(dto.ProjectId))
                return Forbid();

            if (dto.ParentId.HasValue &&
                !await _authorizationService.CanEditPlanningItemAsync(dto.ParentId.Value))
                return Forbid();

            if (dto.TaskId.HasValue &&
                !await _authorizationService.CanEditTaskAsync(dto.TaskId.Value))
                return Forbid();

            try
            {
                var result = await _planningItemService.CreateAsync(dto);

                return CreatedAtAction(
                    nameof(GetById),
                    new { id = result.Id },
                    result
                );
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPost("project/{projectId}/sync-tasks")]
        public async Task<ActionResult<PlanningItemSyncResultDto>> SyncProjectTasks(int projectId)
        {
            if (!await _authorizationService.CanEditPlanningAsync(projectId))
                return Forbid();

            try
            {
                var result = await _planningItemService.SyncProjectTasksAsync(projectId);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPut("{id}")]
        public async Task<ActionResult<PlanningItemReadDto>> Update(int id, PlanningItemUpdateDto dto)
        {
            if (!await _authorizationService.CanEditPlanningItemAsync(id))
            {
                return NotFound(
                    $"Élément de planning avec l'id {id} introuvable ou accès insuffisant.");
            }

            if (dto.ParentId.HasValue &&
                !await _authorizationService.CanEditPlanningItemAsync(dto.ParentId.Value))
                return Forbid();

            if (dto.TaskId.HasValue &&
                !await _authorizationService.CanEditTaskAsync(dto.TaskId.Value))
                return Forbid();

            try
            {
                var result = await _planningItemService.UpdateAsync(id, dto);

                if (result == null)
                    return NotFound($"Élément de planning avec l'id {id} introuvable.");

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPost("{id}/move")]
        public async Task<ActionResult<PlanningItemReadDto>> Move(int id, PlanningItemMoveDto dto)
        {
            if (!await _authorizationService.CanEditPlanningItemAsync(id))
            {
                return NotFound(
                    $"Élément de planning avec l'id {id} introuvable ou accès insuffisant.");
            }

            if (dto.NewParentId.HasValue &&
                !await _authorizationService.CanEditPlanningItemAsync(dto.NewParentId.Value))
                return Forbid();

            try
            {
                var result = await _planningItemService.MoveAsync(id, dto);

                if (result == null)
                    return NotFound($"Élément de planning avec l'id {id} introuvable.");

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            if (!await _authorizationService.CanEditPlanningItemAsync(id))
            {
                return NotFound(
                    $"Élément de planning avec l'id {id} introuvable ou accès insuffisant.");
            }

            try
            {
                var deleted = await _planningItemService.DeleteAsync(id);

                if (!deleted)
                    return NotFound($"Élément de planning avec l'id {id} introuvable.");

                return Ok("Élément de planning supprimé avec succès.");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}