namespace PlannerAPI.DTOs.Gantt
{
    // Ancien format plat : GET /api/Gantt/project/{projectId}
    public class GanttTaskDto
    {
        public int Id { get; set; }

        public string Title { get; set; } = string.Empty;

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        public int? Duration { get; set; }

        public bool IsDone { get; set; }

        public bool IsCritical { get; set; }

        public int ProgressPercent { get; set; }

        public int? ActualDuration { get; set; }

        public int? AssignedResourcesCount { get; set; }

        public decimal? WorkloadHours { get; set; }

        public DateTime? EarlyStart { get; set; }

        public DateTime? EarlyFinish { get; set; }

        public DateTime? LateStart { get; set; }

        public DateTime? LateFinish { get; set; }

        public int? TotalFloat { get; set; }

        public List<GanttDependencyDto> Dependencies { get; set; } = new();

        public List<GanttResourceAssignmentDto> ResourceAssignments { get; set; } = new();
        public DateTime? Deadline { get; set; }
        public int DelayDays { get; set; }
        public bool IsLate { get; set; }
    }

    // Nouveau format structuré : GET /api/Gantt/project/{projectId}/structured
    public class GanttStructuredProjectDto
    {
        public int ProjectId { get; set; }

        public string ProjectName { get; set; } = string.Empty;

        public string? ClientName { get; set; }

        public string? ProjectCode { get; set; }

        public DateTime? ProjectStartDate { get; set; }

        public DateTime? ProjectEndDate { get; set; }

        public List<GanttPlanningItemDto> Items { get; set; } = new();
    }

    public class GanttPlanningItemDto
    {
        public int Id { get; set; }

        public int ProjectId { get; set; }

        public int? ParentId { get; set; }

        public string Name { get; set; } = string.Empty;

        public string Type { get; set; } = string.Empty;

        public int SortOrder { get; set; }

        public string WbsCode { get; set; } = string.Empty;

        public int Level { get; set; }

        public int? TaskId { get; set; }

        public GanttTaskDetailsDto? Task { get; set; }
    }

    public class GanttTaskDetailsDto
    {
        public int Id { get; set; }

        public string Title { get; set; } = string.Empty;

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        public int? Duration { get; set; }

        public bool IsDone { get; set; }

        public bool IsCritical { get; set; }

        public int ProgressPercent { get; set; }

        public int? ActualDuration { get; set; }

        public int? AssignedResourcesCount { get; set; }

        public decimal? WorkloadHours { get; set; }

        public DateTime? EarlyStart { get; set; }

        public DateTime? EarlyFinish { get; set; }

        public DateTime? LateStart { get; set; }

        public DateTime? LateFinish { get; set; }

        public int? TotalFloat { get; set; }

        public List<GanttDependencyDto> Dependencies { get; set; } = new();

        public List<GanttResourceAssignmentDto> ResourceAssignments { get; set; } = new();
        public DateTime? Deadline { get; set; }
        public int DelayDays { get; set; }
        public bool IsLate { get; set; }
    }

    public class GanttDependencyDto
    {
        public int Id { get; set; }

        public int PredecessorId { get; set; }

        public int SuccessorId { get; set; }

        public string Type { get; set; } = string.Empty;

        public int OffsetDays { get; set; }
    }

    public class GanttResourceAssignmentDto
    {
        public int AssignmentId { get; set; }

        public int? ResourceId { get; set; }

        public string? ResourceName { get; set; }

        public string? ResourceType { get; set; }

        public int? ResourceGroupId { get; set; }

        public string? ResourceGroupName { get; set; }

        public decimal WorkloadHours { get; set; }

        public int AllocationPercent { get; set; }

    }
}