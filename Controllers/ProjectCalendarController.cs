using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.ProjectCalendars;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectCalendarsController : ControllerBase
    {
        private readonly IProjectCalendarService _calendarService;
        private readonly IProjectAuthorizationService _authorizationService;

        public ProjectCalendarsController(
            IProjectCalendarService calendarService,
            IProjectAuthorizationService authorizationService)
        {
            _calendarService = calendarService;
            _authorizationService = authorizationService;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<ProjectCalendarReadDto>>
            GetByProjectId(int projectId)
        {
            if (!await _authorizationService.CanReadProjectAsync(projectId))
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            var calendar =
                await _calendarService.GetByProjectIdAsync(projectId);

            if (calendar == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(calendar);
        }

        [HttpPut("project/{projectId}")]
        public async Task<ActionResult<ProjectCalendarReadDto>>
            UpdateByProjectId(
                int projectId,
                ProjectCalendarUpdateDto dto)
        {
            if (!await _authorizationService.CanEditPlanningAsync(projectId))
                return Forbid();

            var calendar =
                await _calendarService.UpdateByProjectIdAsync(
                    projectId,
                    dto);

            if (calendar == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(calendar);
        }
    }
}