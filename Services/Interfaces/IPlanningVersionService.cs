using PlannerAPI.DTOs.PlanningVersions;

namespace PlannerAPI.Services.Interfaces
{
    public interface IPlanningVersionService
    {
        Task<PlanningVersionSummaryResponse> CreateAsync(
            int projectId,
            CreatePlanningVersionRequest request);

        Task<List<PlanningVersionSummaryResponse>> GetByProjectAsync(
            int projectId);

        Task<PlanningVersionDetailResponse?> GetByIdAsync(
            int versionId);

        Task<bool> DeleteAsync(
            int versionId);

        Task<PlanningVersionComparisonResponse?> CompareWithCurrentAsync(
            int versionId);

        Task<RestorePlanningVersionResponse?> RestoreAsync(
            int versionId,
            RestorePlanningVersionRequest request);
    }
}