namespace PlannerAPI.DTOs.Resources
{
    public class ResourceAssignmentCreateDto
    {
        public int TaskId { get; set; }

        public int? ResourceId { get; set; }

        public int? ResourceGroupId { get; set; }

        public decimal WorkloadHours { get; set; }

        public int AllocationPercent { get; set; }
    }
}