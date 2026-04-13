using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.DTOs.Tasks;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ProjectService : IProjectService
    {
        private readonly AppDbContext _context;

        public ProjectService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<ProjectReadDto>> GetAllAsync()
        {
            return await _context.Projects
                .Select(p => new ProjectReadDto
                {
                    Id = p.Id,
                    Name = p.Name,
                    Description = p.Description
                })
                .ToListAsync();
        }

        public async Task<ProjectReadDto?> GetByIdAsync(int id)
        {
            return await _context.Projects
                .Where(p => p.Id == id)
                .Select(p => new ProjectReadDto
                {
                    Id = p.Id,
                    Name = p.Name,
                    Description = p.Description
                })
                .FirstOrDefaultAsync();
        }

        public async Task<IEnumerable<TaskReadDto>> GetTasksByProjectIdAsync(int projectId)
        {
            var projectExists = await _context.Projects.AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return Enumerable.Empty<TaskReadDto>();

            return await _context.Tasks
                .Where(t => t.ProjectId == projectId)
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
        }

        public async Task<ProjectReadDto> CreateAsync(ProjectCreateDto dto)
        {
            var project = new Project
            {
                Name = dto.Name,
                Description = dto.Description
            };

            _context.Projects.Add(project);
            await _context.SaveChangesAsync();

            return new ProjectReadDto
            {
                Id = project.Id,
                Name = project.Name,
                Description = project.Description
            };
        }

        public async Task<bool> UpdateAsync(int id, ProjectUpdateDto dto)
        {
            var project = await _context.Projects.FindAsync(id);

            if (project == null)
                return false;

            project.Name = dto.Name;
            project.Description = dto.Description;

            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var project = await _context.Projects.FindAsync(id);

            if (project == null)
                return false;

            _context.Projects.Remove(project);
            await _context.SaveChangesAsync();
            return true;
        }
    }
}