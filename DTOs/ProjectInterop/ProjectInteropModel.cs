namespace PlannerAPI.DTOs.ProjectInterop
{
    /// <summary>
    /// Modèle pivot commun aux imports et exports Microsoft Project XML / MSPDI.
    /// Il ne contient aucun identifiant SQL Planner : les UID sont propres au fichier XML.
    /// </summary>
    public class ProjectInteropModel
    {
        public ProjectInteropProject Project { get; set; } = new();

        public ProjectInteropCalendar Calendar { get; set; } = new();

        public List<ProjectInteropTask> Tasks { get; set; } = new();

        public List<ProjectInteropDependency> Dependencies { get; set; } = new();

        public List<ProjectInteropResource> Resources { get; set; } = new();

        public List<ProjectInteropAssignment> Assignments { get; set; } = new();

        public List<ProjectInteropWarning> Warnings { get; set; } = new();
    }

    public class ProjectInteropProject
    {
        public string Name { get; set; } = string.Empty;

        public string? Description { get; set; }

        public string? ClientName { get; set; }

        public string? ProjectCode { get; set; }

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        /// <summary>
        /// Nombre d'heures considéré pour une journée standard.
        /// Utilisé pour convertir les durées/travaux MSPDI vers les jours/heures Planner.
        /// </summary>
        public decimal HoursPerDay { get; set; } = 8m;

        public decimal HoursPerWeek { get; set; } = 40m;

        public int DaysPerMonth { get; set; } = 20;
    }

    public class ProjectInteropTask
    {
        /// <summary>
        /// UID du fichier MSPDI. N'est jamais persisté comme ID Planner.
        /// </summary>
        public int ExternalUid { get; set; }

        public int? ExternalId { get; set; }

        public string Name { get; set; } = string.Empty;

        public string? Description { get; set; }

        public string? OutlineNumber { get; set; }

        public int OutlineLevel { get; set; }

        public bool IsSummary { get; set; }

        public bool IsMilestone { get; set; }

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        /// <summary>
        /// Durée normalisée en jours ouvrés Planner.
        /// </summary>
        public int DurationDays { get; set; } = 1;

        public int ProgressPercent { get; set; }

        public int? ActualDurationDays { get; set; }

        public decimal? WorkloadHours { get; set; }

        public DateTime? Deadline { get; set; }

        /// <summary>
        /// UID du calendrier MSPDI affecté à la tâche, lorsqu'il existe.
        /// Planner MVP utilise le calendrier projet comme source de vérité.
        /// </summary>
        public int? CalendarUid { get; set; }
    }

    public class ProjectInteropDependency
    {
        public int PredecessorTaskUid { get; set; }

        public int SuccessorTaskUid { get; set; }

        /// <summary>
        /// FS, SS, FF ou SF.
        /// </summary>
        public string Type { get; set; } = "FS";

        /// <summary>
        /// Offset normalisé en jours Planner. Peut être négatif.
        /// </summary>
        public int OffsetDays { get; set; }

        public bool IsCrossProject { get; set; }

        public string? CrossProjectName { get; set; }
    }

    public class ProjectInteropResource
    {
        public int ExternalUid { get; set; }

        public int? ExternalId { get; set; }

        public string Name { get; set; } = string.Empty;

        /// <summary>
        /// Person, Material ou Team dans Planner.
        /// </summary>
        public string Type { get; set; } = "Person";

        public decimal? CapacityHoursPerWeek { get; set; }

        public decimal? CostPerHour { get; set; }

        public string? Email { get; set; }

        public bool IsGeneric { get; set; }
    }

    public class ProjectInteropAssignment
    {
        public int ExternalUid { get; set; }

        public int TaskUid { get; set; }

        public int ResourceUid { get; set; }

        public decimal WorkloadHours { get; set; }

        public int AllocationPercent { get; set; } = 100;

        public int? ProgressPercent { get; set; }
    }

    public class ProjectInteropCalendar
    {
        public int? ExternalUid { get; set; }

        public string? Name { get; set; }

        public bool WorkMonday { get; set; } = true;
        public bool WorkTuesday { get; set; } = true;
        public bool WorkWednesday { get; set; } = true;
        public bool WorkThursday { get; set; } = true;
        public bool WorkFriday { get; set; } = true;
        public bool WorkSaturday { get; set; }
        public bool WorkSunday { get; set; }

        public List<ProjectInteropCalendarException> Exceptions { get; set; } = new();

        public List<ProjectInteropCalendarPeriod> Periods { get; set; } = new();
    }

    public class ProjectInteropCalendarException
    {
        public DateTime Date { get; set; }

        public string Label { get; set; } = string.Empty;

        public bool IsWorkingDay { get; set; }
    }

    public class ProjectInteropCalendarPeriod
    {
        public DateTime StartDate { get; set; }

        public DateTime EndDate { get; set; }

        public string Label { get; set; } = string.Empty;
    }

    public class ProjectInteropWarning
    {
        public string Code { get; set; } = string.Empty;

        public string Message { get; set; } = string.Empty;

        public string Severity { get; set; } = "Warning";

        public string? EntityType { get; set; }

        public string? EntityName { get; set; }

        public int? ExternalUid { get; set; }
    }
}