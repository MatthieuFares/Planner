namespace PlannerAPI.Models
{
    public class ResourceGroupMember
    {
        public int Id { get; set; }

        public int ResourceGroupId { get; set; }
        public ResourceGroup? ResourceGroup { get; set; }

        public int ResourceId { get; set; }
        public Resource? Resource { get; set; }
    }
}