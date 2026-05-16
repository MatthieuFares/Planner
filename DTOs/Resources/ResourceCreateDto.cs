using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.Resources
{
    public class ResourceCreateDto
    {
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        public string Type { get; set; } = "Person";

        public decimal? CapacityHoursPerWeek { get; set; }
        public decimal? CostPerHour { get; set; }
    }
}