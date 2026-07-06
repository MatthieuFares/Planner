namespace PlannerAPI.DTOs.ProjectBaselines
{
    public class ProjectBaselineReadDto
    {
        public int Id { get; set; }

        public int ProjectId { get; set; }

        public string Name { get; set; } = string.Empty;

        public string? Description { get; set; }

        public DateTime CreatedAt { get; set; }

        public bool IsActive { get; set; }

        public int TaskCount { get; set; }
    }
}