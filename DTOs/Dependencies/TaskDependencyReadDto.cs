using PlannerAPI.Models;

namespace PlannerAPI.DTOs.Dependencies
{
    public class TaskDependencyReadDto
    {
        public int Id { get; set; }
        public int PredecessorId { get; set; }
        public int SuccessorId { get; set; }
        public string Type { get; set; } = string.Empty;
        public int OffsetDays { get; set; }
    }
}