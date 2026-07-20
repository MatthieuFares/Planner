using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.ProjectCalendarPeriods;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ProjectCalendarPeriodService : IProjectCalendarPeriodService
    {
        private readonly AppDbContext _context;
        private readonly ITaskSchedulingService _taskSchedulingService;

        public ProjectCalendarPeriodService(
            AppDbContext context,
            ITaskSchedulingService taskSchedulingService)
        {
            _context = context;
            _taskSchedulingService = taskSchedulingService;
        }

        public async Task<IEnumerable<ProjectCalendarPeriodReadDto>?> GetByProjectIdAsync(
            int projectId)
        {
            var calendar = await GetOrCreateCalendarAsync(projectId);

            if (calendar == null)
                return null;

            var periods = await _context.ProjectCalendarPeriods
                .AsNoTracking()
                .Where(p => p.ProjectCalendarId == calendar.Id)
                .OrderBy(p => p.StartDate)
                .ThenBy(p => p.EndDate)
                .ThenBy(p => p.Id)
                .ToListAsync();

            return periods.Select(MapToReadDto);
        }

        public async Task<ProjectCalendarPeriodReadDto?> CreateAsync(
            int projectId,
            ProjectCalendarPeriodCreateDto dto)
        {
            var calendar = await GetOrCreateCalendarAsync(projectId);

            if (calendar == null)
                return null;

            var startDate = dto.StartDate.Date;
            var endDate = dto.EndDate.Date;

            ValidatePeriodDates(startDate, endDate);

            var period = new ProjectCalendarPeriod
            {
                ProjectCalendarId = calendar.Id,
                StartDate = startDate,
                EndDate = endDate,
                Label = NormalizeLabel(dto.Label)
            };

            _context.ProjectCalendarPeriods.Add(period);

            await _context.SaveChangesAsync();
            await _taskSchedulingService.RecalculateProjectAsync(projectId);

            return MapToReadDto(period);
        }

        public async Task<ProjectCalendarPeriodReadDto?> UpdateAsync(
            int periodId,
            ProjectCalendarPeriodUpdateDto dto)
        {
            var period = await _context.ProjectCalendarPeriods
                .FirstOrDefaultAsync(p => p.Id == periodId);

            if (period == null)
                return null;

            var projectId = await GetProjectIdByCalendarIdAsync(
                period.ProjectCalendarId
            );

            var startDate = dto.StartDate.Date;
            var endDate = dto.EndDate.Date;

            ValidatePeriodDates(startDate, endDate);

            period.StartDate = startDate;
            period.EndDate = endDate;
            period.Label = NormalizeLabel(dto.Label);

            await _context.SaveChangesAsync();
            await _taskSchedulingService.RecalculateProjectAsync(projectId);

            return MapToReadDto(period);
        }

        public async Task<bool> DeleteAsync(int periodId)
        {
            var period = await _context.ProjectCalendarPeriods
                .FirstOrDefaultAsync(p => p.Id == periodId);

            if (period == null)
                return false;

            var projectId = await GetProjectIdByCalendarIdAsync(
                period.ProjectCalendarId
            );

            _context.ProjectCalendarPeriods.Remove(period);

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

        private async Task<ProjectCalendar?> GetOrCreateCalendarAsync(
            int projectId)
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

        private static void ValidatePeriodDates(
            DateTime startDate,
            DateTime endDate)
        {
            if (endDate < startDate)
            {
                throw new InvalidOperationException(
                    "La date de fin ne peut pas être antérieure à la date de début."
                );
            }
        }

        private static string NormalizeLabel(string? label)
        {
            var normalized = label?.Trim() ?? string.Empty;

            return string.IsNullOrWhiteSpace(normalized)
                ? "Période non ouvrée"
                : normalized;
        }

        private static ProjectCalendarPeriodReadDto MapToReadDto(
            ProjectCalendarPeriod period)
        {
            return new ProjectCalendarPeriodReadDto
            {
                Id = period.Id,
                ProjectCalendarId = period.ProjectCalendarId,
                StartDate = period.StartDate,
                EndDate = period.EndDate,
                Label = period.Label
            };
        }
    }
}