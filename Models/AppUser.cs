using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Identity;

namespace PlannerAPI.Models
{
    public class AppUser : IdentityUser
    {
        [StringLength(120)]
        public string? DisplayName { get; set; }

        public bool IsActive { get; set; } = true;

        // Permission globale : autorise la création de nouveaux projets.
        public bool CanCreateProjects { get; set; } = false;

        // Permission globale : autorise la création, modification et
        // suppression du catalogue partagé de ressources et de groupes.
        public bool CanManageResources { get; set; } = false;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}