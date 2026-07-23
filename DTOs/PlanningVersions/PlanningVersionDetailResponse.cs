using PlannerAPI.Models;

namespace PlannerAPI.DTOs.PlanningVersions
{
    public class PlanningVersionDetailResponse
    {
        public int Id { get; set; }

        public int ProjectId { get; set; }

        public int VersionNumber { get; set; }

        public string Name { get; set; } = string.Empty;

        public string? Description { get; set; }

        public string? CreatedBy { get; set; }

        public DateTime CreatedAt { get; set; }

        public List<PlanningVersionTaskResponse> Tasks { get; set; }
            = new();

        public List<PlanningVersionItemResponse> Items { get; set; }
            = new();

        public List<PlanningVersionDependencyResponse> Dependencies
        {
            get;
            set;
        } = new();

        public List<PlanningVersionAssignmentResponse> Assignments
        {
            get;
            set;
        } = new();

        public PlanningVersionCalendarResponse? Calendar { get; set; }
    }

    public class PlanningVersionTaskResponse
    {
        public int OriginalTaskId { get; set; }

        public string Title { get; set; } = string.Empty;

        public string? Description { get; set; }

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        public int? Duration { get; set; }

        public int ProgressPercent { get; set; }

        public bool IsDone { get; set; }

        public int? ActualDuration { get; set; }

        public int? AssignedResourcesCount { get; set; }

        public decimal? WorkloadHours { get; set; }

        public DateTime? EarlyStart { get; set; }

        public DateTime? EarlyFinish { get; set; }

        public DateTime? LateStart { get; set; }

        public DateTime? LateFinish { get; set; }

        public int? TotalFloat { get; set; }

        public bool IsCritical { get; set; }

        public DateTime? Deadline { get; set; }

        public int DelayDays { get; set; }

        public bool IsLate { get; set; }
    }

    public class PlanningVersionItemResponse
    {
        public int OriginalPlanningItemId { get; set; }

        public int? OriginalParentId { get; set; }

        public string Name { get; set; } = string.Empty;

        public PlanningItemType Type { get; set; }

        public int SortOrder { get; set; }

        public string WbsCode { get; set; } = string.Empty;

        public int? OriginalTaskId { get; set; }
    }

    public class PlanningVersionDependencyResponse
    {
        public int OriginalDependencyId { get; set; }

        public int OriginalPredecessorTaskId { get; set; }

        public int OriginalSuccessorTaskId { get; set; }

        public string Type { get; set; } = "FS";

        public int OffsetDays { get; set; }
    }

    public class PlanningVersionAssignmentResponse
    {
        public int OriginalAssignmentId { get; set; }

        public int OriginalTaskId { get; set; }

        public int? OriginalResourceId { get; set; }

        public string? ResourceName { get; set; }

        public int? OriginalResourceGroupId { get; set; }

        public string? ResourceGroupName { get; set; }

        public decimal WorkloadHours { get; set; }

        public int AllocationPercent { get; set; }
    }

    public class PlanningVersionCalendarResponse
    {
        public bool WorkMonday { get; set; }

        public bool WorkTuesday { get; set; }

        public bool WorkWednesday { get; set; }

        public bool WorkThursday { get; set; }

        public bool WorkFriday { get; set; }

        public bool WorkSaturday { get; set; }

        public bool WorkSunday { get; set; }

        public List<PlanningVersionCalendarExceptionResponse> Exceptions
        {
            get;
            set;
        } = new();

        public List<PlanningVersionCalendarPeriodResponse> Periods
        {
            get;
            set;
        } = new();
    }

    public class PlanningVersionCalendarExceptionResponse
    {
        public DateTime Date { get; set; }

        public string Label { get; set; } = string.Empty;

        public bool IsWorkingDay { get; set; }
    }

    public class PlanningVersionCalendarPeriodResponse
    {
        public DateTime StartDate { get; set; }

        public DateTime EndDate { get; set; }

        public string Label { get; set; } = string.Empty;
    }
}