using PlannerAPI.DTOs.ProjectCalendarExceptions;

namespace PlannerAPI.Services.Interfaces
{
    public interface IProjectCalendarExceptionService
    {
        Task<IEnumerable<ProjectCalendarExceptionReadDto>?> GetByProjectIdAsync(int projectId);

        Task<ProjectCalendarExceptionReadDto?> CreateAsync(
            int projectId,
            ProjectCalendarExceptionCreateDto dto);

        Task<ProjectCalendarExceptionReadDto?> UpdateAsync(
            int exceptionId,
            ProjectCalendarExceptionUpdateDto dto);

        Task<bool> DeleteAsync(int exceptionId);
    }
}