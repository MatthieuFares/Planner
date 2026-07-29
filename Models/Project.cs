using System.ComponentModel.DataAnnotations;

namespace PlannerAPI.Models
{
    public class Project
    {
        public int Id { get; set; }

        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        [StringLength(100)]
        public string? ClientName { get; set; }

        [StringLength(50)]
        public string? ProjectCode { get; set; }

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        // Nullable pendant la transition afin de conserver les projets
        // existants créés avant l'ajout de l'authentification.
        public string? OwnerUserId { get; set; }

        public AppUser? Owner { get; set; }

        public List<ProjectMember> Members { get; set; } = new();

        public List<PlannerTask> Tasks { get; set; } = new();

        public ProjectCalendar? Calendar { get; set; }

        public List<ProjectBaseline> Baselines { get; set; } = new();
    }
}