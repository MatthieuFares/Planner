namespace PlannerAPI.Models
{
    public class ProjectBaselineTask
    {
        public int Id { get; set; }

        public int ProjectBaselineId { get; set; }
        public ProjectBaseline? ProjectBaseline { get; set; }

        public int TaskId { get; set; }

        public string TaskTitle { get; set; } = string.Empty;

        public string? WbsCode { get; set; }

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        public int Duration { get; set; }

        public int ProgressPercent { get; set; }

        public DateTime? Deadline { get; set; }

        public int TotalFloat { get; set; }

        public bool IsCritical { get; set; }

        public bool IsLate { get; set; }

        public int DelayDays { get; set; }
    }
}