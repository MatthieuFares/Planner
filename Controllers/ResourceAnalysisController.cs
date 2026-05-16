using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Resources;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ResourceAnalysisController : ControllerBase
    {
        private readonly IResourceAnalysisService _analysisService;

        public ResourceAnalysisController(IResourceAnalysisService analysisService)
        {
            _analysisService = analysisService;
        }

        [HttpGet("project/{projectId}")]
        public async Task<ActionResult<ProjectResourceAnalysisDto>> GetProjectAnalysis(int projectId)
        {
            var result = await _analysisService.GetProjectAnalysisAsync(projectId);

            if (result == null)
                return NotFound($"Projet avec l'id {projectId} introuvable.");

            return Ok(result);
        }
    }
}