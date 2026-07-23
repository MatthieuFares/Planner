using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.PlanningVersions
{
    public class RestorePlanningVersionRequest
    {
        /// <summary>
        /// Doit être explicitement positionné à true afin
        /// d'éviter une restauration destructive involontaire.
        /// </summary>
        public bool ConfirmRestore { get; set; }

        /// <summary>
        /// Crée une version de sécurité du planning courant
        /// avant de lancer la restauration.
        /// </summary>
        public bool CreateSafetyVersion { get; set; } = true;

        [StringLength(150)]
        public string? SafetyVersionName { get; set; }

        [StringLength(150)]
        public string? RestoredBy { get; set; }
    }

    public class RestorePlanningVersionResponse
    {
        public int VersionId { get; set; }

        public int ProjectId { get; set; }

        public int VersionNumber { get; set; }

        public string VersionName { get; set; } = string.Empty;

        public DateTime RestoredAt { get; set; }

        public string? RestoredBy { get; set; }

        /// <summary>
        /// Identifiant de la sauvegarde automatique créée
        /// avant la restauration, lorsqu'elle a été demandée.
        /// </summary>
        public int? SafetyVersionId { get; set; }

        public int UpdatedTaskCount { get; set; }

        public int CreatedTaskCount { get; set; }

        public int DeletedTaskCount { get; set; }

        public int RestoredItemCount { get; set; }

        public int RestoredDependencyCount { get; set; }

        public int RestoredAssignmentCount { get; set; }

        public bool CalendarRestored { get; set; }

        public List<PlanningVersionRestoreTaskMappingResponse>
            TaskMappings { get; set; } = new();

        public List<string> Warnings { get; set; } = new();
    }

    public class PlanningVersionRestoreTaskMappingResponse
    {
        public int OriginalTaskId { get; set; }

        public int RestoredTaskId { get; set; }

        /// <summary>
        /// True lorsque la tâche existante a conservé son identifiant.
        /// False lorsqu'une tâche supprimée a dû être recréée
        /// avec un nouvel identifiant.
        /// </summary>
        public bool ReusedExistingId { get; set; }
    }
}