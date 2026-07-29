using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Projects;
using PlannerAPI.DTOs.Tasks;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ProjectService : IProjectService
    {
        private readonly AppDbContext _context;
        private readonly ITaskService _taskService;
        private readonly ICurrentUserService _currentUser;

        public ProjectService(
            AppDbContext context,
            ITaskService taskService,
            ICurrentUserService currentUser)
        {
            _context = context;
            _taskService = taskService;
            _currentUser = currentUser;
        }

        public async Task<IEnumerable<ProjectReadDto>> GetAllAsync()
        {
            var query = _context.Projects
                .AsNoTracking()
                .AsQueryable();

            if (!_currentUser.IsGlobalAdmin)
            {
                var userId = _currentUser.UserId;

                query = query.Where(p =>
                    p.OwnerUserId == userId ||
                    p.Members.Any(m => m.UserId == userId));
            }

            var projects = await query
                .OrderBy(p => p.Name)
                .ToListAsync();

            return projects.Select(MapToReadDto);
        }

        public async Task<ProjectReadDto?> GetByIdAsync(int id)
        {
            var project = await GetAccessibleProjectQuery()
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == id);

            if (project == null)
                return null;

            return MapToReadDto(project);
        }

        public async Task<IEnumerable<TaskReadDto>?> GetTasksByProjectIdAsync(
            int projectId)
        {
            var projectExists = await GetAccessibleProjectQuery()
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return null;

            return await _taskService.GetByProjectIdAsync(projectId);
        }

        public async Task<ProjectReadDto> CreateAsync(ProjectCreateDto dto)
        {
            var userId = _currentUser.UserId;

            var project = new Project
            {
                Name = dto.Name,
                Description = dto.Description,
                ClientName = dto.ClientName,
                ProjectCode = dto.ProjectCode,
                StartDate = dto.StartDate,
                EndDate = dto.EndDate,
                OwnerUserId = userId
            };

            ValidateProjectDates(
                project.StartDate,
                project.EndDate);

            project.Members.Add(
                new ProjectMember
                {
                    UserId = userId,
                    Role = ProjectRole.Manager
                });

            _context.Projects.Add(project);

            await _context.SaveChangesAsync();

            return MapToReadDto(project);
        }

        public async Task<ProjectReadDto?> UpdateAsync(
            int id,
            ProjectUpdateDto dto)
        {
            var project = await GetEditableProjectQuery()
                .FirstOrDefaultAsync(p => p.Id == id);

            if (project == null)
                return null;

            project.Name = dto.Name;
            project.Description = dto.Description;
            project.ClientName = dto.ClientName;
            project.ProjectCode = dto.ProjectCode;
            project.StartDate = dto.StartDate;
            project.EndDate = dto.EndDate;

            ValidateProjectDates(
                project.StartDate,
                project.EndDate);

            await _context.SaveChangesAsync();

            return MapToReadDto(project);
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var project = await GetDeletableProjectQuery()
                .FirstOrDefaultAsync(p => p.Id == id);

            if (project == null)
                return false;

            await using var transaction =
                await _context.Database.BeginTransactionAsync();

            var taskIds = await _context.Tasks
                .Where(t => t.ProjectId == id)
                .Select(t => t.Id)
                .ToListAsync();

            if (taskIds.Any())
            {
                var resourceAssignments =
                    await _context.ResourceAssignments
                        .Where(a => taskIds.Contains(a.TaskId))
                        .ToListAsync();

                if (resourceAssignments.Any())
                {
                    _context.ResourceAssignments.RemoveRange(
                        resourceAssignments);
                }

                var taskDependencies =
                    await _context.TaskDependencies
                        .Where(d =>
                            taskIds.Contains(d.PredecessorId) ||
                            taskIds.Contains(d.SuccessorId))
                        .ToListAsync();

                if (taskDependencies.Any())
                {
                    _context.TaskDependencies.RemoveRange(
                        taskDependencies);
                }
            }

            await DeletePlanningItemsAsync(id);
            await DeleteBaselinesAsync(id);
            await DeleteCalendarAsync(id);

            if (taskIds.Any())
            {
                var tasks = await _context.Tasks
                    .Where(t => t.ProjectId == id)
                    .ToListAsync();

                if (tasks.Any())
                {
                    _context.Tasks.RemoveRange(tasks);
                }
            }

            _context.Projects.Remove(project);

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();

            return true;
        }

        private IQueryable<Project> GetAccessibleProjectQuery()
        {
            if (_currentUser.IsGlobalAdmin)
            {
                return _context.Projects;
            }

            var userId = _currentUser.UserId;

            return _context.Projects
                .Where(p =>
                    p.OwnerUserId == userId ||
                    p.Members.Any(m => m.UserId == userId));
        }

        private IQueryable<Project> GetEditableProjectQuery()
        {
            if (_currentUser.IsGlobalAdmin)
            {
                return _context.Projects;
            }

            var userId = _currentUser.UserId;

            return _context.Projects
                .Where(p =>
                    p.OwnerUserId == userId ||
                    p.Members.Any(m =>
                        m.UserId == userId &&
                        (
                            m.Role == ProjectRole.Manager ||
                            m.Role == ProjectRole.Lead
                        )));
        }

        private IQueryable<Project> GetDeletableProjectQuery()
        {
            if (_currentUser.IsGlobalAdmin)
            {
                return _context.Projects;
            }

            var userId = _currentUser.UserId;

            return _context.Projects
                .Where(p =>
                    p.OwnerUserId == userId ||
                    p.Members.Any(m =>
                        m.UserId == userId &&
                        m.Role == ProjectRole.Manager));
        }

        private async Task DeletePlanningItemsAsync(int projectId)
        {
            var planningItems = await _context.PlanningItems
                .Where(pi => pi.ProjectId == projectId)
                .ToListAsync();

            if (!planningItems.Any())
                return;

            while (planningItems.Any())
            {
                var leafItems = planningItems
                    .Where(item =>
                        !planningItems.Any(
                            other => other.ParentId == item.Id))
                    .ToList();

                if (!leafItems.Any())
                {
                    _context.PlanningItems.RemoveRange(planningItems);
                    planningItems.Clear();
                    break;
                }

                _context.PlanningItems.RemoveRange(leafItems);

                foreach (var leafItem in leafItems)
                {
                    planningItems.Remove(leafItem);
                }

                await _context.SaveChangesAsync();
            }
        }

        private async Task DeleteBaselinesAsync(int projectId)
        {
            var baselineIds = await _context.ProjectBaselines
                .Where(b => b.ProjectId == projectId)
                .Select(b => b.Id)
                .ToListAsync();

            if (!baselineIds.Any())
                return;

            var baselineTasks =
                await _context.ProjectBaselineTasks
                    .Where(t =>
                        baselineIds.Contains(
                            t.ProjectBaselineId))
                    .ToListAsync();

            if (baselineTasks.Any())
            {
                _context.ProjectBaselineTasks.RemoveRange(
                    baselineTasks);
            }

            var baselines = await _context.ProjectBaselines
                .Where(b => b.ProjectId == projectId)
                .ToListAsync();

            if (baselines.Any())
            {
                _context.ProjectBaselines.RemoveRange(baselines);
            }
        }

        private async Task DeleteCalendarAsync(int projectId)
        {
            var calendars = await _context.ProjectCalendars
                .Where(c => c.ProjectId == projectId)
                .ToListAsync();

            if (!calendars.Any())
                return;

            var calendarIds = calendars
                .Select(c => c.Id)
                .ToList();

            var exceptions =
                await _context.ProjectCalendarExceptions
                    .Where(e =>
                        calendarIds.Contains(
                            e.ProjectCalendarId))
                    .ToListAsync();

            if (exceptions.Any())
            {
                _context.ProjectCalendarExceptions.RemoveRange(
                    exceptions);
            }

            _context.ProjectCalendars.RemoveRange(calendars);
        }

        private static ProjectReadDto MapToReadDto(Project project)
        {
            return new ProjectReadDto
            {
                Id = project.Id,
                Name = project.Name,
                Description = project.Description,
                ClientName = project.ClientName,
                ProjectCode = project.ProjectCode,
                StartDate = project.StartDate,
                EndDate = project.EndDate
            };
        }

        private static void ValidateProjectDates(
            DateTime? startDate,
            DateTime? endDate)
        {
            if (startDate.HasValue &&
                endDate.HasValue &&
                endDate.Value.Date < startDate.Value.Date)
            {
                throw new InvalidOperationException(
                    "La date de fin du projet ne peut pas être antérieure à la date de début.");
            }
        }
    }
}