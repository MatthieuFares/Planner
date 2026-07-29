using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/projects")]
    public class ProjectAccessController : ControllerBase
    {
        private readonly IProjectAuthorizationService
            _authorizationService;

        public ProjectAccessController(
            IProjectAuthorizationService authorizationService)
        {
            _authorizationService = authorizationService;
        }

        [HttpGet("{projectId:int}/access")]
        public async Task<ActionResult<ProjectAccessDto>> GetAccess(
            int projectId)
        {
            var canReadProject =
                await _authorizationService
                    .CanReadProjectAsync(projectId);

            if (!canReadProject)
            {
                return NotFound(
                    $"Projet avec l'id {projectId} introuvable.");
            }

            var canEditPlanning =
                await _authorizationService
                    .CanEditPlanningAsync(projectId);

            var canManageMembers =
                await _authorizationService
                    .CanManageMembersAsync(projectId);

            var canDeleteProject =
                await _authorizationService
                    .CanDeleteProjectAsync(projectId);

            var canCreateProjects =
                await _authorizationService
                    .CanCreateProjectAsync();

            var canReadResourceCatalog =
                await _authorizationService
                    .CanReadResourceCatalogAsync();

            var canManageResourceCatalog =
                await _authorizationService
                    .CanManageResourceCatalogAsync();

            return Ok(
                new ProjectAccessDto
                {
                    ProjectId = projectId,
                    CanReadProject = true,
                    CanEditPlanning = canEditPlanning,
                    CanManageMembers = canManageMembers,
                    CanDeleteProject = canDeleteProject,
                    CanCreateProjects = canCreateProjects,
                    CanReadResourceCatalog =
                        canReadResourceCatalog,
                    CanManageResourceCatalog =
                        canManageResourceCatalog,
                    CanImportProjects =
                        canCreateProjects &&
                        canManageResourceCatalog
                });
        }
    }
}
