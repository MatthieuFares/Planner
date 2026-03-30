using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Tasks;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class TaskService : ITaskService
    {
        private readonly AppDbContext _context;

        public TaskService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<TaskReadDto>> GetAllAsync()
        {
            return await _context.Tasks
                .Select(t => new TaskReadDto
                {
                    Id = t.Id,
                    Title = t.Title,
                    Description = t.Description,
                    IsDone = t.IsDone,
                    ProjectId = t.ProjectId
                })
                .ToListAsync();
        }

        public async Task<TaskReadDto?> GetByIdAsync(int id)
        {
            return await _context.Tasks
                .Where(t => t.Id == id)
                .Select(t => new TaskReadDto
                {
                    Id = t.Id,
                    Title = t.Title,
                    Description = t.Description,
                    IsDone = t.IsDone,
                    ProjectId = t.ProjectId
                })
                .FirstOrDefaultAsync();
        }

        public async Task<TaskReadDto?> CreateAsync(TaskCreateDto dto)
        {
            var projectExists = await _context.Projects.AnyAsync(p => p.Id == dto.ProjectId);

            if (!projectExists)
                return null;

            var taskItem = new PlannerTask
            {
                Title = dto.Title,
                Description = dto.Description,
                IsDone = dto.IsDone,
                ProjectId = dto.ProjectId
            };

            _context.Tasks.Add(taskItem);
            await _context.SaveChangesAsync();

            return new TaskReadDto
            {
                Id = taskItem.Id,
                Title = taskItem.Title,
                Description = taskItem.Description,
                IsDone = taskItem.IsDone,
                ProjectId = taskItem.ProjectId
            };
        }

        public async Task<bool> UpdateAsync(int id, TaskUpdateDto dto)
        {
            var taskItem = await _context.Tasks.FindAsync(id);

            if (taskItem == null)
                return false;

            var projectExists = await _context.Projects.AnyAsync(p => p.Id == dto.ProjectId);

            if (!projectExists)
                return false;

            taskItem.Title = dto.Title;
            taskItem.Description = dto.Description;
            taskItem.IsDone = dto.IsDone;
            taskItem.ProjectId = dto.ProjectId;

            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var taskItem = await _context.Tasks.FindAsync(id);

            if (taskItem == null)
                return false;

            _context.Tasks.Remove(taskItem);
            await _context.SaveChangesAsync();
            return true;
        }
    }
}