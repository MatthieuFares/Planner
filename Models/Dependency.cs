namespace PlannerAPI.Models;

public class Dependency
{
    public int Id { get; set; }

    public int PredecessorId { get; set; }
    public TaskItem? Predecessor { get; set; }

    public int SuccessorId { get; set; }
    public TaskItem? Successor { get; set; }

    public string Type { get; set; } = string.Empty; // FS / SS / FF / SF
    public int Lag { get; set; }
}