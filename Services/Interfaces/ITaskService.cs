using PlannerAPI.DTOs.Tasks;

namespace PlannerAPI.Services.Interfaces
{
    public interface ITaskService
    {
        Task<IEnumerable<TaskReadDto>> GetAllAsync();

        Task<TaskReadDto?> GetByIdAsync(int id);

        Task<IEnumerable<TaskReadDto>> GetByProjectIdAsync(int projectId);

        Task<TaskReadDto?> CreateTaskAsync(TaskCreateDto dto);

        Task<TaskReadDto?> UpdateTaskAsync(int id, TaskUpdateDto dto);

        Task<bool> DeleteTaskAsync(int id);
    }
}