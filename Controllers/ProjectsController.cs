using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.DTOs.Tasks;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectsController : ControllerBase
    {
        private readonly IProjectService _projectService;
        private readonly IProjectAuthorizationService
            _authorizationService;
        private readonly ICurrentUserService _currentUser;

        public ProjectsController(
            IProjectService projectService,
            IProjectAuthorizationService authorizationService,
            ICurrentUserService currentUser)
        {
            _projectService = projectService;
            _authorizationService = authorizationService;
            _currentUser = currentUser;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<ProjectReadDto>>>
            GetProjects()
        {
            return Ok(await _projectService.GetAllAsync());
        }

        [HttpGet("list")]
        public async Task<ActionResult<ProjectListResponseDto>>
            GetProjectList()
        {
            var canCreateProjects =
                await _authorizationService
                    .CanCreateProjectAsync();

            var projects =
                (await _projectService.GetListItemsAsync())
                    .ToList();

            var isGlobalAdmin =
                _currentUser.IsGlobalAdmin;

            var canManageAccess =
                isGlobalAdmin ||
                projects.Any(project =>
                    project.CanManageMembers);

            return Ok(
                new ProjectListResponseDto
                {
                    CanCreateProjects =
                        canCreateProjects,
                    CanImportProjects =
                        canCreateProjects,
                    CanManageAccess =
                        canManageAccess,
                    IsGlobalAdmin =
                        isGlobalAdmin,
                    Projects = projects
                });
        }

        [HttpGet("{id:int}")]
        public async Task<ActionResult<ProjectReadDto>>
            GetProjectById(int id)
        {
            var project =
                await _projectService.GetByIdAsync(id);

            if (project == null)
            {
                return NotFound(
                    $"Projet avec l'id {id} introuvable.");
            }

            return Ok(project);
        }

        [HttpGet("{id:int}/tasks")]
        public async Task<ActionResult<IEnumerable<TaskReadDto>>>
            GetTasksByProjectId(int id)
        {
            var tasks =
                await _projectService
                    .GetTasksByProjectIdAsync(id);

            if (tasks == null)
            {
                return NotFound(
                    $"Projet avec l'id {id} introuvable.");
            }

            return Ok(tasks);
        }

        [HttpPost]
        public async Task<ActionResult<ProjectReadDto>>
            CreateProject(ProjectCreateDto dto)
        {
            if (!await _authorizationService
                    .CanCreateProjectAsync())
            {
                return Forbid();
            }

            try
            {
                var result =
                    await _projectService.CreateAsync(dto);

                return CreatedAtAction(
                    nameof(GetProjectById),
                    new { id = result.Id },
                    result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPut("{id:int}")]
        public async Task<ActionResult<ProjectReadDto>>
            UpdateProject(
                int id,
                ProjectUpdateDto dto)
        {
            try
            {
                var result =
                    await _projectService
                        .UpdateAsync(id, dto);

                if (result == null)
                {
                    return NotFound(
                        $"Projet avec l'id {id} introuvable " +
                        "ou accès insuffisant.");
                }

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult>
            DeleteProject(int id)
        {
            try
            {
                var deleted =
                    await _projectService.DeleteAsync(id);

                if (!deleted)
                {
                    return NotFound(
                        $"Projet avec l'id {id} introuvable " +
                        "ou accès insuffisant.");
                }

                return Ok(
                    "Projet supprimé avec succès.");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}
