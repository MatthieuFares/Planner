using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.Resources
{
    public class ResourceAssignmentUpdateDto
    {
        [Required]
        public int TaskId { get; set; }

        public int? ResourceId { get; set; }

        public int? ResourceGroupId { get; set; }

        [Range(0, double.MaxValue)]
        public decimal WorkloadHours { get; set; }

        [Range(0, 100)]
        public int AllocationPercent { get; set; }
    }
}