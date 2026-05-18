namespace PlannerAPI.DTOs.Projects
{
    public class ProjectSummaryDto
    {
        public int ProjectId { get; set; }
        public string ProjectName { get; set; } = string.Empty;

        public DateTime? ProjectStart { get; set; }
        public DateTime? ProjectEnd { get; set; }
        public int? ProjectDurationDays { get; set; }

        public int TaskCount { get; set; }
        public int CompletedTaskCount { get; set; }

        public int CriticalTaskCount { get; set; }
        public int NonCriticalTaskCount { get; set; }

        public int DependencyCount { get; set; }

        public int ResourceCount { get; set; }
        public int ResourceGroupCount { get; set; }

        public decimal TotalWorkloadHours { get; set; }
        public decimal EstimatedCost { get; set; }

        public int OverloadedResourceCount { get; set; }
    }
}