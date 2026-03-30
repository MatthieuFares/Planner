using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.Tasks
{
    public class TaskCreateDto
    {
        [Required]
        [StringLength(100)]
        public string Title { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        public bool IsDone { get; set; } = false;

        [Required]
        public int ProjectId { get; set; }
    }
}