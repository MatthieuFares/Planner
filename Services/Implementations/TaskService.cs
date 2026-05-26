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

        public TaskService(AppDbContext context, ITaskSchedulingService taskSchedulingService)
        {
            _context = context;
            _taskSchedulingService = taskSchedulingService;
        }

        public async Task<TaskReadDto?> CreateTaskAsync(TaskCreateDto dto)
        {
            var projectExists = await _context.Projects.AnyAsync(p => p.Id == dto.ProjectId);

            if (!projectExists)
                return null;

            var taskItem = new PlannerTask
            {
                Title = dto.Title,
                Description = dto.Description,
                IsDone = dto.IsDone,
                ProjectId = dto.ProjectId,
                StartDate = dto.StartDate,
                EndDate = dto.EndDate,
                Duration = dto.Duration,

                ActualDuration = dto.ActualDuration,
                AssignedResourcesCount = dto.AssignedResourcesCount,
                WorkloadHours = dto.WorkloadHours,
                ProgressPercent = dto.ProgressPercent,
            };

            _context.Tasks.Add(taskItem);
            await _context.SaveChangesAsync();

            await _taskSchedulingService.RecalculateTaskDatesAsync(taskItem.Id);

            return new TaskReadDto
            {
                Id = taskItem.Id,
                Title = taskItem.Title,
                Description = taskItem.Description,
                IsDone = taskItem.IsDone,
                ProjectId = taskItem.ProjectId,
                StartDate = taskItem.StartDate,
                EndDate = taskItem.EndDate,
                Duration = taskItem.Duration,

                ActualDuration = taskItem.ActualDuration,
                AssignedResourcesCount = taskItem.AssignedResourcesCount,
                WorkloadHours = taskItem.WorkloadHours,
                ProgressPercent = taskItem.ProgressPercent,
                IsCritical = taskItem.IsCritical
            };
        }
    }
}