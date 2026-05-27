namespace PlannerAPI.DTOs.Resources
{
    public class ResourceGroupMemberReadDto
    {
        public int Id { get; set; }

        public int ResourceGroupId { get; set; }

        public int ResourceId { get; set; }

        public string ResourceName { get; set; } = string.Empty;

        public string ResourceType { get; set; } = string.Empty;

        public decimal CapacityHoursPerWeek { get; set; }

        public decimal CostPerHour { get; set; }
    }
}