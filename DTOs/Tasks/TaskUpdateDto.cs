using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.Tasks
{
    public class TaskUpdateDto
    {
        [Required]
        [StringLength(100)]
        public string Title { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        [Required]
        public int ProjectId { get; set; }

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        public int? Duration { get; set; }

        public int? ActualDuration { get; set; }

        public int? AssignedResourcesCount { get; set; }

        public decimal? WorkloadHours { get; set; }

        [Range(0, 100)]
        public int ProgressPercent { get; set; } = 0;
    }
}