namespace PlannerAPI.DTOs.Resources
{
    public class ResourceAssignmentUpdateDto
    {
        public int TaskId { get; set; }

        public int ResourceId { get; set; }

        public decimal WorkloadHours { get; set; }

        public decimal? AllocationPercent { get; set; }
    }
}