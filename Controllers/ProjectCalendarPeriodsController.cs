using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.ProjectCalendarPeriods;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectCalendarPeriodsController : ControllerBase
    {
        private readonly IProjectCalendarPeriodService _periodService;
        private readonly IProjectAuthorizationService _authorizationService;

        public ProjectCalendarPeriodsController(
            IProjectCalendarPeriodService periodService,
            IProjectAuthorizationService authorizationService)
        {
            _periodService = periodService;
            _authorizationService = authorizationService;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<IEnumerable<ProjectCalendarPeriodReadDto>>>
            GetByProjectId(int projectId)
        {
            if (!await _authorizationService.CanReadProjectAsync(projectId))
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            var periods =
                await _periodService.GetByProjectIdAsync(projectId);

            if (periods == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(periods);
        }

        [HttpPost("project/{projectId}")]
        public async Task<ActionResult<ProjectCalendarPeriodReadDto>>
            Create(
                int projectId,
                ProjectCalendarPeriodCreateDto dto)
        {
            if (!await _authorizationService.CanEditPlanningAsync(projectId))
                return Forbid();

            try
            {
                var period =
                    await _periodService.CreateAsync(projectId, dto);

                if (period == null)
                    return NotFound($"Projet avec l'id {projectId} introuvable.");

                return Ok(period);
            }
            catch (InvalidOperationException error)
            {
                return BadRequest(error.Message);
            }
        }

        [HttpPut("{periodId}")]
        public async Task<ActionResult<ProjectCalendarPeriodReadDto>>
            Update(
                int periodId,
                ProjectCalendarPeriodUpdateDto dto)
        {
            if (!await _authorizationService
                    .CanEditCalendarPeriodAsync(periodId))
            {
                return NotFound(
                    $"Période avec l'id {periodId} introuvable ou accès insuffisant.");
            }

            try
            {
                var period =
                    await _periodService.UpdateAsync(
                        periodId,
                        dto);

                if (period == null)
                    return NotFound($"Période avec l'id {periodId} introuvable.");

                return Ok(period);
            }
            catch (InvalidOperationException error)
            {
                return BadRequest(error.Message);
            }
        }

        [HttpDelete("{periodId}")]
        public async Task<IActionResult> Delete(int periodId)
        {
            if (!await _authorizationService
                    .CanEditCalendarPeriodAsync(periodId))
            {
                return NotFound(
                    $"Période avec l'id {periodId} introuvable ou accès insuffisant.");
            }

            var deleted =
                await _periodService.DeleteAsync(periodId);

            if (!deleted)
                return NotFound($"Période avec l'id {periodId} introuvable.");

            return NoContent();
        }
    }
}