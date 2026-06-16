using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.PlanningItems;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PlanningItemsController : ControllerBase
    {
        private readonly IPlanningItemService _planningItemService;

        public PlanningItemsController(IPlanningItemService planningItemService)
        {
            _planningItemService = planningItemService;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<IEnumerable<PlanningItemReadDto>>> GetByProject(int projectId)
        {
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
            var item = await _planningItemService.GetByIdAsync(id);

            if (item == null)
                return NotFound($"Élément de planning avec l'id {id} introuvable.");

            return Ok(item);
        }

        [HttpPost]
        public async Task<ActionResult<PlanningItemReadDto>> Create(PlanningItemCreateDto dto)
        {
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

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
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