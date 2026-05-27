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
        private readonly ITaskSchedulingService _taskSchedulingService;

        public TaskService(
            AppDbContext context,
            ITaskSchedulingService taskSchedulingService)
        {
            _context = context;
            _taskSchedulingService = taskSchedulingService;
        }

        public async Task<IEnumerable<TaskReadDto>> GetAllAsync()
        {
            var tasks = await _context.Tasks
                .OrderBy(t => t.StartDate)
                .ThenBy(t => t.Id)
                .ToListAsync();

            return tasks.Select(MapToReadDto);
        }

        public async Task<TaskReadDto?> GetByIdAsync(int id)
        {
            var task = await _context.Tasks.FindAsync(id);

            if (task == null)
                return null;

            return MapToReadDto(task);
        }

        public async Task<IEnumerable<TaskReadDto>> GetByProjectIdAsync(int projectId)
        {
            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return Enumerable.Empty<TaskReadDto>();

            var tasks = await _context.Tasks
                .Where(t => t.ProjectId == projectId)
                .OrderBy(t => t.StartDate)
                .ThenBy(t => t.Id)
                .ToListAsync();

            return tasks.Select(MapToReadDto);
        }

        public async Task<TaskReadDto?> CreateTaskAsync(TaskCreateDto dto)
        {
            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == dto.ProjectId);

            if (!projectExists)
                return null;

            var progress = NormalizeProgress(dto.ProgressPercent);

            var taskItem = new PlannerTask
            {
                Title = dto.Title,
                Description = dto.Description,
                ProjectId = dto.ProjectId,

                StartDate = dto.StartDate,
                EndDate = dto.EndDate,
                Duration = dto.Duration,

                ActualDuration = dto.ActualDuration,
                AssignedResourcesCount = dto.AssignedResourcesCount,
                WorkloadHours = dto.WorkloadHours,

                ProgressPercent = progress,
                IsDone = progress >= 100
            };

            _context.Tasks.Add(taskItem);

            await _context.SaveChangesAsync();

            await _taskSchedulingService.RecalculateTaskDatesAsync(taskItem.Id);

            var refreshedTask = await _context.Tasks.FindAsync(taskItem.Id);

            return refreshedTask == null
                ? null
                : MapToReadDto(refreshedTask);
        }

        public async Task<TaskReadDto?> UpdateTaskAsync(int id, TaskUpdateDto dto)
        {
            var taskItem = await _context.Tasks.FindAsync(id);

            if (taskItem == null)
                return null;

            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == dto.ProjectId);

            if (!projectExists)
                return null;

            var progress = NormalizeProgress(dto.ProgressPercent);

            taskItem.Title = dto.Title;
            taskItem.Description = dto.Description;
            taskItem.ProjectId = dto.ProjectId;

            taskItem.StartDate = dto.StartDate;
            taskItem.EndDate = dto.EndDate;
            taskItem.Duration = dto.Duration;

            taskItem.ActualDuration = dto.ActualDuration;
            taskItem.AssignedResourcesCount = dto.AssignedResourcesCount;
            taskItem.WorkloadHours = dto.WorkloadHours;

            taskItem.ProgressPercent = progress;
            taskItem.IsDone = progress >= 100;

            await _context.SaveChangesAsync();

            await _taskSchedulingService.RecalculateTaskDatesAsync(taskItem.Id);

            var refreshedTask = await _context.Tasks.FindAsync(taskItem.Id);

            return refreshedTask == null
                ? null
                : MapToReadDto(refreshedTask);
        }

        public async Task<bool> DeleteTaskAsync(int id)
        {
            var taskItem = await _context.Tasks.FindAsync(id);

            if (taskItem == null)
                return false;

            _context.Tasks.Remove(taskItem);

            await _context.SaveChangesAsync();

            return true;
        }

        private static int NormalizeProgress(int progressPercent)
        {
            return Math.Clamp(progressPercent, 0, 100);
        }

        private static TaskReadDto MapToReadDto(PlannerTask task)
        {
            return new TaskReadDto
            {
                Id = task.Id,
                Title = task.Title,
                Description = task.Description,
                IsDone = task.IsDone,
                ProjectId = task.ProjectId,

                StartDate = task.StartDate,
                EndDate = task.EndDate,
                Duration = task.Duration,

                ActualDuration = task.ActualDuration,
                AssignedResourcesCount = task.AssignedResourcesCount,
                WorkloadHours = task.WorkloadHours,

                IsCritical = task.IsCritical,
                EarlyStart = task.EarlyStart,
                EarlyFinish = task.EarlyFinish,
                LateStart = task.LateStart,
                LateFinish = task.LateFinish,
                TotalFloat = task.TotalFloat,

                ProgressPercent = task.ProgressPercent
            };
        }
    }
}