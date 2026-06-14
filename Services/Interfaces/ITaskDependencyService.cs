using PlannerAPI.DTOs.Dependencies;

namespace PlannerAPI.Services.Interfaces
{
    public interface ITaskDependencyService
    {
        Task<IEnumerable<TaskDependencyReadDto>> GetByTaskIdAsync(int taskId);

        Task<TaskDependencyReadDto> AddDependencyAsync(TaskDependencyCreateDto dto);

        Task<TaskDependencyReadDto?> UpdateAsync(int id, TaskDependencyUpdateDto dto);

        Task<bool> DeleteAsync(int id);
    }
}