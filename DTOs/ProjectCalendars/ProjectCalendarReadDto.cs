namespace PlannerAPI.DTOs.ProjectCalendars
{
    public class ProjectCalendarReadDto
    {
        public int Id { get; set; }
        public int ProjectId { get; set; }

        public bool WorkMonday { get; set; }
        public bool WorkTuesday { get; set; }
        public bool WorkWednesday { get; set; }
        public bool WorkThursday { get; set; }
        public bool WorkFriday { get; set; }
        public bool WorkSaturday { get; set; }
        public bool WorkSunday { get; set; }
    }
}