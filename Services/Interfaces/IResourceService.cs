using PlannerAPI.DTOs.Resources;

namespace PlannerAPI.Services.Interfaces
{
    public interface IResourceService
    {
        Task<IEnumerable<ResourceReadDto>> GetAllAsync();

        Task<ResourceReadDto?> GetByIdAsync(int id);

        Task<ResourceReadDto> CreateAsync(ResourceCreateDto dto);

        Task<ResourceReadDto?> UpdateAsync(int id, ResourceUpdateDto dto);

        Task<bool> DeleteAsync(int id);
    }
}