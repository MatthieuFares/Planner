using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.Dependencies
{
    public class TaskDependencyUpdateDto
    {
        [Required]
        public int PredecessorId { get; set; }

        [Required]
        public int SuccessorId { get; set; }

        [Required]
        [StringLength(2)]
        public string Type { get; set; } = "FS";

        [Range(-3650, 3650)]
        public int OffsetDays { get; set; } = 0;
    }
}