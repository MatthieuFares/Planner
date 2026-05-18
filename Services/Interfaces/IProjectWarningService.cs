using PlannerAPI.DTOs.Projects;

namespace PlannerAPI.Services.Interfaces
{
    public interface IProjectWarningService
    {
        Task<IEnumerable<ProjectWarningDto>?> GetWarningsAsync(int projectId);
    }
}