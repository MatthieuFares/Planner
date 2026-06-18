using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.ProjectCalendars;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectCalendarsController : ControllerBase
    {
        private readonly IProjectCalendarService _calendarService;

        public ProjectCalendarsController(IProjectCalendarService calendarService)
        {
            _calendarService = calendarService;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<ProjectCalendarReadDto>> GetByProjectId(int projectId)
        {
            var calendar = await _calendarService.GetByProjectIdAsync(projectId);

            if (calendar == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(calendar);
        }

        [HttpPut("project/{projectId}")]
        public async Task<ActionResult<ProjectCalendarReadDto>> UpdateByProjectId(
            int projectId,
            ProjectCalendarUpdateDto dto)
        {
            var calendar = await _calendarService.UpdateByProjectIdAsync(projectId, dto);

            if (calendar == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(calendar);
        }
    }
}