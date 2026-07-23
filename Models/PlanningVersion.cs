using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class PlanningVersion
    {
        public int Id { get; set; }

        public int ProjectId { get; set; }
        public Project? Project { get; set; }

        /// <summary>
        /// Numéro chronologique de la version dans le projet.
        /// Exemple : 1, 2, 3...
        /// </summary>
        public int VersionNumber { get; set; }

        [Required]
        [StringLength(150)]
        public string Name { get; set; } = string.Empty;

        [StringLength(1000)]
        public string? Description { get; set; }

        /// <summary>
        /// Auteur textuel en attendant l’intégration
        /// complète de l’authentification.
        /// </summary>
        [StringLength(150)]
        public string? CreatedBy { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public List<PlanningVersionTask> Tasks { get; set; } = new();

        public List<PlanningVersionItem> Items { get; set; } = new();

        public List<PlanningVersionDependency> Dependencies { get; set; }
            = new();

        public List<PlanningVersionAssignment> Assignments { get; set; }
            = new();

        public PlanningVersionCalendar? Calendar { get; set; }
    }
}