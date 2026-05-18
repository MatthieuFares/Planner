using PlannerAPI.DTOs.Projects;

namespace PlannerAPI.Services.Interfaces
{
    public interface IProjectSummaryService
    {
        Task<ProjectSummaryDto?> GetSummaryAsync(int projectId);
    }
}