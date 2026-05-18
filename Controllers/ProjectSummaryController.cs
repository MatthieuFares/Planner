using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/projects")]
    public class ProjectSummaryController : ControllerBase
    {
        private readonly IProjectSummaryService _summaryService;

        public ProjectSummaryController(IProjectSummaryService summaryService)
        {
            _summaryService = summaryService;
        }

        [HttpGet("{projectId}/summary")]
        public async Task<ActionResult<ProjectSummaryDto>> GetSummary(int projectId)
        {
            var summary = await _summaryService.GetSummaryAsync(projectId);

            if (summary == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(summary);
        }
    }
}