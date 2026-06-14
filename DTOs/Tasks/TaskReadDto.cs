namespace PlannerAPI.DTOs.Tasks
{
    public class TaskReadDto
    {
        public int Id { get; set; }

        public string Title { get; set; } = string.Empty;

        public string? Description { get; set; }

        public bool IsDone { get; set; }

        public int ProjectId { get; set; }

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        public int? Duration { get; set; }

        public int? ActualDuration { get; set; }

        public int? AssignedResourcesCount { get; set; }

        public decimal? WorkloadHours { get; set; }

        public bool IsCritical { get; set; }

        public DateTime? EarlyStart { get; set; }

        public DateTime? EarlyFinish { get; set; }

        public DateTime? LateStart { get; set; }

        public DateTime? LateFinish { get; set; }

        public int? TotalFloat { get; set; }

        public int ProgressPercent { get; set; }
    }
}