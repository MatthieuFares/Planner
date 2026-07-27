using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.Tasks;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class TaskService : ITaskService
    {
        private readonly AppDbContext _context;
        private readonly ITaskSchedulingService _taskSchedulingService;

        public TaskService(
            AppDbContext context,
            ITaskSchedulingService taskSchedulingService)
        {
            _context = context;
            _taskSchedulingService = taskSchedulingService;
        }

        public async Task<IEnumerable<TaskReadDto>> GetAllAsync()
        {
            var tasks = await _context.Tasks
                .OrderBy(t => t.StartDate)
                .ThenBy(t => t.Id)
                .ToListAsync();

            return tasks.Select(MapToReadDto);
        }

        public async Task<TaskReadDto?> GetByIdAsync(int id)
        {
            var task = await _context.Tasks.FindAsync(id);

            if (task == null)
                return null;

            return MapToReadDto(task);
        }

        public async Task<IEnumerable<TaskReadDto>> GetByProjectIdAsync(int projectId)
        {
            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
                return Enumerable.Empty<TaskReadDto>();

            var tasks = await _context.Tasks
                .Where(t => t.ProjectId == projectId)
                .OrderBy(t => t.StartDate)
                .ThenBy(t => t.Id)
                .ToListAsync();

            return tasks.Select(MapToReadDto);
        }

        public async Task<TaskReadDto?> CreateTaskAsync(TaskCreateDto dto)
        {
            var projectExists = await _context.Projects
                .AnyAsync(p => p.Id == dto.ProjectId);

            if (!projectExists)
                return null;

            var progress = NormalizeProgress(dto.ProgressPercent);

            var taskItem = new PlannerTask
            {
                Title = dto.Title,
                Description = dto.Description,
                ProjectId = dto.ProjectId,

                StartDate = dto.StartDate,
                EndDate = dto.EndDate,
                Duration = dto.Duration,

                ActualDuration = dto.ActualDuration,
                AssignedResourcesCount = dto.AssignedResourcesCount,
                WorkloadHours = dto.WorkloadHours,

                ProgressPercent = progress,
                IsDone = progress >= 100,
                Deadline = dto.Deadline,
            };

            _context.Tasks.Add(taskItem);

            await _context.SaveChangesAsync();

            await _taskSchedulingService.RecalculateTaskDatesAsync(taskItem.Id);

            var refreshedTask = await _context.Tasks.FindAsync(taskItem.Id);

            return refreshedTask == null
                ? null
                : MapToReadDto(refreshedTask);
        }

        public async Task<TaskReadDto?> UpdateTaskAsync(int id, TaskUpdateDto dto)
        {
            var taskItem = await _context.Tasks.FindAsync(id);

            if (taskItem == null)
                return null;

            if (dto.ProjectId != taskItem.ProjectId)
                throw new InvalidOperationException(
                    "Le changement de projet d'une tâche existante n'est pas autorisé.");

            var progress = NormalizeProgress(dto.ProgressPercent);

            taskItem.Title = dto.Title;
            taskItem.Description = dto.Description;

            taskItem.StartDate = dto.StartDate;
            taskItem.EndDate = dto.EndDate;
            taskItem.Duration = dto.Duration;

            taskItem.ActualDuration = dto.ActualDuration;
            taskItem.AssignedResourcesCount = dto.AssignedResourcesCount;
            taskItem.WorkloadHours = dto.WorkloadHours;

            taskItem.ProgressPercent = progress;
            taskItem.IsDone = progress >= 100;
            taskItem.Deadline = dto.Deadline;

            // Un élément de planning lié à une tâche doit toujours
            // afficher le même nom que la tâche.
            var linkedPlanningItems = await _context.PlanningItems
                .Where(i => i.TaskId == id)
                .ToListAsync();

            foreach (var planningItem in linkedPlanningItems)
            {
                planningItem.Name = dto.Title;
            }

            await _context.SaveChangesAsync();

            await _taskSchedulingService.RecalculateTaskDatesAsync(taskItem.Id);

            var refreshedTask = await _context.Tasks.FindAsync(taskItem.Id);

            return refreshedTask == null
                ? null
                : MapToReadDto(refreshedTask);
        }

        public async Task<bool> DeleteTaskAsync(int id)
        {
            var taskItem = await _context.Tasks.FindAsync(id);

            if (taskItem == null)
                return false;

            var hasDependencies = await _context.TaskDependencies
                .AnyAsync(d => d.PredecessorId == id || d.SuccessorId == id);

            if (hasDependencies)
                throw new InvalidOperationException(
                    "Impossible de supprimer cette tâche car elle est utilisée dans une ou plusieurs dépendances.");

            var hasAssignments = await _context.ResourceAssignments
                .AnyAsync(a => a.TaskId == id);

            if (hasAssignments)
                throw new InvalidOperationException(
                    "Impossible de supprimer cette tâche car elle possède une ou plusieurs assignations de ressources.");

            var projectId = taskItem.ProjectId;

            var linkedPlanningItems = await _context.PlanningItems
                .Where(i => i.TaskId == id)
                .ToListAsync();

            if (linkedPlanningItems.Any())
            {
                _context.PlanningItems.RemoveRange(linkedPlanningItems);
            }

            _context.Tasks.Remove(taskItem);

            await _context.SaveChangesAsync();

            await RecalculateProjectWbsCodesAsync(projectId);

            return true;
        }

        private async Task RecalculateProjectWbsCodesAsync(int projectId)
        {
            var items = await _context.PlanningItems
                .Where(i => i.ProjectId == projectId)
                .ToListAsync();

            ApplyWbsCodes(items, parentId: null, prefix: string.Empty);

            await _context.SaveChangesAsync();
        }

        private static void ApplyWbsCodes(
            List<PlanningItem> items,
            int? parentId,
            string prefix)
        {
            var children = items
                .Where(i => i.ParentId == parentId)
                .OrderBy(i => i.SortOrder)
                .ThenBy(i => i.Id)
                .ToList();

            for (var index = 0; index < children.Count; index++)
            {
                var child = children[index];

                child.WbsCode = string.IsNullOrWhiteSpace(prefix)
                    ? $"{index + 1}"
                    : $"{prefix}.{index + 1}";

                ApplyWbsCodes(items, child.Id, child.WbsCode);
            }
        }

        private static int NormalizeProgress(int progressPercent)
        {
            return Math.Clamp(progressPercent, 0, 100);
        }

        private static TaskReadDto MapToReadDto(PlannerTask task)
        {
            return new TaskReadDto
            {
                Id = task.Id,
                Title = task.Title,
                Description = task.Description,
                IsDone = task.IsDone,
                ProjectId = task.ProjectId,

                StartDate = task.StartDate,
                EndDate = task.EndDate,
                Duration = task.Duration,

                ActualDuration = task.ActualDuration,
                AssignedResourcesCount = task.AssignedResourcesCount,
                WorkloadHours = task.WorkloadHours,

                IsCritical = task.IsCritical,
                EarlyStart = task.EarlyStart,
                EarlyFinish = task.EarlyFinish,
                LateStart = task.LateStart,
                LateFinish = task.LateFinish,
                TotalFloat = task.TotalFloat,

                ProgressPercent = task.ProgressPercent,
                Deadline = task.Deadline,
                DelayDays = task.DelayDays,
                IsLate = task.IsLate,
            };
        }
    }
}