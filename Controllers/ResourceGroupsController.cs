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
                return NotFound($"Groupe avec l'id {id} introuvable.");

            return Ok(group);
        }

        [HttpGet("{groupId}/members")]
        public async Task<ActionResult<IEnumerable<ResourceGroupMemberReadDto>>> GetMembers(int groupId)
        {
            var members = await _groupService.GetMembersAsync(groupId);

            if (members == null)
                return NotFound($"Groupe avec l'id {groupId} introuvable.");

            return Ok(members);
        }

        [HttpPost]
        public async Task<ActionResult<ResourceGroupReadDto>> Create(ResourceGroupCreateDto dto)
        {
            try
            {
                var result = await _groupService.CreateAsync(dto);

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

        [HttpPut("{id}")]
        public async Task<ActionResult<ResourceGroupReadDto>> Update(int id, ResourceGroupUpdateDto dto)
        {
            try
            {
                var result = await _groupService.UpdateAsync(id, dto);

                if (result == null)
                    return NotFound($"Groupe avec l'id {id} introuvable.");

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
                var deleted = await _groupService.DeleteAsync(id);

                if (!deleted)
                    return NotFound($"Groupe avec l'id {id} introuvable.");

                return Ok("Groupe supprimé avec succès.");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPost("members")]
        public async Task<ActionResult<ResourceGroupMemberReadDto>> AddMember(ResourceGroupMemberCreateDto dto)
        {
            try
            {
                var member = await _groupService.AddMemberAsync(dto);

                return Ok(member);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpDelete("{groupId}/members/{resourceId}")]
        public async Task<IActionResult> RemoveMember(int groupId, int resourceId)
        {
            try
            {
                var removed = await _groupService.RemoveMemberAsync(groupId, resourceId);

            if (!removed)
                return NotFound("Membre introuvable dans ce groupe.");

                return Ok("Membre retiré avec succès.");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}