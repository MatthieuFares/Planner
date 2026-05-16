using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class ResourceGroup
    {
        public int Id { get; set; }

        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        public List<ResourceGroupMember> Members { get; set; } = new();
    }
}