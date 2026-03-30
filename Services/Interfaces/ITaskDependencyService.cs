using PlannerAPI.DTOs.Dependencies;

namespace PlannerAPI.Services.Interfaces
{
    public interface ITaskDependencyService
    {
        Task<IEnumerable<TaskDependencyReadDto>> GetAllAsync();
        Task<TaskDependencyReadDto?> GetByIdAsync(int id);
        Task<IEnumerable<TaskDependencyReadDto>> GetByTaskIdAsync(int taskId);
        Task<(bool Success, string? Error, TaskDependencyReadDto? Data)> CreateAsync(TaskDependencyCreateDto dto);
        Task<(bool Success, string? Error)> UpdateAsync(int id, TaskDependencyUpdateDto dto);
        Task<bool> DeleteAsync(int id);
    }
}