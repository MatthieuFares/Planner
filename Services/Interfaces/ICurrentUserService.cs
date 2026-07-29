namespace PlannerAPI.Services.Interfaces
{
    public interface ICurrentUserService
    {
        bool IsAuthenticated { get; }

        string UserId { get; }

        bool IsGlobalAdmin { get; }
    }
}