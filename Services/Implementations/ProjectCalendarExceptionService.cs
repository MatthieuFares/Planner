using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.ProjectCalendarExceptions;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ProjectCalendarExceptionService : IProjectCalendarExceptionService
    {
        private readonly AppDbContext _context;
        private readonly ITaskSchedulingService _taskSchedulingService;

        public ProjectCalendarExceptionService(
            AppDbContext context,
            ITaskSchedulingService taskSchedulingService)
        {
            _context = context;
            _taskSchedulingService = taskSchedulingService;
        }

        public async Task<IEnumerable<ProjectCalendarExceptionReadDto>?> GetByProjectIdAsync(
            int projectId)
        {
            var calendar = await GetOrCreateCalendarAsync(projectId);

            if (calendar == null)
                return null;

            var exceptions = await _context.ProjectCalendarExceptions
                .Where(e => e.ProjectCalendarId == calendar.Id)
                .OrderBy(e => e.Date)
                .ToListAsync();

            return exceptions.Select(MapToReadDto);
        }

        public async Task<ProjectCalendarExceptionReadDto?> CreateAsync(
            int projectId,
            ProjectCalendarExceptionCreateDto dto)
        {
            var calendar = await GetOrCreateCalendarAsync(projectId);

            if (calendar == null)
                return null;

            var normalizedDate = dto.Date.Date;

            var existingException = await _context.ProjectCalendarExceptions
                .FirstOrDefaultAsync(e =>
                    e.ProjectCalendarId == calendar.Id &&
                    e.Date.Date == normalizedDate);

            if (existingException != null)
            {
                existingException.Label = dto.Label.Trim();
                existingException.IsWorkingDay = dto.IsWorkingDay;

                await _context.SaveChangesAsync();
                await _taskSchedulingService.RecalculateProjectAsync(projectId);

                return MapToReadDto(existingException);
            }

            var exception = new ProjectCalendarException
            {
                ProjectCalendarId = calendar.Id,
                Date = normalizedDate,
                Label = dto.Label.Trim(),
                IsWorkingDay = dto.IsWorkingDay
            };

            _context.ProjectCalendarExceptions.Add(exception);

            await _context.SaveChangesAsync();
            await _taskSchedulingService.RecalculateProjectAsync(projectId);

            return MapToReadDto(exception);
        }

        public async Task<ProjectCalendarExceptionReadDto?> UpdateAsync(
            int exceptionId,
            ProjectCalendarExceptionUpdateDto dto)
        {
            var exception = await _context.ProjectCalendarExceptions
                .FirstOrDefaultAsync(e => e.Id == exceptionId);

            if (exception == null)
                return null;

            var projectId = await GetProjectIdByCalendarIdAsync(
                exception.ProjectCalendarId
            );

            var normalizedDate = dto.Date.Date;

            var duplicateDate = await _context.ProjectCalendarExceptions
                .AnyAsync(e =>
                    e.Id != exceptionId &&
                    e.ProjectCalendarId == exception.ProjectCalendarId &&
                    e.Date.Date == normalizedDate);

            if (duplicateDate)
            {
                throw new InvalidOperationException(
                    "Une exception existe déjà pour cette date sur ce calendrier."
                );
            }

            exception.Date = normalizedDate;
            exception.Label = dto.Label.Trim();
            exception.IsWorkingDay = dto.IsWorkingDay;

            await _context.SaveChangesAsync();
            await _taskSchedulingService.RecalculateProjectAsync(projectId);

            return MapToReadDto(exception);
        }

        public async Task<bool> DeleteAsync(int exceptionId)
        {
            var exception = await _context.ProjectCalendarExceptions
                .FirstOrDefaultAsync(e => e.Id == exceptionId);

            if (exception == null)
                return false;

            var projectId = await GetProjectIdByCalendarIdAsync(
                exception.ProjectCalendarId
            );

            _context.ProjectCalendarExceptions.Remove(exception);

            await _context.SaveChangesAsync();
            await _taskSchedulingService.RecalculateProjectAsync(projectId);

            return true;
        }

        private async Task<int> GetProjectIdByCalendarIdAsync(
            int projectCalendarId)
        {
            return await _context.ProjectCalendars
                .Where(c => c.Id == projectCalendarId)
                .Select(c => c.ProjectId)
                .FirstAsync();
        }

        private async Task<ProjectCalendar?> GetOrCreateCalendarAsync(int projectId)
        {
            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return null;

            var calendar = await _context.ProjectCalendars
                .FirstOrDefaultAsync(c => c.ProjectId == projectId);

            if (calendar != null)
                return calendar;

            calendar = new ProjectCalendar
            {
                ProjectId = projectId,
                WorkMonday = true,
                WorkTuesday = true,
                WorkWednesday = true,
                WorkThursday = true,
                WorkFriday = true,
                WorkSaturday = false,
                WorkSunday = false
            };

            _context.ProjectCalendars.Add(calendar);
            await _context.SaveChangesAsync();

            return calendar;
        }

        private static ProjectCalendarExceptionReadDto MapToReadDto(
            ProjectCalendarException exception)
        {
            return new ProjectCalendarExceptionReadDto
            {
                Id = exception.Id,
                ProjectCalendarId = exception.ProjectCalendarId,
                Date = exception.Date,
                Label = exception.Label,
                IsWorkingDay = exception.IsWorkingDay
            };
        }
    }
}