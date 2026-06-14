using PlannerAPI.DTOs.Resources;

namespace PlannerAPI.Services.Interfaces
{
    public interface IResourceGroupService
    {
        Task<IEnumerable<ResourceGroupReadDto>> GetAllAsync();

        Task<ResourceGroupReadDto?> GetByIdAsync(int id);

        Task<IEnumerable<ResourceGroupMemberReadDto>?> GetMembersAsync(int groupId);

        Task<ResourceGroupReadDto> CreateAsync(ResourceGroupCreateDto dto);

        Task<ResourceGroupReadDto?> UpdateAsync(int id, ResourceGroupUpdateDto dto);

        Task<bool> DeleteAsync(int id);

        Task<ResourceGroupMemberReadDto> AddMemberAsync(ResourceGroupMemberCreateDto dto);

        Task<bool> RemoveMemberAsync(int groupId, int resourceId);
    }
}