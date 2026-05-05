using System.ComponentModel.DataAnnotations;
using PlannerAPI.Models;

namespace PlannerAPI.DTOs.Dependencies
{
    public class TaskDependencyUpdateDto
    {
        [Required]
        public int PredecessorId { get; set; }

        [Required]
        public int SuccessorId { get; set; }

        [Required]
        public string Type { get; set; } = "FS";
        public int OffsetDays { get; set; } = 0;
    }
}