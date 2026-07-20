using System.Threading.Tasks;

namespace PlannerAPI.Services.Interfaces
{
    public interface ITaskSchedulingService
    {
        Task RecalculateTaskDatesAsync(int taskId);

        Task RecalculateProjectAsync(int projectId);
    }
}