using System.Globalization;
using System.Xml;
using System.Xml.Linq;
using PlannerAPI.DTOs.ProjectInterop;

namespace PlannerAPI.Services.ProjectInterop
{
    /// <summary>
    /// Parse un fichier Microsoft Project XML / MSPDI vers le modèle pivot Planner.
    /// Cette classe ne touche jamais à la base de données.
    /// </summary>
    public class MicrosoftProjectXmlParser
    {
        public async Task<ProjectInteropModel> ParseAsync(
            Stream xmlStream,
            CancellationToken cancellationToken = default)
        {
            if (xmlStream == null)
                throw new ArgumentNullException(nameof(xmlStream));

            var settings = new XmlReaderSettings
            {
                Async = true,
                DtdProcessing = DtdProcessing.Prohibit,
                XmlResolver = null,
                IgnoreComments = true,
                IgnoreProcessingInstructions = true
            };

            using var reader = XmlReader.Create(xmlStream, settings);

            XDocument document;

            try
            {
                document = await XDocument.LoadAsync(
                    reader,
                    LoadOptions.None,
                    cancellationToken);
            }
            catch (XmlException ex)
            {
                throw new InvalidOperationException(
                    "Le fichier XML est invalide ou illisible.",
                    ex);
            }

            var root = document.Root;

            if (root == null ||
                !string.Equals(
                    root.Name.LocalName,
                    "Project",
                    StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    "Le fichier ne contient pas un projet Microsoft Project XML / MSPDI valide.");
            }

            var model = new ProjectInteropModel();

            ParseProject(root, model);
            ParseCalendar(root, model);
            ParseTasks(root, model);
            ParseResources(root, model);
            ParseAssignments(root, model);
            ParseDependencies(root, model);

            AddCrossChecks(model);

            return model;
        }

        private static void ParseProject(
            XElement root,
            ProjectInteropModel model)
        {
            var minutesPerDay =
                ReadInt(root, "MinutesPerDay") ?? 480;

            var minutesPerWeek =
                ReadInt(root, "MinutesPerWeek") ?? 2400;

            var daysPerMonth =
                ReadInt(root, "DaysPerMonth") ?? 20;

            if (minutesPerDay <= 0)
                minutesPerDay = 480;

            if (minutesPerWeek <= 0)
                minutesPerWeek = 2400;

            if (daysPerMonth <= 0)
                daysPerMonth = 20;

            var title = ReadString(root, "Title");
            var fileName = ReadString(root, "Name");

            var projectName = !string.IsNullOrWhiteSpace(title)
                ? title.Trim()
                : NormalizeProjectFileName(fileName);

            if (string.IsNullOrWhiteSpace(projectName))
            {
                projectName = "Projet importé";

                AddWarning(
                    model,
                    code: "PROJECT_NAME_MISSING",
                    message:
                        "Le XML ne contient pas de nom de projet exploitable. "
                        + "Le nom « Projet importé » sera proposé.");
            }

            model.Project = new ProjectInteropProject
            {
                Name = projectName,
                Description =
                    ReadString(root, "Comments")
                    ?? ReadString(root, "Subject"),
                StartDate =
                    ReadDateTime(root, "StartDate")
                    ?? ReadDateTime(root, "Start"),
                EndDate =
                    ReadDateTime(root, "FinishDate")
                    ?? ReadDateTime(root, "Finish"),
                HoursPerDay =
                    Math.Round(minutesPerDay / 60m, 4),
                HoursPerWeek =
                    Math.Round(minutesPerWeek / 60m, 4),
                DaysPerMonth = daysPerMonth
            };
        }

        private static void ParseCalendar(
            XElement root,
            ProjectInteropModel model)
        {
            var calendarsContainer =
                Child(root, "Calendars");

            if (calendarsContainer == null)
            {
                model.Calendar = new ProjectInteropCalendar();

                AddWarning(
                    model,
                    code: "CALENDAR_MISSING",
                    message:
                        "Aucun calendrier n'a été trouvé. "
                        + "Le calendrier Planner lundi-vendredi sera utilisé.",
                    entityType: "Calendar");

                return;
            }

            var calendars = Children(
                    calendarsContainer,
                    "Calendar")
                .ToList();

            if (calendars.Count == 0)
            {
                model.Calendar = new ProjectInteropCalendar();

                AddWarning(
                    model,
                    code: "CALENDAR_MISSING",
                    message:
                        "Aucun calendrier exploitable n'a été trouvé. "
                        + "Le calendrier Planner lundi-vendredi sera utilisé.",
                    entityType: "Calendar");

                return;
            }

            var requestedCalendarUid =
                ReadInt(root, "CalendarUID");

            XElement? selectedCalendar = null;

            if (requestedCalendarUid.HasValue)
            {
                selectedCalendar = calendars.FirstOrDefault(
                    c =>
                        ReadInt(c, "UID")
                        == requestedCalendarUid.Value);
            }

            selectedCalendar ??=
                calendars.FirstOrDefault(
                    c => ReadBool(c, "IsBaseCalendar") == true);

            selectedCalendar ??= calendars[0];

            var selectedUid =
                ReadInt(selectedCalendar, "UID");

            model.Calendar = new ProjectInteropCalendar
            {
                ExternalUid = selectedUid,
                Name = ReadString(selectedCalendar, "Name")
            };

            ParseWeekDays(
                selectedCalendar,
                model.Calendar,
                model);

            ParseCalendarExceptions(
                selectedCalendar,
                model.Calendar,
                model);

            var workWeeks = Descendants(
                    selectedCalendar,
                    "WorkWeek")
                .Any();

            if (workWeeks)
            {
                AddWarning(
                    model,
                    code: "CALENDAR_WORKWEEKS_UNSUPPORTED",
                    message:
                        "Le calendrier contient des semaines de travail spécifiques. "
                        + "Elles ne sont pas reproduites dans le MVP Planner.",
                    entityType: "Calendar",
                    entityName: model.Calendar.Name,
                    externalUid: selectedUid);
            }

            if (calendars.Count > 1)
            {
                AddWarning(
                    model,
                    code: "MULTIPLE_CALENDARS",
                    message:
                        $"Le XML contient {calendars.Count} calendriers. "
                        + $"Planner utilisera « {model.Calendar.Name ?? "calendrier principal"} » "
                        + "comme calendrier projet.",
                    entityType: "Calendar",
                    entityName: model.Calendar.Name,
                    externalUid: selectedUid);
            }
        }

        private static void ParseWeekDays(
            XElement calendarElement,
            ProjectInteropCalendar calendar,
            ProjectInteropModel model)
        {
            var weekDaysContainer =
                Child(calendarElement, "WeekDays");

            if (weekDaysContainer == null)
                return;

            foreach (var weekDay in
                     Children(weekDaysContainer, "WeekDay"))
            {
                var dayType =
                    ReadInt(weekDay, "DayType");

                if (!dayType.HasValue ||
                    dayType.Value == 0)
                {
                    continue;
                }

                var dayWorking =
                    ReadBool(weekDay, "DayWorking");

                if (!dayWorking.HasValue)
                    continue;

                SetWorkingDay(
                    calendar,
                    dayType.Value,
                    dayWorking.Value);

                if (Descendants(
                        weekDay,
                        "WorkingTime")
                    .Any())
                {
                    AddWarning(
                        model,
                        code: "WORKING_TIMES_IGNORED",
                        message:
                            "Des plages horaires détaillées sont présentes "
                            + "dans le calendrier. Planner conserve le jour ouvré "
                            + "ou non ouvré, mais pas les horaires intra-journée.",
                        entityType: "Calendar",
                        entityName: calendar.Name,
                        externalUid: calendar.ExternalUid);
                }
            }
        }

        private static void ParseCalendarExceptions(
            XElement calendarElement,
            ProjectInteropCalendar calendar,
            ProjectInteropModel model)
        {
            var exceptionsContainer =
                Child(calendarElement, "Exceptions");

            if (exceptionsContainer == null)
                return;

            foreach (var exception in
                     Children(
                         exceptionsContainer,
                         "Exception"))
            {
                var name =
                    ReadString(exception, "Name")
                    ?? "Exception importée";

                var dayWorking =
                    ReadBool(exception, "DayWorking")
                    ?? false;

                var type =
                    ReadInt(exception, "Type");

                var timePeriod =
                    Child(exception, "TimePeriod");

                var from =
                    timePeriod == null
                        ? null
                        : ReadDateTime(
                            timePeriod,
                            "FromDate");

                var to =
                    timePeriod == null
                        ? null
                        : ReadDateTime(
                            timePeriod,
                            "ToDate");

                if (!from.HasValue ||
                    !to.HasValue)
                {
                    AddWarning(
                        model,
                        code: "CALENDAR_EXCEPTION_DATES_MISSING",
                        message:
                            $"L'exception « {name} » n'a pas de période exploitable "
                            + "et a été ignorée.",
                        entityType: "CalendarException",
                        entityName: name);

                    continue;
                }

                var start =
                    from.Value.Date;

                var end =
                    to.Value.Date;

                if (end < start)
                {
                    (start, end) = (end, start);
                }

                var recurring =
                    type.HasValue &&
                    type.Value != 1 &&
                    type.Value != 9;

                if (recurring)
                {
                    AddWarning(
                        model,
                        code: "RECURRING_CALENDAR_EXCEPTION_FLATTENED",
                        message:
                            $"L'exception récurrente « {name} » est importée "
                            + "uniquement sur la période explicitement présente dans le XML.",
                        entityType: "CalendarException",
                        entityName: name);
                }

                if (start == end)
                {
                    AddCalendarException(
                        calendar,
                        new ProjectInteropCalendarException
                        {
                            Date = start,
                            Label = name,
                            IsWorkingDay = dayWorking
                        });

                    continue;
                }

                if (!dayWorking)
                {
                    calendar.Periods.Add(
                        new ProjectInteropCalendarPeriod
                        {
                            StartDate = start,
                            EndDate = end,
                            Label = name
                        });

                    continue;
                }

                var spanDays =
                    (end - start).Days + 1;

                if (spanDays > 366)
                {
                    AddWarning(
                        model,
                        code: "WORKING_EXCEPTION_RANGE_TOO_LONG",
                        message:
                            $"La période ouvrée exceptionnelle « {name} » couvre "
                            + $"{spanDays} jours et n'a pas été développée jour par jour.",
                        entityType: "CalendarException",
                        entityName: name);

                    continue;
                }

                for (var date = start;
                     date <= end;
                     date = date.AddDays(1))
                {
                    AddCalendarException(
                        calendar,
                        new ProjectInteropCalendarException
                        {
                            Date = date,
                            Label = name,
                            IsWorkingDay = true
                        });
                }
            }
        }

        private static void ParseTasks(
            XElement root,
            ProjectInteropModel model)
        {
            var tasksContainer =
                Child(root, "Tasks");

            if (tasksContainer == null)
            {
                AddWarning(
                    model,
                    code: "TASKS_MISSING",
                    message:
                        "Le fichier ne contient aucune collection de tâches.",
                    entityType: "Task");

                return;
            }

            var hoursPerDay =
                model.Project.HoursPerDay > 0
                    ? model.Project.HoursPerDay
                    : 8m;

            foreach (var taskElement in
                     Children(tasksContainer, "Task"))
            {
                var uid =
                    ReadInt(taskElement, "UID");

                if (!uid.HasValue)
                {
                    AddWarning(
                        model,
                        code: "TASK_UID_MISSING",
                        message:
                            "Une tâche sans UID a été ignorée.",
                        entityType: "Task",
                        entityName:
                            ReadString(
                                taskElement,
                                "Name"));

                    continue;
                }

                // UID 0 est généralement la tâche récapitulative du projet.
                if (uid.Value == 0)
                    continue;

                if (ReadBool(
                        taskElement,
                        "IsNull")
                    == true)
                {
                    continue;
                }

                var name =
                    ReadString(taskElement, "Name");

                if (string.IsNullOrWhiteSpace(name))
                {
                    name = $"Tâche {uid.Value}";

                    AddWarning(
                        model,
                        code: "TASK_NAME_MISSING",
                        message:
                            $"La tâche UID {uid.Value} n'a pas de nom. "
                            + $"« {name} » sera utilisé.",
                        entityType: "Task",
                        entityName: name,
                        externalUid: uid.Value);
                }

                var isSummary =
                    ReadBool(
                        taskElement,
                        "Summary")
                    ?? false;

                var isMilestone =
                    ReadBool(
                        taskElement,
                        "Milestone")
                    ?? false;

                var duration =
                    ParseDuration(
                        ReadString(
                            taskElement,
                            "Duration"));

                var actualDuration =
                    ParseDuration(
                        ReadString(
                            taskElement,
                            "ActualDuration"));

                var work =
                    ParseDuration(
                        ReadString(
                            taskElement,
                            "Work"));

                var durationDays =
                    ConvertDurationToPlannerDays(
                        duration,
                        hoursPerDay,
                        allowZero: isMilestone);

                int? actualDurationDays =
                    actualDuration.HasValue
                        ? ConvertDurationToPlannerDays(
                            actualDuration,
                            hoursPerDay,
                            allowZero: true)
                        : null;

                var task = new ProjectInteropTask
                {
                    ExternalUid = uid.Value,
                    ExternalId =
                        ReadInt(taskElement, "ID"),
                    Name = name.Trim(),
                    Description =
                        ReadString(
                            taskElement,
                            "Notes"),
                    OutlineNumber =
                        ReadString(
                            taskElement,
                            "OutlineNumber")
                        ?? ReadString(
                            taskElement,
                            "WBS"),
                    OutlineLevel =
                        Math.Max(
                            0,
                            ReadInt(
                                taskElement,
                                "OutlineLevel")
                            ?? 0),
                    IsSummary = isSummary,
                    IsMilestone = isMilestone,
                    StartDate =
                        ReadDateTime(
                            taskElement,
                            "Start"),
                    EndDate =
                        ReadDateTime(
                            taskElement,
                            "Finish"),
                    DurationDays =
                        durationDays,
                    ProgressPercent =
                        Math.Clamp(
                            ReadInt(
                                taskElement,
                                "PercentComplete")
                            ?? 0,
                            0,
                            100),
                    ActualDurationDays =
                        actualDurationDays,
                    WorkloadHours =
                        work.HasValue
                            ? Math.Round(
                                (decimal)
                                work.Value.TotalHours,
                                2)
                            : null,
                    Deadline =
                        ReadDateTime(
                            taskElement,
                            "Deadline"),
                    CalendarUid =
                        ReadInt(
                            taskElement,
                            "CalendarUID")
                };

                model.Tasks.Add(task);

                if (isMilestone &&
                    durationDays == 0)
                {
                    AddWarning(
                        model,
                        code: "MILESTONE_DETECTED",
                        message:
                            $"La tâche « {task.Name} » est un jalon de durée nulle. "
                            + "Planner devra la normaliser lors de l'import.",
                        entityType: "Task",
                        entityName: task.Name,
                        externalUid: task.ExternalUid);
                }

                if (task.CalendarUid.HasValue &&
                    model.Calendar.ExternalUid.HasValue &&
                    task.CalendarUid.Value !=
                    model.Calendar.ExternalUid.Value)
                {
                    AddWarning(
                        model,
                        code: "TASK_CALENDAR_NOT_PROJECT_CALENDAR",
                        message:
                            $"La tâche « {task.Name} » utilise un calendrier spécifique. "
                            + "Le MVP Planner utilisera le calendrier projet.",
                        entityType: "Task",
                        entityName: task.Name,
                        externalUid: task.ExternalUid);
                }
            }
        }

        private static void ParseDependencies(
            XElement root,
            ProjectInteropModel model)
        {
            var tasksContainer =
                Child(root, "Tasks");

            if (tasksContainer == null)
                return;

            var tasksByUid =
                model.Tasks.ToDictionary(
                    t => t.ExternalUid);

            var minutesPerDay =
                (double)(
                    model.Project.HoursPerDay > 0
                        ? model.Project.HoursPerDay * 60m
                        : 480m);

            foreach (var taskElement in
                     Children(tasksContainer, "Task"))
            {
                var successorUid =
                    ReadInt(taskElement, "UID");

                if (!successorUid.HasValue ||
                    successorUid.Value == 0 ||
                    !tasksByUid.TryGetValue(
                        successorUid.Value,
                        out var successorTask))
                {
                    continue;
                }

                foreach (var link in
                         Children(
                             taskElement,
                             "PredecessorLink"))
                {
                    var predecessorUid =
                        ReadInt(
                            link,
                            "PredecessorUID");

                    if (!predecessorUid.HasValue)
                    {
                        AddWarning(
                            model,
                            code: "DEPENDENCY_PREDECESSOR_MISSING",
                            message:
                                $"Une dépendance de « {successorTask.Name} » "
                                + "n'a pas de PredecessorUID et a été ignorée.",
                            entityType: "Dependency",
                            entityName:
                                successorTask.Name,
                            externalUid:
                                successorTask.ExternalUid);

                        continue;
                    }

                    var crossProject =
                        ReadBool(
                            link,
                            "CrossProject")
                        ?? false;

                    if (crossProject)
                    {
                        AddWarning(
                            model,
                            code: "CROSS_PROJECT_DEPENDENCY_UNSUPPORTED",
                            message:
                                $"La dépendance externe vers « {successorTask.Name} » "
                                + "n'est pas importée dans le MVP Planner.",
                            entityType: "Dependency",
                            entityName:
                                successorTask.Name,
                            externalUid:
                                successorTask.ExternalUid);

                        continue;
                    }

                    if (!tasksByUid.TryGetValue(
                            predecessorUid.Value,
                            out var predecessorTask))
                    {
                        AddWarning(
                            model,
                            code: "DEPENDENCY_PREDECESSOR_NOT_FOUND",
                            message:
                                $"Le prédécesseur UID {predecessorUid.Value} "
                                + $"de « {successorTask.Name} » est introuvable.",
                            entityType: "Dependency",
                            entityName:
                                successorTask.Name,
                            externalUid:
                                successorTask.ExternalUid);

                        continue;
                    }

                    if (predecessorTask.IsSummary ||
                        successorTask.IsSummary)
                    {
                        AddWarning(
                            model,
                            code: "SUMMARY_DEPENDENCY_SKIPPED",
                            message:
                                $"La dépendance « {predecessorTask.Name} » → "
                                + $"« {successorTask.Name} » implique une tâche récapitulative "
                                + "et a été ignorée.",
                            entityType: "Dependency",
                            entityName:
                                successorTask.Name,
                            externalUid:
                                successorTask.ExternalUid);

                        continue;
                    }

                    var rawType =
                        ReadInt(link, "Type")
                        ?? 1;

                    var dependencyType =
                        MapDependencyType(
                            rawType,
                            model,
                            successorTask);

                    var linkLag =
                        ReadLong(
                            link,
                            "LinkLag")
                        ?? 0L;

                    var offsetDays =
                        ConvertLinkLagToDays(
                            linkLag,
                            minutesPerDay,
                            model,
                            successorTask);

                    model.Dependencies.Add(
                        new ProjectInteropDependency
                        {
                            PredecessorTaskUid =
                                predecessorUid.Value,
                            SuccessorTaskUid =
                                successorUid.Value,
                            Type =
                                dependencyType,
                            OffsetDays =
                                offsetDays,
                            IsCrossProject =
                                false,
                            CrossProjectName =
                                ReadString(
                                    link,
                                    "CrossProjectName")
                        });
                }
            }
        }

        private static void ParseResources(
            XElement root,
            ProjectInteropModel model)
        {
            var resourcesContainer =
                Child(root, "Resources");

            if (resourcesContainer == null)
                return;

            foreach (var resourceElement in
                     Children(
                         resourcesContainer,
                         "Resource"))
            {
                var uid =
                    ReadInt(
                        resourceElement,
                        "UID");

                if (!uid.HasValue ||
                    uid.Value == 0)
                {
                    continue;
                }

                if (ReadBool(
                        resourceElement,
                        "IsNull")
                    == true)
                {
                    continue;
                }

                var name =
                    ReadString(
                        resourceElement,
                        "Name");

                if (string.IsNullOrWhiteSpace(name))
                {
                    name =
                        $"Ressource {uid.Value}";
                }

                var rawType =
                    ReadInt(
                        resourceElement,
                        "Type")
                    ?? 1;

                var plannerType =
                    rawType switch
                    {
                        0 => "Material",
                        1 => "Person",
                        2 => "Material",
                        _ => "Person"
                    };

                if (rawType == 2)
                {
                    AddWarning(
                        model,
                        code: "COST_RESOURCE_NORMALIZED",
                        message:
                            $"La ressource de coût « {name} » est importée "
                            + "comme ressource Material dans le modèle intermédiaire.",
                        entityType: "Resource",
                        entityName: name,
                        externalUid: uid.Value);
                }

                var maxUnits =
                    ReadDecimal(
                        resourceElement,
                        "MaxUnits");

                decimal? capacity =
                    maxUnits.HasValue
                        ? Math.Round(
                            Math.Max(
                                0m,
                                maxUnits.Value)
                            * model.Project.HoursPerWeek,
                            2)
                        : null;

                var standardRate =
                    ReadDecimal(
                        resourceElement,
                        "StandardRate");

                var standardRateFormat =
                    ReadInt(
                        resourceElement,
                        "StandardRateFormat")
                    ?? 2;

                var costPerHour =
                    ConvertStandardRateToHourly(
                        standardRate,
                        standardRateFormat,
                        model,
                        name,
                        uid.Value);

                model.Resources.Add(
                    new ProjectInteropResource
                    {
                        ExternalUid =
                            uid.Value,
                        ExternalId =
                            ReadInt(
                                resourceElement,
                                "ID"),
                        Name =
                            name.Trim(),
                        Type =
                            plannerType,
                        CapacityHoursPerWeek =
                            capacity,
                        CostPerHour =
                            costPerHour,
                        Email =
                            ReadString(
                                resourceElement,
                                "EmailAddress"),
                        IsGeneric =
                            ReadBool(
                                resourceElement,
                                "IsGeneric")
                            ?? false
                    });
            }
        }

        private static void ParseAssignments(
            XElement root,
            ProjectInteropModel model)
        {
            var assignmentsContainer =
                Child(root, "Assignments");

            if (assignmentsContainer == null)
                return;

            var tasksByUid =
                model.Tasks.ToDictionary(
                    t => t.ExternalUid);

            var resourcesByUid =
                model.Resources.ToDictionary(
                    r => r.ExternalUid);

            foreach (var assignmentElement in
                     Children(
                         assignmentsContainer,
                         "Assignment"))
            {
                var uid =
                    ReadInt(
                        assignmentElement,
                        "UID")
                    ?? 0;

                var taskUid =
                    ReadInt(
                        assignmentElement,
                        "TaskUID");

                var resourceUid =
                    ReadInt(
                        assignmentElement,
                        "ResourceUID");

                if (!taskUid.HasValue ||
                    !resourceUid.HasValue ||
                    resourceUid.Value == 0)
                {
                    continue;
                }

                if (!tasksByUid.TryGetValue(
                        taskUid.Value,
                        out var task))
                {
                    AddWarning(
                        model,
                        code: "ASSIGNMENT_TASK_NOT_FOUND",
                        message:
                            $"L'affectation UID {uid} référence une tâche inexistante "
                            + $"(UID {taskUid.Value}) et a été ignorée.",
                        entityType: "Assignment",
                        externalUid: uid);

                    continue;
                }

                if (task.IsSummary)
                {
                    AddWarning(
                        model,
                        code: "SUMMARY_ASSIGNMENT_SKIPPED",
                        message:
                            $"Une affectation portée par la tâche récapitulative "
                            + $"« {task.Name} » a été ignorée.",
                        entityType: "Assignment",
                        entityName: task.Name,
                        externalUid: uid);

                    continue;
                }

                if (!resourcesByUid.ContainsKey(
                        resourceUid.Value))
                {
                    AddWarning(
                        model,
                        code: "ASSIGNMENT_RESOURCE_NOT_FOUND",
                        message:
                            $"L'affectation UID {uid} référence une ressource inexistante "
                            + $"(UID {resourceUid.Value}) et a été ignorée.",
                        entityType: "Assignment",
                        externalUid: uid);

                    continue;
                }

                var work =
                    ParseDuration(
                        ReadString(
                            assignmentElement,
                            "Work"));

                var units =
                    ReadDecimal(
                        assignmentElement,
                        "Units")
                    ?? 1m;

                var allocation =
                    (int)Math.Round(
                        units * 100m,
                        MidpointRounding.AwayFromZero);

                if (allocation <= 0)
                {
                    allocation = 1;
                }

                if (allocation > 100)
                {
                    AddWarning(
                        model,
                        code: "ASSIGNMENT_ALLOCATION_CLAMPED",
                        message:
                            $"L'affectation UID {uid} utilise {allocation}% d'allocation. "
                            + "Planner est limité à 100% dans le MVP ; la valeur sera ramenée à 100%.",
                        entityType: "Assignment",
                        externalUid: uid);

                    allocation = 100;
                }

                model.Assignments.Add(
                    new ProjectInteropAssignment
                    {
                        ExternalUid = uid,
                        TaskUid =
                            taskUid.Value,
                        ResourceUid =
                            resourceUid.Value,
                        WorkloadHours =
                            work.HasValue
                                ? Math.Round(
                                    (decimal)
                                    work.Value.TotalHours,
                                    2)
                                : 0m,
                        AllocationPercent =
                            allocation,
                        ProgressPercent =
                            ReadInt(
                                assignmentElement,
                                "PercentWorkComplete")
                    });
            }
        }

        private static void AddCrossChecks(
            ProjectInteropModel model)
        {
            var duplicateTaskUids =
                model.Tasks
                    .GroupBy(t => t.ExternalUid)
                    .Where(g => g.Count() > 1)
                    .Select(g => g.Key)
                    .ToList();

            foreach (var uid in duplicateTaskUids)
            {
                AddWarning(
                    model,
                    code: "DUPLICATE_TASK_UID",
                    message:
                        $"Le XML contient plusieurs tâches avec l'UID {uid}. "
                        + "L'import sera bloqué tant que le fichier n'est pas corrigé.",
                    severity: "Error",
                    entityType: "Task",
                    externalUid: uid);
            }

            var duplicateResourceUids =
                model.Resources
                    .GroupBy(r => r.ExternalUid)
                    .Where(g => g.Count() > 1)
                    .Select(g => g.Key)
                    .ToList();

            foreach (var uid in duplicateResourceUids)
            {
                AddWarning(
                    model,
                    code: "DUPLICATE_RESOURCE_UID",
                    message:
                        $"Le XML contient plusieurs ressources avec l'UID {uid}. "
                        + "L'import sera bloqué tant que le fichier n'est pas corrigé.",
                    severity: "Error",
                    entityType: "Resource",
                    externalUid: uid);
            }

            if (!model.Tasks.Any(
                    t => !t.IsSummary))
            {
                AddWarning(
                    model,
                    code: "NO_LEAF_TASKS",
                    message:
                        "Aucune tâche exécutable n'a été détectée dans le fichier.",
                    severity: "Error",
                    entityType: "Task");
            }
        }

        private static string MapDependencyType(
            int rawType,
            ProjectInteropModel model,
            ProjectInteropTask successorTask)
        {
            return rawType switch
            {
                0 => "FF",
                1 => "FS",
                2 => "SF",
                3 => "SS",
                _ => AddUnknownDependencyTypeWarning(
                    rawType,
                    model,
                    successorTask)
            };
        }

        private static string AddUnknownDependencyTypeWarning(
            int rawType,
            ProjectInteropModel model,
            ProjectInteropTask successorTask)
        {
            AddWarning(
                model,
                code: "DEPENDENCY_TYPE_UNKNOWN",
                message:
                    $"Le type de dépendance {rawType} de « {successorTask.Name} » "
                    + "n'est pas reconnu. FS sera utilisé.",
                entityType: "Dependency",
                entityName: successorTask.Name,
                externalUid: successorTask.ExternalUid);

            return "FS";
        }

        private static int ConvertLinkLagToDays(
            long linkLag,
            double minutesPerDay,
            ProjectInteropModel model,
            ProjectInteropTask successorTask)
        {
            if (linkLag == 0 ||
                minutesPerDay <= 0)
            {
                return 0;
            }

            // MSPDI stocke LinkLag en dixièmes de minute.
            var minutes =
                linkLag / 10d;

            var exactDays =
                minutes / minutesPerDay;

            var roundedDays =
                (int)Math.Round(
                    exactDays,
                    MidpointRounding.AwayFromZero);

            if (Math.Abs(
                    exactDays - roundedDays)
                > 0.0001)
            {
                AddWarning(
                    model,
                    code: "DEPENDENCY_LAG_ROUNDED",
                    message:
                        $"Le décalage de dépendance de « {successorTask.Name} » "
                        + $"correspond à {exactDays:0.##} jour(s). "
                        + $"Planner l'arrondira à {roundedDays} jour(s).",
                    entityType: "Dependency",
                    entityName: successorTask.Name,
                    externalUid: successorTask.ExternalUid);
            }

            return roundedDays;
        }

        private static decimal? ConvertStandardRateToHourly(
            decimal? standardRate,
            int standardRateFormat,
            ProjectInteropModel model,
            string resourceName,
            int resourceUid)
        {
            if (!standardRate.HasValue)
                return null;

            var hoursPerDay =
                model.Project.HoursPerDay > 0
                    ? model.Project.HoursPerDay
                    : 8m;

            var hoursPerWeek =
                model.Project.HoursPerWeek > 0
                    ? model.Project.HoursPerWeek
                    : 40m;

            var hoursPerMonth =
                hoursPerDay
                * Math.Max(
                    1,
                    model.Project.DaysPerMonth);

            decimal hourlyRate;

            switch (standardRateFormat)
            {
                case 1: // minute
                    hourlyRate =
                        standardRate.Value * 60m;
                    break;

                case 2: // heure
                    hourlyRate =
                        standardRate.Value;
                    break;

                case 3: // jour
                    hourlyRate =
                        standardRate.Value / hoursPerDay;
                    break;

                case 4: // semaine
                    hourlyRate =
                        standardRate.Value / hoursPerWeek;
                    break;

                case 5: // mois
                    hourlyRate =
                        standardRate.Value / hoursPerMonth;
                    break;

                case 7: // année
                    hourlyRate =
                        standardRate.Value
                        / (hoursPerWeek * 52m);
                    break;

                case 8: // material / unité
                    AddWarning(
                        model,
                        code: "MATERIAL_RATE_SEMANTICS_DIFFER",
                        message:
                            $"Le taux de la ressource matérielle « {resourceName} » "
                            + "est exprimé par unité dans Project. Planner stocke un coût horaire ; "
                            + "la valeur est conservée telle quelle dans le modèle intermédiaire.",
                        entityType: "Resource",
                        entityName: resourceName,
                        externalUid: resourceUid);

                    hourlyRate =
                        standardRate.Value;
                    break;

                default:
                    AddWarning(
                        model,
                        code: "RESOURCE_RATE_FORMAT_UNKNOWN",
                        message:
                            $"Le format de taux {standardRateFormat} de « {resourceName} » "
                            + "n'est pas reconnu. La valeur est traitée comme un taux horaire.",
                        entityType: "Resource",
                        entityName: resourceName,
                        externalUid: resourceUid);

                    hourlyRate =
                        standardRate.Value;
                    break;
            }

            return Math.Round(
                hourlyRate,
                2);
        }

        private static int ConvertDurationToPlannerDays(
            TimeSpan? duration,
            decimal hoursPerDay,
            bool allowZero)
        {
            if (!duration.HasValue)
                return allowZero ? 0 : 1;

            var hours =
                (decimal)
                duration.Value.TotalHours;

            if (hours <= 0)
                return allowZero ? 0 : 1;

            if (hoursPerDay <= 0)
                hoursPerDay = 8m;

            return Math.Max(
                allowZero ? 0 : 1,
                (int)Math.Ceiling(
                    hours / hoursPerDay));
        }

        private static TimeSpan? ParseDuration(
            string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return null;

            try
            {
                return XmlConvert.ToTimeSpan(
                    value.Trim());
            }
            catch (FormatException)
            {
                return null;
            }
        }

        private static void SetWorkingDay(
            ProjectInteropCalendar calendar,
            int dayType,
            bool isWorking)
        {
            // MSPDI : 1=dimanche, 2=lundi, ... 7=samedi.
            switch (dayType)
            {
                case 1:
                    calendar.WorkSunday =
                        isWorking;
                    break;
                case 2:
                    calendar.WorkMonday =
                        isWorking;
                    break;
                case 3:
                    calendar.WorkTuesday =
                        isWorking;
                    break;
                case 4:
                    calendar.WorkWednesday =
                        isWorking;
                    break;
                case 5:
                    calendar.WorkThursday =
                        isWorking;
                    break;
                case 6:
                    calendar.WorkFriday =
                        isWorking;
                    break;
                case 7:
                    calendar.WorkSaturday =
                        isWorking;
                    break;
            }
        }

        private static void AddCalendarException(
            ProjectInteropCalendar calendar,
            ProjectInteropCalendarException exception)
        {
            var existing =
                calendar.Exceptions.FirstOrDefault(
                    e => e.Date.Date
                         == exception.Date.Date);

            if (existing != null)
            {
                existing.Label =
                    exception.Label;
                existing.IsWorkingDay =
                    exception.IsWorkingDay;
                return;
            }

            calendar.Exceptions.Add(
                exception);
        }

        private static void AddWarning(
            ProjectInteropModel model,
            string code,
            string message,
            string severity = "Warning",
            string? entityType = null,
            string? entityName = null,
            int? externalUid = null)
        {
            // Évite de répéter exactement le même warning pour chaque WorkingTime.
            var alreadyExists =
                model.Warnings.Any(
                    w =>
                        w.Code == code
                        && w.Message == message
                        && w.EntityType == entityType
                        && w.EntityName == entityName
                        && w.ExternalUid == externalUid);

            if (alreadyExists)
                return;

            model.Warnings.Add(
                new ProjectInteropWarning
                {
                    Code = code,
                    Message = message,
                    Severity = severity,
                    EntityType = entityType,
                    EntityName = entityName,
                    ExternalUid = externalUid
                });
        }

        private static XElement? Child(
            XElement parent,
            string localName)
        {
            return parent
                .Elements()
                .FirstOrDefault(
                    e => string.Equals(
                        e.Name.LocalName,
                        localName,
                        StringComparison.OrdinalIgnoreCase));
        }

        private static IEnumerable<XElement> Children(
            XElement parent,
            string localName)
        {
            return parent
                .Elements()
                .Where(
                    e => string.Equals(
                        e.Name.LocalName,
                        localName,
                        StringComparison.OrdinalIgnoreCase));
        }

        private static IEnumerable<XElement> Descendants(
            XElement parent,
            string localName)
        {
            return parent
                .Descendants()
                .Where(
                    e => string.Equals(
                        e.Name.LocalName,
                        localName,
                        StringComparison.OrdinalIgnoreCase));
        }

        private static string? ReadString(
            XElement parent,
            string localName)
        {
            var value =
                Child(parent, localName)?.Value;

            return string.IsNullOrWhiteSpace(value)
                ? null
                : value.Trim();
        }

        private static int? ReadInt(
            XElement parent,
            string localName)
        {
            var value =
                ReadString(parent, localName);

            return int.TryParse(
                value,
                NumberStyles.Integer,
                CultureInfo.InvariantCulture,
                out var result)
                ? result
                : null;
        }

        private static long? ReadLong(
            XElement parent,
            string localName)
        {
            var value =
                ReadString(parent, localName);

            return long.TryParse(
                value,
                NumberStyles.Integer,
                CultureInfo.InvariantCulture,
                out var result)
                ? result
                : null;
        }

        private static decimal? ReadDecimal(
            XElement parent,
            string localName)
        {
            var value =
                ReadString(parent, localName);

            return decimal.TryParse(
                value,
                NumberStyles.Float,
                CultureInfo.InvariantCulture,
                out var result)
                ? result
                : null;
        }

        private static bool? ReadBool(
            XElement parent,
            string localName)
        {
            var value =
                ReadString(parent, localName);

            if (value == null)
                return null;

            if (value == "1")
                return true;

            if (value == "0")
                return false;

            return bool.TryParse(
                value,
                out var result)
                ? result
                : null;
        }

        private static DateTime? ReadDateTime(
            XElement parent,
            string localName)
        {
            var value =
                ReadString(parent, localName);

            if (value == null)
                return null;

            return DateTime.TryParse(
                value,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AllowWhiteSpaces
                | DateTimeStyles.AssumeLocal,
                out var result)
                ? result
                : null;
        }

        private static string NormalizeProjectFileName(
            string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return string.Empty;

            var name =
                value.Trim();

            if (name.EndsWith(
                    ".xml",
                    StringComparison.OrdinalIgnoreCase))
            {
                name =
                    name[..^4];
            }
            else if (name.EndsWith(
                         ".mspdi",
                         StringComparison.OrdinalIgnoreCase))
            {
                name =
                    name[..^6];
            }

            return name.Trim();
        }
    }
}