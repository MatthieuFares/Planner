using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.Resources
{
    public class ResourceUpdateDto
    {
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [Required]
        [StringLength(50)]
        public string Type { get; set; } = "Person";

        public decimal? CapacityHoursPerWeek { get; set; }

        public decimal? CostPerHour { get; set; }
    }
}