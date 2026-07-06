using PlannerAPI.DTOs.ProjectBaselines;

namespace PlannerAPI.Services.Interfaces
{
    public interface IProjectBaselineService
    {
        Task<IEnumerable<ProjectBaselineReadDto>?> GetByProjectIdAsync(int projectId);

        Task<ProjectBaselineDetailDto?> GetByIdAsync(int baselineId);

        Task<ProjectBaselineDetailDto?> CreateAsync(
            int projectId,
            ProjectBaselineCreateDto dto);

        Task<ProjectBaselineComparisonDto?> CompareAsync(int baselineId);

        Task<ProjectBaselineReadDto?> SetActiveAsync(int baselineId);

        Task<bool> DeleteAsync(int baselineId);
    }
}