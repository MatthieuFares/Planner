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

        public TaskDependencyService(
            AppDbContext context,
            ITaskSchedulingService taskSchedulingService)
        {
            _context = context;
            _taskSchedulingService = taskSchedulingService;
        }

        public async Task<IEnumerable<TaskDependencyReadDto>> GetByTaskIdAsync(int taskId)
        {
            var taskExists = await _context.Tasks.AnyAsync(t => t.Id == taskId);

            if (!taskExists)
                return Enumerable.Empty<TaskDependencyReadDto>();

            var dependencies = await _context.TaskDependencies
                .Where(td => td.SuccessorId == taskId || td.PredecessorId == taskId)
                .OrderBy(td => td.PredecessorId)
                .ThenBy(td => td.SuccessorId)
                .ThenBy(td => td.Type)
                .ToListAsync();

            return dependencies.Select(MapToReadDto);
        }

        public async Task<TaskDependencyReadDto> AddDependencyAsync(TaskDependencyCreateDto dto)
        {
            var parsedType = ParseDependencyType(dto.Type);

            await ValidateDependencyAsync(
                predecessorId: dto.PredecessorId,
                successorId: dto.SuccessorId,
                type: parsedType,
                ignoredDependencyId: null
            );

            var dependency = new TaskDependency
            {
                PredecessorId = dto.PredecessorId,
                SuccessorId = dto.SuccessorId,
                Type = parsedType.ToString(),
                OffsetDays = dto.OffsetDays
            };

            _context.TaskDependencies.Add(dependency);

            await _context.SaveChangesAsync();

            await _taskSchedulingService.RecalculateTaskDatesAsync(dependency.SuccessorId);

            return MapToReadDto(dependency);
        }

        public async Task<TaskDependencyReadDto?> UpdateAsync(int id, TaskDependencyUpdateDto dto)
        {
            var dependency = await _context.TaskDependencies.FindAsync(id);

            if (dependency == null)
                return null;

            var parsedType = ParseDependencyType(dto.Type);

            await ValidateDependencyAsync(
                predecessorId: dto.PredecessorId,
                successorId: dto.SuccessorId,
                type: parsedType,
                ignoredDependencyId: id
            );

            var oldSuccessorId = dependency.SuccessorId;

            dependency.PredecessorId = dto.PredecessorId;
            dependency.SuccessorId = dto.SuccessorId;
            dependency.Type = parsedType.ToString();
            dependency.OffsetDays = dto.OffsetDays;

            await _context.SaveChangesAsync();

            await _taskSchedulingService.RecalculateTaskDatesAsync(dependency.SuccessorId);

            if (oldSuccessorId != dependency.SuccessorId)
            {
                await _taskSchedulingService.RecalculateTaskDatesAsync(oldSuccessorId);
            }

            return MapToReadDto(dependency);
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

        private async Task ValidateDependencyAsync(
            int predecessorId,
            int successorId,
            DependencyType type,
            int? ignoredDependencyId)
        {
            if (predecessorId == successorId)
            {
                throw new InvalidOperationException(
                    "Une tâche ne peut pas dépendre d'elle-même."
                );
            }

            var predecessor = await _context.Tasks
                .AsNoTracking()
                .FirstOrDefaultAsync(t => t.Id == predecessorId);

            var successor = await _context.Tasks
                .AsNoTracking()
                .FirstOrDefaultAsync(t => t.Id == successorId);

            if (predecessor == null || successor == null)
            {
                throw new InvalidOperationException(
                    "Une ou plusieurs tâches sont introuvables."
                );
            }

            if (predecessor.ProjectId != successor.ProjectId)
            {
                throw new InvalidOperationException(
                    "Une dépendance ne peut lier que des tâches du même projet."
                );
            }

            var dependencyExists = await _context.TaskDependencies.AnyAsync(td =>
                td.PredecessorId == predecessorId &&
                td.SuccessorId == successorId &&
                td.Type == type.ToString() &&
                (!ignoredDependencyId.HasValue || td.Id != ignoredDependencyId.Value)
            );

            if (dependencyExists)
            {
                throw new InvalidOperationException(
                    "Cette dépendance existe déjà."
                );
            }

            var createsCycle = await CreatesCycleAsync(
                predecessorId,
                successorId,
                ignoredDependencyId
            );

            if (createsCycle)
            {
                throw new InvalidOperationException(
                    "Cette dépendance créerait un cycle entre les tâches."
                );
            }
        }

        private static DependencyType ParseDependencyType(string type)
        {
            if (string.IsNullOrWhiteSpace(type))
            {
                throw new InvalidOperationException(
                    "Le type de dépendance est obligatoire. Valeurs autorisées : FS, SS, FF, SF."
                );
            }

            var parsed = Enum.TryParse<DependencyType>(
                type,
                ignoreCase: true,
                out var dependencyType
            );

            if (!parsed || !Enum.IsDefined(typeof(DependencyType), dependencyType))
            {
                throw new InvalidOperationException(
                    "Type de dépendance invalide. Valeurs autorisées : FS, SS, FF, SF."
                );
            }

            return dependencyType;
        }

        private async Task<bool> CreatesCycleAsync(
            int predecessorId,
            int successorId,
            int? ignoredDependencyId)
        {
            if (predecessorId == successorId)
                return true;

            var visited = new HashSet<int>();

            return await HasPathToTargetAsync(
                currentTaskId: successorId,
                targetTaskId: predecessorId,
                visited: visited,
                ignoredDependencyId: ignoredDependencyId
            );
        }

        private async Task<bool> HasPathToTargetAsync(
            int currentTaskId,
            int targetTaskId,
            HashSet<int> visited,
            int? ignoredDependencyId)
        {
            if (!visited.Add(currentTaskId))
                return false;

            var query = _context.TaskDependencies
                .Where(td => td.PredecessorId == currentTaskId);

            if (ignoredDependencyId.HasValue)
            {
                query = query.Where(td => td.Id != ignoredDependencyId.Value);
            }

            var nextSuccessorIds = await query
                .Select(td => td.SuccessorId)
                .Distinct()
                .ToListAsync();

            foreach (var nextId in nextSuccessorIds)
            {
                if (nextId == targetTaskId)
                    return true;

                var found = await HasPathToTargetAsync(
                    currentTaskId: nextId,
                    targetTaskId: targetTaskId,
                    visited: visited,
                    ignoredDependencyId: ignoredDependencyId
                );

                if (found)
                    return true;
            }

            return false;
        }

        private static TaskDependencyReadDto MapToReadDto(TaskDependency dependency)
        {
            return new TaskDependencyReadDto
            {
                Id = dependency.Id,
                PredecessorId = dependency.PredecessorId,
                SuccessorId = dependency.SuccessorId,
                Type = dependency.Type,
                OffsetDays = dependency.OffsetDays
            };
        }
    }
}