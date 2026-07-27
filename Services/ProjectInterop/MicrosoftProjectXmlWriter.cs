using System.Globalization;
using System.Xml.Linq;
using PlannerAPI.DTOs.ProjectInterop;

namespace PlannerAPI.Services.ProjectInterop
{
    /// <summary>
    /// Génère un fichier Microsoft Project XML / MSPDI à partir
    /// du modèle pivot Planner.
    ///
    /// Cette classe ne lit pas la base de données :
    /// Planner -> ProjectInteropModel -> MicrosoftProjectXmlWriter -> XML.
    /// </summary>
    public class MicrosoftProjectXmlWriter
    {
        private static readonly XNamespace ProjectNamespace =
            "http://schemas.microsoft.com/project";

        public async Task<byte[]> WriteAsync(
            ProjectInteropModel model,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(model);

            ValidateModel(model);

            var document = BuildDocument(model);

            await using var stream = new MemoryStream();

            await document.SaveAsync(
                stream,
                SaveOptions.None,
                cancellationToken);

            return stream.ToArray();
        }

        public async Task WriteAsync(
            ProjectInteropModel model,
            Stream output,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(model);
            ArgumentNullException.ThrowIfNull(output);

            ValidateModel(model);

            var document = BuildDocument(model);

            await document.SaveAsync(
                output,
                SaveOptions.None,
                cancellationToken);
        }

        private static XDocument BuildDocument(
            ProjectInteropModel model)
        {
            var hoursPerDay =
                model.Project.HoursPerDay > 0
                    ? model.Project.HoursPerDay
                    : 8m;

            var hoursPerWeek =
                model.Project.HoursPerWeek > 0
                    ? model.Project.HoursPerWeek
                    : 40m;

            var daysPerMonth =
                model.Project.DaysPerMonth > 0
                    ? model.Project.DaysPerMonth
                    : 20;

            var calendarUid =
                model.Calendar.ExternalUid.GetValueOrDefault(1);

            if (calendarUid <= 0)
                calendarUid = 1;

            var root = new XElement(
                ProjectNamespace + "Project",

                // SaveVersion est requis par le schéma MSPDI.
                new XElement(
                    ProjectNamespace + "SaveVersion",
                    12),

                new XElement(
                    ProjectNamespace + "Name",
                    BuildXmlFileName(model.Project.Name)),

                new XElement(
                    ProjectNamespace + "Title",
                    SafeText(
                        model.Project.Name,
                        "Projet Planner")),

                OptionalElement(
                    "Subject",
                    model.Project.Description),

                OptionalDateElement(
                    "StartDate",
                    model.Project.StartDate),

                OptionalDateElement(
                    "FinishDate",
                    model.Project.EndDate),

                new XElement(
                    ProjectNamespace + "MinutesPerDay",
                    DecimalToIntegerMinutes(
                        hoursPerDay)),

                new XElement(
                    ProjectNamespace + "MinutesPerWeek",
                    DecimalToIntegerMinutes(
                        hoursPerWeek)),

                new XElement(
                    ProjectNamespace + "DaysPerMonth",
                    daysPerMonth),

                new XElement(
                    ProjectNamespace + "CalendarUID",
                    calendarUid),

                BuildCalendars(
                    model,
                    calendarUid,
                    hoursPerDay),

                BuildTasks(
                    model,
                    calendarUid,
                    hoursPerDay),

                BuildResources(
                    model,
                    hoursPerWeek),

                BuildAssignments(model)
            );

            return new XDocument(
                new XDeclaration(
                    "1.0",
                    "utf-8",
                    null),
                root);
        }

        private static XElement BuildCalendars(
            ProjectInteropModel model,
            int calendarUid,
            decimal hoursPerDay)
        {
            var calendar = model.Calendar;

            var calendarElement = new XElement(
                ProjectNamespace + "Calendar",
                new XElement(
                    ProjectNamespace + "UID",
                    calendarUid),
                new XElement(
                    ProjectNamespace + "Name",
                    SafeText(
                        calendar.Name,
                        "Calendrier Planner")),
                new XElement(
                    ProjectNamespace + "IsBaseCalendar",
                    1),
                BuildWeekDays(
                    calendar,
                    hoursPerDay)
            );

            var exceptionsElement =
                BuildCalendarExceptions(calendar);

            if (exceptionsElement != null)
            {
                calendarElement.Add(
                    exceptionsElement);
            }

            return new XElement(
                ProjectNamespace + "Calendars",
                calendarElement);
        }

        private static XElement BuildWeekDays(
            ProjectInteropCalendar calendar,
            decimal hoursPerDay)
        {
            var weekDays = new XElement(
                ProjectNamespace + "WeekDays");

            AddWeekDay(
                weekDays,
                dayType: 1,
                isWorking: calendar.WorkSunday,
                hoursPerDay: hoursPerDay);

            AddWeekDay(
                weekDays,
                dayType: 2,
                isWorking: calendar.WorkMonday,
                hoursPerDay: hoursPerDay);

            AddWeekDay(
                weekDays,
                dayType: 3,
                isWorking: calendar.WorkTuesday,
                hoursPerDay: hoursPerDay);

            AddWeekDay(
                weekDays,
                dayType: 4,
                isWorking: calendar.WorkWednesday,
                hoursPerDay: hoursPerDay);

            AddWeekDay(
                weekDays,
                dayType: 5,
                isWorking: calendar.WorkThursday,
                hoursPerDay: hoursPerDay);

            AddWeekDay(
                weekDays,
                dayType: 6,
                isWorking: calendar.WorkFriday,
                hoursPerDay: hoursPerDay);

            AddWeekDay(
                weekDays,
                dayType: 7,
                isWorking: calendar.WorkSaturday,
                hoursPerDay: hoursPerDay);

            return weekDays;
        }

        private static void AddWeekDay(
            XElement weekDays,
            int dayType,
            bool isWorking,
            decimal hoursPerDay)
        {
            var weekDay = new XElement(
                ProjectNamespace + "WeekDay",
                new XElement(
                    ProjectNamespace + "DayType",
                    dayType),
                new XElement(
                    ProjectNamespace + "DayWorking",
                    isWorking ? 1 : 0)
            );

            if (isWorking)
            {
                weekDay.Add(
                    BuildWorkingTimes(hoursPerDay));
            }

            weekDays.Add(weekDay);
        }

        private static XElement BuildWorkingTimes(
            decimal hoursPerDay)
        {
            var normalizedHours =
                Math.Clamp(
                    hoursPerDay,
                    1m,
                    12m);

            var morningHours =
                Math.Min(
                    normalizedHours,
                    4m);

            var afternoonHours =
                Math.Max(
                    0m,
                    normalizedHours - morningHours);

            var workingTimes = new XElement(
                ProjectNamespace + "WorkingTimes");

            workingTimes.Add(
                BuildWorkingTime(
                    startHour: 8m,
                    durationHours: morningHours));

            if (afternoonHours > 0)
            {
                workingTimes.Add(
                    BuildWorkingTime(
                        startHour: 13m,
                        durationHours: afternoonHours));
            }

            return workingTimes;
        }

        private static XElement BuildWorkingTime(
            decimal startHour,
            decimal durationHours)
        {
            var fromTime =
                TimeOnlyFromDecimalHours(
                    startHour);

            var toTime =
                TimeOnlyFromDecimalHours(
                    startHour + durationHours);

            return new XElement(
                ProjectNamespace + "WorkingTime",
                new XElement(
                    ProjectNamespace + "FromTime",
                    FormatTime(fromTime)),
                new XElement(
                    ProjectNamespace + "ToTime",
                    FormatTime(toTime))
            );
        }

        private static XElement? BuildCalendarExceptions(
            ProjectInteropCalendar calendar)
        {
            var exceptions =
                new List<XElement>();

            foreach (var exception in
                     calendar.Exceptions
                         .OrderBy(e => e.Date))
            {
                exceptions.Add(
                    BuildCalendarException(
                        name: exception.Label,
                        startDate:
                            exception.Date.Date,
                        endDate:
                            exception.Date.Date,
                        isWorking:
                            exception.IsWorkingDay));
            }

            foreach (var period in
                     calendar.Periods
                         .OrderBy(p => p.StartDate)
                         .ThenBy(p => p.EndDate))
            {
                var start =
                    period.StartDate.Date;

                var end =
                    period.EndDate.Date;

                if (end < start)
                    (start, end) = (end, start);

                exceptions.Add(
                    BuildCalendarException(
                        name: period.Label,
                        startDate: start,
                        endDate: end,
                        isWorking: false));
            }

            if (exceptions.Count == 0)
                return null;

            return new XElement(
                ProjectNamespace + "Exceptions",
                exceptions);
        }

        private static XElement BuildCalendarException(
            string? name,
            DateTime startDate,
            DateTime endDate,
            bool isWorking)
        {
            var exception = new XElement(
                ProjectNamespace + "Exception",
                new XElement(
                    ProjectNamespace + "Name",
                    SafeText(
                        name,
                        "Exception Planner")),
                new XElement(
                    ProjectNamespace + "Type",
                    1),
                new XElement(
                    ProjectNamespace + "DayWorking",
                    isWorking ? 1 : 0),
                new XElement(
                    ProjectNamespace + "TimePeriod",
                    new XElement(
                        ProjectNamespace + "FromDate",
                        FormatDateTime(
                            startDate)),
                    new XElement(
                        ProjectNamespace + "ToDate",
                        FormatDateTime(
                            endDate.Date
                                .AddHours(23)
                                .AddMinutes(59)
                                .AddSeconds(59)))
                )
            );

            if (isWorking)
            {
                exception.Add(
                    BuildWorkingTimes(
                        8m));
            }

            return exception;
        }

        private static XElement BuildTasks(
            ProjectInteropModel model,
            int calendarUid,
            decimal hoursPerDay)
        {
            var tasksElement = new XElement(
                ProjectNamespace + "Tasks");

            tasksElement.Add(
                BuildProjectSummaryTask(model));

            var dependenciesBySuccessor =
                model.Dependencies
                    .GroupBy(
                        dependency =>
                            dependency.SuccessorTaskUid)
                    .ToDictionary(
                        group => group.Key,
                        group => group.ToList());

            var orderedTasks =
                model.Tasks
                    .OrderBy(task =>
                        task.ExternalId
                        ?? int.MaxValue)
                    .ThenBy(task =>
                        task.OutlineNumber,
                        OutlineNumberComparer.Instance)
                    .ThenBy(task =>
                        task.ExternalUid)
                    .ToList();

            var nextId = 1;

            foreach (var task in orderedTasks)
            {
                var taskId =
                    task.ExternalId.HasValue
                    && task.ExternalId.Value > 0
                        ? task.ExternalId.Value
                        : nextId;

                nextId =
                    Math.Max(
                        nextId + 1,
                        taskId + 1);

                var taskElement = new XElement(
                    ProjectNamespace + "Task",

                    new XElement(
                        ProjectNamespace + "UID",
                        task.ExternalUid),

                    new XElement(
                        ProjectNamespace + "ID",
                        taskId),

                    new XElement(
                        ProjectNamespace + "Name",
                        SafeText(
                            task.Name,
                            $"Tâche {task.ExternalUid}")),

                    new XElement(
                        ProjectNamespace + "Type",
                        0),

                    new XElement(
                        ProjectNamespace + "IsNull",
                        0),

                    new XElement(
                        ProjectNamespace + "CreateDate",
                        FormatDateTime(
                            DateTime.Now)),

                    OptionalDateElement(
                        "Start",
                        task.StartDate),

                    OptionalDateElement(
                        "Finish",
                        task.EndDate),

                    new XElement(
                        ProjectNamespace + "Duration",
                        FormatDurationFromDays(
                            task.IsSummary || task.IsMilestone
                                ? 0
                                : Math.Max(
                                    1,
                                    task.DurationDays),
                            hoursPerDay)),

                    new XElement(
                        ProjectNamespace + "DurationFormat",
                        7),

                    new XElement(
                        ProjectNamespace + "Work",
                        FormatDurationFromHours(
                            task.WorkloadHours
                            ?? 0m)),

                    new XElement(
                        ProjectNamespace + "Milestone",
                        task.IsMilestone ? 1 : 0),

                    new XElement(
                        ProjectNamespace + "Summary",
                        task.IsSummary ? 1 : 0),

                    new XElement(
                        ProjectNamespace + "OutlineNumber",
                        SafeText(
                            task.OutlineNumber,
                            taskId.ToString(
                                CultureInfo.InvariantCulture))),

                    new XElement(
                        ProjectNamespace + "OutlineLevel",
                        Math.Max(
                            1,
                            task.OutlineLevel)),

                    new XElement(
                        ProjectNamespace + "PercentComplete",
                        Math.Clamp(
                            task.ProgressPercent,
                            0,
                            100)),

                    new XElement(
                        ProjectNamespace + "PercentWorkComplete",
                        Math.Clamp(
                            task.ProgressPercent,
                            0,
                            100)),

                    OptionalDateElement(
                        "Deadline",
                        task.Deadline),

                    new XElement(
                        ProjectNamespace + "CalendarUID",
                        task.CalendarUid.GetValueOrDefault(
                            calendarUid))
                );

                if (task.ActualDurationDays.HasValue)
                {
                    taskElement.Add(
                        new XElement(
                            ProjectNamespace + "ActualDuration",
                            FormatDurationFromDays(
                                Math.Max(
                                    0,
                                    task.ActualDurationDays.Value),
                                hoursPerDay)));
                }

                if (dependenciesBySuccessor.TryGetValue(
                        task.ExternalUid,
                        out var dependencies))
                {
                    foreach (var dependency in dependencies)
                    {
                        taskElement.Add(
                            BuildPredecessorLink(
                                dependency,
                                hoursPerDay));
                    }
                }

                tasksElement.Add(taskElement);
            }

            return tasksElement;
        }

        private static XElement BuildProjectSummaryTask(
            ProjectInteropModel model)
        {
            return new XElement(
                ProjectNamespace + "Task",
                new XElement(
                    ProjectNamespace + "UID",
                    0),
                new XElement(
                    ProjectNamespace + "ID",
                    0),
                new XElement(
                    ProjectNamespace + "Name",
                    SafeText(
                        model.Project.Name,
                        "Projet Planner")),
                new XElement(
                    ProjectNamespace + "Type",
                    1),
                new XElement(
                    ProjectNamespace + "IsNull",
                    0),
                new XElement(
                    ProjectNamespace + "Summary",
                    1),
                new XElement(
                    ProjectNamespace + "OutlineNumber",
                    0),
                new XElement(
                    ProjectNamespace + "OutlineLevel",
                    0),
                OptionalDateElement(
                    "Start",
                    model.Project.StartDate),
                OptionalDateElement(
                    "Finish",
                    model.Project.EndDate)
            );
        }

        private static XElement BuildPredecessorLink(
            ProjectInteropDependency dependency,
            decimal hoursPerDay)
        {
            var typeValue =
                dependency.Type
                    .Trim()
                    .ToUpperInvariant() switch
                {
                    "FF" => 0,
                    "FS" => 1,
                    "SF" => 2,
                    "SS" => 3,
                    _ => 1
                };

            var minutesPerDay =
                DecimalToIntegerMinutes(
                    hoursPerDay);

            var linkLag =
                dependency.OffsetDays
                * minutesPerDay
                * 10;

            return new XElement(
                ProjectNamespace + "PredecessorLink",
                new XElement(
                    ProjectNamespace + "PredecessorUID",
                    dependency.PredecessorTaskUid),
                new XElement(
                    ProjectNamespace + "Type",
                    typeValue),
                new XElement(
                    ProjectNamespace + "CrossProject",
                    dependency.IsCrossProject ? 1 : 0),
                OptionalElement(
                    "CrossProjectName",
                    dependency.CrossProjectName),
                new XElement(
                    ProjectNamespace + "LinkLag",
                    linkLag),

                // LagFormat = 7 correspond à un décalage exprimé en jours.
                new XElement(
                    ProjectNamespace + "LagFormat",
                    7)
            );
        }

        private static XElement BuildResources(
            ProjectInteropModel model,
            decimal hoursPerWeek)
        {
            if (model.Resources.Count == 0)
            {
                return new XElement(
                    ProjectNamespace + "Resources");
            }

            var resourcesElement = new XElement(
                ProjectNamespace + "Resources");

            foreach (var resource in
                     model.Resources
                         .OrderBy(r =>
                             r.ExternalId
                             ?? int.MaxValue)
                         .ThenBy(r =>
                             r.ExternalUid))
            {
                var typeValue =
                    resource.Type.Equals(
                        "Material",
                        StringComparison.OrdinalIgnoreCase)
                        ? 0
                        : 1;

                decimal maxUnits = 1m;

                if (resource.CapacityHoursPerWeek.HasValue
                    && hoursPerWeek > 0)
                {
                    maxUnits =
                        Math.Max(
                            0m,
                            resource.CapacityHoursPerWeek.Value
                            / hoursPerWeek);
                }

                var resourceElement = new XElement(
                    ProjectNamespace + "Resource",

                    new XElement(
                        ProjectNamespace + "UID",
                        resource.ExternalUid),

                    new XElement(
                        ProjectNamespace + "ID",
                        resource.ExternalId
                        ?? resource.ExternalUid),

                    new XElement(
                        ProjectNamespace + "Name",
                        SafeText(
                            resource.Name,
                            $"Ressource {resource.ExternalUid}")),

                    new XElement(
                        ProjectNamespace + "Type",
                        typeValue),

                    new XElement(
                        ProjectNamespace + "IsNull",
                        0),

                    new XElement(
                        ProjectNamespace + "MaxUnits",
                        maxUnits.ToString(
                            "0.####",
                            CultureInfo.InvariantCulture)),

                    new XElement(
                        ProjectNamespace + "StandardRate",
                        (resource.CostPerHour ?? 0m)
                            .ToString(
                                "0.####",
                                CultureInfo.InvariantCulture)),

                    // 2 = taux horaire.
                    new XElement(
                        ProjectNamespace + "StandardRateFormat",
                        2)
                );

                if (!string.IsNullOrWhiteSpace(
                        resource.Email))
                {
                    resourceElement.Add(
                        new XElement(
                            ProjectNamespace + "EmailAddress",
                            resource.Email.Trim()));
                }

                resourceElement.Add(
                    new XElement(
                        ProjectNamespace + "IsGeneric",
                        resource.IsGeneric ? 1 : 0));

                resourcesElement.Add(
                    resourceElement);
            }

            return resourcesElement;
        }

        private static XElement BuildAssignments(
            ProjectInteropModel model)
        {
            var assignmentsElement = new XElement(
                ProjectNamespace + "Assignments");

            foreach (var assignment in
                     model.Assignments
                         .OrderBy(a => a.ExternalUid))
            {
                var uid =
                    assignment.ExternalUid > 0
                        ? assignment.ExternalUid
                        : BuildFallbackAssignmentUid(
                            assignment);

                assignmentsElement.Add(
                    new XElement(
                        ProjectNamespace + "Assignment",

                        new XElement(
                            ProjectNamespace + "UID",
                            uid),

                        new XElement(
                            ProjectNamespace + "TaskUID",
                            assignment.TaskUid),

                        new XElement(
                            ProjectNamespace + "ResourceUID",
                            assignment.ResourceUid),

                        new XElement(
                            ProjectNamespace + "Units",
                            (Math.Clamp(
                                    assignment.AllocationPercent,
                                    1,
                                    100)
                             / 100m)
                            .ToString(
                                "0.####",
                                CultureInfo.InvariantCulture)),

                        new XElement(
                            ProjectNamespace + "Work",
                            FormatDurationFromHours(
                                Math.Max(
                                    0m,
                                    assignment.WorkloadHours))),

                        new XElement(
                            ProjectNamespace + "PercentWorkComplete",
                            Math.Clamp(
                                assignment.ProgressPercent
                                ?? 0,
                                0,
                                100))
                    )
                );
            }

            return assignmentsElement;
        }

        private static void ValidateModel(
            ProjectInteropModel model)
        {
            if (string.IsNullOrWhiteSpace(
                    model.Project.Name))
            {
                throw new InvalidOperationException(
                    "Le projet à exporter doit avoir un nom.");
            }

            var duplicateTaskUid =
                model.Tasks
                    .GroupBy(t => t.ExternalUid)
                    .FirstOrDefault(g =>
                        g.Key <= 0
                        || g.Count() > 1);

            if (duplicateTaskUid != null)
            {
                throw new InvalidOperationException(
                    "Les UID de tâches du modèle d'interop "
                    + "doivent être uniques et strictement positifs.");
            }

            var duplicateResourceUid =
                model.Resources
                    .GroupBy(r => r.ExternalUid)
                    .FirstOrDefault(g =>
                        g.Key <= 0
                        || g.Count() > 1);

            if (duplicateResourceUid != null)
            {
                throw new InvalidOperationException(
                    "Les UID de ressources du modèle d'interop "
                    + "doivent être uniques et strictement positifs.");
            }

            var taskUids =
                model.Tasks
                    .Select(t => t.ExternalUid)
                    .ToHashSet();

            foreach (var dependency in
                     model.Dependencies)
            {
                if (!taskUids.Contains(
                        dependency.PredecessorTaskUid)
                    || !taskUids.Contains(
                        dependency.SuccessorTaskUid))
                {
                    throw new InvalidOperationException(
                        "Une dépendance référence une tâche "
                        + "absente du modèle d'interop.");
                }
            }

            var resourceUids =
                model.Resources
                    .Select(r => r.ExternalUid)
                    .ToHashSet();

            foreach (var assignment in
                     model.Assignments)
            {
                if (!taskUids.Contains(
                        assignment.TaskUid))
                {
                    throw new InvalidOperationException(
                        "Une assignation référence une tâche "
                        + "absente du modèle d'interop.");
                }

                if (!resourceUids.Contains(
                        assignment.ResourceUid))
                {
                    throw new InvalidOperationException(
                        "Une assignation référence une ressource "
                        + "absente du modèle d'interop.");
                }
            }
        }

        private static XElement? OptionalElement(
            string name,
            string? value)
        {
            return string.IsNullOrWhiteSpace(value)
                ? null
                : new XElement(
                    ProjectNamespace + name,
                    value.Trim());
        }

        private static XElement? OptionalDateElement(
            string name,
            DateTime? value)
        {
            return value.HasValue
                ? new XElement(
                    ProjectNamespace + name,
                    FormatDateTime(
                        value.Value))
                : null;
        }

        private static string FormatDateTime(
            DateTime value)
        {
            return value.ToString(
                "yyyy-MM-dd'T'HH:mm:ss",
                CultureInfo.InvariantCulture);
        }

        private static string FormatTime(
            TimeOnly value)
        {
            return value.ToString(
                "HH:mm:ss",
                CultureInfo.InvariantCulture);
        }

        private static string FormatDurationFromDays(
            int days,
            decimal hoursPerDay)
        {
            if (days <= 0)
                return "PT0H0M0S";

            var hours =
                days
                * Math.Max(
                    1m,
                    hoursPerDay);

            return FormatDurationFromHours(
                hours);
        }

        private static string FormatDurationFromHours(
            decimal hours)
        {
            if (hours <= 0)
                return "PT0H0M0S";

            // Microsoft Project sérialise ses durées de travail sous
            // forme de "Project Time" en heures (ex. PT16H0M0S),
            // y compris au-delà de 24 heures. On évite donc P1D/P2D,
            // qui représentent des jours calendaires ISO 8601.
            var totalSeconds =
                (long)Math.Round(
                    hours * 3600m,
                    MidpointRounding.AwayFromZero);

            var wholeHours =
                totalSeconds / 3600;

            var remainingSeconds =
                totalSeconds % 3600;

            var minutes =
                remainingSeconds / 60;

            var seconds =
                remainingSeconds % 60;

            return string.Create(
                CultureInfo.InvariantCulture,
                $"PT{wholeHours}H{minutes}M{seconds}S");
        }

        private static int DecimalToIntegerMinutes(
            decimal hours)
        {
            return Math.Max(
                1,
                (int)Math.Round(
                    hours * 60m,
                    MidpointRounding.AwayFromZero));
        }

        private static TimeOnly TimeOnlyFromDecimalHours(
            decimal hours)
        {
            var totalMinutes =
                (int)Math.Round(
                    hours * 60m,
                    MidpointRounding.AwayFromZero);

            totalMinutes =
                Math.Clamp(
                    totalMinutes,
                    0,
                    (24 * 60) - 1);

            return new TimeOnly(
                totalMinutes / 60,
                totalMinutes % 60);
        }

        private static int BuildFallbackAssignmentUid(
            ProjectInteropAssignment assignment)
        {
            unchecked
            {
                var value =
                    Math.Abs(
                        HashCode.Combine(
                            assignment.TaskUid,
                            assignment.ResourceUid));

                return value == 0
                    ? 1
                    : value;
            }
        }

        private static string BuildXmlFileName(
            string? projectName)
        {
            var normalized =
                SafeText(
                    projectName,
                    "Projet_Planner");

            var invalid =
                Path.GetInvalidFileNameChars();

            foreach (var character in invalid)
            {
                normalized =
                    normalized.Replace(
                        character,
                        '_');
            }

            normalized =
                normalized.Trim();

            if (!normalized.EndsWith(
                    ".xml",
                    StringComparison.OrdinalIgnoreCase))
            {
                normalized += ".xml";
            }

            return normalized;
        }

        private static string SafeText(
            string? value,
            string fallback)
        {
            return string.IsNullOrWhiteSpace(value)
                ? fallback
                : value.Trim();
        }

        private sealed class OutlineNumberComparer :
            IComparer<string?>
        {
            public static readonly OutlineNumberComparer Instance =
                new();

            public int Compare(
                string? left,
                string? right)
            {
                if (ReferenceEquals(left, right))
                    return 0;

                if (left == null)
                    return 1;

                if (right == null)
                    return -1;

                var leftParts =
                    left.Split('.');
                var rightParts =
                    right.Split('.');

                var max =
                    Math.Max(
                        leftParts.Length,
                        rightParts.Length);

                for (var index = 0;
                     index < max;
                     index++)
                {
                    if (index >= leftParts.Length)
                        return -1;

                    if (index >= rightParts.Length)
                        return 1;

                    var leftNumeric =
                        int.TryParse(
                            leftParts[index],
                            NumberStyles.Integer,
                            CultureInfo.InvariantCulture,
                            out var leftNumber);

                    var rightNumeric =
                        int.TryParse(
                            rightParts[index],
                            NumberStyles.Integer,
                            CultureInfo.InvariantCulture,
                            out var rightNumber);

                    int comparison;

                    if (leftNumeric && rightNumeric)
                    {
                        comparison =
                            leftNumber.CompareTo(
                                rightNumber);
                    }
                    else
                    {
                        comparison =
                            string.Compare(
                                leftParts[index],
                                rightParts[index],
                                StringComparison.OrdinalIgnoreCase);
                    }

                    if (comparison != 0)
                        return comparison;
                }

                return 0;
            }
        }
    }
}