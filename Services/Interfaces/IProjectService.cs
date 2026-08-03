using PlannerAPI.DTOs.Projects;
using PlannerAPI.DTOs.Tasks;

namespace PlannerAPI.Services.Interfaces
{
    public interface IProjectService
    {
        Task<IEnumerable<ProjectReadDto>> GetAllAsync();

        Task<IEnumerable<ProjectListItemDto>> GetListItemsAsync();

        Task<ProjectReadDto?> GetByIdAsync(int id);

        Task<IEnumerable<TaskReadDto>?> GetTasksByProjectIdAsync(
            int projectId);

        Task<ProjectReadDto> CreateAsync(ProjectCreateDto dto);

        Task<ProjectReadDto?> UpdateAsync(
            int id,
            ProjectUpdateDto dto);

        Task<bool> DeleteAsync(int id);
    }
}
