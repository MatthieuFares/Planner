using PlannerAPI.DTOs.Resources;

namespace PlannerAPI.Services.Interfaces
{
    public interface IResourceGroupService
    {
        Task<IEnumerable<ResourceGroupReadDto>> GetAllAsync();
        Task<ResourceGroupReadDto?> GetByIdAsync(int id);
        Task<ResourceGroupReadDto> CreateAsync(ResourceGroupCreateDto dto);
        Task<bool> AddMemberAsync(ResourceGroupMemberCreateDto dto);
        Task<bool> RemoveMemberAsync(int groupId, int resourceId);
        Task<bool> UpdateAsync(int id, ResourceGroupUpdateDto dto);
        Task<bool> DeleteAsync(int id);     
    }
}