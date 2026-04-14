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
            var predecessorExists = await _context.Tasks.AnyAsync(t => t.Id == dto.PredecessorId);
            var successorExists = await _context.Tasks.AnyAsync(t => t.Id == dto.SuccessorId);

            if (!predecessorExists || !successorExists)
                throw new InvalidOperationException("Une ou plusieurs tâches sont introuvables.");

            var dependencyExists = await _context.TaskDependencies.AnyAsync(td =>
                td.PredecessorId == dto.PredecessorId &&
                td.SuccessorId == dto.SuccessorId &&
                td.Type == dto.Type);

            if (dependencyExists)
                throw new InvalidOperationException("Cette dépendance existe déjà.");

            // ANTI-CYCLE 
            var createsCycle = await CreatesCycleAsync(dto.PredecessorId, dto.SuccessorId);
            if (createsCycle)
                throw new InvalidOperationException("Cette dépendance créerait un cycle entre les tâches.");

            var dependency = new TaskDependency
            {
                PredecessorId = dto.PredecessorId,
                SuccessorId = dto.SuccessorId,
                Type = dto.Type
            };

            _context.TaskDependencies.Add(dependency);
            await _context.SaveChangesAsync();

            // recalcul
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

            // recalcul après modif
            await _taskSchedulingService.RecalculateTaskDatesAsync(dto.SuccessorId);

            return true;
        }

                private async Task<bool> CreatesCycleAsync(int predecessorId, int successorId)
        {
            if (predecessorId == successorId)
                return true;

            var visited = new HashSet<int>();
            return await HasPathToTargetAsync(successorId, predecessorId, visited);
        }

        private async Task<bool> HasPathToTargetAsync(int currentTaskId, int targetTaskId, HashSet<int> visited)
        {
            if (!visited.Add(currentTaskId))
                return false;

            var nextSuccessorIds = await _context.TaskDependencies
                .Where(td => td.PredecessorId == currentTaskId)
                .Select(td => td.SuccessorId)
                .Distinct()
                .ToListAsync();

            foreach (var nextId in nextSuccessorIds)
            {
                if (nextId == targetTaskId)
                    return true;

                var found = await HasPathToTargetAsync(nextId, targetTaskId, visited);
                if (found)
                    return true;
            }

            return false;
        }
        
                public async Task<bool> DeleteAsync(int id)
        {
            var dependency = await _context.TaskDependencies.FindAsync(id);

            if (dependency == null)
                return false;

            var successorId = dependency.SuccessorId;

            _context.TaskDependencies.Remove(dependency);
            await _context.SaveChangesAsync();

            await _taskSchedulingService.RecalculateTaskDatesAsync(successorId);

            return true;
        }
    }
}