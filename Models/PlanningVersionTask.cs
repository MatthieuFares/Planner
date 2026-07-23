using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class PlanningVersionTask
    {
        public int Id { get; set; }

        public int PlanningVersionId { get; set; }
        public PlanningVersion? PlanningVersion { get; set; }

        /// <summary>
        /// Identifiant de la tâche au moment de la création de la version.
        /// Ce n'est volontairement pas une clé étrangère vers PlannerTask.
        /// </summary>
        public int OriginalTaskId { get; set; }

        [Required]
        [StringLength(100)]
        public string Title { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        // Planning
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public int? Duration { get; set; }

        // Avancement
        public int ProgressPercent { get; set; }
        public bool IsDone { get; set; }
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
        public bool IsCritical { get; set; }

        // Deadline / retard
        public DateTime? Deadline { get; set; }
        public int DelayDays { get; set; }
        public bool IsLate { get; set; }
    }
}