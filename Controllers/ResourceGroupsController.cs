using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ResourceGroupsController : ControllerBase
    {
        private readonly IResourceGroupService _groupService;

        public ResourceGroupsController(IResourceGroupService groupService)
        {
            _groupService = groupService;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<ResourceGroupReadDto>>> GetAll()
        {
            var groups = await _groupService.GetAllAsync();

            return Ok(groups);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<ResourceGroupReadDto>> GetById(int id)
        {
            var group = await _groupService.GetByIdAsync(id);

            if (group == null)
                return NotFound();

            return Ok(group);
        }

        [HttpPost]
        public async Task<ActionResult<ResourceGroupReadDto>> Create(ResourceGroupCreateDto dto)
        {
            var result = await _groupService.CreateAsync(dto);

            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPost("members")]
        public async Task<IActionResult> AddMember(ResourceGroupMemberCreateDto dto)
        {
            var added = await _groupService.AddMemberAsync(dto);

            if (!added)
                return BadRequest("Impossible d'ajouter le membre.");

            return Ok();
        }

        [HttpDelete("{groupId}/members/{resourceId}")]
        public async Task<IActionResult> RemoveMember(int groupId, int resourceId)
        {
            var removed = await _groupService.RemoveMemberAsync(groupId, resourceId);

            if (!removed)
                return NotFound();

            return NoContent();
        }
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, ResourceGroupUpdateDto dto)
        {
            var updated = await _groupService.UpdateAsync(id, dto);

            if (!updated)
                return NotFound();

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _groupService.DeleteAsync(id);

            if (!deleted)
                return NotFound();

            return NoContent();
        }
    }
}