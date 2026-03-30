namespace PlannerAPI.Models
{
    public enum DependencyType
    {
        FinishToStart, // FS
        StartToStart,  // SS
        FinishToFinish,// FF
        StartToFinish  // SF
    }
}