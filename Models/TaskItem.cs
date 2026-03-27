namespace PlannerAPI.Models;

public class TaskItem
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }

    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public int Duration { get; set; }

    public int ProjectId { get; set; }
    public Project? Project { get; set; }

    public List<Dependency> Predecessors { get; set; } = new();
    public List<Dependency> Successors { get; set; } = new();
}