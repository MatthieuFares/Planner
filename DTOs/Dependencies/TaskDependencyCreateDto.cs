using System.ComponentModel.DataAnnotations;
using PlannerAPI.Models;

namespace PlannerAPI.DTOs.Dependencies
{
    public class TaskDependencyCreateDto
    {
        [Required]
        public int PredecessorId { get; set; }

        [Required]
        public int SuccessorId { get; set; }

        [Required]
        public DependencyType Type { get; set; }
    }
}