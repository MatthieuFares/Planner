namespace PlannerAPI.Services.Interfaces
{
    public interface IProjectAuthorizationService
    {
        Task<bool> CanCreateProjectAsync();

        Task<bool> CanReadProjectAsync(int projectId);

        Task<bool> CanEditPlanningAsync(int projectId);

        Task<bool> CanManageMembersAsync(int projectId);

        Task<bool> CanDeleteProjectAsync(int projectId);

        Task<bool> CanReadTaskAsync(int taskId);

        Task<bool> CanEditTaskAsync(int taskId);

        Task<bool> CanReadDependencyAsync(int dependencyId);

        Task<bool> CanEditDependencyAsync(int dependencyId);

        Task<bool> CanReadPlanningItemAsync(int planningItemId);

        Task<bool> CanEditPlanningItemAsync(int planningItemId);

        Task<bool> CanReadCalendarExceptionAsync(int exceptionId);

        Task<bool> CanEditCalendarExceptionAsync(int exceptionId);

        Task<bool> CanReadCalendarPeriodAsync(int periodId);

        Task<bool> CanEditCalendarPeriodAsync(int periodId);

        Task<bool> CanReadResourceCatalogAsync();

        Task<bool> CanManageResourceCatalogAsync();

        Task<bool> CanReadAssignmentAsync(int assignmentId);

        Task<bool> CanEditAssignmentAsync(int assignmentId);

        Task<bool> CanReadBaselineAsync(int baselineId);

        Task<bool> CanEditBaselineAsync(int baselineId);

        Task<bool> CanReadPlanningVersionAsync(int versionId);

        Task<bool> CanEditPlanningVersionAsync(int versionId);
    }
}