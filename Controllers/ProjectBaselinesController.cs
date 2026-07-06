using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.ProjectBaselines;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectBaselinesController : ControllerBase
    {
        private readonly IProjectBaselineService _baselineService;

        public ProjectBaselinesController(IProjectBaselineService baselineService)
        {
            _baselineService = baselineService;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<IEnumerable<ProjectBaselineReadDto>>> GetByProjectId(
            int projectId)
        {
            var baselines = await _baselineService.GetByProjectIdAsync(projectId);

            if (baselines == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(baselines);
        }

        [HttpGet("{baselineId}")]
        public async Task<ActionResult<ProjectBaselineDetailDto>> GetById(int baselineId)
        {
            var baseline = await _baselineService.GetByIdAsync(baselineId);

            if (baseline == null)
                return NotFound($"Baseline avec l'id {baselineId} introuvable.");

            return Ok(baseline);
        }

        [HttpPost("project/{projectId}")]
        public async Task<ActionResult<ProjectBaselineDetailDto>> Create(
            int projectId,
            ProjectBaselineCreateDto dto)
        {
            var baseline = await _baselineService.CreateAsync(projectId, dto);

            if (baseline == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(baseline);
        }

        [HttpGet("{baselineId}/comparison")]
        public async Task<ActionResult<ProjectBaselineComparisonDto>> Compare(int baselineId)
        {
            var comparison = await _baselineService.CompareAsync(baselineId);

            if (comparison == null)
                return NotFound($"Baseline avec l'id {baselineId} introuvable.");

            return Ok(comparison);
        }

        [HttpPut("{baselineId}/set-active")]
        public async Task<ActionResult<ProjectBaselineReadDto>> SetActive(int baselineId)
        {
            var baseline = await _baselineService.SetActiveAsync(baselineId);

            if (baseline == null)
                return NotFound($"Baseline avec l'id {baselineId} introuvable.");

            return Ok(baseline);
        }

        [HttpDelete("{baselineId}")]
        public async Task<IActionResult> Delete(int baselineId)
        {
            var deleted = await _baselineService.DeleteAsync(baselineId);

            if (!deleted)
                return NotFound($"Baseline avec l'id {baselineId} introuvable.");

            return NoContent();
        }
    }
}