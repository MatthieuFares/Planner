namespace PlannerAPI.DTOs.Resources
{
    public class ProjectResourceAnalysisDto
    {
        public int ProjectId { get; set; }
        public decimal TotalWorkloadHours { get; set; }
        public decimal EstimatedCost { get; set; }
        public List<ResourceWorkloadDto> Resources { get; set; } = new();
    }

    public class ResourceWorkloadDto
    {
        public int ResourceId { get; set; }
        public string ResourceName { get; set; } = string.Empty;
        public string ResourceType { get; set; } = string.Empty;

        public decimal AssignedHours { get; set; }
        public decimal? CapacityHoursPerWeek { get; set; }
        public decimal? CostPerHour { get; set; }

        public decimal EstimatedCost { get; set; }
        public decimal? UtilizationPercent { get; set; }
        public bool IsOverloaded { get; set; }
    }
}