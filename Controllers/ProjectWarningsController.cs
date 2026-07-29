using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/projects")]
    public class ProjectWarningsController : ControllerBase
    {
        private readonly IProjectWarningService _warningService;
        private readonly IProjectAuthorizationService _authorizationService;

        public ProjectWarningsController(
            IProjectWarningService warningService,
            IProjectAuthorizationService authorizationService)
        {
            _warningService = warningService;
            _authorizationService = authorizationService;
        }

        [HttpGet("{projectId}/warnings")]
        public async Task<ActionResult<IEnumerable<ProjectWarningDto>>>
            GetWarnings(int projectId)
        {
            if (!await _authorizationService.CanReadProjectAsync(projectId))
            {
                return NotFound(
                    $"Projet avec l'id {projectId} introuvable.");
            }

            var warnings =
                await _warningService.GetWarningsAsync(projectId);

            if (warnings == null)
            {
                return NotFound(
                    $"Projet avec l'id {projectId} introuvable.");
            }

            return Ok(warnings);
        }
    }
}