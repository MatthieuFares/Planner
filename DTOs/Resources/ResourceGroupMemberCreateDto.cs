using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.Resources
{
    public class ResourceGroupMemberCreateDto
    {
        [Required]
        public int ResourceGroupId { get; set; }

        [Required]
        public int ResourceId { get; set; }
    }
}