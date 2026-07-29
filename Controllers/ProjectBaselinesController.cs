using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.ProjectBaselines;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectBaselinesController : ControllerBase
    {
        private readonly IProjectBaselineService _baselineService;
        private readonly IProjectAuthorizationService _authorizationService;

        public ProjectBaselinesController(
            IProjectBaselineService baselineService,
            IProjectAuthorizationService authorizationService)
        {
            _baselineService = baselineService;
            _authorizationService = authorizationService;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<IEnumerable<ProjectBaselineReadDto>>>
            GetByProjectId(int projectId)
        {
            if (!await _authorizationService.CanReadProjectAsync(projectId))
            {
                return NotFound(
                    $"Projet avec l'id {projectId} introuvable.");
            }

            var baselines =
                await _baselineService.GetByProjectIdAsync(projectId);

            if (baselines == null)
            {
                return NotFound(
                    $"Projet avec l'id {projectId} introuvable.");
            }

            return Ok(baselines);
        }

        [HttpGet("{baselineId}")]
        public async Task<ActionResult<ProjectBaselineDetailDto>>
            GetById(int baselineId)
        {
            if (!await _authorizationService
                    .CanReadBaselineAsync(baselineId))
            {
                return NotFound(
                    $"Baseline avec l'id {baselineId} introuvable.");
            }

            var baseline =
                await _baselineService.GetByIdAsync(baselineId);

            if (baseline == null)
            {
                return NotFound(
                    $"Baseline avec l'id {baselineId} introuvable.");
            }

            return Ok(baseline);
        }

        [HttpPost("project/{projectId}")]
        public async Task<ActionResult<ProjectBaselineDetailDto>>
            Create(
                int projectId,
                ProjectBaselineCreateDto dto)
        {
            if (!await _authorizationService
                    .CanEditPlanningAsync(projectId))
            {
                return Forbid();
            }

            var baseline =
                await _baselineService.CreateAsync(projectId, dto);

            if (baseline == null)
            {
                return NotFound(
                    $"Projet avec l'id {projectId} introuvable.");
            }

            return Ok(baseline);
        }

        [HttpGet("{baselineId}/comparison")]
        public async Task<ActionResult<ProjectBaselineComparisonDto>>
            Compare(int baselineId)
        {
            if (!await _authorizationService
                    .CanReadBaselineAsync(baselineId))
            {
                return NotFound(
                    $"Baseline avec l'id {baselineId} introuvable.");
            }

            var comparison =
                await _baselineService.CompareAsync(baselineId);

            if (comparison == null)
            {
                return NotFound(
                    $"Baseline avec l'id {baselineId} introuvable.");
            }

            return Ok(comparison);
        }

        [HttpPut("{baselineId}/set-active")]
        public async Task<ActionResult<ProjectBaselineReadDto>>
            SetActive(int baselineId)
        {
            if (!await _authorizationService
                    .CanEditBaselineAsync(baselineId))
            {
                return NotFound(
                    $"Baseline avec l'id {baselineId} introuvable ou accès insuffisant.");
            }

            var baseline =
                await _baselineService.SetActiveAsync(baselineId);

            if (baseline == null)
            {
                return NotFound(
                    $"Baseline avec l'id {baselineId} introuvable.");
            }

            return Ok(baseline);
        }

        [HttpDelete("{baselineId}")]
        public async Task<IActionResult> Delete(int baselineId)
        {
            if (!await _authorizationService
                    .CanEditBaselineAsync(baselineId))
            {
                return NotFound(
                    $"Baseline avec l'id {baselineId} introuvable ou accès insuffisant.");
            }

            var deleted =
                await _baselineService.DeleteAsync(baselineId);

            if (!deleted)
            {
                return NotFound(
                    $"Baseline avec l'id {baselineId} introuvable.");
            }

            return NoContent();
        }
    }
}