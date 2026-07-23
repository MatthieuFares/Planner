using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class PlanningVersionCalendarException
    {
        public int Id { get; set; }

        public int PlanningVersionCalendarId { get; set; }
        public PlanningVersionCalendar? PlanningVersionCalendar { get; set; }

        public DateTime Date { get; set; }

        [Required]
        [StringLength(150)]
        public string Label { get; set; } = string.Empty;

        public bool IsWorkingDay { get; set; }
    }
}