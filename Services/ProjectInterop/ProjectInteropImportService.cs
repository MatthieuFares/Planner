using System.Data;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.ProjectInterop;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.ProjectInterop
{
    public class ProjectInteropImportResult
    {
        public int ProjectId { get; set; }

        public string ProjectName { get; set; } = string.Empty;

        public int StructureItemCount { get; set; }

        public int TaskCount { get; set; }

        public int DependencyCount { get; set; }

        public int ResourceCount { get; set; }

        public int CreatedResourceCount { get; set; }

        public int ReusedResourceCount { get; set; }

        public int AssignmentCount { get; set; }

        public int CalendarExceptionCount { get; set; }

        public int CalendarPeriodCount { get; set; }

        public List<ProjectInteropWarning> Warnings { get; set; } = new();
    }

    /// <summary>
    /// Importe un ProjectInteropModel dans Planner.
    /// Toute l'opération est transactionnelle : en cas d'erreur,
    /// aucun demi-projet n'est conservé.
    /// </summary>
    public class ProjectInteropImportService
    {
        private readonly AppDbContext _context;
        private readonly ITaskSchedulingService _taskSchedulingService;
        private readonly ICurrentUserService _currentUserService;

        public ProjectInteropImportService(
            AppDbContext context,
            ITaskSchedulingService taskSchedulingService,
            ICurrentUserService currentUserService)
        {
            _context = context;
            _taskSchedulingService = taskSchedulingService;
            _currentUserService = currentUserService;
        }

        public async Task<ProjectInteropImportResult> ImportAsync(
            ProjectInteropModel model,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(model);

            var currentUserId = _currentUserService.UserId;

            if (string.IsNullOrWhiteSpace(currentUserId))
            {
                throw new InvalidOperationException(
                    "L'utilisateur authentifié est introuvable.");
            }

            var blockingErrors = model.Warnings
                .Where(w =>
                    string.Equals(
                        w.Severity,
                        "Error",
                        StringComparison.OrdinalIgnoreCase))
                .ToList();

            if (blockingErrors.Count > 0)
            {
                throw new InvalidOperationException(
                    "L'import est bloqué par une ou plusieurs erreurs détectées dans le fichier.");
            }

            var executableTasks = model.Tasks
                .Where(t => !t.IsSummary)
                .ToList();

            if (executableTasks.Count == 0)
            {
                throw new InvalidOperationException(
                    "Aucune tâche exécutable n'a été trouvée dans le fichier.");
            }

            if (HasDependencyCycle(model.Dependencies))
            {
                throw new InvalidOperationException(
                    "Le fichier contient un cycle de dépendances. "
                    + "Le projet n'a pas été importé.");
            }

            await using var transaction =
                await _context.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable,
                    cancellationToken);

            try
            {
                var currentUser = await _context.Users
                    .FirstOrDefaultAsync(
                        user =>
                            user.Id == currentUserId &&
                            user.IsActive,
                        cancellationToken);

                if (currentUser == null)
                {
                    throw new InvalidOperationException(
                        "L'utilisateur authentifié est introuvable "
                        + "ou désactivé.");
                }

                // L'importateur devient owner + Manager et conserve
                // durablement la permission de créer/importer.
                currentUser.CanCreateProjects = true;

                var result = new ProjectInteropImportResult
                {
                    Warnings = model.Warnings.ToList()
                };

                // =====================================================
                // 1. Projet
                // =====================================================

                var project = new Project
                {
                    Name = TrimTo(
                        model.Project.Name,
                        100,
                        fallback: "Projet importé"),
                    Description = TrimNullable(
                        model.Project.Description,
                        500),
                    ClientName = TrimNullable(
                        model.Project.ClientName,
                        100),
                    ProjectCode = TrimNullable(
                        model.Project.ProjectCode,
                        50),
                    OwnerUserId = currentUserId,
                    StartDate =
                        model.Project.StartDate
                        ?? executableTasks
                            .Where(t => t.StartDate.HasValue)
                            .Select(t => t.StartDate)
                            .Min(),
                    EndDate =
                        model.Project.EndDate
                        ?? executableTasks
                            .Where(t => t.EndDate.HasValue)
                            .Select(t => t.EndDate)
                            .Max()
                };

                _context.Projects.Add(project);
                await _context.SaveChangesAsync(cancellationToken);

                _context.ProjectMembers.Add(
                    new ProjectMember
                    {
                        ProjectId = project.Id,
                        UserId = currentUserId,
                        Role = ProjectRole.Manager,
                        CreatedAt = DateTime.UtcNow
                    });

                await _context.SaveChangesAsync(cancellationToken);

                // =====================================================
                // 2. Calendrier projet
                // =====================================================

                var calendar = new ProjectCalendar
                {
                    ProjectId = project.Id,
                    WorkMonday = model.Calendar.WorkMonday,
                    WorkTuesday = model.Calendar.WorkTuesday,
                    WorkWednesday = model.Calendar.WorkWednesday,
                    WorkThursday = model.Calendar.WorkThursday,
                    WorkFriday = model.Calendar.WorkFriday,
                    WorkSaturday = model.Calendar.WorkSaturday,
                    WorkSunday = model.Calendar.WorkSunday
                };

                _context.ProjectCalendars.Add(calendar);
                await _context.SaveChangesAsync(cancellationToken);

                var calendarExceptions = model.Calendar.Exceptions
                    .GroupBy(e => e.Date.Date)
                    .Select(g => g.Last())
                    .Select(e => new ProjectCalendarException
                    {
                        ProjectCalendarId = calendar.Id,
                        Date = e.Date.Date,
                        Label = TrimTo(
                            e.Label,
                            150,
                            fallback: "Exception importée"),
                        IsWorkingDay = e.IsWorkingDay
                    })
                    .ToList();

                if (calendarExceptions.Count > 0)
                {
                    _context.ProjectCalendarExceptions.AddRange(
                        calendarExceptions);
                }

                var calendarPeriods = model.Calendar.Periods
                    .Where(p => p.EndDate.Date >= p.StartDate.Date)
                    .Select(p => new ProjectCalendarPeriod
                    {
                        ProjectCalendarId = calendar.Id,
                        StartDate = p.StartDate.Date,
                        EndDate = p.EndDate.Date,
                        Label = TrimTo(
                            p.Label,
                            150,
                            fallback: "Période importée")
                    })
                    .ToList();

                if (calendarPeriods.Count > 0)
                {
                    _context.ProjectCalendarPeriods.AddRange(
                        calendarPeriods);
                }

                await _context.SaveChangesAsync(cancellationToken);

                // =====================================================
                // 3. Ressources globales
                // =====================================================

                var resourceByExternalUid =
                    new Dictionary<int, Resource>();

                var createdResources = 0;
                var reusedResources = 0;

                foreach (var sourceResource in model.Resources)
                {
                    var resourceName = TrimTo(
                        sourceResource.Name,
                        100,
                        fallback:
                            $"Ressource {sourceResource.ExternalUid}");

                    var resourceType = NormalizeResourceType(
                        sourceResource.Type);

                    var existingMatches =
                        await _context.Resources
                            .Where(r =>
                                r.Name == resourceName
                                && r.Type == resourceType)
                            .ToListAsync(cancellationToken);

                    Resource resource;

                    if (existingMatches.Count == 1)
                    {
                        resource = existingMatches[0];
                        reusedResources++;
                    }
                    else
                    {
                        if (existingMatches.Count > 1)
                        {
                            result.Warnings.Add(
                                new ProjectInteropWarning
                                {
                                    Code =
                                        "AMBIGUOUS_EXISTING_RESOURCE",
                                    Message =
                                        $"Plusieurs ressources Planner portent déjà "
                                        + $"le nom « {resourceName} » avec le type "
                                        + $"« {resourceType} ». Une nouvelle ressource "
                                        + "a été créée pour éviter une fusion ambiguë.",
                                    Severity = "Warning",
                                    EntityType = "Resource",
                                    EntityName = resourceName,
                                    ExternalUid =
                                        sourceResource.ExternalUid
                                });
                        }

                        resource = new Resource
                        {
                            Name = resourceName,
                            Type = resourceType,
                            CapacityHoursPerWeek =
                                sourceResource.CapacityHoursPerWeek,
                            CostPerHour =
                                sourceResource.CostPerHour
                        };

                        _context.Resources.Add(resource);
                        createdResources++;
                    }

                    resourceByExternalUid[
                        sourceResource.ExternalUid] = resource;
                }

                await _context.SaveChangesAsync(cancellationToken);

                // =====================================================
                // 4. Tâches
                // =====================================================

                var plannerTaskByExternalUid =
                    new Dictionary<int, PlannerTask>();

                foreach (var sourceTask in executableTasks)
                {
                    var duration = Math.Max(
                        1,
                        sourceTask.DurationDays);

                    var startDate = sourceTask.StartDate;
                    var endDate = sourceTask.EndDate;

                    if (startDate.HasValue &&
                        (!endDate.HasValue ||
                         endDate.Value < startDate.Value))
                    {
                        endDate = startDate.Value;
                    }

                    var progress = Math.Clamp(
                        sourceTask.ProgressPercent,
                        0,
                        100);

                    var plannerTask = new PlannerTask
                    {
                        ProjectId = project.Id,
                        Title = TrimTo(
                            sourceTask.Name,
                            100,
                            fallback:
                                $"Tâche {sourceTask.ExternalUid}"),
                        Description = TrimNullable(
                            sourceTask.Description,
                            500),
                        StartDate = startDate,
                        EndDate = endDate,
                        Duration = duration,
                        ProgressPercent = progress,
                        IsDone = progress >= 100,
                        ActualDuration =
                            sourceTask.ActualDurationDays,
                        WorkloadHours =
                            sourceTask.WorkloadHours,
                        Deadline = sourceTask.Deadline
                    };

                    _context.Tasks.Add(plannerTask);

                    plannerTaskByExternalUid[
                        sourceTask.ExternalUid] = plannerTask;
                }

                await _context.SaveChangesAsync(cancellationToken);

                // =====================================================
                // 5. Hiérarchie / WBS
                // =====================================================

                var summaryItemsByOutline =
                    new Dictionary<string, PlanningItem>(
                        StringComparer.OrdinalIgnoreCase);

                var summaryItemsByUid =
                    new Dictionary<int, PlanningItem>();

                var sortOrderByParent =
                    new Dictionary<PlanningItem, int>();

                var rootSortOrder = 0;

                foreach (var sourceTask in model.Tasks)
                {
                    if (!sourceTask.IsSummary)
                        continue;

                    var parent =
                        FindParentSummary(
                            sourceTask,
                            summaryItemsByOutline,
                            summaryItemsByUid,
                            model.Tasks);

                    var sortOrder =
                        parent == null
                            ? ++rootSortOrder
                            : NextSortOrder(
                                sortOrderByParent,
                                parent);

                    var planningItem = new PlanningItem
                    {
                        ProjectId = project.Id,
                        Parent = parent,
                        Name = TrimTo(
                            sourceTask.Name,
                            150,
                            fallback:
                                $"Structure {sourceTask.ExternalUid}"),
                        Type = MapStructureType(
                            sourceTask.OutlineLevel),
                        SortOrder = sortOrder,
                        WbsCode = TrimTo(
                            sourceTask.OutlineNumber,
                            50,
                            fallback:
                                parent == null
                                    ? rootSortOrder.ToString()
                                    : $"{parent.WbsCode}.{sortOrder}"),
                        TaskId = null
                    };

                    _context.PlanningItems.Add(planningItem);

                    summaryItemsByUid[
                        sourceTask.ExternalUid] = planningItem;

                    if (!string.IsNullOrWhiteSpace(
                            sourceTask.OutlineNumber))
                    {
                        summaryItemsByOutline[
                            sourceTask.OutlineNumber.Trim()] =
                                planningItem;
                    }
                }

                await _context.SaveChangesAsync(cancellationToken);

                PlanningItem? unclassifiedSection = null;

                foreach (var sourceTask in executableTasks)
                {
                    if (!plannerTaskByExternalUid.TryGetValue(
                            sourceTask.ExternalUid,
                            out var plannerTask))
                    {
                        continue;
                    }

                    var parent =
                        FindParentSummary(
                            sourceTask,
                            summaryItemsByOutline,
                            summaryItemsByUid,
                            model.Tasks);

                    if (parent == null)
                    {
                        if (unclassifiedSection == null)
                        {
                            var nextRootSort =
                                ++rootSortOrder;

                            unclassifiedSection =
                                new PlanningItem
                                {
                                    ProjectId = project.Id,
                                    ParentId = null,
                                    Name = "Tâches non classées",
                                    Type = PlanningItemType.Section,
                                    SortOrder = nextRootSort,
                                    WbsCode =
                                        nextRootSort.ToString(),
                                    TaskId = null
                                };

                            _context.PlanningItems.Add(
                                unclassifiedSection);

                            await _context.SaveChangesAsync(
                                cancellationToken);
                        }

                        parent = unclassifiedSection;

                        result.Warnings.Add(
                            new ProjectInteropWarning
                            {
                                Code =
                                    "TASK_WITHOUT_STRUCTURAL_PARENT",
                                Message =
                                    $"La tâche « {sourceTask.Name} » "
                                    + "n'avait pas de parent structurel exploitable. "
                                    + "Elle a été placée dans « Tâches non classées ».",
                                Severity = "Warning",
                                EntityType = "Task",
                                EntityName =
                                    sourceTask.Name,
                                ExternalUid =
                                    sourceTask.ExternalUid
                            });
                    }

                    var sortOrder = NextSortOrder(
                        sortOrderByParent,
                        parent);

                    var taskItem = new PlanningItem
                    {
                        ProjectId = project.Id,
                        ParentId = parent.Id,
                        Name = TrimTo(
                            sourceTask.Name,
                            150,
                            fallback:
                                $"Tâche {sourceTask.ExternalUid}"),
                        Type = PlanningItemType.Task,
                        SortOrder = sortOrder,
                        WbsCode = TrimTo(
                            sourceTask.OutlineNumber,
                            50,
                            fallback:
                                $"{parent.WbsCode}.{sortOrder}"),
                        TaskId = plannerTask.Id
                    };

                    _context.PlanningItems.Add(taskItem);
                }

                await _context.SaveChangesAsync(cancellationToken);

                // =====================================================
                // 6. Dépendances
                // =====================================================

                var dependencyEntities =
                    new List<TaskDependency>();

                var dependencyKeys =
                    new HashSet<string>(
                        StringComparer.OrdinalIgnoreCase);

                foreach (var sourceDependency in
                         model.Dependencies)
                {
                    if (!plannerTaskByExternalUid.TryGetValue(
                            sourceDependency.PredecessorTaskUid,
                            out var predecessor))
                    {
                        continue;
                    }

                    if (!plannerTaskByExternalUid.TryGetValue(
                            sourceDependency.SuccessorTaskUid,
                            out var successor))
                    {
                        continue;
                    }

                    if (predecessor.Id == successor.Id)
                    {
                        throw new InvalidOperationException(
                            $"La tâche « {successor.Title} » "
                            + "possède une dépendance vers elle-même.");
                    }

                    var type = NormalizeDependencyType(
                        sourceDependency.Type);

                    var dependencyKey =
                        $"{predecessor.Id}:{successor.Id}:{type}";

                    if (!dependencyKeys.Add(dependencyKey))
                        continue;

                    dependencyEntities.Add(
                        new TaskDependency
                        {
                            PredecessorId = predecessor.Id,
                            SuccessorId = successor.Id,
                            Type = type,
                            OffsetDays =
                                sourceDependency.OffsetDays
                        });
                }

                if (dependencyEntities.Count > 0)
                {
                    _context.TaskDependencies.AddRange(
                        dependencyEntities);

                    await _context.SaveChangesAsync(
                        cancellationToken);
                }

                // =====================================================
                // 7. Assignations
                // =====================================================

                var assignmentEntities =
                    new List<ResourceAssignment>();

                foreach (var sourceAssignment in
                         model.Assignments)
                {
                    if (!plannerTaskByExternalUid.TryGetValue(
                            sourceAssignment.TaskUid,
                            out var task))
                    {
                        continue;
                    }

                    if (!resourceByExternalUid.TryGetValue(
                            sourceAssignment.ResourceUid,
                            out var resource))
                    {
                        continue;
                    }

                    assignmentEntities.Add(
                        new ResourceAssignment
                        {
                            TaskId = task.Id,
                            ResourceId = resource.Id,
                            ResourceGroupId = null,
                            WorkloadHours =
                                Math.Max(
                                    0m,
                                    sourceAssignment.WorkloadHours),
                            AllocationPercent =
                                Math.Clamp(
                                    sourceAssignment.AllocationPercent,
                                    1,
                                    100)
                        });
                }

                if (assignmentEntities.Count > 0)
                {
                    _context.ResourceAssignments.AddRange(
                        assignmentEntities);

                    await _context.SaveChangesAsync(
                        cancellationToken);
                }

                var assignmentsByTask = assignmentEntities
                    .GroupBy(a => a.TaskId)
                    .ToDictionary(
                        group => group.Key,
                        group => group.ToList());

                foreach (var task in plannerTaskByExternalUid.Values)
                {
                    if (!assignmentsByTask.TryGetValue(
                            task.Id,
                            out var taskAssignments))
                    {
                        task.AssignedResourcesCount = 0;
                        continue;
                    }

                    task.AssignedResourcesCount =
                        taskAssignments.Count;

                    if (!task.WorkloadHours.HasValue ||
                        task.WorkloadHours.Value <= 0)
                    {
                        task.WorkloadHours =
                            taskAssignments.Sum(
                                a => a.WorkloadHours);
                    }
                }

                await _context.SaveChangesAsync(
                    cancellationToken);

                // =====================================================
                // 8. Recalcul Planner
                // =====================================================

                foreach (var task in plannerTaskByExternalUid
                             .Values
                             .OrderBy(t => t.StartDate)
                             .ThenBy(t => t.Id))
                {
                    await _taskSchedulingService
                        .RecalculateTaskDatesAsync(task.Id);
                }

                await RefreshProjectDatesAsync(
                    project,
                    cancellationToken);

                await _context.SaveChangesAsync(
                    cancellationToken);

                await transaction.CommitAsync(
                    cancellationToken);

                result.ProjectId = project.Id;
                result.ProjectName = project.Name;
                result.StructureItemCount =
                    model.Tasks.Count(t => t.IsSummary);
                result.TaskCount =
                    plannerTaskByExternalUid.Count;
                result.DependencyCount =
                    dependencyEntities.Count;
                result.ResourceCount =
                    resourceByExternalUid.Count;
                result.CreatedResourceCount =
                    createdResources;
                result.ReusedResourceCount =
                    reusedResources;
                result.AssignmentCount =
                    assignmentEntities.Count;
                result.CalendarExceptionCount =
                    calendarExceptions.Count;
                result.CalendarPeriodCount =
                    calendarPeriods.Count;

                return result;
            }
            catch
            {
                await transaction.RollbackAsync(
                    cancellationToken);

                throw;
            }
        }

        private async Task RefreshProjectDatesAsync(
            Project project,
            CancellationToken cancellationToken)
        {
            var dates = await _context.Tasks
                .Where(t => t.ProjectId == project.Id)
                .Select(t => new
                {
                    t.StartDate,
                    t.EndDate
                })
                .ToListAsync(cancellationToken);

            var starts = dates
                .Where(d => d.StartDate.HasValue)
                .Select(d => d.StartDate!.Value)
                .ToList();

            var ends = dates
                .Where(d => d.EndDate.HasValue)
                .Select(d => d.EndDate!.Value)
                .ToList();

            if (starts.Count > 0)
                project.StartDate = starts.Min();

            if (ends.Count > 0)
                project.EndDate = ends.Max();
        }

        private static PlanningItem? FindParentSummary(
            ProjectInteropTask sourceTask,
            IReadOnlyDictionary<string, PlanningItem>
                summaryItemsByOutline,
            IReadOnlyDictionary<int, PlanningItem>
                summaryItemsByUid,
            IReadOnlyList<ProjectInteropTask> sourceTasks)
        {
            var outline =
                sourceTask.OutlineNumber?.Trim();

            if (!string.IsNullOrWhiteSpace(outline))
            {
                var separatorIndex =
                    outline.LastIndexOf('.');

                if (separatorIndex > 0)
                {
                    var parentOutline =
                        outline[..separatorIndex];

                    if (summaryItemsByOutline.TryGetValue(
                            parentOutline,
                            out var parentByOutline))
                    {
                        return parentByOutline;
                    }
                }
            }

            var sourceIndex = -1;

            for (var index = 0;
                 index < sourceTasks.Count;
                 index++)
            {
                if (sourceTasks[index].ExternalUid
                    == sourceTask.ExternalUid)
                {
                    sourceIndex = index;
                    break;
                }
            }

            if (sourceIndex <= 0)
                return null;

            for (var index = sourceIndex - 1;
                 index >= 0;
                 index--)
            {
                var candidate = sourceTasks[index];

                if (!candidate.IsSummary)
                    continue;

                if (candidate.OutlineLevel
                    >= sourceTask.OutlineLevel)
                {
                    continue;
                }

                if (summaryItemsByUid.TryGetValue(
                        candidate.ExternalUid,
                        out var parentByOrder))
                {
                    return parentByOrder;
                }
            }

            return null;
        }

        private static PlanningItemType MapStructureType(
            int outlineLevel)
        {
            return outlineLevel switch
            {
                <= 1 => PlanningItemType.Section,
                2 => PlanningItemType.Phase,
                3 => PlanningItemType.Zone,
                4 => PlanningItemType.Floor,
                _ => PlanningItemType.Lot
            };
        }

        private static int NextSortOrder(
            IDictionary<PlanningItem, int> sortOrderByParent,
            PlanningItem parent)
        {
            if (!sortOrderByParent.TryGetValue(
                    parent,
                    out var current))
            {
                current = 0;
            }

            current++;
            sortOrderByParent[parent] = current;

            return current;
        }

        private static string NormalizeDependencyType(
            string? value)
        {
            var normalized =
                value?.Trim().ToUpperInvariant();

            return normalized switch
            {
                "FS" => "FS",
                "SS" => "SS",
                "FF" => "FF",
                "SF" => "SF",
                _ => "FS"
            };
        }

        private static string NormalizeResourceType(
            string? value)
        {
            var normalized =
                value?.Trim();

            if (string.IsNullOrWhiteSpace(normalized))
                return "Person";

            if (normalized.Equals(
                    "Material",
                    StringComparison.OrdinalIgnoreCase))
            {
                return "Material";
            }

            if (normalized.Equals(
                    "Team",
                    StringComparison.OrdinalIgnoreCase))
            {
                return "Team";
            }

            return "Person";
        }

        private static bool HasDependencyCycle(
            IEnumerable<ProjectInteropDependency>
                dependencies)
        {
            var adjacency =
                new Dictionary<int, List<int>>();

            foreach (var dependency in dependencies)
            {
                if (!adjacency.TryGetValue(
                        dependency.PredecessorTaskUid,
                        out var successors))
                {
                    successors = new List<int>();

                    adjacency[
                        dependency.PredecessorTaskUid] =
                            successors;
                }

                successors.Add(
                    dependency.SuccessorTaskUid);
            }

            var visiting = new HashSet<int>();
            var visited = new HashSet<int>();

            bool Visit(int node)
            {
                if (visiting.Contains(node))
                    return true;

                if (visited.Contains(node))
                    return false;

                visiting.Add(node);

                if (adjacency.TryGetValue(
                        node,
                        out var successors))
                {
                    foreach (var successor in successors)
                    {
                        if (Visit(successor))
                            return true;
                    }
                }

                visiting.Remove(node);
                visited.Add(node);

                return false;
            }

            foreach (var node in adjacency.Keys)
            {
                if (Visit(node))
                    return true;
            }

            return false;
        }

        private static string TrimTo(
            string? value,
            int maxLength,
            string fallback)
        {
            var normalized =
                string.IsNullOrWhiteSpace(value)
                    ? fallback
                    : value.Trim();

            return normalized.Length <= maxLength
                ? normalized
                : normalized[..maxLength];
        }

        private static string? TrimNullable(
            string? value,
            int maxLength)
        {
            if (string.IsNullOrWhiteSpace(value))
                return null;

            var normalized = value.Trim();

            return normalized.Length <= maxLength
                ? normalized
                : normalized[..maxLength];
        }
    }
}