namespace PlannerAPI.DTOs.Tasks
{
    public class TaskReadDto
    {
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string? Description { get; set; }
        public bool IsDone { get; set; }
        public int ProjectId { get; set; }
    }
}