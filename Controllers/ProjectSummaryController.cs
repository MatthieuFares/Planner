using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/projects")]
    public class ProjectSummaryController : ControllerBase
    {
        private readonly IProjectSummaryService _summaryService;
        private readonly IProjectAuthorizationService _authorizationService;

        public ProjectSummaryController(
            IProjectSummaryService summaryService,
            IProjectAuthorizationService authorizationService)
        {
            _summaryService = summaryService;
            _authorizationService = authorizationService;
        }

        [HttpGet("{projectId}/summary")]
        public async Task<ActionResult<ProjectSummaryDto>> GetSummary(
            int projectId)
        {
            if (!await _authorizationService.CanReadProjectAsync(projectId))
            {
                return NotFound(
                    $"Projet avec l'id {projectId} introuvable.");
            }

            var summary =
                await _summaryService.GetSummaryAsync(projectId);

            if (summary == null)
            {
                return NotFound(
                    $"Projet avec l'id {projectId} introuvable.");
            }

            return Ok(summary);
        }
    }
}