using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.PlanningVersions
{
    public class CreatePlanningVersionRequest
    {
        [Required]
        [StringLength(150)]
        public string Name { get; set; } = string.Empty;

        [StringLength(1000)]
        public string? Description { get; set; }

        [StringLength(150)]
        public string? CreatedBy { get; set; }
    }
}