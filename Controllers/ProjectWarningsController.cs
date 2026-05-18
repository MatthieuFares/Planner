using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/projects")]
    public class ProjectWarningsController : ControllerBase
    {
        private readonly IProjectWarningService _warningService;

        public ProjectWarningsController(IProjectWarningService warningService)
        {
            _warningService = warningService;
        }

        [HttpGet("{projectId}/warnings")]
        public async Task<ActionResult<IEnumerable<ProjectWarningDto>>> GetWarnings(int projectId)
        {
            var warnings = await _warningService.GetWarningsAsync(projectId);

            if (warnings == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(warnings);
        }
    }
}