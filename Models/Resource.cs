using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class Resource
    {
        public int Id { get; set; }

        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [StringLength(50)]
        public string Type { get; set; } = "Person";

        public decimal? CapacityHoursPerWeek { get; set; }
        public decimal? CostPerHour { get; set; }

        public List<ResourceAssignment> Assignments { get; set; } = new();
    }
}