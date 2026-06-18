namespace PlannerAPI.DTOs.ProjectCalendars
{
    public class ProjectCalendarUpdateDto
    {
        public bool WorkMonday { get; set; }
        public bool WorkTuesday { get; set; }
        public bool WorkWednesday { get; set; }
        public bool WorkThursday { get; set; }
        public bool WorkFriday { get; set; }
        public bool WorkSaturday { get; set; }
        public bool WorkSunday { get; set; }
    }
}