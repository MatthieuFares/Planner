using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.DTOs.ProjectInterop;
using PlannerAPI.Models;

namespace PlannerAPI.Services.ProjectInterop
{
    /// <summary>
    /// Construit le modèle pivot ProjectInteropModel à partir
    /// d'un projet Planner existant.
    ///
    /// Aucun XML n'est généré ici :
    /// BDD Planner -> ProjectInteropModel -> MicrosoftProjectXmlWriter.
    /// </summary>
    public class ProjectInteropExportService
    {
        private readonly AppDbContext _context;

        public ProjectInteropExportService(
            AppDbContext context)
        {
            _context = context;
        }

        public async Task<ProjectInteropModel> BuildModelAsync(
            int projectId,
            CancellationToken cancellationToken = default)
        {
            var project = await _context.Projects
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    p => p.Id == projectId,
                    cancellationToken);

            if (project == null)
            {
                throw new InvalidOperationException(
                    $"Projet avec l'id {projectId} introuvable.");
            }

            var tasks = await _context.Tasks
                .AsNoTracking()
                .Where(t => t.ProjectId == projectId)
                .OrderBy(t => t.StartDate)
                .ThenBy(t => t.Id)
                .ToListAsync(cancellationToken);

            var planningItems = await _context.PlanningItems
                .AsNoTracking()
                .Where(i => i.ProjectId == projectId)
                .OrderBy(i => i.SortOrder)
                .ThenBy(i => i.Id)
                .ToListAsync(cancellationToken);

            var dependencies = await _context.TaskDependencies
                .AsNoTracking()
                .Where(d =>
                    d.Predecessor != null &&
                    d.Successor != null &&
                    d.Predecessor.ProjectId == projectId &&
                    d.Successor.ProjectId == projectId)
                .OrderBy(d => d.Id)
                .ToListAsync(cancellationToken);

            var assignments = await _context.ResourceAssignments
                .AsNoTracking()
                .Include(a => a.Resource)
                .Include(a => a.Task)
                .Where(a =>
                    a.Task != null &&
                    a.Task.ProjectId == projectId)
                .OrderBy(a => a.Id)
                .ToListAsync(cancellationToken);

            var calendar = await _context.ProjectCalendars
                .AsNoTracking()
                .Include(c => c.Exceptions)
                .Include(c => c.Periods)
                .FirstOrDefaultAsync(
                    c => c.ProjectId == projectId,
                    cancellationToken);

            var taskStartDates = tasks
                .Where(t => t.StartDate.HasValue)
                .Select(t => t.StartDate!.Value)
                .ToList();

            var taskEndDates = tasks
                .Where(t => t.EndDate.HasValue)
                .Select(t => t.EndDate!.Value)
                .ToList();

            var exportStartDate =
                taskStartDates.Count > 0
                    ? taskStartDates.Min()
                    : project.StartDate;

            var exportEndDate =
                taskEndDates.Count > 0
                    ? taskEndDates.Max()
                    : project.EndDate;

            var model = new ProjectInteropModel
            {
                Project = new ProjectInteropProject
                {
                    Name = project.Name,
                    Description = project.Description,
                    ClientName = project.ClientName,
                    ProjectCode = project.ProjectCode,
                    StartDate = exportStartDate,
                    EndDate = exportEndDate,
                    HoursPerDay = 8m,
                    HoursPerWeek = 40m,
                    DaysPerMonth = 20
                },
                Calendar = BuildCalendar(calendar)
            };

            var orderedItems =
                OrderItemsByHierarchy(planningItems);

            var sourceTasksById =
                tasks.ToDictionary(t => t.Id);

            var externalUidByTaskId =
                new Dictionary<int, int>();

            var externalUidByPlanningItemId =
                new Dictionary<int, int>();

            var nextTaskUid = 1;
            var nextExternalId = 1;

            foreach (var item in orderedItems)
            {
                var externalUid = nextTaskUid++;
                externalUidByPlanningItemId[item.Id] =
                    externalUid;

                if (item.Type == PlanningItemType.Task)
                {
                    if (!item.TaskId.HasValue ||
                        !sourceTasksById.TryGetValue(
                            item.TaskId.Value,
                            out var plannerTask))
                    {
                        model.Warnings.Add(
                            new ProjectInteropWarning
                            {
                                Code =
                                    "PLANNING_ITEM_TASK_MISSING",
                                Message =
                                    $"L'élément WBS « {item.Name} » "
                                    + "ne référence plus une tâche Planner valide "
                                    + "et n'a pas été exporté comme tâche.",
                                Severity = "Warning",
                                EntityType = "PlanningItem",
                                EntityName = item.Name
                            });

                        continue;
                    }

                    externalUidByTaskId[
                        plannerTask.Id] = externalUid;

                    model.Tasks.Add(
                        BuildLeafTask(
                            plannerTask,
                            item,
                            externalUid,
                            nextExternalId++,
                            model.Calendar.ExternalUid));
                }
                else
                {
                    model.Tasks.Add(
                        BuildSummaryTask(
                            item,
                            externalUid,
                            nextExternalId++,
                            model.Calendar.ExternalUid));
                }
            }

            // Sécurité : une tâche Planner ancienne/non synchronisée
            // ne doit pas disparaître silencieusement de l'export.
            var exportedTaskIds =
                externalUidByTaskId.Keys.ToHashSet();

            var nextRootWbs =
                GetNextRootWbsNumber(planningItems);

            foreach (var task in tasks
                         .Where(t => !exportedTaskIds.Contains(t.Id))
                         .OrderBy(t => t.StartDate)
                         .ThenBy(t => t.Id))
            {
                var externalUid = nextTaskUid++;
                externalUidByTaskId[task.Id] =
                    externalUid;

                var wbs =
                    $"{nextRootWbs++}";

                model.Tasks.Add(
                    new ProjectInteropTask
                    {
                        ExternalUid = externalUid,
                        ExternalId = nextExternalId++,
                        Name = task.Title,
                        Description = task.Description,
                        OutlineNumber = wbs,
                        OutlineLevel = 1,
                        IsSummary = false,
                        IsMilestone =
                            (task.Duration ?? 1) <= 0,
                        StartDate = task.StartDate,
                        EndDate = task.EndDate,
                        DurationDays =
                            Math.Max(1, task.Duration ?? 1),
                        ProgressPercent =
                            Math.Clamp(
                                task.ProgressPercent,
                                0,
                                100),
                        ActualDurationDays =
                            task.ActualDuration,
                        WorkloadHours =
                            task.WorkloadHours,
                        Deadline = task.Deadline,
                        CalendarUid =
                            model.Calendar.ExternalUid
                    });

                model.Warnings.Add(
                    new ProjectInteropWarning
                    {
                        Code =
                            "TASK_WITHOUT_PLANNING_ITEM_EXPORTED",
                        Message =
                            $"La tâche « {task.Title} » n'avait pas "
                            + "d'élément WBS associé. Elle a été exportée "
                            + $"à la racine avec le WBS {wbs}.",
                        Severity = "Warning",
                        EntityType = "Task",
                        EntityName = task.Title
                    });
            }

            BuildDependencies(
                model,
                dependencies,
                externalUidByTaskId);

            await BuildResourcesAndAssignmentsAsync(
                model,
                assignments,
                externalUidByTaskId,
                cancellationToken);

            AddProjectMetadataWarning(model);

            return model;
        }

        private static ProjectInteropCalendar BuildCalendar(
            ProjectCalendar? source)
        {
            if (source == null)
            {
                return new ProjectInteropCalendar
                {
                    ExternalUid = 1,
                    Name = "Calendrier Planner",
                    WorkMonday = true,
                    WorkTuesday = true,
                    WorkWednesday = true,
                    WorkThursday = true,
                    WorkFriday = true,
                    WorkSaturday = false,
                    WorkSunday = false
                };
            }

            return new ProjectInteropCalendar
            {
                ExternalUid = 1,
                Name = "Calendrier Planner",
                WorkMonday = source.WorkMonday,
                WorkTuesday = source.WorkTuesday,
                WorkWednesday = source.WorkWednesday,
                WorkThursday = source.WorkThursday,
                WorkFriday = source.WorkFriday,
                WorkSaturday = source.WorkSaturday,
                WorkSunday = source.WorkSunday,
                Exceptions = source.Exceptions
                    .OrderBy(e => e.Date)
                    .Select(e =>
                        new ProjectInteropCalendarException
                        {
                            Date = e.Date.Date,
                            Label = e.Label,
                            IsWorkingDay =
                                e.IsWorkingDay
                        })
                    .ToList(),
                Periods = source.Periods
                    .OrderBy(p => p.StartDate)
                    .ThenBy(p => p.EndDate)
                    .Select(p =>
                        new ProjectInteropCalendarPeriod
                        {
                            StartDate =
                                p.StartDate.Date,
                            EndDate =
                                p.EndDate.Date,
                            Label = p.Label
                        })
                    .ToList()
            };
        }

        private static ProjectInteropTask BuildSummaryTask(
            PlanningItem item,
            int externalUid,
            int externalId,
            int? calendarUid)
        {
            return new ProjectInteropTask
            {
                ExternalUid = externalUid,
                ExternalId = externalId,
                Name = item.Name,
                OutlineNumber = item.WbsCode,
                OutlineLevel =
                    GetOutlineLevel(item.WbsCode),
                IsSummary = true,
                IsMilestone = false,
                DurationDays = 0,
                ProgressPercent = 0,
                CalendarUid = calendarUid
            };
        }

        private static ProjectInteropTask BuildLeafTask(
            PlannerTask task,
            PlanningItem item,
            int externalUid,
            int externalId,
            int? calendarUid)
        {
            var duration =
                task.Duration ?? 1;

            return new ProjectInteropTask
            {
                ExternalUid = externalUid,
                ExternalId = externalId,
                Name = task.Title,
                Description = task.Description,
                OutlineNumber = item.WbsCode,
                OutlineLevel =
                    GetOutlineLevel(item.WbsCode),
                IsSummary = false,
                IsMilestone = duration <= 0,
                StartDate = task.StartDate,
                EndDate = task.EndDate,
                DurationDays =
                    Math.Max(1, duration),
                ProgressPercent =
                    Math.Clamp(
                        task.ProgressPercent,
                        0,
                        100),
                ActualDurationDays =
                    task.ActualDuration,
                WorkloadHours =
                    task.WorkloadHours,
                Deadline = task.Deadline,
                CalendarUid = calendarUid
            };
        }

        private static void BuildDependencies(
            ProjectInteropModel model,
            IEnumerable<TaskDependency> dependencies,
            IReadOnlyDictionary<int, int>
                externalUidByTaskId)
        {
            foreach (var dependency in dependencies)
            {
                if (!externalUidByTaskId.TryGetValue(
                        dependency.PredecessorId,
                        out var predecessorUid))
                {
                    continue;
                }

                if (!externalUidByTaskId.TryGetValue(
                        dependency.SuccessorId,
                        out var successorUid))
                {
                    continue;
                }

                model.Dependencies.Add(
                    new ProjectInteropDependency
                    {
                        PredecessorTaskUid =
                            predecessorUid,
                        SuccessorTaskUid =
                            successorUid,
                        Type =
                            NormalizeDependencyType(
                                dependency.Type),
                        OffsetDays =
                            dependency.OffsetDays,
                        IsCrossProject = false
                    });
            }
        }

        private async Task BuildResourcesAndAssignmentsAsync(
            ProjectInteropModel model,
            IReadOnlyList<ResourceAssignment> assignments,
            IReadOnlyDictionary<int, int>
                externalUidByTaskId,
            CancellationToken cancellationToken)
        {
            var resourceUidByPlannerId =
                new Dictionary<int, int>();

            var nextResourceUid = 1;
            var nextAssignmentUid = 1;

            async Task<int> EnsureResourceAsync(
                Resource resource)
            {
                if (resourceUidByPlannerId.TryGetValue(
                        resource.Id,
                        out var existingUid))
                {
                    return existingUid;
                }

                var uid = nextResourceUid++;
                resourceUidByPlannerId[
                    resource.Id] = uid;

                model.Resources.Add(
                    new ProjectInteropResource
                    {
                        ExternalUid = uid,
                        ExternalId = uid,
                        Name = resource.Name,
                        Type =
                            NormalizeResourceType(
                                resource.Type),
                        CapacityHoursPerWeek =
                            resource.CapacityHoursPerWeek,
                        CostPerHour =
                            resource.CostPerHour
                    });

                return uid;
            }

            foreach (var assignment in assignments)
            {
                if (!externalUidByTaskId.TryGetValue(
                        assignment.TaskId,
                        out var taskUid))
                {
                    continue;
                }

                if (assignment.ResourceId.HasValue)
                {
                    var resource =
                        assignment.Resource;

                    if (resource == null)
                    {
                        resource =
                            await _context.Resources
                                .AsNoTracking()
                                .FirstOrDefaultAsync(
                                    r =>
                                        r.Id
                                        == assignment.ResourceId.Value,
                                    cancellationToken);
                    }

                    if (resource == null)
                        continue;

                    var resourceUid =
                        await EnsureResourceAsync(
                            resource);

                    model.Assignments.Add(
                        new ProjectInteropAssignment
                        {
                            ExternalUid =
                                nextAssignmentUid++,
                            TaskUid = taskUid,
                            ResourceUid =
                                resourceUid,
                            WorkloadHours =
                                assignment.WorkloadHours,
                            AllocationPercent =
                                Math.Clamp(
                                    assignment.AllocationPercent,
                                    1,
                                    100),
                            ProgressPercent =
                                assignment.Task?.ProgressPercent
                        });

                    continue;
                }

                if (!assignment.ResourceGroupId.HasValue)
                    continue;

                var members =
                    await _context.ResourceGroupMembers
                        .AsNoTracking()
                        .Include(m => m.Resource)
                        .Where(m =>
                            m.ResourceGroupId
                            == assignment.ResourceGroupId.Value)
                        .OrderBy(m => m.ResourceId)
                        .ToListAsync(cancellationToken);

                var validMembers =
                    members
                        .Where(m => m.Resource != null)
                        .ToList();

                if (validMembers.Count == 0)
                {
                    model.Warnings.Add(
                        new ProjectInteropWarning
                        {
                            Code =
                                "EMPTY_RESOURCE_GROUP_SKIPPED",
                            Message =
                                $"Une assignation de groupe sur la tâche UID "
                                + $"{taskUid} n'a aucun membre exploitable "
                                + "et n'a pas été exportée.",
                            Severity = "Warning",
                            EntityType = "Assignment"
                        });

                    continue;
                }

                var workloadPerMember =
                    assignment.WorkloadHours
                    / validMembers.Count;

                foreach (var member in validMembers)
                {
                    var resourceUid =
                        await EnsureResourceAsync(
                            member.Resource!);

                    model.Assignments.Add(
                        new ProjectInteropAssignment
                        {
                            ExternalUid =
                                nextAssignmentUid++,
                            TaskUid = taskUid,
                            ResourceUid =
                                resourceUid,
                            WorkloadHours =
                                Math.Round(
                                    workloadPerMember,
                                    2),
                            AllocationPercent =
                                Math.Clamp(
                                    assignment.AllocationPercent,
                                    1,
                                    100),
                            ProgressPercent =
                                assignment.Task?.ProgressPercent
                        });
                }

                model.Warnings.Add(
                    new ProjectInteropWarning
                    {
                        Code =
                            "RESOURCE_GROUP_EXPANDED",
                        Message =
                            $"Une assignation de groupe a été développée "
                            + $"en {validMembers.Count} assignation(s) "
                            + "de ressources individuelles pour l'export MSPDI.",
                        Severity = "Warning",
                        EntityType = "Assignment"
                    });
            }
        }

        private static List<PlanningItem>
            OrderItemsByHierarchy(
                IReadOnlyList<PlanningItem> items)
        {
            var ordered =
                new List<PlanningItem>();

            var visited =
                new HashSet<int>();

            void AddChildren(int? parentId)
            {
                var children =
                    items
                        .Where(i =>
                            i.ParentId == parentId)
                        .OrderBy(i =>
                            i.SortOrder)
                        .ThenBy(i => i.Id)
                        .ToList();

                foreach (var child in children)
                {
                    if (!visited.Add(child.Id))
                        continue;

                    ordered.Add(child);
                    AddChildren(child.Id);
                }
            }

            AddChildren(null);

            foreach (var remaining in
                     items
                         .Where(i =>
                             !visited.Contains(i.Id))
                         .OrderBy(i => i.SortOrder)
                         .ThenBy(i => i.Id))
            {
                if (!visited.Add(remaining.Id))
                    continue;

                ordered.Add(remaining);
                AddChildren(remaining.Id);
            }

            return ordered;
        }

        private static int GetOutlineLevel(
            string? wbsCode)
        {
            if (string.IsNullOrWhiteSpace(wbsCode))
                return 1;

            return Math.Max(
                1,
                wbsCode.Split(
                    '.',
                    StringSplitOptions.RemoveEmptyEntries)
                .Length);
        }

        private static int GetNextRootWbsNumber(
            IReadOnlyList<PlanningItem> items)
        {
            var max = 0;

            foreach (var item in items
                         .Where(i =>
                             i.ParentId == null))
            {
                var firstPart =
                    item.WbsCode?
                        .Split('.')
                        .FirstOrDefault();

                if (int.TryParse(
                        firstPart,
                        out var value))
                {
                    max = Math.Max(max, value);
                }
            }

            return max + 1;
        }

        private static string NormalizeDependencyType(
            string? value)
        {
            return value?
                .Trim()
                .ToUpperInvariant() switch
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
            if (string.Equals(
                    value,
                    "Material",
                    StringComparison.OrdinalIgnoreCase))
            {
                return "Material";
            }

            if (string.Equals(
                    value,
                    "Team",
                    StringComparison.OrdinalIgnoreCase))
            {
                return "Team";
            }

            return "Person";
        }

        private static void AddProjectMetadataWarning(
            ProjectInteropModel model)
        {
            if (string.IsNullOrWhiteSpace(
                    model.Project.ProjectCode)
                && string.IsNullOrWhiteSpace(
                    model.Project.ClientName))
            {
                return;
            }

            model.Warnings.Add(
                new ProjectInteropWarning
                {
                    Code =
                        "PLANNER_PROJECT_METADATA_NOT_NATIVE_MSPDI",
                    Message =
                        "Le code projet et le nom client sont conservés "
                        + "dans le modèle Planner, mais ne sont pas encore "
                        + "exportés comme champs personnalisés MSPDI.",
                    Severity = "Warning",
                    EntityType = "Project",
                    EntityName =
                        model.Project.Name
                });
        }
    }
}