using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ResourceGroupsController : ControllerBase
    {
        private readonly IResourceGroupService _groupService;
        private readonly IProjectAuthorizationService _authorizationService;

        public ResourceGroupsController(
            IResourceGroupService groupService,
            IProjectAuthorizationService authorizationService)
        {
            _groupService = groupService;
            _authorizationService = authorizationService;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<ResourceGroupReadDto>>> GetAll()
        {
            if (!await _authorizationService.CanReadResourceCatalogAsync())
                return Forbid();

            return Ok(await _groupService.GetAllAsync());
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<ResourceGroupReadDto>> GetById(int id)
        {
            if (!await _authorizationService.CanReadResourceCatalogAsync())
                return Forbid();

            var group = await _groupService.GetByIdAsync(id);

            if (group == null)
                return NotFound($"Groupe avec l'id {id} introuvable.");

            return Ok(group);
        }

        [HttpGet("{groupId}/members")]
        public async Task<ActionResult<IEnumerable<ResourceGroupMemberReadDto>>> GetMembers(
            int groupId)
        {
            if (!await _authorizationService.CanReadResourceCatalogAsync())
                return Forbid();

            var members = await _groupService.GetMembersAsync(groupId);

            if (members == null)
                return NotFound($"Groupe avec l'id {groupId} introuvable.");

            return Ok(members);
        }

        [HttpPost]
        public async Task<ActionResult<ResourceGroupReadDto>> Create(
            ResourceGroupCreateDto dto)
        {
            if (!await _authorizationService.CanManageResourceCatalogAsync())
                return Forbid();

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
        public async Task<ActionResult<ResourceGroupReadDto>> Update(
            int id,
            ResourceGroupUpdateDto dto)
        {
            if (!await _authorizationService.CanManageResourceCatalogAsync())
                return Forbid();

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
            if (!await _authorizationService.CanManageResourceCatalogAsync())
                return Forbid();

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
        public async Task<ActionResult<ResourceGroupMemberReadDto>> AddMember(
            ResourceGroupMemberCreateDto dto)
        {
            if (!await _authorizationService.CanManageResourceCatalogAsync())
                return Forbid();

            try
            {
                return Ok(await _groupService.AddMemberAsync(dto));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpDelete("{groupId}/members/{resourceId}")]
        public async Task<IActionResult> RemoveMember(
            int groupId,
            int resourceId)
        {
            if (!await _authorizationService.CanManageResourceCatalogAsync())
                return Forbid();

            try
            {
                var removed =
                    await _groupService.RemoveMemberAsync(groupId, resourceId);

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