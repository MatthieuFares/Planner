using PlannerAPI.DTOs.ProjectCalendars;

namespace PlannerAPI.Services.Interfaces
{
    public interface IProjectCalendarService
    {
        Task<ProjectCalendarReadDto?> GetByProjectIdAsync(int projectId);
        Task<ProjectCalendarReadDto?> UpdateByProjectIdAsync(int projectId, ProjectCalendarUpdateDto dto);
    }
}