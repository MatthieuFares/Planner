using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.ProjectCalendars;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ProjectCalendarService : IProjectCalendarService
    {
        private readonly AppDbContext _context;

        public ProjectCalendarService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<ProjectCalendarReadDto?> GetByProjectIdAsync(int projectId)
        {
            var calendar = await GetOrCreateCalendarAsync(projectId);

            if (calendar == null)
                return null;

            return MapToReadDto(calendar);
        }

        public async Task<ProjectCalendarReadDto?> UpdateByProjectIdAsync(int projectId, ProjectCalendarUpdateDto dto)
        {
            var calendar = await GetOrCreateCalendarAsync(projectId);

            if (calendar == null)
                return null;

            calendar.WorkMonday = dto.WorkMonday;
            calendar.WorkTuesday = dto.WorkTuesday;
            calendar.WorkWednesday = dto.WorkWednesday;
            calendar.WorkThursday = dto.WorkThursday;
            calendar.WorkFriday = dto.WorkFriday;
            calendar.WorkSaturday = dto.WorkSaturday;
            calendar.WorkSunday = dto.WorkSunday;

            await _context.SaveChangesAsync();

            return MapToReadDto(calendar);
        }

        private async Task<ProjectCalendar?> GetOrCreateCalendarAsync(int projectId)
        {
            var projectExists = await _context.Projects.AnyAsync(p => p.Id == projectId);

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

        private static ProjectCalendarReadDto MapToReadDto(ProjectCalendar calendar)
        {
            return new ProjectCalendarReadDto
            {
                Id = calendar.Id,
                ProjectId = calendar.ProjectId,
                WorkMonday = calendar.WorkMonday,
                WorkTuesday = calendar.WorkTuesday,
                WorkWednesday = calendar.WorkWednesday,
                WorkThursday = calendar.WorkThursday,
                WorkFriday = calendar.WorkFriday,
                WorkSaturday = calendar.WorkSaturday,
                WorkSunday = calendar.WorkSunday
            };
        }
    }
}