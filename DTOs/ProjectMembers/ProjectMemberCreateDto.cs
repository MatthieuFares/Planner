using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.DTOs.ProjectMembers
{
    public class ProjectMemberCreateDto
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;

        [Required]
        public string Role { get; set; } = string.Empty;
    }
}
