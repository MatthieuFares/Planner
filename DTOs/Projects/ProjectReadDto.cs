namespace PlannerAPI.DTOs.Projects
{
    public class ProjectReadDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
    }
}