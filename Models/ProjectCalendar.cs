namespace PlannerAPI.Models
{
    public class ProjectCalendar
    {
        public int Id { get; set; }

        public int ProjectId { get; set; }
        public Project? Project { get; set; }

        public bool WorkMonday { get; set; } = true;
        public bool WorkTuesday { get; set; } = true;
        public bool WorkWednesday { get; set; } = true;
        public bool WorkThursday { get; set; } = true;
        public bool WorkFriday { get; set; } = true;
        public bool WorkSaturday { get; set; } = false;
        public bool WorkSunday { get; set; } = false;

        public List<ProjectCalendarException> Exceptions { get; set; } = new();

        public List<ProjectCalendarPeriod> Periods { get; set; } = new();
    }
}