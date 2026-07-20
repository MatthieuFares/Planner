namespace PlannerAPI.DTOs.ProjectCalendarPeriods
{
    public class ProjectCalendarPeriodReadDto
    {
        public int Id { get; set; }

        public int ProjectCalendarId { get; set; }

        public DateTime StartDate { get; set; }

        public DateTime EndDate { get; set; }

        public string Label { get; set; } = string.Empty;
    }
}