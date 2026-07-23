namespace PlannerAPI.DTOs.PlanningVersions
{
    public class PlanningVersionComparisonResponse
    {
        public int VersionId { get; set; }

        public int ProjectId { get; set; }

        public int VersionNumber { get; set; }

        public string VersionName { get; set; } = string.Empty;

        public DateTime VersionCreatedAt { get; set; }

        public DateTime ComparedAt { get; set; }

        public PlanningVersionComparisonSummary Summary { get; set; }
            = new();

        public List<PlanningVersionTaskComparisonResponse> Tasks
        {
            get;
            set;
        } = new();

        /// <summary>
        /// Indique si la structure hiérarchique du Gantt
        /// diffère de celle enregistrée dans la version.
        /// </summary>
        public bool StructureChanged { get; set; }

        /// <summary>
        /// Indique si les dépendances diffèrent de celles
        /// enregistrées dans la version.
        /// </summary>
        public bool DependenciesChanged { get; set; }

        /// <summary>
        /// Indique si les assignations diffèrent de celles
        /// enregistrées dans la version.
        /// </summary>
        public bool AssignmentsChanged { get; set; }

        /// <summary>
        /// Indique si le calendrier courant diffère de celui
        /// enregistré dans la version.
        /// </summary>
        public bool CalendarChanged { get; set; }
    }

    public class PlanningVersionComparisonSummary
    {
        public int VersionTaskCount { get; set; }

        public int CurrentTaskCount { get; set; }

        public int AddedTaskCount { get; set; }

        public int RemovedTaskCount { get; set; }

        public int ModifiedTaskCount { get; set; }

        public int UnchangedTaskCount { get; set; }

        public int ChangedTaskCount =>
            AddedTaskCount +
            RemovedTaskCount +
            ModifiedTaskCount;
    }

    public class PlanningVersionTaskComparisonResponse
    {
        /// <summary>
        /// Identifiant de la tâche dans le planning d'origine.
        /// Pour une tâche ajoutée après la version, cet identifiant
        /// correspond à l'identifiant courant.
        /// </summary>
        public int TaskId { get; set; }

        /// <summary>
        /// Added, Removed, Modified ou Unchanged.
        /// </summary>
        public string Status { get; set; } = string.Empty;

        public string Title { get; set; } = string.Empty;

        /// <summary>
        /// Liste des propriétés ayant changé.
        /// Exemple : StartDate, EndDate, Duration.
        /// </summary>
        public List<string> ChangedFields { get; set; } = new();

        public PlanningVersionTaskStateResponse? VersionState
        {
            get;
            set;
        }

        public PlanningVersionTaskStateResponse? CurrentState
        {
            get;
            set;
        }
    }

    public class PlanningVersionTaskStateResponse
    {
        public int TaskId { get; set; }

        public string Title { get; set; } = string.Empty;

        public string? Description { get; set; }

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        public int? Duration { get; set; }

        public int ProgressPercent { get; set; }

        public bool IsDone { get; set; }

        public int? ActualDuration { get; set; }

        public int? AssignedResourcesCount { get; set; }

        public decimal? WorkloadHours { get; set; }

        public DateTime? EarlyStart { get; set; }

        public DateTime? EarlyFinish { get; set; }

        public DateTime? LateStart { get; set; }

        public DateTime? LateFinish { get; set; }

        public int? TotalFloat { get; set; }

        public bool IsCritical { get; set; }

        public DateTime? Deadline { get; set; }

        public int DelayDays { get; set; }

        public bool IsLate { get; set; }
    }
}