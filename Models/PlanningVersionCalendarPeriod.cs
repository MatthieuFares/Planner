using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class PlanningVersionCalendarPeriod
    {
        public int Id { get; set; }

        public int PlanningVersionCalendarId { get; set; }

        public PlanningVersionCalendar? PlanningVersionCalendar
        {
            get;
            set;
        }

        public DateTime StartDate { get; set; }

        public DateTime EndDate { get; set; }

        [Required]
        [StringLength(150)]
        public string Label { get; set; } = string.Empty;
    }
}