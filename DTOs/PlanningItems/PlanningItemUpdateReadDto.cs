namespace PlannerAPI.DTOs.PlanningItems
{
    public class PlanningItemReadDto
    {
        public int Id { get; set; }

        public int ProjectId { get; set; }

        public int? ParentId { get; set; }

        public string Name { get; set; } = string.Empty;

        public string Type { get; set; } = string.Empty;

        public int SortOrder { get; set; }

        public string WbsCode { get; set; } = string.Empty;

        public int Level { get; set; }

        public int? TaskId { get; set; }

        public string? TaskTitle { get; set; }

        public DateTime? TaskStartDate { get; set; }

        public DateTime? TaskEndDate { get; set; }

        public int? TaskDuration { get; set; }

        public int? TaskProgressPercent { get; set; }

        public bool? TaskIsDone { get; set; }

        public bool? TaskIsCritical { get; set; }

        public int? TaskTotalFloat { get; set; }
    }
}