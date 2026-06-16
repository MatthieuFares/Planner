using PlannerAPI.DTOs.PlanningItems;

namespace PlannerAPI.Services.Interfaces
{
    public interface IPlanningItemService
    {
        Task<IEnumerable<PlanningItemReadDto>> GetByProjectIdAsync(int projectId);

        Task<PlanningItemReadDto?> GetByIdAsync(int id);

        Task<PlanningItemReadDto> CreateAsync(PlanningItemCreateDto dto);

        Task<PlanningItemReadDto?> UpdateAsync(int id, PlanningItemUpdateDto dto);

        Task<bool> DeleteAsync(int id);
        Task<PlanningItemSyncResultDto> SyncProjectTasksAsync(int projectId);
        
        Task<PlanningItemReadDto?> MoveAsync(int id, PlanningItemMoveDto dto);

    }
}