namespace PlannerAPI.Models
{
    public class ProjectBaseline
    {
        public int Id { get; set; }

        public int ProjectId { get; set; }
        public Project? Project { get; set; }

        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public bool IsActive { get; set; } = false;

        public List<ProjectBaselineTask> Tasks { get; set; } = new();
    }
}