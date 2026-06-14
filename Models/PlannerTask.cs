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

        public int ProjectId { get; set; }
        public Project? Project { get; set; }

        // Planning
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public int? Duration { get; set; }

        // Avancement
        public int ProgressPercent { get; set; } = 0;
        public bool IsDone { get; set; } = false;
        public int? ActualDuration { get; set; }

        // Charge / ressources
        public int? AssignedResourcesCount { get; set; }
        public decimal? WorkloadHours { get; set; }

        // Chemin critique / CPM
        public DateTime? EarlyStart { get; set; }
        public DateTime? EarlyFinish { get; set; }
        public DateTime? LateStart { get; set; }
        public DateTime? LateFinish { get; set; }
        public int? TotalFloat { get; set; }
        public bool IsCritical { get; set; } = false;

        // Relations
        public List<TaskDependency> Predecessors { get; set; } = new();
        public List<TaskDependency> Successors { get; set; } = new();
        public List<ResourceAssignment> ResourceAssignments { get; set; } = new();
    }
}