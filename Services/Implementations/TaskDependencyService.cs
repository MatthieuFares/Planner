using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Dependencies;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class TaskDependencyService : ITaskDependencyService
    {
        private readonly AppDbContext _context;
        private readonly ITaskSchedulingService _taskSchedulingService;

        public TaskDependencyService(AppDbContext context, ITaskSchedulingService taskSchedulingService)
        {
            _context = context;
            _taskSchedulingService = taskSchedulingService;
        }

        public async Task<IEnumerable<TaskDependencyReadDto>> GetByTaskIdAsync(int taskId)
        {
            return await _context.TaskDependencies
                .Where(td => td.SuccessorId == taskId || td.PredecessorId == taskId)
                .Select(td => new TaskDependencyReadDto
                {
                    Id = td.Id,
                    PredecessorId = td.PredecessorId,
                    SuccessorId = td.SuccessorId,
                    Type = td.Type
                })
                .ToListAsync();
        }

        public async Task AddDependencyAsync(TaskDependencyCreateDto dto)
        {
            var dependency = new TaskDependency
            {
                PredecessorId = dto.PredecessorId,
                SuccessorId = dto.SuccessorId,
                Type = dto.Type
            };

            _context.TaskDependencies.Add(dependency);
            await _context.SaveChangesAsync();

            // 🔥 recalcul des dates
            await _taskSchedulingService.RecalculateTaskDatesAsync(dto.SuccessorId);
        }

        public async Task<bool> UpdateAsync(int id, TaskDependencyUpdateDto dto)
        {
            var dependency = await _context.TaskDependencies.FindAsync(id);

            if (dependency == null)
                return false;

            // sécurité basique
            if (dto.PredecessorId == dto.SuccessorId)
                return false;

            dependency.PredecessorId = dto.PredecessorId;
            dependency.SuccessorId = dto.SuccessorId;
            dependency.Type = dto.Type;

            await _context.SaveChangesAsync();

            // 🔥 recalcul après modif
            await _taskSchedulingService.RecalculateTaskDatesAsync(dto.SuccessorId);

            return true;
        }
    }
}