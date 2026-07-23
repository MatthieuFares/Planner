using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class PlanningVersionDependency
    {
        public int Id { get; set; }

        public int PlanningVersionId { get; set; }
        public PlanningVersion? PlanningVersion { get; set; }

        /// <summary>
        /// Identifiant de la dépendance au moment
        /// de la création de la version.
        /// </summary>
        public int OriginalDependencyId { get; set; }

        /// <summary>
        /// Identifiant d'origine de la tâche prédécesseur.
        /// </summary>
        public int OriginalPredecessorTaskId { get; set; }

        /// <summary>
        /// Identifiant d'origine de la tâche successeur.
        /// </summary>
        public int OriginalSuccessorTaskId { get; set; }

        /// <summary>
        /// Type de dépendance : FS, SS, FF ou SF.
        /// Conservé en string pour rester compatible
        /// avec l'entité TaskDependency actuelle.
        /// </summary>
        [Required]
        [StringLength(2)]
        public string Type { get; set; } = "FS";

        public int OffsetDays { get; set; }
    }
}