using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class ProjectAuthorizationService : IProjectAuthorizationService
    {
        private readonly AppDbContext _context;
        private readonly ICurrentUserService _currentUser;

        public ProjectAuthorizationService(
            AppDbContext context,
            ICurrentUserService currentUser)
        {
            _context = context;
            _currentUser = currentUser;
        }

        public async Task<bool> CanCreateProjectAsync()
        {
            if (_currentUser.IsGlobalAdmin)
                return true;

            var userId = _currentUser.UserId;

            var user = await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(candidate =>
                    candidate.Id == userId &&
                    candidate.IsActive);

            if (user == null)
                return false;

            if (user.CanCreateProjects)
                return true;

            // Le rôle Manager donne la capacité de créer/importer
            // uniquement tant que le rôle existe. Il ne modifie pas
            // la permission durable stockée sur AppUser.
            return await _context.Projects
                .AsNoTracking()
                .AnyAsync(project =>
                    project.OwnerUserId == userId ||
                    project.Members.Any(member =>
                        member.UserId == userId &&
                        member.Role ==
                            ProjectRole.Manager));
        }

        public async Task<bool> CanReadProjectAsync(int projectId)
        {
            if (_currentUser.IsGlobalAdmin)
                return await ProjectExistsAsync(projectId);

            var userId = _currentUser.UserId;

            return await _context.Projects
                .AsNoTracking()
                .AnyAsync(p =>
                    p.Id == projectId &&
                    (
                        p.OwnerUserId == userId ||
                        p.Members.Any(m => m.UserId == userId)
                    ));
        }

        public async Task<bool> CanEditPlanningAsync(int projectId)
        {
            if (_currentUser.IsGlobalAdmin)
                return await ProjectExistsAsync(projectId);

            var userId = _currentUser.UserId;

            return await _context.Projects
                .AsNoTracking()
                .AnyAsync(p =>
                    p.Id == projectId &&
                    (
                        p.OwnerUserId == userId ||
                        p.Members.Any(m =>
                            m.UserId == userId &&
                            (
                                m.Role == ProjectRole.Manager ||
                                m.Role == ProjectRole.Lead
                            ))
                    ));
        }

        public async Task<bool> CanManageMembersAsync(int projectId)
        {
            if (_currentUser.IsGlobalAdmin)
                return await ProjectExistsAsync(projectId);

            var userId = _currentUser.UserId;

            return await _context.Projects
                .AsNoTracking()
                .AnyAsync(p =>
                    p.Id == projectId &&
                    (
                        p.OwnerUserId == userId ||
                        p.Members.Any(m =>
                            m.UserId == userId &&
                            m.Role == ProjectRole.Manager)
                    ));
        }

        public async Task<bool> CanDeleteProjectAsync(int projectId)
        {
            return await CanManageMembersAsync(projectId);
        }

        public async Task<bool> CanReadTaskAsync(int taskId)
        {
            var projectId = await GetTaskProjectIdAsync(taskId);

            return projectId.HasValue &&
                   await CanReadProjectAsync(projectId.Value);
        }

        public async Task<bool> CanEditTaskAsync(int taskId)
        {
            var projectId = await GetTaskProjectIdAsync(taskId);

            return projectId.HasValue &&
                   await CanEditPlanningAsync(projectId.Value);
        }

        public async Task<bool> CanReadDependencyAsync(int dependencyId)
        {
            var projectId = await GetDependencyProjectIdAsync(dependencyId);

            return projectId.HasValue &&
                   await CanReadProjectAsync(projectId.Value);
        }

        public async Task<bool> CanEditDependencyAsync(int dependencyId)
        {
            var projectId = await GetDependencyProjectIdAsync(dependencyId);

            return projectId.HasValue &&
                   await CanEditPlanningAsync(projectId.Value);
        }

        public async Task<bool> CanReadPlanningItemAsync(int planningItemId)
        {
            var projectId =
                await GetPlanningItemProjectIdAsync(planningItemId);

            return projectId.HasValue &&
                   await CanReadProjectAsync(projectId.Value);
        }

        public async Task<bool> CanEditPlanningItemAsync(int planningItemId)
        {
            var projectId =
                await GetPlanningItemProjectIdAsync(planningItemId);

            return projectId.HasValue &&
                   await CanEditPlanningAsync(projectId.Value);
        }

        public async Task<bool> CanReadCalendarExceptionAsync(int exceptionId)
        {
            var projectId =
                await GetCalendarExceptionProjectIdAsync(exceptionId);

            return projectId.HasValue &&
                   await CanReadProjectAsync(projectId.Value);
        }

        public async Task<bool> CanEditCalendarExceptionAsync(int exceptionId)
        {
            var projectId =
                await GetCalendarExceptionProjectIdAsync(exceptionId);

            return projectId.HasValue &&
                   await CanEditPlanningAsync(projectId.Value);
        }

        public async Task<bool> CanReadCalendarPeriodAsync(int periodId)
        {
            var projectId =
                await GetCalendarPeriodProjectIdAsync(periodId);

            return projectId.HasValue &&
                   await CanReadProjectAsync(projectId.Value);
        }

        public async Task<bool> CanEditCalendarPeriodAsync(int periodId)
        {
            var projectId =
                await GetCalendarPeriodProjectIdAsync(periodId);

            return projectId.HasValue &&
                   await CanEditPlanningAsync(projectId.Value);
        }

        public async Task<bool> CanReadResourceCatalogAsync()
        {
            if (_currentUser.IsGlobalAdmin)
                return true;

            var userId = _currentUser.UserId;

            var activeUser = await _context.Users
                .AsNoTracking()
                .AnyAsync(user =>
                    user.Id == userId &&
                    user.IsActive);

            if (!activeUser)
                return false;

            var canManageCatalog = await _context.Users
                .AsNoTracking()
                .AnyAsync(user =>
                    user.Id == userId &&
                    user.CanManageResources);

            if (canManageCatalog)
                return true;

            // Le catalogue est partagé à l'échelle de l'instance Planner.
            // Un utilisateur qui édite au moins un planning doit pouvoir
            // sélectionner les ressources/groupes existants.
            return await _context.Projects
                .AsNoTracking()
                .AnyAsync(project =>
                    project.OwnerUserId == userId ||
                    project.Members.Any(member =>
                        member.UserId == userId &&
                        (
                            member.Role == ProjectRole.Manager ||
                            member.Role == ProjectRole.Lead
                        )));
        }

        public async Task<bool> CanManageResourceCatalogAsync()
        {
            if (_currentUser.IsGlobalAdmin)
                return true;

            var userId = _currentUser.UserId;

            return await _context.Users
                .AsNoTracking()
                .AnyAsync(user =>
                    user.Id == userId &&
                    user.IsActive &&
                    user.CanManageResources);
        }

        public async Task<bool> CanReadAssignmentAsync(int assignmentId)
        {
            var projectId =
                await GetAssignmentProjectIdAsync(assignmentId);

            return projectId.HasValue &&
                   await CanReadProjectAsync(projectId.Value);
        }

        public async Task<bool> CanEditAssignmentAsync(int assignmentId)
        {
            var projectId =
                await GetAssignmentProjectIdAsync(assignmentId);

            return projectId.HasValue &&
                   await CanEditPlanningAsync(projectId.Value);
        }

        public async Task<bool> CanReadBaselineAsync(int baselineId)
        {
            var projectId =
                await GetBaselineProjectIdAsync(baselineId);

            return projectId.HasValue &&
                   await CanReadProjectAsync(projectId.Value);
        }

        public async Task<bool> CanEditBaselineAsync(int baselineId)
        {
            var projectId =
                await GetBaselineProjectIdAsync(baselineId);

            return projectId.HasValue &&
                   await CanEditPlanningAsync(projectId.Value);
        }

        public async Task<bool> CanReadPlanningVersionAsync(int versionId)
        {
            var projectId =
                await GetPlanningVersionProjectIdAsync(versionId);

            return projectId.HasValue &&
                   await CanReadProjectAsync(projectId.Value);
        }

        public async Task<bool> CanEditPlanningVersionAsync(int versionId)
        {
            var projectId =
                await GetPlanningVersionProjectIdAsync(versionId);

            return projectId.HasValue &&
                   await CanEditPlanningAsync(projectId.Value);
        }

        private async Task<int?> GetTaskProjectIdAsync(int taskId)
        {
            return await _context.Tasks
                .AsNoTracking()
                .Where(t => t.Id == taskId)
                .Select(t => (int?)t.ProjectId)
                .FirstOrDefaultAsync();
        }

        private async Task<int?> GetDependencyProjectIdAsync(int dependencyId)
        {
            return await (
                from dependency in _context.TaskDependencies.AsNoTracking()
                join predecessor in _context.Tasks.AsNoTracking()
                    on dependency.PredecessorId equals predecessor.Id
                where dependency.Id == dependencyId
                select (int?)predecessor.ProjectId
            ).FirstOrDefaultAsync();
        }

        private async Task<int?> GetPlanningItemProjectIdAsync(
            int planningItemId)
        {
            return await _context.PlanningItems
                .AsNoTracking()
                .Where(item => item.Id == planningItemId)
                .Select(item => (int?)item.ProjectId)
                .FirstOrDefaultAsync();
        }

        private async Task<int?> GetCalendarExceptionProjectIdAsync(
            int exceptionId)
        {
            return await (
                from exception in _context.ProjectCalendarExceptions.AsNoTracking()
                join calendar in _context.ProjectCalendars.AsNoTracking()
                    on exception.ProjectCalendarId equals calendar.Id
                where exception.Id == exceptionId
                select (int?)calendar.ProjectId
            ).FirstOrDefaultAsync();
        }

        private async Task<int?> GetCalendarPeriodProjectIdAsync(
            int periodId)
        {
            return await (
                from period in _context.ProjectCalendarPeriods.AsNoTracking()
                join calendar in _context.ProjectCalendars.AsNoTracking()
                    on period.ProjectCalendarId equals calendar.Id
                where period.Id == periodId
                select (int?)calendar.ProjectId
            ).FirstOrDefaultAsync();
        }

        private async Task<int?> GetAssignmentProjectIdAsync(
            int assignmentId)
        {
            return await (
                from assignment in _context.ResourceAssignments.AsNoTracking()
                join task in _context.Tasks.AsNoTracking()
                    on assignment.TaskId equals task.Id
                where assignment.Id == assignmentId
                select (int?)task.ProjectId
            ).FirstOrDefaultAsync();
        }

        private async Task<int?> GetBaselineProjectIdAsync(
            int baselineId)
        {
            return await _context.ProjectBaselines
                .AsNoTracking()
                .Where(baseline => baseline.Id == baselineId)
                .Select(baseline => (int?)baseline.ProjectId)
                .FirstOrDefaultAsync();
        }

        private async Task<int?> GetPlanningVersionProjectIdAsync(
            int versionId)
        {
            return await _context.PlanningVersions
                .AsNoTracking()
                .Where(version => version.Id == versionId)
                .Select(version => (int?)version.ProjectId)
                .FirstOrDefaultAsync();
        }

        private async Task<bool> ProjectExistsAsync(int projectId)
        {
            return await _context.Projects
                .AsNoTracking()
                .AnyAsync(p => p.Id == projectId);
        }
    }
}