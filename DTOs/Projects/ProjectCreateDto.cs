using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.Projects
{
    public class ProjectCreateDto
    {
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        [StringLength(100)]
        public string? ClientName { get; set; }

        [StringLength(50)]
        public string? ProjectCode { get; set; }

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }
    }
}