using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class PlannerTask
    {
        public int Id { get; set; }

        [Required]
        [StringLength(100)]
        public string Title { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        public bool IsDone { get; set; } = false;

        public int ProjectId { get; set; }
        public Project? Project { get; set; }

        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public int? Duration { get; set; }

        public List<TaskDependency> Predecessors { get; set; } = new();
        public List<TaskDependency> Successors { get; set; } = new();
    }
}