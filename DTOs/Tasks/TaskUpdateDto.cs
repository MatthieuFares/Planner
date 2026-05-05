using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.Tasks
{
public class TaskUpdateDto
{
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsDone { get; set; }
    public int ProjectId { get; set; }

    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public int? Duration { get; set; }

    public int? ActualDuration { get; set; }
    public int? AssignedResourcesCount { get; set; }
    public decimal? WorkloadHours { get; set; }
}
}