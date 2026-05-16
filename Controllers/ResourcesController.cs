using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ResourcesController : ControllerBase
    {
        private readonly IResourceService _resourceService;

        public ResourcesController(IResourceService resourceService)
        {
            _resourceService = resourceService;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<ResourceReadDto>>> GetAll()
        {
            var resources = await _resourceService.GetAllAsync();

            return Ok(resources);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<ResourceReadDto>> GetById(int id)
        {
            var resource = await _resourceService.GetByIdAsync(id);

            if (resource == null)
                return NotFound();

            return Ok(resource);
        }

        [HttpPost]
        public async Task<ActionResult<ResourceReadDto>> Create(ResourceCreateDto dto)
        {
            var result = await _resourceService.CreateAsync(dto);

            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, ResourceUpdateDto dto)
        {
            var updated = await _resourceService.UpdateAsync(id, dto);

            if (!updated)
                return NotFound();

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _resourceService.DeleteAsync(id);

            if (!deleted)
                return NotFound();

            return NoContent();
        }
    }
}