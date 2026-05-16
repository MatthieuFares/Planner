namespace PlannerAPI.DTOs.Resources
{
    public class ResourceAssignmentReadDto
    {
        public int Id { get; set; }

        public int TaskId { get; set; }

        public int ResourceId { get; set; }

        public string ResourceName { get; set; } = string.Empty;

        public decimal WorkloadHours { get; set; }

        public decimal? AllocationPercent { get; set; }
    }
}