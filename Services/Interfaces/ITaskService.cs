using PlannerAPI.DTOs.Tasks;

namespace PlannerAPI.Services.Interfaces
{
    public interface ITaskService
    {
        Task<TaskReadDto?> CreateTaskAsync(TaskCreateDto dto);
    }
}