using Microsoft.AspNetCore.Mvc;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.DTOs.Tasks;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectsController : ControllerBase
    {
        private readonly IProjectService _projectService;

        public ProjectsController(IProjectService projectService)
        {
            _projectService = projectService;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<ProjectReadDto>>> GetProjects()
        {
            var projects = await _projectService.GetAllAsync();

            return Ok(projects);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<ProjectReadDto>> GetProjectById(int id)
        {
            var project = await _projectService.GetByIdAsync(id);

            if (project == null)
                return NotFound($"Projet avec l'id {id} introuvable.");

            return Ok(project);
        }

        [HttpGet("{id}/tasks")]
        public async Task<ActionResult<IEnumerable<TaskReadDto>>> GetTasksByProjectId(int id)
        {
            var tasks = await _projectService.GetTasksByProjectIdAsync(id);

            if (tasks == null)
                return NotFound($"Projet avec l'id {id} introuvable.");

            return Ok(tasks);
        }

        [HttpPost]
        public async Task<ActionResult<ProjectReadDto>> CreateProject(ProjectCreateDto dto)
        {
            var result = await _projectService.CreateAsync(dto);

            return CreatedAtAction(
                nameof(GetProjectById),
                new { id = result.Id },
                result
            );
        }

        [HttpPut("{id}")]
        public async Task<ActionResult<ProjectReadDto>> UpdateProject(int id, ProjectUpdateDto dto)
        {
            var result = await _projectService.UpdateAsync(id, dto);

            if (result == null)
                return NotFound($"Projet avec l'id {id} introuvable.");

            return Ok(result);
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteProject(int id)
        {
            var deleted = await _projectService.DeleteAsync(id);

            if (!deleted)
                return NotFound($"Projet avec l'id {id} introuvable.");

            return Ok("Projet supprimé avec succès.");
        }
    }
}