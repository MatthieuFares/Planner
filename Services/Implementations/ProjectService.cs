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

        public async Task<IEnumerable<ProjectReadDto>>
            GetAllAsync()
        {
            var query = _context.Projects
                .AsNoTracking()
                .AsQueryable();

            if (!_currentUser.IsGlobalAdmin)
            {
                var userId = _currentUser.UserId;

                query = query.Where(project =>
                    project.OwnerUserId == userId ||
                    project.Members.Any(member =>
                        member.UserId == userId));
            }

            var projects = await query
                .OrderBy(project => project.Name)
                .ToListAsync();

            return projects.Select(MapToReadDto);
        }

        public async Task<IEnumerable<ProjectListItemDto>>
            GetListItemsAsync()
        {
            if (_currentUser.IsGlobalAdmin)
            {
                return await _context.Projects
                    .AsNoTracking()
                    .OrderBy(project => project.Name)
                    .Select(project =>
                        new ProjectListItemDto
                        {
                            Id = project.Id,
                            Name = project.Name,
                            Description =
                                project.Description,
                            ClientName =
                                project.ClientName,
                            ProjectCode =
                                project.ProjectCode,
                            StartDate =
                                project.StartDate,
                            EndDate =
                                project.EndDate,
                            CanEditPlanning = true,
                            CanManageMembers = true,
                            CanDeleteProject = true
                        })
                    .ToListAsync();
            }

            var userId = _currentUser.UserId;

            return await _context.Projects
                .AsNoTracking()
                .Where(project =>
                    project.OwnerUserId == userId ||
                    project.Members.Any(member =>
                        member.UserId == userId))
                .OrderBy(project => project.Name)
                .Select(project =>
                    new ProjectListItemDto
                    {
                        Id = project.Id,
                        Name = project.Name,
                        Description =
                            project.Description,
                        ClientName =
                            project.ClientName,
                        ProjectCode =
                            project.ProjectCode,
                        StartDate =
                            project.StartDate,
                        EndDate =
                            project.EndDate,
                        CanEditPlanning =
                            project.OwnerUserId ==
                                userId ||
                            project.Members.Any(
                                member =>
                                    member.UserId ==
                                        userId &&
                                    (
                                        member.Role ==
                                            ProjectRole.Manager ||
                                        member.Role ==
                                            ProjectRole.Lead
                                    )),
                        CanManageMembers =
                            project.OwnerUserId ==
                                userId ||
                            project.Members.Any(
                                member =>
                                    member.UserId ==
                                        userId &&
                                    member.Role ==
                                        ProjectRole.Manager),
                        CanDeleteProject =
                            project.OwnerUserId ==
                                userId ||
                            project.Members.Any(
                                member =>
                                    member.UserId ==
                                        userId &&
                                    member.Role ==
                                        ProjectRole.Manager)
                    })
                .ToListAsync();
        }

        public async Task<ProjectReadDto?>
            GetByIdAsync(int id)
        {
            var project = await GetAccessibleProjectQuery()
                .AsNoTracking()
                .FirstOrDefaultAsync(project =>
                    project.Id == id);

            if (project == null)
            {
                return null;
            }

            return MapToReadDto(project);
        }

        public async Task<IEnumerable<TaskReadDto>?>
            GetTasksByProjectIdAsync(int projectId)
        {
            var projectExists =
                await GetAccessibleProjectQuery()
                    .AnyAsync(project =>
                        project.Id == projectId);

            if (!projectExists)
            {
                return null;
            }

            return await _taskService
                .GetByProjectIdAsync(projectId);
        }

        public async Task<ProjectReadDto>
            CreateAsync(ProjectCreateDto dto)
        {
            var userId = _currentUser.UserId;

            var currentUser = await _context.Users
                .FirstOrDefaultAsync(user =>
                    user.Id == userId &&
                    user.IsActive);

            if (currentUser == null)
            {
                throw new InvalidOperationException(
                    "L'utilisateur authentifié est introuvable "
                    + "ou désactivé.");
            }

            // La permission est persistée indépendamment du projet.
            // La suppression du dernier projet ne la retire donc pas.
            currentUser.CanCreateProjects = true;

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

        public async Task<ProjectReadDto?>
            UpdateAsync(
                int id,
                ProjectUpdateDto dto)
        {
            var project = await GetEditableProjectQuery()
                .FirstOrDefaultAsync(existingProject =>
                    existingProject.Id == id);

            if (project == null)
            {
                return null;
            }

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
                .FirstOrDefaultAsync(existingProject =>
                    existingProject.Id == id);

            if (project == null)
            {
                return false;
            }

            await using var transaction =
                await _context.Database
                    .BeginTransactionAsync();

            var taskIds = await _context.Tasks
                .Where(task =>
                    task.ProjectId == id)
                .Select(task => task.Id)
                .ToListAsync();

            if (taskIds.Any())
            {
                var resourceAssignments =
                    await _context.ResourceAssignments
                        .Where(assignment =>
                            taskIds.Contains(
                                assignment.TaskId))
                        .ToListAsync();

                if (resourceAssignments.Any())
                {
                    _context.ResourceAssignments
                        .RemoveRange(
                            resourceAssignments);
                }

                var taskDependencies =
                    await _context.TaskDependencies
                        .Where(dependency =>
                            taskIds.Contains(
                                dependency.PredecessorId) ||
                            taskIds.Contains(
                                dependency.SuccessorId))
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
                    .Where(task =>
                        task.ProjectId == id)
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

        private IQueryable<Project>
            GetAccessibleProjectQuery()
        {
            if (_currentUser.IsGlobalAdmin)
            {
                return _context.Projects;
            }

            var userId = _currentUser.UserId;

            return _context.Projects
                .Where(project =>
                    project.OwnerUserId == userId ||
                    project.Members.Any(member =>
                        member.UserId == userId));
        }

        private IQueryable<Project>
            GetEditableProjectQuery()
        {
            if (_currentUser.IsGlobalAdmin)
            {
                return _context.Projects;
            }

            var userId = _currentUser.UserId;

            return _context.Projects
                .Where(project =>
                    project.OwnerUserId == userId ||
                    project.Members.Any(member =>
                        member.UserId == userId &&
                        (
                            member.Role ==
                                ProjectRole.Manager ||
                            member.Role ==
                                ProjectRole.Lead
                        )));
        }

        private IQueryable<Project>
            GetDeletableProjectQuery()
        {
            if (_currentUser.IsGlobalAdmin)
            {
                return _context.Projects;
            }

            var userId = _currentUser.UserId;

            return _context.Projects
                .Where(project =>
                    project.OwnerUserId == userId ||
                    project.Members.Any(member =>
                        member.UserId == userId &&
                        member.Role ==
                            ProjectRole.Manager));
        }

        private async Task DeletePlanningItemsAsync(
            int projectId)
        {
            var planningItems =
                await _context.PlanningItems
                    .Where(item =>
                        item.ProjectId == projectId)
                    .ToListAsync();

            if (!planningItems.Any())
            {
                return;
            }

            while (planningItems.Any())
            {
                var leafItems = planningItems
                    .Where(item =>
                        !planningItems.Any(other =>
                            other.ParentId == item.Id))
                    .ToList();

                if (!leafItems.Any())
                {
                    _context.PlanningItems.RemoveRange(
                        planningItems);

                    planningItems.Clear();
                    break;
                }

                _context.PlanningItems.RemoveRange(
                    leafItems);

                foreach (var leafItem in leafItems)
                {
                    planningItems.Remove(leafItem);
                }

                await _context.SaveChangesAsync();
            }
        }

        private async Task DeleteBaselinesAsync(
            int projectId)
        {
            var baselineIds =
                await _context.ProjectBaselines
                    .Where(baseline =>
                        baseline.ProjectId ==
                            projectId)
                    .Select(baseline => baseline.Id)
                    .ToListAsync();

            if (!baselineIds.Any())
            {
                return;
            }

            var baselineTasks =
                await _context.ProjectBaselineTasks
                    .Where(task =>
                        baselineIds.Contains(
                            task.ProjectBaselineId))
                    .ToListAsync();

            if (baselineTasks.Any())
            {
                _context.ProjectBaselineTasks.RemoveRange(
                    baselineTasks);
            }

            var baselines =
                await _context.ProjectBaselines
                    .Where(baseline =>
                        baseline.ProjectId ==
                            projectId)
                    .ToListAsync();

            if (baselines.Any())
            {
                _context.ProjectBaselines.RemoveRange(
                    baselines);
            }
        }

        private async Task DeleteCalendarAsync(
            int projectId)
        {
            var calendars =
                await _context.ProjectCalendars
                    .Where(calendar =>
                        calendar.ProjectId ==
                            projectId)
                    .ToListAsync();

            if (!calendars.Any())
            {
                return;
            }

            var calendarIds = calendars
                .Select(calendar => calendar.Id)
                .ToList();

            var exceptions =
                await _context.ProjectCalendarExceptions
                    .Where(exception =>
                        calendarIds.Contains(
                            exception
                                .ProjectCalendarId))
                    .ToListAsync();

            if (exceptions.Any())
            {
                _context.ProjectCalendarExceptions
                    .RemoveRange(exceptions);
            }

            _context.ProjectCalendars.RemoveRange(
                calendars);
        }

        private static ProjectReadDto MapToReadDto(
            Project project)
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
                endDate.Value.Date <
                    startDate.Value.Date)
            {
                throw new InvalidOperationException(
                    "La date de fin du projet ne peut pas " +
                    "être antérieure à la date de début.");
            }
        }
    }
}
