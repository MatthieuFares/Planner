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

        public TaskDependencyService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<TaskDependencyReadDto>> GetAllAsync()
        {
            return await _context.TaskDependencies
                .Select(td => new TaskDependencyReadDto
                {
                    Id = td.Id,
                    PredecessorId = td.PredecessorId,
                    SuccessorId = td.SuccessorId,
                    Type = td.Type
                })
                .ToListAsync();
        }

        public async Task<TaskDependencyReadDto?> GetByIdAsync(int id)
        {
            return await _context.TaskDependencies
                .Where(td => td.Id == id)
                .Select(td => new TaskDependencyReadDto
                {
                    Id = td.Id,
                    PredecessorId = td.PredecessorId,
                    SuccessorId = td.SuccessorId,
                    Type = td.Type
                })
                .FirstOrDefaultAsync();
        }

        public async Task<IEnumerable<TaskDependencyReadDto>> GetByTaskIdAsync(int taskId)
        {
            return await _context.TaskDependencies
                .Where(td => td.PredecessorId == taskId || td.SuccessorId == taskId)
                .Select(td => new TaskDependencyReadDto
                {
                    Id = td.Id,
                    PredecessorId = td.PredecessorId,
                    SuccessorId = td.SuccessorId,
                    Type = td.Type
                })
                .ToListAsync();
        }

        public async Task<(bool Success, string? Error, TaskDependencyReadDto? Data)> CreateAsync(TaskDependencyCreateDto dto)
        {
            if (dto.PredecessorId == dto.SuccessorId)
                return (false, "Une tâche ne peut pas dépendre d'elle-même.", null);

            var predecessorExists = await _context.Tasks.AnyAsync(t => t.Id == dto.PredecessorId);
            var successorExists = await _context.Tasks.AnyAsync(t => t.Id == dto.SuccessorId);

            if (!predecessorExists || !successorExists)
                return (false, "Une des tâches n'existe pas.", null);

            var alreadyExists = await _context.TaskDependencies.AnyAsync(td =>
                td.PredecessorId == dto.PredecessorId &&
                td.SuccessorId == dto.SuccessorId &&
                td.Type == dto.Type);

            if (alreadyExists)
                return (false, "Cette dépendance existe déjà.", null);

            var dependency = new TaskDependency
            {
                PredecessorId = dto.PredecessorId,
                SuccessorId = dto.SuccessorId,
                Type = dto.Type
            };

            _context.TaskDependencies.Add(dependency);
            await _context.SaveChangesAsync();

            var result = new TaskDependencyReadDto
            {
                Id = dependency.Id,
                PredecessorId = dependency.PredecessorId,
                SuccessorId = dependency.SuccessorId,
                Type = dependency.Type
            };

            return (true, null, result);
        }

        public async Task<(bool Success, string? Error)> UpdateAsync(int id, TaskDependencyUpdateDto dto)
        {
            var dependency = await _context.TaskDependencies.FindAsync(id);

            if (dependency == null)
                return (false, "Dépendance introuvable.");

            if (dto.PredecessorId == dto.SuccessorId)
                return (false, "Une tâche ne peut pas dépendre d'elle-même.");

            var predecessorExists = await _context.Tasks.AnyAsync(t => t.Id == dto.PredecessorId);
            var successorExists = await _context.Tasks.AnyAsync(t => t.Id == dto.SuccessorId);

            if (!predecessorExists || !successorExists)
                return (false, "Une des tâches n'existe pas.");

            var duplicateExists = await _context.TaskDependencies.AnyAsync(td =>
                td.Id != id &&
                td.PredecessorId == dto.PredecessorId &&
                td.SuccessorId == dto.SuccessorId &&
                td.Type == dto.Type);

            if (duplicateExists)
                return (false, "Une dépendance identique existe déjà.");

            dependency.PredecessorId = dto.PredecessorId;
            dependency.SuccessorId = dto.SuccessorId;
            dependency.Type = dto.Type;

            await _context.SaveChangesAsync();

            return (true, null);
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var dependency = await _context.TaskDependencies.FindAsync(id);

            if (dependency == null)
                return false;

            _context.TaskDependencies.Remove(dependency);
            await _context.SaveChangesAsync();

            return true;
        }
    }
}