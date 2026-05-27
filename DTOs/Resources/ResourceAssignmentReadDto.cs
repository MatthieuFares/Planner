namespace PlannerAPI.DTOs.Resources
{
    public class ResourceAssignmentReadDto
    {
        public int Id { get; set; }

        public int TaskId { get; set; }
        public string? TaskTitle { get; set; }

        public int? ResourceId { get; set; }
        public string? ResourceName { get; set; }

        public int? ResourceGroupId { get; set; }
        public string? ResourceGroupName { get; set; }

        public decimal WorkloadHours { get; set; }

        public int AllocationPercent { get; set; }
    }
}