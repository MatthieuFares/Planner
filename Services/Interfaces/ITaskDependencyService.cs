using PlannerAPI.DTOs.Dependencies;

namespace PlannerAPI.Services.Interfaces
{
    public interface ITaskDependencyService
    {
        Task<IEnumerable<TaskDependencyReadDto>> GetByTaskIdAsync(int taskId);

        Task AddDependencyAsync(TaskDependencyCreateDto dto);

        Task<bool> UpdateAsync(int id, TaskDependencyUpdateDto dto);

        Task<bool> DeleteAsync(int id);
    }
}