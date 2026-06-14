using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.PlanningItems
{
    public class PlanningItemUpdateDto
    {
        public int? ParentId { get; set; }

        [Required]
        [StringLength(150)]
        public string Name { get; set; } = string.Empty;

        [Required]
        public string Type { get; set; } = "Task";

        public int SortOrder { get; set; } = 0;

        public int? TaskId { get; set; }
    }
}