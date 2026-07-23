using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class PlanningVersionAssignment
    {
        public int Id { get; set; }

        public int PlanningVersionId { get; set; }
        public PlanningVersion? PlanningVersion { get; set; }

        /// <summary>
        /// Identifiant de l'assignation au moment
        /// de la création de la version.
        /// </summary>
        public int OriginalAssignmentId { get; set; }

        /// <summary>
        /// Identifiant d'origine de la tâche assignée.
        /// </summary>
        public int OriginalTaskId { get; set; }

        /// <summary>
        /// Identifiant d'origine de la ressource individuelle.
        /// Null lorsqu'il s'agit d'une assignation de groupe.
        /// Ce champ n'est pas une clé étrangère.
        /// </summary>
        public int? OriginalResourceId { get; set; }

        /// <summary>
        /// Nom figé de la ressource pour que la version
        /// reste lisible même si la ressource est supprimée.
        /// </summary>
        [StringLength(150)]
        public string? ResourceName { get; set; }

        /// <summary>
        /// Identifiant d'origine du groupe de ressources.
        /// Null lorsqu'il s'agit d'une assignation individuelle.
        /// Ce champ n'est pas une clé étrangère.
        /// </summary>
        public int? OriginalResourceGroupId { get; set; }

        /// <summary>
        /// Nom figé du groupe pour conserver
        /// une version historiquement lisible.
        /// </summary>
        [StringLength(150)]
        public string? ResourceGroupName { get; set; }

        public decimal WorkloadHours { get; set; }

        public int AllocationPercent { get; set; }
    }
}