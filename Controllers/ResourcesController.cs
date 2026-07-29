using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ResourcesController : ControllerBase
    {
        private readonly IResourceService _resourceService;
        private readonly IProjectAuthorizationService _authorizationService;

        public ResourcesController(
            IResourceService resourceService,
            IProjectAuthorizationService authorizationService)
        {
            _resourceService = resourceService;
            _authorizationService = authorizationService;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<ResourceReadDto>>> GetAll()
        {
            if (!await _authorizationService.CanReadResourceCatalogAsync())
                return Forbid();

            return Ok(await _resourceService.GetAllAsync());
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<ResourceReadDto>> GetById(int id)
        {
            if (!await _authorizationService.CanReadResourceCatalogAsync())
                return Forbid();

            var resource = await _resourceService.GetByIdAsync(id);

            if (resource == null)
                return NotFound($"Ressource avec l'id {id} introuvable.");

            return Ok(resource);
        }

        [HttpPost]
        public async Task<ActionResult<ResourceReadDto>> Create(ResourceCreateDto dto)
        {
            if (!await _authorizationService.CanManageResourceCatalogAsync())
                return Forbid();

            try
            {
                var result = await _resourceService.CreateAsync(dto);

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
        public async Task<ActionResult<ResourceReadDto>> Update(
            int id,
            ResourceUpdateDto dto)
        {
            if (!await _authorizationService.CanManageResourceCatalogAsync())
                return Forbid();

            try
            {
                var result = await _resourceService.UpdateAsync(id, dto);

                if (result == null)
                    return NotFound($"Ressource avec l'id {id} introuvable.");

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
                var deleted = await _resourceService.DeleteAsync(id);

                if (!deleted)
                    return NotFound($"Ressource avec l'id {id} introuvable.");

                return Ok("Ressource supprimée avec succès.");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}