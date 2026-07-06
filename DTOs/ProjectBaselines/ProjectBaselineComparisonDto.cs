namespace PlannerAPI.DTOs.ProjectBaselines
{
    public class ProjectBaselineComparisonDto
    {
        public int BaselineId { get; set; }

        public int ProjectId { get; set; }

        public string BaselineName { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; }

        public bool IsActive { get; set; }

        public List<ProjectBaselineComparisonRowDto> Rows { get; set; } = new();
    }

    public class ProjectBaselineComparisonRowDto
    {
        public int TaskId { get; set; }

        public string TaskTitle { get; set; } = string.Empty;

        public string? WbsCode { get; set; }

        public DateTime? BaselineStartDate { get; set; }

        public DateTime? CurrentStartDate { get; set; }

        public int? StartVarianceDays { get; set; }

        public DateTime? BaselineEndDate { get; set; }

        public DateTime? CurrentEndDate { get; set; }

        public int? EndVarianceDays { get; set; }

        public int BaselineDuration { get; set; }

        public int CurrentDuration { get; set; }

        public int DurationVarianceDays { get; set; }

        public int BaselineProgressPercent { get; set; }

        public int CurrentProgressPercent { get; set; }

        public int ProgressVariancePercent { get; set; }

        public DateTime? BaselineDeadline { get; set; }

        public DateTime? CurrentDeadline { get; set; }

        public int BaselineTotalFloat { get; set; }

        public int CurrentTotalFloat { get; set; }

        public int TotalFloatVariance { get; set; }

        public bool BaselineIsCritical { get; set; }

        public bool CurrentIsCritical { get; set; }

        public bool BaselineIsLate { get; set; }

        public bool CurrentIsLate { get; set; }

        public int BaselineDelayDays { get; set; }

        public int CurrentDelayDays { get; set; }

        public bool IsDelayedComparedToBaseline { get; set; }

        public bool IsMissingFromCurrentPlanning { get; set; }
    }
}