using PlannerAPI.DTOs.ProjectCalendarPeriods;

namespace PlannerAPI.Services.Interfaces
{
    public interface IProjectCalendarPeriodService
    {
        Task<IEnumerable<ProjectCalendarPeriodReadDto>?> GetByProjectIdAsync(int projectId);

        Task<ProjectCalendarPeriodReadDto?> CreateAsync(
            int projectId,
            ProjectCalendarPeriodCreateDto dto);

        Task<ProjectCalendarPeriodReadDto?> UpdateAsync(
            int periodId,
            ProjectCalendarPeriodUpdateDto dto);

        Task<bool> DeleteAsync(int periodId);
    }
}