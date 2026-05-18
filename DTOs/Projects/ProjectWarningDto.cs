namespace PlannerAPI.DTOs.Projects
{
    public class ProjectWarningDto
    {
        public string Type { get; set; } = string.Empty;
        public string Severity { get; set; } = "Info";
        public string Message { get; set; } = string.Empty;

        public int? TaskId { get; set; }
        public string? TaskTitle { get; set; }

        public int? ResourceId { get; set; }
        public string? ResourceName { get; set; }
    }
}