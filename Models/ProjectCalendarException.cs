namespace PlannerAPI.Models
{
    public class ProjectCalendarException
    {
        public int Id { get; set; }

        public int ProjectCalendarId { get; set; }
        public ProjectCalendar? ProjectCalendar { get; set; }

        public DateTime Date { get; set; }

        public string Label { get; set; } = string.Empty;

        public bool IsWorkingDay { get; set; }
    }
}