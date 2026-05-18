using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.Resources
{
    public class ResourceGroupUpdateDto
    {
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }
    }
}