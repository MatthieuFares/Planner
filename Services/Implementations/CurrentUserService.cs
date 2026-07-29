using System.Security.Claims;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class CurrentUserService : ICurrentUserService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public CurrentUserService(IHttpContextAccessor httpContextAccessor)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        private ClaimsPrincipal? User =>
            _httpContextAccessor.HttpContext?.User;

        public bool IsAuthenticated =>
            User?.Identity?.IsAuthenticated == true;

        public string UserId =>
            User?.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new InvalidOperationException(
                "Aucun utilisateur authentifié n'est disponible dans le contexte courant.");

        public bool IsGlobalAdmin =>
            User?.IsInRole("Admin") == true;
    }
}
