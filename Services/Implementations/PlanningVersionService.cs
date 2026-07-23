using System.Data;
using System.Globalization;
using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.PlanningVersions;
using PlannerAPI.Models;
using PlannerAPI.Services.Interfaces;

namespace PlannerAPI.Services.Implementations
{
    public class PlanningVersionService : IPlanningVersionService
    {
        private readonly AppDbContext _context;

        public PlanningVersionService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<PlanningVersionSummaryResponse> CreateAsync(
            int projectId,
            CreatePlanningVersionRequest request)
        {
            var name = request.Name?.Trim();

            if (string.IsNullOrWhiteSpace(name))
            {
                throw new ArgumentException(
                    "Le nom de la version est obligatoire.",
                    nameof(request));
            }

            var projectExists = await _context.Projects
                .AsNoTracking()
                .AnyAsync(p => p.Id == projectId);

            if (!projectExists)
            {
                throw new KeyNotFoundException(
                    $"Le projet {projectId} est introuvable.");
            }

            await using var transaction =
                await _context.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable);

            try
            {
                var nextVersionNumber =
                    (await _context.PlanningVersions
                        .Where(v => v.ProjectId == projectId)
                        .MaxAsync(v => (int?)v.VersionNumber) ?? 0) + 1;

                var tasks = await _context.Tasks
                    .AsNoTracking()
                    .Where(t => t.ProjectId == projectId)
                    .OrderBy(t => t.Id)
                    .ToListAsync();

                var taskIds = tasks
                    .Select(t => t.Id)
                    .ToList();

                var items = await _context.PlanningItems
                    .AsNoTracking()
                    .Where(i => i.ProjectId == projectId)
                    .OrderBy(i => i.SortOrder)
                    .ThenBy(i => i.Id)
                    .ToListAsync();

                var dependencies = taskIds.Count == 0
                    ? new List<TaskDependency>()
                    : await _context.TaskDependencies
                        .AsNoTracking()
                        .Where(d =>
                            taskIds.Contains(d.PredecessorId) &&
                            taskIds.Contains(d.SuccessorId))
                        .OrderBy(d => d.Id)
                        .ToListAsync();

                var assignments = taskIds.Count == 0
                    ? new List<ResourceAssignment>()
                    : await _context.ResourceAssignments
                        .AsNoTracking()
                        .Include(a => a.Resource)
                        .Include(a => a.ResourceGroup)
                        .Where(a => taskIds.Contains(a.TaskId))
                        .OrderBy(a => a.Id)
                        .ToListAsync();

                var calendar = await _context.ProjectCalendars
                    .AsNoTracking()
                    .Include(c => c.Exceptions)
                    .Include(c => c.Periods)
                    .AsSplitQuery()
                    .SingleOrDefaultAsync(c => c.ProjectId == projectId);

                var version = new PlanningVersion
                {
                    ProjectId = projectId,
                    VersionNumber = nextVersionNumber,
                    Name = name,
                    Description = NormalizeOptionalText(
                        request.Description),
                    CreatedBy = NormalizeOptionalText(
                        request.CreatedBy),
                    CreatedAt = DateTime.UtcNow,
                    Tasks = tasks
                        .Select(MapTaskSnapshot)
                        .ToList(),
                    Items = items
                        .Select(MapItemSnapshot)
                        .ToList(),
                    Dependencies = dependencies
                        .Select(MapDependencySnapshot)
                        .ToList(),
                    Assignments = assignments
                        .Select(MapAssignmentSnapshot)
                        .ToList(),
                    Calendar = calendar is null
                        ? null
                        : MapCalendarSnapshot(calendar)
                };

                _context.PlanningVersions.Add(version);

                await _context.SaveChangesAsync();
                await transaction.CommitAsync();

                return MapSummary(version);
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        public async Task<List<PlanningVersionSummaryResponse>>
            GetByProjectAsync(int projectId)
        {
            return await _context.PlanningVersions
                .AsNoTracking()
                .Where(v => v.ProjectId == projectId)
                .OrderByDescending(v => v.VersionNumber)
                .Select(v => new PlanningVersionSummaryResponse
                {
                    Id = v.Id,
                    ProjectId = v.ProjectId,
                    VersionNumber = v.VersionNumber,
                    Name = v.Name,
                    Description = v.Description,
                    CreatedBy = v.CreatedBy,
                    CreatedAt = v.CreatedAt,
                    TaskCount = v.Tasks.Count,
                    ItemCount = v.Items.Count,
                    DependencyCount = v.Dependencies.Count,
                    AssignmentCount = v.Assignments.Count,
                    HasCalendar = v.Calendar != null
                })
                .ToListAsync();
        }

        public async Task<PlanningVersionDetailResponse?> GetByIdAsync(
            int versionId)
        {
            var version = await LoadVersionAsync(versionId);

            return version is null
                ? null
                : MapDetail(version);
        }

        public async Task<PlanningVersionComparisonResponse?>
            CompareWithCurrentAsync(int versionId)
        {
            var version = await LoadVersionAsync(versionId);

            if (version is null)
            {
                return null;
            }

            var currentTasks = await _context.Tasks
                .AsNoTracking()
                .Where(t => t.ProjectId == version.ProjectId)
                .OrderBy(t => t.Id)
                .ToListAsync();

            var currentTaskIds = currentTasks
                .Select(t => t.Id)
                .ToList();

            var currentItems = await _context.PlanningItems
                .AsNoTracking()
                .Where(i => i.ProjectId == version.ProjectId)
                .OrderBy(i => i.Id)
                .ToListAsync();

            var currentDependencies = currentTaskIds.Count == 0
                ? new List<TaskDependency>()
                : await _context.TaskDependencies
                    .AsNoTracking()
                    .Where(d =>
                        currentTaskIds.Contains(d.PredecessorId) &&
                        currentTaskIds.Contains(d.SuccessorId))
                    .OrderBy(d => d.Id)
                    .ToListAsync();

            var currentAssignments = currentTaskIds.Count == 0
                ? new List<ResourceAssignment>()
                : await _context.ResourceAssignments
                    .AsNoTracking()
                    .Where(a => currentTaskIds.Contains(a.TaskId))
                    .OrderBy(a => a.Id)
                    .ToListAsync();

            var currentCalendar = await _context.ProjectCalendars
                .AsNoTracking()
                .Include(c => c.Exceptions)
                .Include(c => c.Periods)
                .AsSplitQuery()
                .SingleOrDefaultAsync(
                    c => c.ProjectId == version.ProjectId);

            var versionTasksById = version.Tasks
                .ToDictionary(t => t.OriginalTaskId);

            var currentTasksById = currentTasks
                .ToDictionary(t => t.Id);

            var allTaskIds = versionTasksById.Keys
                .Union(currentTasksById.Keys)
                .OrderBy(id => id)
                .ToList();

            var taskComparisons =
                new List<PlanningVersionTaskComparisonResponse>();

            foreach (var taskId in allTaskIds)
            {
                versionTasksById.TryGetValue(
                    taskId,
                    out var versionTask);

                currentTasksById.TryGetValue(
                    taskId,
                    out var currentTask);

                if (versionTask is null && currentTask is not null)
                {
                    taskComparisons.Add(
                        new PlanningVersionTaskComparisonResponse
                        {
                            TaskId = taskId,
                            Status = "Added",
                            Title = currentTask.Title,
                            ChangedFields = new List<string>
                            {
                                "Task"
                            },
                            VersionState = null,
                            CurrentState =
                                MapCurrentTaskState(currentTask)
                        });

                    continue;
                }

                if (versionTask is not null && currentTask is null)
                {
                    taskComparisons.Add(
                        new PlanningVersionTaskComparisonResponse
                        {
                            TaskId = taskId,
                            Status = "Removed",
                            Title = versionTask.Title,
                            ChangedFields = new List<string>
                            {
                                "Task"
                            },
                            VersionState =
                                MapVersionTaskState(versionTask),
                            CurrentState = null
                        });

                    continue;
                }

                if (versionTask is null || currentTask is null)
                {
                    continue;
                }

                var changedFields = GetChangedTaskFields(
                    versionTask,
                    currentTask);

                taskComparisons.Add(
                    new PlanningVersionTaskComparisonResponse
                    {
                        TaskId = taskId,
                        Status = changedFields.Count == 0
                            ? "Unchanged"
                            : "Modified",
                        Title = currentTask.Title,
                        ChangedFields = changedFields,
                        VersionState =
                            MapVersionTaskState(versionTask),
                        CurrentState =
                            MapCurrentTaskState(currentTask)
                    });
            }

            return new PlanningVersionComparisonResponse
            {
                VersionId = version.Id,
                ProjectId = version.ProjectId,
                VersionNumber = version.VersionNumber,
                VersionName = version.Name,
                VersionCreatedAt = version.CreatedAt,
                ComparedAt = DateTime.UtcNow,
                Summary = new PlanningVersionComparisonSummary
                {
                    VersionTaskCount = version.Tasks.Count,
                    CurrentTaskCount = currentTasks.Count,
                    AddedTaskCount = taskComparisons.Count(
                        t => t.Status == "Added"),
                    RemovedTaskCount = taskComparisons.Count(
                        t => t.Status == "Removed"),
                    ModifiedTaskCount = taskComparisons.Count(
                        t => t.Status == "Modified"),
                    UnchangedTaskCount = taskComparisons.Count(
                        t => t.Status == "Unchanged")
                },
                Tasks = taskComparisons,
                StructureChanged = HasStructureChanged(
                    version.Items,
                    currentItems),
                DependenciesChanged = HasDependenciesChanged(
                    version.Dependencies,
                    currentDependencies),
                AssignmentsChanged = HasAssignmentsChanged(
                    version.Assignments,
                    currentAssignments),
                CalendarChanged = HasCalendarChanged(
                    version.Calendar,
                    currentCalendar)
            };
        }

        public async Task<RestorePlanningVersionResponse?> RestoreAsync(
            int versionId,
            RestorePlanningVersionRequest request)
        {
            if (!request.ConfirmRestore)
            {
                throw new ArgumentException(
                    "La restauration doit être explicitement confirmée.",
                    nameof(request));
            }

            var version = await LoadVersionAsync(versionId);

            if (version is null)
            {
                return null;
            }

            await using var transaction =
                await _context.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable);

            try
            {
                int? safetyVersionId = null;

                if (request.CreateSafetyVersion)
                {
                    var safetyName =
                        NormalizeOptionalText(request.SafetyVersionName)
                        ?? $"Sauvegarde avant restauration V{version.VersionNumber}";

                    var safetyVersion = await CreateSafetySnapshotAsync(
                        version.ProjectId,
                        safetyName,
                        $"Sauvegarde automatique avant restauration de la version V{version.VersionNumber} - {version.Name}.",
                        NormalizeOptionalText(request.RestoredBy));

                    safetyVersionId = safetyVersion.Id;
                }

                var warnings = new List<string>();

                var currentTasks = await _context.Tasks
                    .Where(t => t.ProjectId == version.ProjectId)
                    .OrderBy(t => t.Id)
                    .ToListAsync();

                var currentTaskIds = currentTasks
                    .Select(t => t.Id)
                    .ToList();

                if (currentTaskIds.Count > 0)
                {
                    var dependencies = await _context.TaskDependencies
                        .Where(d =>
                            currentTaskIds.Contains(d.PredecessorId) ||
                            currentTaskIds.Contains(d.SuccessorId))
                        .ToListAsync();

                    _context.TaskDependencies.RemoveRange(dependencies);

                    var assignments = await _context.ResourceAssignments
                        .Where(a => currentTaskIds.Contains(a.TaskId))
                        .ToListAsync();

                    _context.ResourceAssignments.RemoveRange(assignments);
                }

                await DeletePlanningItemsSafelyAsync(version.ProjectId);
                await _context.SaveChangesAsync();

                var versionTasksById = version.Tasks
                    .ToDictionary(t => t.OriginalTaskId);

                var currentTasksById = currentTasks
                    .ToDictionary(t => t.Id);

                var taskMappings = new Dictionary<int, int>();
                var mappingResponses =
                    new List<PlanningVersionRestoreTaskMappingResponse>();

                var updatedTaskCount = 0;
                var createdTaskCount = 0;

                foreach (var versionTask in version.Tasks
                    .OrderBy(t => t.OriginalTaskId))
                {
                    if (currentTasksById.TryGetValue(
                        versionTask.OriginalTaskId,
                        out var existingTask))
                    {
                        ApplyTaskSnapshot(
                            existingTask,
                            versionTask,
                            version.ProjectId);

                        taskMappings[versionTask.OriginalTaskId] =
                            existingTask.Id;

                        mappingResponses.Add(
                            new PlanningVersionRestoreTaskMappingResponse
                            {
                                OriginalTaskId =
                                    versionTask.OriginalTaskId,
                                RestoredTaskId = existingTask.Id,
                                ReusedExistingId = true
                            });

                        updatedTaskCount++;
                    }
                    else
                    {
                        var recreatedTask = CreateTaskFromSnapshot(
                            versionTask,
                            version.ProjectId);

                        _context.Tasks.Add(recreatedTask);
                        await _context.SaveChangesAsync();

                        taskMappings[versionTask.OriginalTaskId] =
                            recreatedTask.Id;

                        mappingResponses.Add(
                            new PlanningVersionRestoreTaskMappingResponse
                            {
                                OriginalTaskId =
                                    versionTask.OriginalTaskId,
                                RestoredTaskId = recreatedTask.Id,
                                ReusedExistingId = false
                            });

                        createdTaskCount++;
                    }
                }

                var tasksToDelete = currentTasks
                    .Where(t => !versionTasksById.ContainsKey(t.Id))
                    .ToList();

                _context.Tasks.RemoveRange(tasksToDelete);
                await _context.SaveChangesAsync();

                var restoredItemCount =
                    await RestorePlanningItemsAsync(
                        version,
                        taskMappings,
                        warnings);

                var restoredDependencyCount = 0;

                foreach (var dependency in version.Dependencies
                    .OrderBy(d => d.OriginalDependencyId))
                {
                    if (!taskMappings.TryGetValue(
                            dependency.OriginalPredecessorTaskId,
                            out var predecessorId) ||
                        !taskMappings.TryGetValue(
                            dependency.OriginalSuccessorTaskId,
                            out var successorId))
                    {
                        warnings.Add(
                            $"Dépendance {dependency.OriginalDependencyId} ignorée : une tâche liée n'a pas pu être restaurée.");
                        continue;
                    }

                    _context.TaskDependencies.Add(
                        new TaskDependency
                        {
                            PredecessorId = predecessorId,
                            SuccessorId = successorId,
                            Type = dependency.Type,
                            OffsetDays = dependency.OffsetDays
                        });

                    restoredDependencyCount++;
                }

                var resourceIds = version.Assignments
                    .Where(a => a.OriginalResourceId.HasValue)
                    .Select(a => a.OriginalResourceId!.Value)
                    .Distinct()
                    .ToList();

                var groupIds = version.Assignments
                    .Where(a => a.OriginalResourceGroupId.HasValue)
                    .Select(a => a.OriginalResourceGroupId!.Value)
                    .Distinct()
                    .ToList();

                var existingResourceIds = resourceIds.Count == 0
                    ? new HashSet<int>()
                    : (await _context.Resources
                        .AsNoTracking()
                        .Where(r => resourceIds.Contains(r.Id))
                        .Select(r => r.Id)
                        .ToListAsync())
                        .ToHashSet();

                var existingGroupIds = groupIds.Count == 0
                    ? new HashSet<int>()
                    : (await _context.ResourceGroups
                        .AsNoTracking()
                        .Where(g => groupIds.Contains(g.Id))
                        .Select(g => g.Id)
                        .ToListAsync())
                        .ToHashSet();

                var restoredAssignmentCount = 0;

                foreach (var assignment in version.Assignments
                    .OrderBy(a => a.OriginalAssignmentId))
                {
                    if (!taskMappings.TryGetValue(
                        assignment.OriginalTaskId,
                        out var restoredTaskId))
                    {
                        warnings.Add(
                            $"Assignation {assignment.OriginalAssignmentId} ignorée : tâche introuvable.");
                        continue;
                    }

                    if (assignment.OriginalResourceId.HasValue &&
                        !existingResourceIds.Contains(
                            assignment.OriginalResourceId.Value))
                    {
                        warnings.Add(
                            $"Assignation {assignment.OriginalAssignmentId} ignorée : la ressource « {assignment.ResourceName ?? assignment.OriginalResourceId.Value.ToString()} » n'existe plus.");
                        continue;
                    }

                    if (assignment.OriginalResourceGroupId.HasValue &&
                        !existingGroupIds.Contains(
                            assignment.OriginalResourceGroupId.Value))
                    {
                        warnings.Add(
                            $"Assignation {assignment.OriginalAssignmentId} ignorée : le groupe « {assignment.ResourceGroupName ?? assignment.OriginalResourceGroupId.Value.ToString()} » n'existe plus.");
                        continue;
                    }

                    if (!assignment.OriginalResourceId.HasValue &&
                        !assignment.OriginalResourceGroupId.HasValue)
                    {
                        warnings.Add(
                            $"Assignation {assignment.OriginalAssignmentId} ignorée : aucune ressource ni aucun groupe.");
                        continue;
                    }

                    _context.ResourceAssignments.Add(
                        new ResourceAssignment
                        {
                            TaskId = restoredTaskId,
                            ResourceId = assignment.OriginalResourceId,
                            ResourceGroupId =
                                assignment.OriginalResourceGroupId,
                            WorkloadHours = assignment.WorkloadHours,
                            AllocationPercent =
                                assignment.AllocationPercent
                        });

                    restoredAssignmentCount++;
                }

                var calendarRestored =
                    await RestoreCalendarAsync(
                        version.ProjectId,
                        version.Calendar);

                await _context.SaveChangesAsync();
                await transaction.CommitAsync();

                return new RestorePlanningVersionResponse
                {
                    VersionId = version.Id,
                    ProjectId = version.ProjectId,
                    VersionNumber = version.VersionNumber,
                    VersionName = version.Name,
                    RestoredAt = DateTime.UtcNow,
                    RestoredBy =
                        NormalizeOptionalText(request.RestoredBy),
                    SafetyVersionId = safetyVersionId,
                    UpdatedTaskCount = updatedTaskCount,
                    CreatedTaskCount = createdTaskCount,
                    DeletedTaskCount = tasksToDelete.Count,
                    RestoredItemCount = restoredItemCount,
                    RestoredDependencyCount =
                        restoredDependencyCount,
                    RestoredAssignmentCount =
                        restoredAssignmentCount,
                    CalendarRestored = calendarRestored,
                    TaskMappings = mappingResponses,
                    Warnings = warnings
                };
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        public async Task<bool> DeleteAsync(int versionId)
        {
            var version = await _context.PlanningVersions
                .SingleOrDefaultAsync(v => v.Id == versionId);

            if (version is null)
            {
                return false;
            }

            _context.PlanningVersions.Remove(version);
            await _context.SaveChangesAsync();

            return true;
        }

        private async Task<PlanningVersion> CreateSafetySnapshotAsync(
            int projectId,
            string name,
            string? description,
            string? createdBy)
        {
            var nextVersionNumber =
                (await _context.PlanningVersions
                    .Where(v => v.ProjectId == projectId)
                    .MaxAsync(v => (int?)v.VersionNumber) ?? 0) + 1;

            var tasks = await _context.Tasks
                .AsNoTracking()
                .Where(t => t.ProjectId == projectId)
                .OrderBy(t => t.Id)
                .ToListAsync();

            var taskIds = tasks.Select(t => t.Id).ToList();

            var items = await _context.PlanningItems
                .AsNoTracking()
                .Where(i => i.ProjectId == projectId)
                .OrderBy(i => i.SortOrder)
                .ThenBy(i => i.Id)
                .ToListAsync();

            var dependencies = taskIds.Count == 0
                ? new List<TaskDependency>()
                : await _context.TaskDependencies
                    .AsNoTracking()
                    .Where(d =>
                        taskIds.Contains(d.PredecessorId) &&
                        taskIds.Contains(d.SuccessorId))
                    .OrderBy(d => d.Id)
                    .ToListAsync();

            var assignments = taskIds.Count == 0
                ? new List<ResourceAssignment>()
                : await _context.ResourceAssignments
                    .AsNoTracking()
                    .Include(a => a.Resource)
                    .Include(a => a.ResourceGroup)
                    .Where(a => taskIds.Contains(a.TaskId))
                    .OrderBy(a => a.Id)
                    .ToListAsync();

            var calendar = await _context.ProjectCalendars
                .AsNoTracking()
                .Include(c => c.Exceptions)
                .Include(c => c.Periods)
                .AsSplitQuery()
                .SingleOrDefaultAsync(c => c.ProjectId == projectId);

            var version = new PlanningVersion
            {
                ProjectId = projectId,
                VersionNumber = nextVersionNumber,
                Name = name,
                Description = description,
                CreatedBy = createdBy,
                CreatedAt = DateTime.UtcNow,
                Tasks = tasks.Select(MapTaskSnapshot).ToList(),
                Items = items.Select(MapItemSnapshot).ToList(),
                Dependencies = dependencies
                    .Select(MapDependencySnapshot)
                    .ToList(),
                Assignments = assignments
                    .Select(MapAssignmentSnapshot)
                    .ToList(),
                Calendar = calendar is null
                    ? null
                    : MapCalendarSnapshot(calendar)
            };

            _context.PlanningVersions.Add(version);
            await _context.SaveChangesAsync();

            return version;
        }

        private async Task DeletePlanningItemsSafelyAsync(
            int projectId)
        {
            while (true)
            {
                var leafItems = await _context.PlanningItems
                    .Where(i =>
                        i.ProjectId == projectId &&
                        !_context.PlanningItems.Any(
                            child => child.ParentId == i.Id))
                    .ToListAsync();

                if (leafItems.Count == 0)
                {
                    var remaining = await _context.PlanningItems
                        .CountAsync(i => i.ProjectId == projectId);

                    if (remaining > 0)
                    {
                        throw new InvalidOperationException(
                            "La hiérarchie contient une relation cyclique et ne peut pas être supprimée proprement.");
                    }

                    break;
                }

                _context.PlanningItems.RemoveRange(leafItems);
                await _context.SaveChangesAsync();
            }
        }

        private async Task<int> RestorePlanningItemsAsync(
            PlanningVersion version,
            IReadOnlyDictionary<int, int> taskMappings,
            ICollection<string> warnings)
        {
            var pending = version.Items
                .OrderBy(i => i.SortOrder)
                .ThenBy(i => i.OriginalPlanningItemId)
                .ToList();

            var itemMappings = new Dictionary<int, int>();
            var restoredCount = 0;

            while (pending.Count > 0)
            {
                var creatable = pending
                    .Where(i =>
                        !i.OriginalParentId.HasValue ||
                        itemMappings.ContainsKey(
                            i.OriginalParentId.Value))
                    .ToList();

                if (creatable.Count == 0)
                {
                    foreach (var orphan in pending)
                    {
                        warnings.Add(
                            $"Élément « {orphan.Name} » restauré à la racine : parent d'origine introuvable.");
                    }

                    creatable = pending.ToList();
                }

                foreach (var snapshot in creatable)
                {
                    int? restoredTaskId = null;

                    if (snapshot.OriginalTaskId.HasValue)
                    {
                        if (taskMappings.TryGetValue(
                            snapshot.OriginalTaskId.Value,
                            out var mappedTaskId))
                        {
                            restoredTaskId = mappedTaskId;
                        }
                        else
                        {
                            warnings.Add(
                                $"Élément « {snapshot.Name} » restauré sans tâche liée : tâche d'origine introuvable.");
                        }
                    }

                    var item = new PlanningItem
                    {
                        ProjectId = version.ProjectId,
                        ParentId =
                            snapshot.OriginalParentId.HasValue &&
                            itemMappings.TryGetValue(
                                snapshot.OriginalParentId.Value,
                                out var restoredParentId)
                                ? restoredParentId
                                : null,
                        Name = snapshot.Name,
                        Type = snapshot.Type,
                        SortOrder = snapshot.SortOrder,
                        WbsCode = snapshot.WbsCode,
                        TaskId = restoredTaskId
                    };

                    _context.PlanningItems.Add(item);
                    await _context.SaveChangesAsync();

                    itemMappings[snapshot.OriginalPlanningItemId] =
                        item.Id;

                    restoredCount++;
                    pending.Remove(snapshot);
                }
            }

            return restoredCount;
        }

        private async Task<bool> RestoreCalendarAsync(
            int projectId,
            PlanningVersionCalendar? versionCalendar)
        {
            var currentCalendar = await _context.ProjectCalendars
                .Include(c => c.Exceptions)
                .Include(c => c.Periods)
                .AsSplitQuery()
                .SingleOrDefaultAsync(c => c.ProjectId == projectId);

            if (versionCalendar is null)
            {
                if (currentCalendar is not null)
                {
                    _context.ProjectCalendars.Remove(currentCalendar);
                }

                return false;
            }

            if (currentCalendar is null)
            {
                currentCalendar = new ProjectCalendar
                {
                    ProjectId = projectId
                };

                _context.ProjectCalendars.Add(currentCalendar);
            }
            else
            {
                _context.ProjectCalendarExceptions.RemoveRange(
                    currentCalendar.Exceptions);

                _context.ProjectCalendarPeriods.RemoveRange(
                    currentCalendar.Periods);
            }

            currentCalendar.WorkMonday =
                versionCalendar.WorkMonday;
            currentCalendar.WorkTuesday =
                versionCalendar.WorkTuesday;
            currentCalendar.WorkWednesday =
                versionCalendar.WorkWednesday;
            currentCalendar.WorkThursday =
                versionCalendar.WorkThursday;
            currentCalendar.WorkFriday =
                versionCalendar.WorkFriday;
            currentCalendar.WorkSaturday =
                versionCalendar.WorkSaturday;
            currentCalendar.WorkSunday =
                versionCalendar.WorkSunday;

            currentCalendar.Exceptions =
                versionCalendar.Exceptions
                    .OrderBy(e => e.Date)
                    .Select(e => new ProjectCalendarException
                    {
                        Date = e.Date,
                        Label = e.Label,
                        IsWorkingDay = e.IsWorkingDay
                    })
                    .ToList();

            currentCalendar.Periods =
                versionCalendar.Periods
                    .OrderBy(p => p.StartDate)
                    .ThenBy(p => p.EndDate)
                    .Select(p => new ProjectCalendarPeriod
                    {
                        StartDate = p.StartDate,
                        EndDate = p.EndDate,
                        Label = p.Label
                    })
                    .ToList();

            return true;
        }

        private static void ApplyTaskSnapshot(
            PlannerTask task,
            PlanningVersionTask snapshot,
            int projectId)
        {
            task.ProjectId = projectId;
            task.Title = snapshot.Title;
            task.Description = snapshot.Description;
            task.StartDate = snapshot.StartDate;
            task.EndDate = snapshot.EndDate;
            task.Duration = snapshot.Duration;
            task.ProgressPercent = snapshot.ProgressPercent;
            task.IsDone = snapshot.IsDone;
            task.ActualDuration = snapshot.ActualDuration;
            task.AssignedResourcesCount =
                snapshot.AssignedResourcesCount;
            task.WorkloadHours = snapshot.WorkloadHours;
            task.EarlyStart = snapshot.EarlyStart;
            task.EarlyFinish = snapshot.EarlyFinish;
            task.LateStart = snapshot.LateStart;
            task.LateFinish = snapshot.LateFinish;
            task.TotalFloat = snapshot.TotalFloat;
            task.IsCritical = snapshot.IsCritical;
            task.Deadline = snapshot.Deadline;
            task.DelayDays = snapshot.DelayDays;
            task.IsLate = snapshot.IsLate;
        }

        private static PlannerTask CreateTaskFromSnapshot(
            PlanningVersionTask snapshot,
            int projectId)
        {
            var task = new PlannerTask();
            ApplyTaskSnapshot(task, snapshot, projectId);
            return task;
        }

        private async Task<PlanningVersion?> LoadVersionAsync(
            int versionId)
        {
            return await _context.PlanningVersions
                .AsNoTracking()
                .Include(v => v.Tasks)
                .Include(v => v.Items)
                .Include(v => v.Dependencies)
                .Include(v => v.Assignments)
                .Include(v => v.Calendar)
                    .ThenInclude(c => c!.Exceptions)
                .Include(v => v.Calendar)
                    .ThenInclude(c => c!.Periods)
                .AsSplitQuery()
                .SingleOrDefaultAsync(v => v.Id == versionId);
        }

        private static List<string> GetChangedTaskFields(
            PlanningVersionTask versionTask,
            PlannerTask currentTask)
        {
            var changedFields = new List<string>();

            AddChangedField(
                changedFields,
                "Title",
                versionTask.Title != currentTask.Title);

            AddChangedField(
                changedFields,
                "Description",
                versionTask.Description != currentTask.Description);

            AddChangedField(
                changedFields,
                "StartDate",
                versionTask.StartDate != currentTask.StartDate);

            AddChangedField(
                changedFields,
                "EndDate",
                versionTask.EndDate != currentTask.EndDate);

            AddChangedField(
                changedFields,
                "Duration",
                versionTask.Duration != currentTask.Duration);

            AddChangedField(
                changedFields,
                "ProgressPercent",
                versionTask.ProgressPercent !=
                currentTask.ProgressPercent);

            AddChangedField(
                changedFields,
                "IsDone",
                versionTask.IsDone != currentTask.IsDone);

            AddChangedField(
                changedFields,
                "ActualDuration",
                versionTask.ActualDuration !=
                currentTask.ActualDuration);

            AddChangedField(
                changedFields,
                "AssignedResourcesCount",
                versionTask.AssignedResourcesCount !=
                currentTask.AssignedResourcesCount);

            AddChangedField(
                changedFields,
                "WorkloadHours",
                versionTask.WorkloadHours !=
                currentTask.WorkloadHours);

            AddChangedField(
                changedFields,
                "EarlyStart",
                versionTask.EarlyStart != currentTask.EarlyStart);

            AddChangedField(
                changedFields,
                "EarlyFinish",
                versionTask.EarlyFinish != currentTask.EarlyFinish);

            AddChangedField(
                changedFields,
                "LateStart",
                versionTask.LateStart != currentTask.LateStart);

            AddChangedField(
                changedFields,
                "LateFinish",
                versionTask.LateFinish != currentTask.LateFinish);

            AddChangedField(
                changedFields,
                "TotalFloat",
                versionTask.TotalFloat != currentTask.TotalFloat);

            AddChangedField(
                changedFields,
                "IsCritical",
                versionTask.IsCritical != currentTask.IsCritical);

            AddChangedField(
                changedFields,
                "Deadline",
                versionTask.Deadline != currentTask.Deadline);

            AddChangedField(
                changedFields,
                "DelayDays",
                versionTask.DelayDays != currentTask.DelayDays);

            AddChangedField(
                changedFields,
                "IsLate",
                versionTask.IsLate != currentTask.IsLate);

            return changedFields;
        }

        private static void AddChangedField(
            ICollection<string> changedFields,
            string fieldName,
            bool hasChanged)
        {
            if (hasChanged)
            {
                changedFields.Add(fieldName);
            }
        }

        private static bool HasStructureChanged(
            IEnumerable<PlanningVersionItem> versionItems,
            IEnumerable<PlanningItem> currentItems)
        {
            var versionList = versionItems.ToList();
            var currentList = currentItems.ToList();

            if (versionList.Count != currentList.Count)
            {
                return true;
            }

            var versionItemsById = versionList
                .ToDictionary(i => i.OriginalPlanningItemId);

            var currentItemsById = currentList
                .ToDictionary(i => i.Id);

            var versionSignatures = versionList
                .Select(i => string.Join(
                    "|",
                    Escape(i.WbsCode),
                    Escape(GetVersionParentWbsCode(
                        i,
                        versionItemsById)),
                    Escape(i.Name),
                    (int)i.Type,
                    i.SortOrder,
                    i.OriginalTaskId.HasValue
                        ? "task"
                        : "structure"))
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToList();

            var currentSignatures = currentList
                .Select(i => string.Join(
                    "|",
                    Escape(i.WbsCode),
                    Escape(GetCurrentParentWbsCode(
                        i,
                        currentItemsById)),
                    Escape(i.Name),
                    (int)i.Type,
                    i.SortOrder,
                    i.TaskId.HasValue
                        ? "task"
                        : "structure"))
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToList();

            return !versionSignatures.SequenceEqual(
                currentSignatures,
                StringComparer.Ordinal);
        }

        private static string GetVersionParentWbsCode(
            PlanningVersionItem item,
            IReadOnlyDictionary<int, PlanningVersionItem> itemsById)
        {
            if (!item.OriginalParentId.HasValue)
            {
                return "root";
            }

            return itemsById.TryGetValue(
                item.OriginalParentId.Value,
                out var parent)
                    ? parent.WbsCode
                    : $"missing:{item.OriginalParentId.Value}";
        }

        private static string GetCurrentParentWbsCode(
            PlanningItem item,
            IReadOnlyDictionary<int, PlanningItem> itemsById)
        {
            if (!item.ParentId.HasValue)
            {
                return "root";
            }

            return itemsById.TryGetValue(
                item.ParentId.Value,
                out var parent)
                    ? parent.WbsCode
                    : $"missing:{item.ParentId.Value}";
        }

        private static bool HasDependenciesChanged(
            IEnumerable<PlanningVersionDependency>
                versionDependencies,
            IEnumerable<TaskDependency> currentDependencies)
        {
            var versionSet = versionDependencies
                .Select(d => string.Join(
                    "|",
                    d.OriginalPredecessorTaskId,
                    d.OriginalSuccessorTaskId,
                    Escape(d.Type),
                    d.OffsetDays))
                .ToHashSet(StringComparer.Ordinal);

            var currentSet = currentDependencies
                .Select(d => string.Join(
                    "|",
                    d.PredecessorId,
                    d.SuccessorId,
                    Escape(d.Type),
                    d.OffsetDays))
                .ToHashSet(StringComparer.Ordinal);

            return !versionSet.SetEquals(currentSet);
        }

        private static bool HasAssignmentsChanged(
            IEnumerable<PlanningVersionAssignment>
                versionAssignments,
            IEnumerable<ResourceAssignment> currentAssignments)
        {
            var versionSet = versionAssignments
                .Select(a => string.Join(
                    "|",
                    a.OriginalTaskId,
                    NullableInt(a.OriginalResourceId),
                    NullableInt(a.OriginalResourceGroupId),
                    DecimalText(a.WorkloadHours),
                    a.AllocationPercent))
                .ToHashSet(StringComparer.Ordinal);

            var currentSet = currentAssignments
                .Select(a => string.Join(
                    "|",
                    a.TaskId,
                    NullableInt(a.ResourceId),
                    NullableInt(a.ResourceGroupId),
                    DecimalText(a.WorkloadHours),
                    a.AllocationPercent))
                .ToHashSet(StringComparer.Ordinal);

            return !versionSet.SetEquals(currentSet);
        }

        private static bool HasCalendarChanged(
            PlanningVersionCalendar? versionCalendar,
            ProjectCalendar? currentCalendar)
        {
            if (versionCalendar is null && currentCalendar is null)
            {
                return false;
            }

            if (versionCalendar is null || currentCalendar is null)
            {
                return true;
            }

            if (versionCalendar.WorkMonday !=
                    currentCalendar.WorkMonday ||
                versionCalendar.WorkTuesday !=
                    currentCalendar.WorkTuesday ||
                versionCalendar.WorkWednesday !=
                    currentCalendar.WorkWednesday ||
                versionCalendar.WorkThursday !=
                    currentCalendar.WorkThursday ||
                versionCalendar.WorkFriday !=
                    currentCalendar.WorkFriday ||
                versionCalendar.WorkSaturday !=
                    currentCalendar.WorkSaturday ||
                versionCalendar.WorkSunday !=
                    currentCalendar.WorkSunday)
            {
                return true;
            }

            var versionExceptions = versionCalendar.Exceptions
                .Select(e => string.Join(
                    "|",
                    DateText(e.Date),
                    Escape(e.Label),
                    e.IsWorkingDay))
                .ToHashSet(StringComparer.Ordinal);

            var currentExceptions = currentCalendar.Exceptions
                .Select(e => string.Join(
                    "|",
                    DateText(e.Date),
                    Escape(e.Label),
                    e.IsWorkingDay))
                .ToHashSet(StringComparer.Ordinal);

            if (!versionExceptions.SetEquals(currentExceptions))
            {
                return true;
            }

            var versionPeriods = versionCalendar.Periods
                .Select(p => string.Join(
                    "|",
                    DateText(p.StartDate),
                    DateText(p.EndDate),
                    Escape(p.Label)))
                .ToHashSet(StringComparer.Ordinal);

            var currentPeriods = currentCalendar.Periods
                .Select(p => string.Join(
                    "|",
                    DateText(p.StartDate),
                    DateText(p.EndDate),
                    Escape(p.Label)))
                .ToHashSet(StringComparer.Ordinal);

            return !versionPeriods.SetEquals(currentPeriods);
        }

        private static PlanningVersionTaskStateResponse
            MapVersionTaskState(PlanningVersionTask task)
        {
            return new PlanningVersionTaskStateResponse
            {
                TaskId = task.OriginalTaskId,
                Title = task.Title,
                Description = task.Description,
                StartDate = task.StartDate,
                EndDate = task.EndDate,
                Duration = task.Duration,
                ProgressPercent = task.ProgressPercent,
                IsDone = task.IsDone,
                ActualDuration = task.ActualDuration,
                AssignedResourcesCount =
                    task.AssignedResourcesCount,
                WorkloadHours = task.WorkloadHours,
                EarlyStart = task.EarlyStart,
                EarlyFinish = task.EarlyFinish,
                LateStart = task.LateStart,
                LateFinish = task.LateFinish,
                TotalFloat = task.TotalFloat,
                IsCritical = task.IsCritical,
                Deadline = task.Deadline,
                DelayDays = task.DelayDays,
                IsLate = task.IsLate
            };
        }

        private static PlanningVersionTaskStateResponse
            MapCurrentTaskState(PlannerTask task)
        {
            return new PlanningVersionTaskStateResponse
            {
                TaskId = task.Id,
                Title = task.Title,
                Description = task.Description,
                StartDate = task.StartDate,
                EndDate = task.EndDate,
                Duration = task.Duration,
                ProgressPercent = task.ProgressPercent,
                IsDone = task.IsDone,
                ActualDuration = task.ActualDuration,
                AssignedResourcesCount =
                    task.AssignedResourcesCount,
                WorkloadHours = task.WorkloadHours,
                EarlyStart = task.EarlyStart,
                EarlyFinish = task.EarlyFinish,
                LateStart = task.LateStart,
                LateFinish = task.LateFinish,
                TotalFloat = task.TotalFloat,
                IsCritical = task.IsCritical,
                Deadline = task.Deadline,
                DelayDays = task.DelayDays,
                IsLate = task.IsLate
            };
        }

        private static PlanningVersionTask MapTaskSnapshot(
            PlannerTask task)
        {
            return new PlanningVersionTask
            {
                OriginalTaskId = task.Id,
                Title = task.Title,
                Description = task.Description,
                StartDate = task.StartDate,
                EndDate = task.EndDate,
                Duration = task.Duration,
                ProgressPercent = task.ProgressPercent,
                IsDone = task.IsDone,
                ActualDuration = task.ActualDuration,
                AssignedResourcesCount =
                    task.AssignedResourcesCount,
                WorkloadHours = task.WorkloadHours,
                EarlyStart = task.EarlyStart,
                EarlyFinish = task.EarlyFinish,
                LateStart = task.LateStart,
                LateFinish = task.LateFinish,
                TotalFloat = task.TotalFloat,
                IsCritical = task.IsCritical,
                Deadline = task.Deadline,
                DelayDays = task.DelayDays,
                IsLate = task.IsLate
            };
        }

        private static PlanningVersionItem MapItemSnapshot(
            PlanningItem item)
        {
            return new PlanningVersionItem
            {
                OriginalPlanningItemId = item.Id,
                OriginalParentId = item.ParentId,
                Name = item.Name,
                Type = item.Type,
                SortOrder = item.SortOrder,
                WbsCode = item.WbsCode,
                OriginalTaskId = item.TaskId
            };
        }

        private static PlanningVersionDependency
            MapDependencySnapshot(TaskDependency dependency)
        {
            return new PlanningVersionDependency
            {
                OriginalDependencyId = dependency.Id,
                OriginalPredecessorTaskId =
                    dependency.PredecessorId,
                OriginalSuccessorTaskId =
                    dependency.SuccessorId,
                Type = dependency.Type,
                OffsetDays = dependency.OffsetDays
            };
        }

        private static PlanningVersionAssignment
            MapAssignmentSnapshot(ResourceAssignment assignment)
        {
            return new PlanningVersionAssignment
            {
                OriginalAssignmentId = assignment.Id,
                OriginalTaskId = assignment.TaskId,
                OriginalResourceId = assignment.ResourceId,
                ResourceName = assignment.Resource?.Name,
                OriginalResourceGroupId =
                    assignment.ResourceGroupId,
                ResourceGroupName =
                    assignment.ResourceGroup?.Name,
                WorkloadHours = assignment.WorkloadHours,
                AllocationPercent = assignment.AllocationPercent
            };
        }

        private static PlanningVersionCalendar MapCalendarSnapshot(
            ProjectCalendar calendar)
        {
            return new PlanningVersionCalendar
            {
                WorkMonday = calendar.WorkMonday,
                WorkTuesday = calendar.WorkTuesday,
                WorkWednesday = calendar.WorkWednesday,
                WorkThursday = calendar.WorkThursday,
                WorkFriday = calendar.WorkFriday,
                WorkSaturday = calendar.WorkSaturday,
                WorkSunday = calendar.WorkSunday,
                Exceptions = calendar.Exceptions
                    .OrderBy(e => e.Date)
                    .Select(e =>
                        new PlanningVersionCalendarException
                        {
                            Date = e.Date,
                            Label = e.Label,
                            IsWorkingDay = e.IsWorkingDay
                        })
                    .ToList(),
                Periods = calendar.Periods
                    .OrderBy(p => p.StartDate)
                    .ThenBy(p => p.EndDate)
                    .Select(p =>
                        new PlanningVersionCalendarPeriod
                        {
                            StartDate = p.StartDate,
                            EndDate = p.EndDate,
                            Label = p.Label
                        })
                    .ToList()
            };
        }

        private static PlanningVersionSummaryResponse MapSummary(
            PlanningVersion version)
        {
            return new PlanningVersionSummaryResponse
            {
                Id = version.Id,
                ProjectId = version.ProjectId,
                VersionNumber = version.VersionNumber,
                Name = version.Name,
                Description = version.Description,
                CreatedBy = version.CreatedBy,
                CreatedAt = version.CreatedAt,
                TaskCount = version.Tasks.Count,
                ItemCount = version.Items.Count,
                DependencyCount = version.Dependencies.Count,
                AssignmentCount = version.Assignments.Count,
                HasCalendar = version.Calendar != null
            };
        }

        private static PlanningVersionDetailResponse MapDetail(
            PlanningVersion version)
        {
            return new PlanningVersionDetailResponse
            {
                Id = version.Id,
                ProjectId = version.ProjectId,
                VersionNumber = version.VersionNumber,
                Name = version.Name,
                Description = version.Description,
                CreatedBy = version.CreatedBy,
                CreatedAt = version.CreatedAt,
                Tasks = version.Tasks
                    .OrderBy(t => t.OriginalTaskId)
                    .Select(t => new PlanningVersionTaskResponse
                    {
                        OriginalTaskId = t.OriginalTaskId,
                        Title = t.Title,
                        Description = t.Description,
                        StartDate = t.StartDate,
                        EndDate = t.EndDate,
                        Duration = t.Duration,
                        ProgressPercent = t.ProgressPercent,
                        IsDone = t.IsDone,
                        ActualDuration = t.ActualDuration,
                        AssignedResourcesCount =
                            t.AssignedResourcesCount,
                        WorkloadHours = t.WorkloadHours,
                        EarlyStart = t.EarlyStart,
                        EarlyFinish = t.EarlyFinish,
                        LateStart = t.LateStart,
                        LateFinish = t.LateFinish,
                        TotalFloat = t.TotalFloat,
                        IsCritical = t.IsCritical,
                        Deadline = t.Deadline,
                        DelayDays = t.DelayDays,
                        IsLate = t.IsLate
                    })
                    .ToList(),
                Items = version.Items
                    .OrderBy(i => i.OriginalParentId)
                    .ThenBy(i => i.SortOrder)
                    .ThenBy(i => i.OriginalPlanningItemId)
                    .Select(i => new PlanningVersionItemResponse
                    {
                        OriginalPlanningItemId =
                            i.OriginalPlanningItemId,
                        OriginalParentId = i.OriginalParentId,
                        Name = i.Name,
                        Type = i.Type,
                        SortOrder = i.SortOrder,
                        WbsCode = i.WbsCode,
                        OriginalTaskId = i.OriginalTaskId
                    })
                    .ToList(),
                Dependencies = version.Dependencies
                    .OrderBy(d => d.OriginalDependencyId)
                    .Select(d =>
                        new PlanningVersionDependencyResponse
                        {
                            OriginalDependencyId =
                                d.OriginalDependencyId,
                            OriginalPredecessorTaskId =
                                d.OriginalPredecessorTaskId,
                            OriginalSuccessorTaskId =
                                d.OriginalSuccessorTaskId,
                            Type = d.Type,
                            OffsetDays = d.OffsetDays
                        })
                    .ToList(),
                Assignments = version.Assignments
                    .OrderBy(a => a.OriginalAssignmentId)
                    .Select(a =>
                        new PlanningVersionAssignmentResponse
                        {
                            OriginalAssignmentId =
                                a.OriginalAssignmentId,
                            OriginalTaskId =
                                a.OriginalTaskId,
                            OriginalResourceId =
                                a.OriginalResourceId,
                            ResourceName = a.ResourceName,
                            OriginalResourceGroupId =
                                a.OriginalResourceGroupId,
                            ResourceGroupName =
                                a.ResourceGroupName,
                            WorkloadHours =
                                a.WorkloadHours,
                            AllocationPercent =
                                a.AllocationPercent
                        })
                    .ToList(),
                Calendar = version.Calendar is null
                    ? null
                    : new PlanningVersionCalendarResponse
                    {
                        WorkMonday =
                            version.Calendar.WorkMonday,
                        WorkTuesday =
                            version.Calendar.WorkTuesday,
                        WorkWednesday =
                            version.Calendar.WorkWednesday,
                        WorkThursday =
                            version.Calendar.WorkThursday,
                        WorkFriday =
                            version.Calendar.WorkFriday,
                        WorkSaturday =
                            version.Calendar.WorkSaturday,
                        WorkSunday =
                            version.Calendar.WorkSunday,
                        Exceptions = version.Calendar.Exceptions
                            .OrderBy(e => e.Date)
                            .Select(e =>
                                new PlanningVersionCalendarExceptionResponse
                                {
                                    Date = e.Date,
                                    Label = e.Label,
                                    IsWorkingDay =
                                        e.IsWorkingDay
                                })
                            .ToList(),
                        Periods = version.Calendar.Periods
                            .OrderBy(p => p.StartDate)
                            .ThenBy(p => p.EndDate)
                            .Select(p =>
                                new PlanningVersionCalendarPeriodResponse
                                {
                                    StartDate =
                                        p.StartDate,
                                    EndDate = p.EndDate,
                                    Label = p.Label
                                })
                            .ToList()
                    }
            };
        }

        private static string? NormalizeOptionalText(string? value)
        {
            var normalized = value?.Trim();

            return string.IsNullOrWhiteSpace(normalized)
                ? null
                : normalized;
        }

        private static string NullableInt(int? value)
        {
            return value?.ToString(CultureInfo.InvariantCulture)
                ?? "null";
        }

        private static string DecimalText(decimal value)
        {
            return value.ToString(
                "0.############################",
                CultureInfo.InvariantCulture);
        }

        private static string DateText(DateTime value)
        {
            return value.Date.ToString(
                "yyyy-MM-dd",
                CultureInfo.InvariantCulture);
        }

        private static string Escape(string? value)
        {
            return value?
                .Replace("\\", "\\\\", StringComparison.Ordinal)
                .Replace("|", "\\|", StringComparison.Ordinal)
                ?? string.Empty;
        }
    }
}