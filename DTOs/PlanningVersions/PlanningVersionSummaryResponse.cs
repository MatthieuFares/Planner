namespace PlannerAPI.DTOs.PlanningVersions
{
    public class PlanningVersionSummaryResponse
    {
        public int Id { get; set; }

        public int ProjectId { get; set; }

        public int VersionNumber { get; set; }

        public string Name { get; set; } = string.Empty;

        public string? Description { get; set; }

        public string? CreatedBy { get; set; }

        public DateTime CreatedAt { get; set; }

        public int TaskCount { get; set; }

        public int ItemCount { get; set; }

        public int DependencyCount { get; set; }

        public int AssignmentCount { get; set; }

        public bool HasCalendar { get; set; }
    }
}