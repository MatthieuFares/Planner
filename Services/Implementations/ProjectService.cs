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
        private readonly ITaskService _taskService;

        public ProjectService(AppDbContext context, ITaskService taskService)
        {
            _context = context;
            _taskService = taskService;
        }

        public async Task<IEnumerable<ProjectReadDto>> GetAllAsync()
        {
            var projects = await _context.Projects
                .OrderBy(p => p.Name)
                .ToListAsync();

            return projects.Select(MapToReadDto);
        }

        public async Task<ProjectReadDto?> GetByIdAsync(int id)
        {
            var project = await _context.Projects.FindAsync(id);

            if (project == null)
                return null;

            return MapToReadDto(project);
        }

        public async Task<IEnumerable<TaskReadDto>?> GetTasksByProjectIdAsync(int projectId)
        {
            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return null;

            return await _taskService.GetByProjectIdAsync(projectId);
        }

        public async Task<ProjectReadDto> CreateAsync(ProjectCreateDto dto)
        {
            var project = new Project
            {
                Name = dto.Name,
                Description = dto.Description,
                ClientName = dto.ClientName,
                ProjectCode = dto.ProjectCode,
                StartDate = dto.StartDate,
                EndDate = dto.EndDate
            };

            ValidateProjectDates(project.StartDate, project.EndDate);

            _context.Projects.Add(project);

            await _context.SaveChangesAsync();

            return MapToReadDto(project);
        }

        public async Task<ProjectReadDto?> UpdateAsync(int id, ProjectUpdateDto dto)
        {
            var project = await _context.Projects.FindAsync(id);

            if (project == null)
                return null;

            project.Name = dto.Name;
            project.Description = dto.Description;
            project.ClientName = dto.ClientName;
            project.ProjectCode = dto.ProjectCode;
            project.StartDate = dto.StartDate;
            project.EndDate = dto.EndDate;

            ValidateProjectDates(project.StartDate, project.EndDate);

            await _context.SaveChangesAsync();

            return MapToReadDto(project);
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var project = await _context.Projects.FindAsync(id);

            if (project == null)
                return false;

            var hasTasks = await _context.Tasks
                .AnyAsync(t => t.ProjectId == id);

            if (hasTasks)
                throw new InvalidOperationException(
                    "Impossible de supprimer ce projet car il contient une ou plusieurs tâches.");

            _context.Projects.Remove(project);

            await _context.SaveChangesAsync();

            return true;
        }

        private static ProjectReadDto MapToReadDto(Project project)
        {
            return new ProjectReadDto
            {
                Id = project.Id,
                Name = project.Name,
                Description = project.Description,
                ClientName = project.ClientName,
                ProjectCode = project.ProjectCode,
                StartDate = project.StartDate,
                EndDate = project.EndDate
            };
        }
        private static void ValidateProjectDates(DateTime? startDate, DateTime? endDate)
        {
            if (startDate.HasValue &&
                endDate.HasValue &&
                endDate.Value.Date < startDate.Value.Date)
            {
                throw new InvalidOperationException(
                    "La date de fin du projet ne peut pas être antérieure à la date de début.");
            }
        }
    }
}