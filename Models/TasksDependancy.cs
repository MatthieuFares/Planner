namespace PlannerAPI.Models
{
    public class TaskDependency
    {
        public int Id { get; set; }

        public int PredecessorId { get; set; }
        public PlannerTask? Predecessor { get; set; }

        public int SuccessorId { get; set; }
        public PlannerTask? Successor { get; set; }

        public DependencyType Type { get; set; }
    }
}