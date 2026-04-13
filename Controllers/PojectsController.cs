using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.DTOs.Tasks;
using PlannerAPI.Models;

namespace PlannerAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public ProjectsController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async System.Threading.Tasks.Task<ActionResult<IEnumerable<ProjectReadDto>>> GetProjects()
        {
            var projects = await _context.Projects
                .Select(p => new ProjectReadDto
                {
                    Id = p.Id,
                    Name = p.Name,
                    Description = p.Description
                })
                .ToListAsync();

            return Ok(projects);
        }

        [HttpGet("{id}")]
        public async System.Threading.Tasks.Task<ActionResult<ProjectReadDto>> GetProjectById(int id)
        {
            var project = await _context.Projects.FindAsync(id);

            if (project == null)
                return NotFound();

            var dto = new ProjectReadDto
            {
                Id = project.Id,
                Name = project.Name,
                Description = project.Description
            };

            return Ok(dto);
        }

        [HttpGet("{id}/tasks")]
        public async System.Threading.Tasks.Task<ActionResult<IEnumerable<TaskReadDto>>> GetTasksByProjectId(int id)
        {
            var projectExists = await _context.Projects.AnyAsync(p => p.Id == id);

            if (!projectExists)
                return NotFound($"Projet avec l'id {id} introuvable.");

            var tasks = await _context.Tasks
                .Where(t => t.ProjectId == id)
                .Select(t => new TaskReadDto
                {
                    Id = t.Id,
                    Title = t.Title,
                    Description = t.Description,
                    IsDone = t.IsDone,
                    ProjectId = t.ProjectId,
                    StartDate = t.StartDate,
                    EndDate = t.EndDate,
                    Duration = t.Duration
                })
                .ToListAsync();
                
            return Ok(tasks);
        }

        [HttpPost]
        public async System.Threading.Tasks.Task<ActionResult<ProjectReadDto>> CreateProject(ProjectCreateDto dto)
        {
            var project = new Project
            {
                Name = dto.Name,
                Description = dto.Description
            };

            _context.Projects.Add(project);
            await _context.SaveChangesAsync();

            var result = new ProjectReadDto
            {
                Id = project.Id,
                Name = project.Name,
                Description = project.Description
            };

            return CreatedAtAction(nameof(GetProjectById), new { id = project.Id }, result);
        }

        [HttpPut("{id}")]
        public async System.Threading.Tasks.Task<IActionResult> UpdateProject(int id, ProjectUpdateDto dto)
        {
            var project = await _context.Projects.FindAsync(id);

            if (project == null)
                return NotFound();

            project.Name = dto.Name;
            project.Description = dto.Description;

            await _context.SaveChangesAsync();

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async System.Threading.Tasks.Task<IActionResult> DeleteProject(int id)
        {
            var project = await _context.Projects.FindAsync(id);

            if (project == null)
                return NotFound();

            _context.Projects.Remove(project);
            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}