using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.ProjectBaselines
{
    public class ProjectBaselineCreateDto
    {
        [Required]
        [MaxLength(150)]
        public string Name { get; set; } = string.Empty;

        [MaxLength(500)]
        public string? Description { get; set; }

        public bool SetAsActive { get; set; } = true;
    }
}