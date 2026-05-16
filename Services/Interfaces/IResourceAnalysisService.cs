using PlannerAPI.DTOs.Resources;

namespace PlannerAPI.Services.Interfaces
{
    public interface IResourceAnalysisService
    {
        Task<ProjectResourceAnalysisDto?> GetProjectAnalysisAsync(int projectId);
    }
}