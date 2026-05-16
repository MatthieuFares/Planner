using PlannerAPI.DTOs.Resources;

namespace PlannerAPI.Services.Interfaces
{
    public interface IResourceAssignmentService
    {
        Task<ResourceAssignmentReadDto> CreateAsync(ResourceAssignmentCreateDto dto);

        Task<IEnumerable<ResourceAssignmentReadDto>> GetByTaskIdAsync(int taskId);

        Task<bool> UpdateAsync(int id, ResourceAssignmentUpdateDto dto);

        Task<bool> DeleteAsync(int id);
    }
}