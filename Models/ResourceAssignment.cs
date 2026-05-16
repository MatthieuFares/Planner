namespace PlannerAPI.Models
{
    public class ResourceAssignment
    {
        public int Id { get; set; }

        public int TaskId { get; set; }
        public PlannerTask? Task { get; set; }

        public int ResourceId { get; set; }
        public Resource? Resource { get; set; }

        public decimal WorkloadHours { get; set; }
        public decimal? AllocationPercent { get; set; }
    }
}