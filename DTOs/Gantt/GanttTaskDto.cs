namespace PlannerAPI.DTOs.Gantt
{
    public class GanttTaskDto
    {
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;

        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public int? Duration { get; set; }

        public bool IsDone { get; set; }
        public bool IsCritical { get; set; }

        public int? ActualDuration { get; set; }
        public int? AssignedResourcesCount { get; set; }
        public decimal? WorkloadHours { get; set; }
        public List<GanttDependencyDto> Dependencies { get; set; } = new();
        public DateTime? EarlyStart { get; set; }
        public DateTime? EarlyFinish { get; set; }
        public DateTime? LateStart { get; set; }
        public DateTime? LateFinish { get; set; }
        public int? TotalFloat { get; set; }
        public List<GanttResourceAssignmentDto> ResourceAssignments { get; set; } = new();
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
        public int ResourceId { get; set; }
        public string ResourceName { get; set; } = string.Empty;
        public string ResourceType { get; set; } = string.Empty;
        public decimal WorkloadHours { get; set; }
        public decimal? AllocationPercent { get; set; }
    }
}