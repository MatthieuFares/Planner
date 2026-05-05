namespace PlannerAPI.Models
{
    public class TaskDependency
    {
        public int Id { get; set; }

        public int PredecessorId { get; set; }
        public PlannerTask? Predecessor { get; set; }

        public int SuccessorId { get; set; }
        public PlannerTask? Successor { get; set; }

        public string Type { get; set; } = "FS";

        public int OffsetDays { get; set; } = 0;
    }
}