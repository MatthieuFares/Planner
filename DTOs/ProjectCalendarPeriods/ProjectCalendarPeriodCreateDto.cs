using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.ProjectCalendarPeriods
{
    public class ProjectCalendarPeriodCreateDto : IValidatableObject
    {
        [Required]
        public DateTime StartDate { get; set; }

        [Required]
        public DateTime EndDate { get; set; }

        [MaxLength(150)]
        public string Label { get; set; } = string.Empty;

        public IEnumerable<ValidationResult> Validate(
            ValidationContext validationContext)
        {
            if (EndDate.Date < StartDate.Date)
            {
                yield return new ValidationResult(
                    "La date de fin ne peut pas être antérieure à la date de début.",
                    new[]
                    {
                        nameof(StartDate),
                        nameof(EndDate)
                    }
                );
            }
        }
    }
}