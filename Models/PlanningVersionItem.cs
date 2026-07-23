using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class PlanningVersionItem
    {
        public int Id { get; set; }

        public int PlanningVersionId { get; set; }
        public PlanningVersion? PlanningVersion { get; set; }

        /// <summary>
        /// Identifiant de l'élément de planning au moment
        /// de la création de la version.
        /// </summary>
        public int OriginalPlanningItemId { get; set; }

        /// <summary>
        /// Identifiant d'origine du parent.
        /// Null pour un élément situé à la racine.
        /// </summary>
        public int? OriginalParentId { get; set; }

        [Required]
        [StringLength(150)]
        public string Name { get; set; } = string.Empty;

        public PlanningItemType Type { get; set; }

        public int SortOrder { get; set; }

        [StringLength(50)]
        public string WbsCode { get; set; } = string.Empty;

        /// <summary>
        /// Identifiant de la tâche liée au moment
        /// de la création de la version.
        /// Null pour les éléments structurants.
        /// </summary>
        public int? OriginalTaskId { get; set; }
    }
}