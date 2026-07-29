using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ResourceAnalysisController : ControllerBase
    {
        private readonly IResourceAnalysisService _analysisService;
        private readonly IProjectAuthorizationService _authorizationService;

        public ResourceAnalysisController(
            IResourceAnalysisService analysisService,
            IProjectAuthorizationService authorizationService)
        {
            _analysisService = analysisService;
            _authorizationService = authorizationService;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<ProjectResourceAnalysisDto>>
            GetProjectAnalysis(int projectId)
        {
            if (!await _authorizationService.CanReadProjectAsync(projectId))
            {
                return NotFound(
                    $"Projet avec l'id {projectId} introuvable.");
            }

            var result =
                await _analysisService
                    .GetProjectAnalysisAsync(projectId);

            if (result == null)
            {
                return NotFound(
                    $"Projet avec l'id {projectId} introuvable.");
            }

            return Ok(result);
        }
    }
}