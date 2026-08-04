using PlannerAPI.DTOs.AccessManagement;

namespace PlannerAPI.Services.Interfaces
{
    public interface IAccessManagementService
    {
        Task<AccessManagementOverviewDto>
            GetOverviewAsync();

        Task UpdateGlobalPermissionsAsync(
            string userId,
            GlobalUserPermissionsUpdateDto dto);
    }
}
