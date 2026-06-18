using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.ProjectCalendarExceptions
{
    public class ProjectCalendarExceptionCreateDto
    {
        [Required]
        public DateTime Date { get; set; }

        [MaxLength(150)]
        public string Label { get; set; } = string.Empty;

        public bool IsWorkingDay { get; set; }
    }
}