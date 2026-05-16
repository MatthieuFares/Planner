namespace PlannerAPI.DTOs.Resources
{
    public class ResourceReadDto
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string Type { get; set; } = string.Empty;

        public decimal? CapacityHoursPerWeek { get; set; }
        public decimal? CostPerHour { get; set; }
    }
}