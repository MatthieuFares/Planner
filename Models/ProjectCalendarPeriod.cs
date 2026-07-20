namespace PlannerAPI.Models
{
    public class ProjectCalendarPeriod
    {
        public int Id { get; set; }

        public int ProjectCalendarId { get; set; }
        public ProjectCalendar? ProjectCalendar { get; set; }

        public DateTime StartDate { get; set; }

        public DateTime EndDate { get; set; }

        public string Label { get; set; } = string.Empty;
    }
}