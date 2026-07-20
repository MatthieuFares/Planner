using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.ProjectCalendarPeriods;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectCalendarPeriodsController : ControllerBase
    {
        private readonly IProjectCalendarPeriodService _periodService;

        public ProjectCalendarPeriodsController(
            IProjectCalendarPeriodService periodService)
        {
            _periodService = periodService;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<IEnumerable<ProjectCalendarPeriodReadDto>>> GetByProjectId(
            int projectId)
        {
            var periods = await _periodService.GetByProjectIdAsync(projectId);

            if (periods == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(periods);
        }

        [HttpPost("project/{projectId}")]
        public async Task<ActionResult<ProjectCalendarPeriodReadDto>> Create(
            int projectId,
            ProjectCalendarPeriodCreateDto dto)
        {
            try
            {
                var period = await _periodService.CreateAsync(projectId, dto);

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
        public async Task<ActionResult<ProjectCalendarPeriodReadDto>> Update(
            int periodId,
            ProjectCalendarPeriodUpdateDto dto)
        {
            try
            {
                var period = await _periodService.UpdateAsync(periodId, dto);

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
            var deleted = await _periodService.DeleteAsync(periodId);

            if (!deleted)
                return NotFound($"Période avec l'id {periodId} introuvable.");

            return NoContent();
        }
    }
}