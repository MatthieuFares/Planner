namespace PlannerAPI.Models
{
    public class PlanningVersionCalendar
    {
        public int Id { get; set; }

        public int PlanningVersionId { get; set; }
        public PlanningVersion? PlanningVersion { get; set; }

        public bool WorkMonday { get; set; } = true;
        public bool WorkTuesday { get; set; } = true;
        public bool WorkWednesday { get; set; } = true;
        public bool WorkThursday { get; set; } = true;
        public bool WorkFriday { get; set; } = true;
        public bool WorkSaturday { get; set; }
        public bool WorkSunday { get; set; }

        public List<PlanningVersionCalendarException> Exceptions { get; set; }
            = new();

        public List<PlanningVersionCalendarPeriod> Periods { get; set; }
            = new();
    }
}