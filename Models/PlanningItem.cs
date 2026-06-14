using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class PlanningItem
    {
        public int Id { get; set; }

        public int ProjectId { get; set; }
        public Project? Project { get; set; }

        public int? ParentId { get; set; }
        public PlanningItem? Parent { get; set; }

        public List<PlanningItem> Children { get; set; } = new();

        [Required]
        [StringLength(150)]
        public string Name { get; set; } = string.Empty;

        public PlanningItemType Type { get; set; }

        public int SortOrder { get; set; }

        [StringLength(50)]
        public string WbsCode { get; set; } = string.Empty;

        public int? TaskId { get; set; }
        public PlannerTask? Task { get; set; }
    }
}