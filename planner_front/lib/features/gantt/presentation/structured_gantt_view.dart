import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../projects/data/project_access_api.dart';
import '../../projects/data/project_access_model.dart';
import '../data/structured_gantt_api.dart';
import '../data/structured_gantt_model.dart';
import '../export/gantt_export_controller.dart';

import '../../project_baseline/data/project_baseline_api.dart';
import '../../project_baseline/data/project_baseline_model.dart';

import '../../project_calendar/data/project_calendar_api.dart';
import '../../project_calendar/data/project_calendar_exception_api.dart';
import '../../project_calendar/data/project_calendar_exception_model.dart';
import '../../project_calendar/data/project_calendar_model.dart';
import '../../project_calendar/data/project_calendar_period_api.dart';
import '../../project_calendar/data/project_calendar_period_model.dart';

import '../../tasks/data/task_api.dart';
import '../../tasks/data/task_model.dart';
import '../../tasks/presentation/task_form_dialog.dart';
import '../../tasks/presentation/task_form_result.dart';
import '../../tasks/presentation/task_edit_dialog.dart';
import '../../tasks/presentation/task_edit_result.dart';

import '../../dependencies/data/dependency_api.dart';
import '../../dependencies/data/dependency_model.dart';

import '../../resources/data/resource_assignment_api.dart';
import '../../resources/data/resource_assignment_model.dart';

String _formatGanttOperationError(Object error) {
  if (error is DioException) {
    final response = error.response;
    final data = response?.data;

    String? backendMessage;

    if (data is String && data.trim().isNotEmpty) {
      backendMessage = data.trim();
    } else if (data is Map) {
      for (final key in const [
        'message',
        'detail',
        'error',
        'title',
      ]) {
        final value = data[key];

        if (value is String && value.trim().isNotEmpty) {
          backendMessage = value.trim();
          break;
        }
      }
    }

    final normalized =
        (backendMessage ?? error.message ?? '').toLowerCase();

    if (normalized.contains('cycle')) {
      return 'Impossible d’ajouter cette dépendance : '
          'elle créerait un cycle dans le planning.';
    }

    if (normalized.contains('dépendance') ||
        normalized.contains('dependance')) {
      return backendMessage ??
          'La dépendance demandée est invalide.';
    }

    if (response?.statusCode == 400) {
      return backendMessage ??
          'La modification demandée est invalide.';
    }

    if (response?.statusCode == 404) {
      return backendMessage ??
          'Un élément nécessaire à la modification est introuvable.';
    }

    if (response?.statusCode != null &&
        response!.statusCode! >= 500) {
      return 'Une erreur serveur est survenue pendant la modification.';
    }

    if (backendMessage != null) {
      return backendMessage;
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Impossible de contacter le serveur. '
          'Vérifie que l’API Planner est démarrée.';
    }
  }

  final raw = error.toString();

  if (raw.toLowerCase().contains('cycle')) {
    return 'Impossible d’ajouter cette dépendance : '
        'elle créerait un cycle dans le planning.';
  }

  return 'La modification n’a pas pu être enregistrée.';
}

enum StructuredGanttDisplayMode {
  auto,
  month,
  quarter,
  year,
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

int _calendarDaysBetween(DateTime start, DateTime end) {
  return _dateOnly(end).difference(_dateOnly(start)).inDays;
}

const double _ganttHeaderHeight = 92;
const double _ganttRowHeight = 48;
const double _ganttLeftPanelBaseWidth = 420;
const double _ganttStartColumnWidth = 82;
const double _ganttEndColumnWidth = 82;
const double _ganttDurationColumnWidth = 58;
const double _ganttProgressColumnWidth = 62;
const double _ganttDeadlineColumnWidth = 82;

const List<String> _planningItemTypes = <String>[
  'Section',
  'Phase',
  'Zone',
  'Floor',
  'Lot',
  'Task',
];

bool _isStructuralPlanningItemType(String type) {
  return type != 'Task';
}

String _planningItemTypeLabel(String type) {
  switch (type) {
    case 'Section':
      return 'Section';
    case 'Phase':
      return 'Phase';
    case 'Zone':
      return 'Zone';
    case 'Floor':
      return 'Étage';
    case 'Lot':
      return 'Lot';
    case 'Task':
      return 'Tâche';
    default:
      return type;
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  final cleanA = _dateOnly(a);
  final cleanB = _dateOnly(b);

  return cleanA.year == cleanB.year &&
      cleanA.month == cleanB.month &&
      cleanA.day == cleanB.day;
}

ProjectCalendarExceptionModel? _findExceptionForDate({
  required DateTime date,
  required List<ProjectCalendarExceptionModel> exceptions,
}) {
  final cleanDate = _dateOnly(date);

  for (final exception in exceptions) {
    if (_isSameDay(exception.date, cleanDate)) {
      return exception;
    }
  }

  return null;
}

ProjectCalendarPeriodModel? _findPeriodForDate({
  required DateTime date,
  required List<ProjectCalendarPeriodModel> periods,
}) {
  final cleanDate = _dateOnly(date);

  for (final period in periods) {
    final startDate = _dateOnly(period.startDate);
    final endDate = _dateOnly(period.endDate);

    if (!cleanDate.isBefore(startDate) && !cleanDate.isAfter(endDate)) {
      return period;
    }
  }

  return null;
}

bool _isWorkingDayForProject({
  required DateTime date,
  required ProjectCalendarModel calendar,
  required List<ProjectCalendarExceptionModel> exceptions,
  required List<ProjectCalendarPeriodModel> periods,
}) {
  final exception = _findExceptionForDate(
    date: date,
    exceptions: exceptions,
  );

  if (exception != null) {
    return exception.isWorkingDay;
  }

  final period = _findPeriodForDate(
    date: date,
    periods: periods,
  );

  if (period != null) {
    return false;
  }

  switch (_dateOnly(date).weekday) {
    case DateTime.monday:
      return calendar.workMonday;
    case DateTime.tuesday:
      return calendar.workTuesday;
    case DateTime.wednesday:
      return calendar.workWednesday;
    case DateTime.thursday:
      return calendar.workThursday;
    case DateTime.friday:
      return calendar.workFriday;
    case DateTime.saturday:
      return calendar.workSaturday;
    case DateTime.sunday:
      return calendar.workSunday;
    default:
      return false;
  }
}

class _StructuredGanttLoadedData {
  final ProjectAccessModel access;
  final StructuredGanttResponse gantt;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;
  final List<ProjectCalendarPeriodModel> periods;
  final List<ProjectBaselineModel> baselines;
  final ProjectBaselineComparisonModel? baselineComparison;
  final int? selectedBaselineId;

  const _StructuredGanttLoadedData({
    required this.access,
    required this.gantt,
    required this.calendar,
    required this.exceptions,
    required this.periods,
    required this.baselines,
    required this.baselineComparison,
    required this.selectedBaselineId,
  });
}


class _CreatePlanningItemDialogResult {
  final String type;
  final String? name;
  final int? parentId;

  const _CreatePlanningItemDialogResult({
    required this.type,
    this.name,
    this.parentId,
  });

  bool get isTask => type == 'Task';
}

class _MovePlanningItemDialogResult {
  final int? newParentId;

  const _MovePlanningItemDialogResult({
    required this.newParentId,
  });
}

class StructuredGanttView extends StatefulWidget {
  final int projectId;

  const StructuredGanttView({
    super.key,
    required this.projectId,
  });

  @override
  State<StructuredGanttView> createState() => _StructuredGanttViewState();
}

class _StructuredGanttViewState extends State<StructuredGanttView> {
  final ProjectAccessApi _projectAccessApi =
      ProjectAccessApi();
  final StructuredGanttApi _ganttApi = StructuredGanttApi();
  final GanttExportController _ganttExportController =
      GanttExportController();
  final TaskApi _taskApi = TaskApi();
  final DependencyApi _dependencyApi = DependencyApi();
  final ResourceAssignmentApi _resourceAssignmentApi = ResourceAssignmentApi();

  final ProjectCalendarApi _calendarApi = ProjectCalendarApi();
  final ProjectCalendarExceptionApi _exceptionApi =
      ProjectCalendarExceptionApi();
  final ProjectCalendarPeriodApi _periodApi =
      ProjectCalendarPeriodApi();
  final ProjectBaselineApi _baselineApi =
      ProjectBaselineApi();

  late Future<_StructuredGanttLoadedData> _ganttFuture;

  double _dayWidth = 24;
  int? _selectedBaselineId;
  bool _showBaselineBars = true;
  StructuredGanttDisplayMode _displayMode =
      StructuredGanttDisplayMode.auto;
  bool _canEditPlanning = false;

  @override
  void initState() {
    super.initState();
    _loadGantt();
  }

  void _loadGantt() {
    _ganttFuture = _loadGanttData();
  }

  Future<_StructuredGanttLoadedData> _loadGanttData() async {
    final access = await _projectAccessApi
        .getProjectAccess(widget.projectId);

    _canEditPlanning = access.canEditPlanning;

    final gantt = await _ganttApi.getStructuredGantt(
      widget.projectId,
    );
    final calendar = await _calendarApi.getByProjectId(
      widget.projectId,
    );
    final exceptions = await _exceptionApi.getByProjectId(
      widget.projectId,
    );
    final periods = await _periodApi.getByProjectId(
      widget.projectId,
    );

    var baselines = <ProjectBaselineModel>[];
    ProjectBaselineComparisonModel? baselineComparison;
    int? resolvedBaselineId = _selectedBaselineId;

    try {
      baselines = await _baselineApi.getByProjectId(
        widget.projectId,
      );

      final baselineWasExplicitlyDisabled =
          resolvedBaselineId == 0;

      if (!baselineWasExplicitlyDisabled) {
        final selectedStillExists = baselines.any(
          (baseline) =>
              baseline.id == resolvedBaselineId,
        );

        if (!selectedStillExists) {
          ProjectBaselineModel? activeBaseline;

          for (final baseline in baselines) {
            if (baseline.isActive) {
              activeBaseline = baseline;
              break;
            }
          }

          resolvedBaselineId = activeBaseline?.id;
        }
      }

      if (resolvedBaselineId != null &&
          resolvedBaselineId > 0) {
        baselineComparison = await _baselineApi.compare(
          resolvedBaselineId,
        );
      }
    } catch (_) {
      // Une erreur de baseline ne doit jamais bloquer
      // le chargement principal du Gantt.
      baselines = <ProjectBaselineModel>[];
      baselineComparison = null;
      resolvedBaselineId = null;
    }

    _selectedBaselineId = resolvedBaselineId;

    return _StructuredGanttLoadedData(
      access: access,
      gantt: gantt,
      calendar: calendar,
      exceptions: exceptions,
      periods: periods,
      baselines: baselines,
      baselineComparison: baselineComparison,
      selectedBaselineId:
          resolvedBaselineId != null &&
                  resolvedBaselineId > 0
              ? resolvedBaselineId
              : null,
    );
  }

  void _changeBaseline(int? baselineId) {
    setState(() {
      // 0 représente volontairement « aucune baseline ».
      _selectedBaselineId = baselineId;
      _loadGantt();
    });
  }

  void _toggleBaselineBars() {
    setState(() {
      _showBaselineBars = !_showBaselineBars;
    });
  }

  void _zoomIn() {
    setState(() {
      _dayWidth = (_dayWidth + 4).clamp(12, 48).toDouble();
    });
  }

  void _zoomOut() {
    setState(() {
      _dayWidth = (_dayWidth - 4).clamp(12, 48).toDouble();
    });
  }

  void _changeDisplayMode(StructuredGanttDisplayMode? mode) {
    if (mode == null) return;

    setState(() {
      _displayMode = mode;
    });
  }

  Future<void> _refreshGantt() async {
    setState(() {
      _loadGantt();
    });
  }

  Future<String> _exportGanttPdf({
    required _StructuredGanttLoadedData loadedData,
    required String fileName,
  }) {
    return _ganttExportController.saveGanttPdf(
      data: loadedData.gantt,
      calendar: loadedData.calendar,
      exceptions: loadedData.exceptions,
      periods: loadedData.periods,
      baselineComparison: loadedData.baselineComparison,
      showBaseline: _showBaselineBars,
      fileName: fileName,
    );
  }

  int _getNextSortOrder({
    required List<StructuredGanttItem> items,
    required int? parentId,
  }) {
    final siblings = items.where((item) => item.parentId == parentId).toList();

    if (siblings.isEmpty) {
      return 1;
    }

    return siblings.fold<int>(
          0,
          (maxSortOrder, item) =>
              item.sortOrder > maxSortOrder ? item.sortOrder : maxSortOrder,
        ) +
        1;
  }

  StructuredGanttItem? _findPlanningItemForTask({
    required List<StructuredGanttItem> items,
    required int taskId,
  }) {
    for (final item in items) {
      if (item.taskId == taskId || item.task?.id == taskId) {
        return item;
      }
    }

    return null;
  }

  PlannerTask _mapStructuredTaskToPlannerTask(StructuredGanttTask task) {
    return PlannerTask(
      id: task.id,
      title: task.title,
      description: null,
      isDone: task.isDone,
      projectId: widget.projectId,
      startDate: task.startDate,
      endDate: task.endDate,
      duration: task.duration,
      workloadHours: task.workloadHours,
      actualDuration: task.actualDuration,
      assignedResourcesCount: task.assignedResourcesCount,
      isCritical: task.isCritical,
      floatValue: task.totalFloat,
      progressPercent: task.progressPercent,
      deadline: task.deadline,
      isLate: task.isLate,
      delayDays: task.delayDays,
    );
  }

  Future<PlannerTask> _loadPlannerTaskForEdit(StructuredGanttTask task) async {
    try {
      final tasks = await _taskApi.getTasksByProject(widget.projectId);

      for (final existingTask in tasks) {
        if (existingTask.id == task.id) {
          return existingTask;
        }
      }
    } catch (_) {
      // Fallback si la liste complète n’est pas disponible.
    }

    return _mapStructuredTaskToPlannerTask(task);
  }

  Future<void> _createTaskRelatedData({
    required PlannerTask createdTask,
    required TaskFormResult result,
  }) async {
    if (result.hasPredecessor) {
      await _dependencyApi.createDependency(
        DependencyCreateRequest(
          predecessorId: result.predecessorTaskId!,
          successorId: createdTask.id,
          type: result.dependencyType,
          offsetDays: result.offsetDays,
        ),
      );
    }

    if (result.hasAssignment) {
      await _resourceAssignmentApi.createAssignment(
        ResourceAssignmentCreateRequest(
          taskId: createdTask.id,
          resourceId: result.resourceId,
          resourceGroupId: result.resourceGroupId,
          workloadHours: result.workloadHours!,
          allocationPercent: result.allocationPercent,
        ),
      );
    }
  }

  Future<void> _syncTasks() async {
    if (!_canEditPlanning) return;

    try {
      await _ganttApi.syncProjectTasks(widget.projectId);

      if (!mounted) return;

      setState(() {
        _loadGantt();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tâches synchronisées avec le Gantt.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur synchronisation : $error'),
        ),
      );
    }
  }

  Future<void> _createTaskUnderParent({
    required int parentId,
  }) async {
    if (!_canEditPlanning) return;

    final result = await showDialog<TaskFormResult>(
      context: context,
      builder: (dialogContext) {
        return TaskFormDialog(projectId: widget.projectId);
      },
    );

    if (!mounted || result == null) return;

    try {
      final createdTask = await _taskApi.createTask(result.taskRequest);

      await _createTaskRelatedData(
        createdTask: createdTask,
        result: result,
      );

      await _ganttApi.syncProjectTasks(widget.projectId);

      final refreshedGantt = await _ganttApi.getStructuredGantt(
        widget.projectId,
      );

      final createdPlanningItem = _findPlanningItemForTask(
        items: refreshedGantt.items,
        taskId: createdTask.id,
      );

      if (!mounted) return;

      if (createdPlanningItem == null) {
        setState(() {
          _loadGantt();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tâche créée, mais impossible de retrouver son élément Gantt.',
            ),
          ),
        );

        return;
      }

      await _ganttApi.movePlanningItem(
        itemId: createdPlanningItem.id,
        newParentId: parentId,
      );

      if (!mounted) return;

      setState(() {
        _loadGantt();
      });

      final details = <String>[];

      if (result.hasPredecessor) {
        details.add('prédécesseur');
      }

      if (result.hasAssignment) {
        details.add('assignation');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            details.isEmpty
                ? 'Tâche "${createdTask.title}" créée dans le Gantt.'
                : 'Tâche "${createdTask.title}" créée dans le Gantt avec ${details.join(' + ')}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur création tâche Gantt : $error'),
        ),
      );
    }
  }

  Future<void> _editTaskFromGantt(
    StructuredGanttItem item,
  ) async {
    if (!_canEditPlanning) return;

    final task = item.task;

    if (task == null) return;

    try {
      final plannerTask = await _loadPlannerTaskForEdit(task);
      final currentGantt = await _ganttApi.getStructuredGantt(
        widget.projectId,
      );

      if (!mounted) return;

      final currentPlanningItem = currentGantt.items.firstWhere(
        (candidate) => candidate.id == item.id,
        orElse: () => item,
      );

      final result = await showDialog<TaskEditResult>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return TaskEditDialog(
            task: plannerTask,
            planningItem: currentPlanningItem,
            planningItems: currentGantt.items,
          );
        },
      );

      if (!mounted || result == null) return;

      await _taskApi.updateTask(
        plannerTask.id,
        result.taskRequest,
      );

      if (item.parentId != result.parentId) {
        await _ganttApi.movePlanningItem(
          itemId: item.id,
          newParentId: result.parentId,
        );
      }

      for (final dependencyId
          in result.dependencyIdsToDelete) {
        await _dependencyApi.deleteDependency(dependencyId);
      }

      for (final action in result.dependenciesToUpdate) {
        await _dependencyApi.updateDependency(
          action.dependencyId,
          action.request,
        );
      }

      for (final request in result.dependenciesToCreate) {
        await _dependencyApi.createDependency(request);
      }

      for (final assignmentId
          in result.assignmentIdsToDelete) {
        await _resourceAssignmentApi.deleteAssignment(
          assignmentId,
        );
      }

      for (final action in result.assignmentsToUpdate) {
        await _resourceAssignmentApi.updateAssignment(
          action.assignmentId,
          action.request,
        );
      }

      for (final request in result.assignmentsToCreate) {
        await _resourceAssignmentApi.createAssignment(
          request,
        );
      }

      await _ganttApi.syncProjectTasks(widget.projectId);

      if (!mounted) return;

      setState(() {
        _loadGantt();
      });

      final changeDetails = <String>[];

      if (item.parentId != result.parentId) {
        changeDetails.add('position');
      }

      if (result.dependencyChangeCount > 0) {
        changeDetails.add(
          '${result.dependencyChangeCount} dépendance(s)',
        );
      }

      if (result.assignmentChangeCount > 0) {
        changeDetails.add(
          '${result.assignmentChangeCount} assignation(s)',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changeDetails.isEmpty
                ? 'Tâche "${result.taskRequest.title}" modifiée.'
                : 'Tâche "${result.taskRequest.title}" modifiée · '
                    '${changeDetails.join(' · ')}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadGantt();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _formatGanttOperationError(error),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _deleteTaskFromGantt(
    StructuredGanttItem item,
  ) async {
    if (!_canEditPlanning) return;

    final task = item.task;

    if (task == null) return;

    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer la tâche'),
          content: Text(
            'Supprimer définitivement la tâche "${task.title}" ?\n\n'
            'Ses dépendances entrantes et sortantes, ses assignations '
            'de ressources et son élément Gantt seront également supprimés.\n\n'
            'Les baselines et versions historiques resteront intactes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmDelete != true) return;

    try {
      await _taskApi.deleteTask(task.id);
      await _ganttApi.syncProjectTasks(widget.projectId);

      if (!mounted) return;

      setState(() {
        _loadGantt();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tâche "${task.title}" supprimée.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadGantt();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _formatGanttOperationError(error),
          ),
          backgroundColor:
              Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _createPlanningItem(
    List<StructuredGanttItem> items,
  ) async {
    if (!_canEditPlanning) return;

    const rootValue = -1;

    final nameController = TextEditingController();
    final structuralParents = items
        .where(
          (item) => _isStructuralPlanningItemType(item.type),
        )
        .toList();

    String selectedType = 'Section';
    int selectedParentValue = rootValue;

    final dialogResult =
        await showDialog<_CreatePlanningItemDialogResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isTask = selectedType == 'Task';
            final selectedTypeLabel =
                _planningItemTypeLabel(selectedType);

            final parentSelectionIsValid = isTask
                ? structuralParents.any(
                    (parent) => parent.id == selectedParentValue,
                  )
                : selectedParentValue == rootValue ||
                    structuralParents.any(
                      (parent) => parent.id == selectedParentValue,
                    );

            if (!parentSelectionIsValid) {
              selectedParentValue = isTask &&
                      structuralParents.isNotEmpty
                  ? structuralParents.first.id
                  : rootValue;
            }

            return AlertDialog(
              title: const Text('Ajouter au Gantt'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _planningItemTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(
                              _planningItemTypeLabel(type),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedType = value;

                            if (selectedType == 'Task') {
                              selectedParentValue =
                                  structuralParents.isEmpty
                                      ? rootValue
                                      : structuralParents.first.id;
                            }
                          });
                        },
                      ),
                      if (!isTask) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText:
                                'Nom du ${selectedTypeLabel.toLowerCase()}',
                            hintText: switch (selectedType) {
                              'Section' => 'Ex : Production MVP',
                              'Phase' => 'Ex : Phase de préparation',
                              'Zone' => 'Ex : Bâtiment A',
                              'Floor' => 'Ex : Étage 2',
                              'Lot' => 'Ex : Électricité',
                              _ => 'Nom de l’élément',
                            },
                            border: const OutlineInputBorder(),
                          ),
                          autofocus: true,
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey<String>(
                          'create-parent-$selectedType-'
                          '$selectedParentValue',
                        ),
                        initialValue: selectedParentValue,
                        decoration: InputDecoration(
                          labelText: isTask
                              ? 'Créer la tâche dans'
                              : 'Parent',
                          helperText: isTask
                              ? 'Une tâche doit avoir un parent structurel.'
                              : 'La racine ou n’importe quel élément structurel.',
                          border: const OutlineInputBorder(),
                        ),
                        items: <DropdownMenuItem<int>>[
                          if (!isTask)
                            const DropdownMenuItem<int>(
                              value: rootValue,
                              child: Text('Racine du projet'),
                            ),
                          ...structuralParents.map((parent) {
                            return DropdownMenuItem<int>(
                              value: parent.id,
                              child: Text(
                                '${parent.wbsCode} · '
                                '${_planningItemTypeLabel(parent.type)} · '
                                '${parent.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: structuralParents.isEmpty && isTask
                            ? null
                            : (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  selectedParentValue = value;
                                });
                              },
                      ),
                      if (isTask &&
                          structuralParents.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Crée d’abord un élément structurel '
                          'avant d’ajouter une tâche.',
                          style: Theme.of(dialogContext)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                      if (isTask) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Le formulaire complet de tâche '
                            's’ouvrira après cette étape.',
                            style: Theme.of(dialogContext)
                                .textTheme
                                .bodySmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: isTask &&
                          structuralParents.isEmpty
                      ? null
                      : () {
                          if (isTask) {
                            if (selectedParentValue ==
                                rootValue) {
                              return;
                            }

                            Navigator.of(dialogContext).pop(
                              _CreatePlanningItemDialogResult(
                                type: selectedType,
                                parentId:
                                    selectedParentValue,
                              ),
                            );
                            return;
                          }

                          final name =
                              nameController.text.trim();

                          if (name.isEmpty) return;

                          Navigator.of(dialogContext).pop(
                            _CreatePlanningItemDialogResult(
                              type: selectedType,
                              name: name,
                              parentId:
                                  selectedParentValue ==
                                          rootValue
                                      ? null
                                      : selectedParentValue,
                            ),
                          );
                        },
                  child: Text(
                    isTask ? 'Continuer' : 'Ajouter',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();

    if (!mounted || dialogResult == null) return;

    if (dialogResult.isTask) {
      await _createTaskUnderParent(
        parentId: dialogResult.parentId!,
      );
      return;
    }

    final sortOrder = _getNextSortOrder(
      items: items,
      parentId: dialogResult.parentId,
    );

    try {
      await _ganttApi.createPlanningItem(
        projectId: widget.projectId,
        name: dialogResult.name!,
        type: dialogResult.type,
        parentId: dialogResult.parentId,
        sortOrder: sortOrder,
      );

      if (!mounted) return;

      setState(() {
        _loadGantt();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_planningItemTypeLabel(dialogResult.type)} '
            'ajouté au Gantt.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur création : $error'),
        ),
      );
    }
  }

  Future<void> _moveItem({
    required StructuredGanttItem item,
    required List<StructuredGanttItem> possibleParents,
  }) async {
    if (!_canEditPlanning) return;

    const rootValue = -1;

    final canMoveToRoot =
        _isStructuralPlanningItemType(item.type);

    int selectedParentValue = item.parentId ??
        (canMoveToRoot
            ? rootValue
            : possibleParents.isEmpty
                ? rootValue
                : possibleParents.first.id);

    final validSelection =
        selectedParentValue == rootValue
            ? canMoveToRoot
            : possibleParents.any(
                (parent) =>
                    parent.id == selectedParentValue,
              );

    if (!validSelection) {
      selectedParentValue = canMoveToRoot
          ? rootValue
          : possibleParents.isEmpty
              ? rootValue
              : possibleParents.first.id;
    }

    final dialogResult =
        await showDialog<_MovePlanningItemDialogResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('Déplacer "${item.name}"'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedParentValue,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau parent',
                        border: OutlineInputBorder(),
                      ),
                      items: <DropdownMenuItem<int>>[
                        if (canMoveToRoot)
                          const DropdownMenuItem<int>(
                            value: rootValue,
                            child: Text('Racine du projet'),
                          ),
                        ...possibleParents.map((parent) {
                          return DropdownMenuItem<int>(
                            value: parent.id,
                            child: Text(
                              '${parent.wbsCode} · '
                              '${_planningItemTypeLabel(parent.type)} · '
                              '${parent.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedParentValue = value;
                        });
                      },
                    ),
                    if (!canMoveToRoot &&
                        possibleParents.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Aucun parent structurel valide '
                        'n’est disponible.',
                        style: Theme.of(dialogContext)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'L’élément lui-même et tous ses '
                        'descendants sont exclus de la liste.',
                        style: Theme.of(dialogContext)
                            .textTheme
                            .bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: !canMoveToRoot &&
                          possibleParents.isEmpty
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(
                            _MovePlanningItemDialogResult(
                              newParentId:
                                  selectedParentValue ==
                                          rootValue
                                      ? null
                                      : selectedParentValue,
                            ),
                          );
                        },
                  child: const Text('Déplacer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || dialogResult == null) return;

    try {
      await _ganttApi.movePlanningItem(
        itemId: item.id,
        newParentId: dialogResult.newParentId,
      );

      if (!mounted) return;

      setState(() {
        _loadGantt();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${item.name}" déplacé avec succès.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur déplacement : $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StructuredGanttLoadedData>(
      future: _ganttFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur Gantt : ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text('Aucune donnée à afficher dans le Gantt.'),
          );
        }

        final loadedData = snapshot.data!;
        final data = loadedData.gantt;

        return _StructuredGanttChart(
          canEdit: loadedData.access.canEditPlanning,
          data: data,
          calendar: loadedData.calendar,
          exceptions: loadedData.exceptions,
          periods: loadedData.periods,
          baselines: loadedData.baselines,
          baselineComparison:
              loadedData.baselineComparison,
          selectedBaselineId:
              loadedData.selectedBaselineId,
          showBaselineBars: _showBaselineBars,
          onBaselineChanged: _changeBaseline,
          onToggleBaselineBars: _toggleBaselineBars,
          dayWidth: _dayWidth,
          displayMode: _displayMode,
          onDisplayModeChanged: _changeDisplayMode,
          onRefresh: _refreshGantt,
          onSyncTasks: _syncTasks,
          onCreateItem: _createPlanningItem,
          onMoveItem: _moveItem,
          onEditTask: _editTaskFromGantt,
          onDeleteTask: _deleteTaskFromGantt,
          onExportPdf: (fileName) => _exportGanttPdf(
            loadedData: loadedData,
            fileName: fileName,
          ),
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
        );
      },
    );
  }
}

class _StructuredGanttChart extends StatefulWidget {
  final bool canEdit;
  final StructuredGanttResponse data;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;
  final List<ProjectCalendarPeriodModel> periods;
  final List<ProjectBaselineModel> baselines;
  final ProjectBaselineComparisonModel? baselineComparison;
  final int? selectedBaselineId;
  final bool showBaselineBars;
  final ValueChanged<int?> onBaselineChanged;
  final VoidCallback onToggleBaselineBars;
  final double dayWidth;
  final StructuredGanttDisplayMode displayMode;
  final ValueChanged<StructuredGanttDisplayMode?> onDisplayModeChanged;
  final VoidCallback onRefresh;
  final Future<void> Function() onSyncTasks;
  final Future<void> Function(List<StructuredGanttItem> items) onCreateItem;
  final Future<void> Function({
    required StructuredGanttItem item,
    required List<StructuredGanttItem> possibleParents,
  }) onMoveItem;
  final Future<void> Function(StructuredGanttItem item) onEditTask;
  final Future<void> Function(StructuredGanttItem item) onDeleteTask;
  final Future<String> Function(String fileName) onExportPdf;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _StructuredGanttChart({
    required this.canEdit,
    required this.data,
    required this.calendar,
    required this.exceptions,
    required this.periods,
    required this.baselines,
    required this.baselineComparison,
    required this.selectedBaselineId,
    required this.showBaselineBars,
    required this.onBaselineChanged,
    required this.onToggleBaselineBars,
    required this.dayWidth,
    required this.displayMode,
    required this.onDisplayModeChanged,
    required this.onRefresh,
    required this.onSyncTasks,
    required this.onCreateItem,
    required this.onMoveItem,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onExportPdf,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  State<_StructuredGanttChart> createState() => _StructuredGanttChartState();
}

class _StructuredGanttChartState extends State<_StructuredGanttChart> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _leftVerticalController = ScrollController();
  final ScrollController _rightVerticalController = ScrollController();

  bool _isSyncingLeft = false;
  bool _isSyncingRight = false;
  bool _isTaskPanelCompact = false;
  bool _isExportingPdf = false;

  bool _showStartColumn = true;
  bool _showEndColumn = true;
  bool _showDurationColumn = true;
  bool _showProgressColumn = true;
  bool _showDeadlineColumn = true;

  int get _visibleDetailColumnCount {
    var count = 0;

    if (_showStartColumn) count++;
    if (_showEndColumn) count++;
    if (_showDurationColumn) count++;
    if (_showProgressColumn) count++;
    if (_showDeadlineColumn) count++;

    return count;
  }

  Future<void> _exportPdf() async {
    if (_isExportingPdf) return;

    final projectCode = widget.data.projectCode.trim();
    final projectName = widget.data.projectName.trim();

    final exportBaseName = projectCode.isNotEmpty
        ? projectCode
        : projectName.isNotEmpty
            ? projectName
            : 'Projet_${widget.data.projectId}';

    final fileNameController = TextEditingController(
      text: '${exportBaseName}_gantt',
    );

    final fileName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined),
              SizedBox(width: 10),
              Text('Exporter le Gantt'),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: fileNameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nom du fichier',
                    hintText: 'Ex. RECETTE-01_gantt',
                    suffixText: '.pdf',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    final trimmed = value.trim();

                    if (trimmed.isNotEmpty) {
                      Navigator.of(dialogContext).pop(trimmed);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  widget.baselineComparison != null &&
                          widget.showBaselineBars
                      ? 'La baseline actuellement affichée sera incluse.'
                      : 'L’export utilisera le planning actuellement chargé.',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () {
                final trimmed = fileNameController.text.trim();

                if (trimmed.isEmpty) return;

                Navigator.of(dialogContext).pop(trimmed);
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('Exporter'),
            ),
          ],
        );
      },
    );

    fileNameController.dispose();

    if (!mounted || fileName == null) return;

    setState(() {
      _isExportingPdf = true;
    });

    try {
      final savedFileName = await widget.onExportPdf(fileName);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gantt exporté : $savedFileName',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur pendant l’export du Gantt : $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
        });
      }
    }
  }

  void _toggleTaskPanel() {
    setState(() {
      _isTaskPanelCompact = !_isTaskPanelCompact;
    });
  }

  Future<void> _showColumnSelector() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateColumn(VoidCallback update) {
              setState(update);
              setDialogState(() {});
            }

            void setAllColumns(bool visible) {
              updateColumn(() {
                _showStartColumn = visible;
                _showEndColumn = visible;
                _showDurationColumn = visible;
                _showProgressColumn = visible;
                _showDeadlineColumn = visible;
              });
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.view_column_outlined),
                  SizedBox(width: 10),
                  Text('Colonnes du Gantt'),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      value: _showStartColumn,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Début'),
                      onChanged: (value) {
                        updateColumn(() {
                          _showStartColumn = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      value: _showEndColumn,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Fin'),
                      onChanged: (value) {
                        updateColumn(() {
                          _showEndColumn = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      value: _showDurationColumn,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Durée'),
                      onChanged: (value) {
                        updateColumn(() {
                          _showDurationColumn = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      value: _showProgressColumn,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Avancement'),
                      onChanged: (value) {
                        updateColumn(() {
                          _showProgressColumn = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      value: _showDeadlineColumn,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Deadline'),
                      onChanged: (value) {
                        updateColumn(() {
                          _showDeadlineColumn = value ?? false;
                        });
                      },
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setAllColumns(false),
                            child: const Text('Masquer tout'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => setAllColumns(true),
                            child: const Text('Tout afficher'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Terminé'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    _leftVerticalController.addListener(() {
      if (_isSyncingRight) return;
      if (!_rightVerticalController.hasClients) return;

      _isSyncingLeft = true;
      _rightVerticalController.jumpTo(_leftVerticalController.offset);
      _isSyncingLeft = false;
    });

    _rightVerticalController.addListener(() {
      if (_isSyncingLeft) return;
      if (!_leftVerticalController.hasClients) return;

      _isSyncingRight = true;
      _leftVerticalController.jumpTo(_rightVerticalController.offset);
      _isSyncingRight = false;
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _leftVerticalController.dispose();
    _rightVerticalController.dispose();
    super.dispose();
  }

  DateTime _startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  DateTime _startOfQuarter(DateTime date) {
    final quarterStartMonth = ((date.month - 1) ~/ 3) * 3 + 1;
    return DateTime(date.year, quarterStartMonth, 1);
  }

  DateTime _endOfQuarter(DateTime date) {
    final quarterStartMonth = ((date.month - 1) ~/ 3) * 3 + 1;
    final nextQuarterStart = DateTime(date.year, quarterStartMonth + 3, 1);
    return nextQuarterStart.subtract(const Duration(days: 1));
  }

  DateTime _startOfYear(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  DateTime _endOfYear(DateTime date) {
    return DateTime(date.year, 12, 31);
  }

  DateTime? _tryReadProjectDate(String fieldName) {
    try {
      final dynamic source = widget.data;

      final dynamic value = fieldName == 'projectStartDate'
          ? source.projectStartDate
          : source.projectEndDate;

      if (value == null) return null;

      if (value is DateTime) {
        return _dateOnly(value);
      }

      if (value is String && value.trim().isNotEmpty) {
        return _dateOnly(DateTime.parse(value));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  ({DateTime start, DateTime end}) _resolveProjectRange(
    List<StructuredGanttItem> taskItems,
  ) {
    final rangeDates = <DateTime>[];

    for (final item in taskItems) {
      final task = item.task;

      if (task == null) continue;

      rangeDates.add(_dateOnly(task.startDate));
      rangeDates.add(_dateOnly(task.endDate));
    }

    final comparison = widget.baselineComparison;

    if (comparison != null) {
      for (final row in comparison.rows) {
        if (row.baselineStartDate != null) {
          rangeDates.add(
            _dateOnly(row.baselineStartDate!),
          );
        }

        if (row.baselineEndDate != null) {
          rangeDates.add(
            _dateOnly(row.baselineEndDate!),
          );
        }
      }
    }

    if (rangeDates.isNotEmpty) {
      final rangeStart = rangeDates.reduce(
        (a, b) => a.isBefore(b) ? a : b,
      );

      final rangeEnd = rangeDates.reduce(
        (a, b) => a.isAfter(b) ? a : b,
      );

      return (
        start: rangeStart,
        end: rangeEnd.isAfter(rangeStart)
            ? rangeEnd
            : rangeStart.add(
                const Duration(days: 30),
              ),
      );
    }

    final fallbackStart =
        _tryReadProjectDate('projectStartDate') ??
            _dateOnly(DateTime.now());

    final fallbackEnd =
        _tryReadProjectDate('projectEndDate');

    return (
      start: fallbackStart,
      end: fallbackEnd != null &&
              fallbackEnd.isAfter(fallbackStart)
          ? fallbackEnd
          : fallbackStart.add(
              const Duration(days: 30),
            ),
    );
  }

  ({DateTime start, DateTime end}) _getVisibleRange({
    required DateTime projectStart,
    required DateTime projectEnd,
  }) {
    final cleanProjectStart = _dateOnly(projectStart);
    final cleanProjectEnd = _dateOnly(projectEnd);

    switch (widget.displayMode) {
      case StructuredGanttDisplayMode.auto:
        final rawDays = _calendarDaysBetween(
          cleanProjectStart,
          cleanProjectEnd,
        );

        if (rawDays < 14) {
          return (
            start: cleanProjectStart.subtract(const Duration(days: 3)),
            end: cleanProjectStart.add(const Duration(days: 18)),
          );
        }

        return (
          start: cleanProjectStart.subtract(const Duration(days: 2)),
          end: cleanProjectEnd.add(const Duration(days: 5)),
        );

      case StructuredGanttDisplayMode.month:
        return (
          start: _startOfMonth(cleanProjectStart),
          end: _endOfMonth(cleanProjectEnd),
        );

      case StructuredGanttDisplayMode.quarter:
        return (
          start: _startOfQuarter(cleanProjectStart),
          end: _endOfQuarter(cleanProjectEnd),
        );

      case StructuredGanttDisplayMode.year:
        return (
          start: _startOfYear(cleanProjectStart),
          end: _endOfYear(cleanProjectEnd),
        );
    }
  }

  String _displayModeLabel(StructuredGanttDisplayMode mode) {
    switch (mode) {
      case StructuredGanttDisplayMode.auto:
        return 'Auto';
      case StructuredGanttDisplayMode.month:
        return 'Mois';
      case StructuredGanttDisplayMode.quarter:
        return 'Trimestre';
      case StructuredGanttDisplayMode.year:
        return 'Année';
    }
  }

  Set<int> _collectDescendantIds({
    required List<StructuredGanttItem> items,
    required int itemId,
  }) {
    final descendantIds = <int>{};
    final pendingIds = <int>[itemId];

    while (pendingIds.isNotEmpty) {
      final currentId = pendingIds.removeLast();

      final children = items.where(
        (candidate) => candidate.parentId == currentId,
      );

      for (final child in children) {
        if (descendantIds.add(child.id)) {
          pendingIds.add(child.id);
        }
      }
    }

    return descendantIds;
  }

  List<StructuredGanttItem> _possibleParentsForItem({
    required List<StructuredGanttItem> items,
    required StructuredGanttItem item,
  }) {
    final descendantIds = _collectDescendantIds(
      items: items,
      itemId: item.id,
    );

    return items.where((candidate) {
      if (!_isStructuralPlanningItemType(candidate.type)) {
        return false;
      }

      if (candidate.id == item.id) {
        return false;
      }

      if (descendantIds.contains(candidate.id)) {
        return false;
      }

      return true;
    }).toList();
  }

  ProjectBaselineComparisonRowModel? _baselineRowForTask(
    int taskId,
  ) {
    final comparison = widget.baselineComparison;

    if (comparison == null) return null;

    for (final row in comparison.rows) {
      if (row.taskId == taskId) {
        return row;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.data.items;

    final taskItems = items.where((item) => item.task != null).toList();

    final resolvedProjectRange = _resolveProjectRange(taskItems);

    final projectStart = resolvedProjectRange.start;
    final projectEnd = resolvedProjectRange.end;

    final visibleRange = _getVisibleRange(
      projectStart: projectStart,
      projectEnd: projectEnd,
    );

    final visibleStart = _dateOnly(visibleRange.start);
    final visibleEnd = _dateOnly(visibleRange.end);

    final totalDaysRaw = _calendarDaysBetween(visibleStart, visibleEnd);
    final totalDays = totalDaysRaw <= 0 ? 1 : totalDaysRaw;

    final chartWidth = (totalDays + 2) * widget.dayWidth;

    var visibleDetailColumnsWidth = 0.0;

    if (_showStartColumn) {
      visibleDetailColumnsWidth += _ganttStartColumnWidth;
    }

    if (_showEndColumn) {
      visibleDetailColumnsWidth += _ganttEndColumnWidth;
    }

    if (_showDurationColumn) {
      visibleDetailColumnsWidth += _ganttDurationColumnWidth;
    }

    if (_showProgressColumn) {
      visibleDetailColumnsWidth += _ganttProgressColumnWidth;
    }

    if (_showDeadlineColumn) {
      visibleDetailColumnsWidth += _ganttDeadlineColumnWidth;
    }

    final taskPanelWidth = _isTaskPanelCompact
        ? _ganttLeftPanelBaseWidth
        : _ganttLeftPanelBaseWidth + visibleDetailColumnsWidth;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Gantt',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${widget.data.projectName} — '
                  '${DateFormat('dd/MM/yyyy').format(visibleStart)} → '
                  '${DateFormat('dd/MM/yyyy').format(visibleEnd)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<StructuredGanttDisplayMode>(
                  initialValue: widget.displayMode,
                  decoration: const InputDecoration(
                    labelText: 'Affichage',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: StructuredGanttDisplayMode.values.map((mode) {
                    return DropdownMenuItem(
                      value: mode,
                      child: Text(_displayModeLabel(mode)),
                    );
                  }).toList(),
                  onChanged: widget.onDisplayModeChanged,
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<int>(
                tooltip: 'Choisir la baseline affichée',
                initialValue:
                    widget.selectedBaselineId ?? 0,
                onSelected: (value) =>
                    widget.onBaselineChanged(value),
                itemBuilder: (context) {
                  return <PopupMenuEntry<int>>[
                    const PopupMenuItem<int>(
                      value: 0,
                      child: Text('Aucune baseline'),
                    ),
                    ...widget.baselines.map((baseline) {
                      return PopupMenuItem<int>(
                        value: baseline.id,
                        child: Row(
                          children: [
                            Icon(
                              baseline.isActive
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                baseline.name,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ];
                },
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 210,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          widget.baselineComparison == null
                              ? 'Baseline'
                              : widget.baselineComparison!
                                  .baselineName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.baselineComparison != null)
                IconButton(
                  tooltip: widget.showBaselineBars
                      ? 'Masquer les barres fantômes'
                      : 'Afficher les barres fantômes',
                  onPressed: widget.onToggleBaselineBars,
                  icon: Icon(
                    widget.showBaselineBars
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showColumnSelector,
                icon: const Icon(Icons.view_column_outlined),
                label: Text('Colonnes ($_visibleDetailColumnCount)'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _toggleTaskPanel,
                icon: Icon(
                  _isTaskPanelCompact
                      ? Icons.view_sidebar_outlined
                      : Icons.view_sidebar,
                ),
                label: Text(
                  _isTaskPanelCompact ? 'Afficher détails' : 'Réduire le volet',
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.onZoomOut,
                icon: const Icon(Icons.zoom_out),
                label: const Text('Zoom -'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.onZoomIn,
                icon: const Icon(Icons.zoom_in),
                label: const Text('Zoom +'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _isExportingPdf ? null : _exportPdf,
                icon: _isExportingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  _isExportingPdf
                      ? 'Export...'
                      : 'Exporter PDF',
                ),
              ),
              if (widget.canEdit) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () =>
                      widget.onCreateItem(items),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.onSyncTasks();
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text(
                    'Synchroniser',
                  ),
                ),
              ],
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Rafraîchir'),
              ),
            ],
          ),
        ),
        if (!widget.canEdit)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              8,
            ),
            child: _ReadOnlyGanttBanner(),
          ),
        if (widget.baselineComparison != null &&
            widget.showBaselineBars)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              8,
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.40),
                    borderRadius:
                        BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Baseline : '
                  '${widget.baselineComparison!.baselineName}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(width: 18),
                Container(
                  width: 28,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                    borderRadius:
                        BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Planning actuel',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],
            ),
          ),
        Expanded(
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: taskPanelWidth,
                child: Column(
                  children: [
                    Container(
                      height: _ganttHeaderHeight,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 60,
                            child: Text(
                              'WBS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Élément',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (!_isTaskPanelCompact &&
                              _showStartColumn)
                            const SizedBox(
                              width: _ganttStartColumnWidth,
                              child: Text(
                                'Début',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (!_isTaskPanelCompact &&
                              _showEndColumn)
                            const SizedBox(
                              width: _ganttEndColumnWidth,
                              child: Text(
                                'Fin',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (!_isTaskPanelCompact &&
                              _showDurationColumn)
                            const SizedBox(
                              width: _ganttDurationColumnWidth,
                              child: Text(
                                'Durée',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (!_isTaskPanelCompact &&
                              _showProgressColumn)
                            const SizedBox(
                              width: _ganttProgressColumnWidth,
                              child: Text(
                                'Avanc.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (!_isTaskPanelCompact &&
                              _showDeadlineColumn)
                            const SizedBox(
                              width: _ganttDeadlineColumnWidth,
                              child: Text(
                                'Deadline',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (widget.canEdit)
                            const SizedBox(
                              width: 100,
                              child: Text(
                                'Actions',
                                textAlign:
                                    TextAlign.center,
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Aucune structure pour le moment.\nAjoute un élément ou synchronise les tâches.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _leftVerticalController,
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];

                                return _StructuredGanttLeftRow(
                                  canEdit: widget.canEdit,
                                  item: item,
                                  compactPanel: _isTaskPanelCompact,
                                  showStartColumn: _showStartColumn,
                                  showEndColumn: _showEndColumn,
                                  showDurationColumn: _showDurationColumn,
                                  showProgressColumn: _showProgressColumn,
                                  showDeadlineColumn: _showDeadlineColumn,
                                  possibleParents:
                                      _possibleParentsForItem(
                                    items: items,
                                    item: item,
                                  ),
                                  onMoveItem: widget.onMoveItem,
                                  onEditTask: widget.onEditTask,
                                  onDeleteTask: widget.onDeleteTask,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final effectiveChartWidth =
                        chartWidth < constraints.maxWidth
                            ? constraints.maxWidth
                            : chartWidth;

                    return Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      notificationPredicate: (notification) {
                        return notification.metrics.axis == Axis.horizontal;
                      },
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: effectiveChartWidth,
                          child: Column(
                            children: [
                              _StructuredGanttDateHeader(
                                visibleStart: visibleStart,
                                totalDays: totalDays,
                                dayWidth: widget.dayWidth,
                                calendar: widget.calendar,
                                exceptions: widget.exceptions,
                                periods: widget.periods,
                              ),
                              Expanded(
                                child: items.isEmpty
                                    ? _StructuredGanttEmptyBarArea(
                                        visibleStart: visibleStart,
                                        totalDays: totalDays,
                                        dayWidth: widget.dayWidth,
                                        calendar: widget.calendar,
                                        exceptions: widget.exceptions,
                                        periods: widget.periods,
                                      )
                                    : ListView.builder(
                                        controller: _rightVerticalController,
                                        itemCount: items.length,
                                        itemBuilder: (context, index) {
                                          final item = items[index];

                                          final baselineRow =
                                              item.task == null ||
                                                      !widget
                                                          .showBaselineBars
                                                  ? null
                                                  : _baselineRowForTask(
                                                      item.task!.id,
                                                    );

                                          return _StructuredGanttBarRow(
                                            item: item,
                                            baselineRow: baselineRow,
                                            visibleStart: visibleStart,
                                            totalDays: totalDays,
                                            dayWidth: widget.dayWidth,
                                            calendar: widget.calendar,
                                            exceptions: widget.exceptions,
                                            periods: widget.periods,
                                          );
                                        },
                                      ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyGanttBanner
    extends StatelessWidget {
  const _ReadOnlyGanttBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            color: Theme.of(context)
                .colorScheme
                .onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode lecture seule : navigation, zoom, '
              'baselines et export restent disponibles.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StructuredGanttEmptyBarArea extends StatelessWidget {
  final DateTime visibleStart;
  final int totalDays;
  final double dayWidth;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;
  final List<ProjectCalendarPeriodModel> periods;

  const _StructuredGanttEmptyBarArea({
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
    required this.calendar,
    required this.exceptions,
    required this.periods,
  });

  @override
  Widget build(BuildContext context) {
    final cleanVisibleStart = _dateOnly(visibleStart);

    return Stack(
      children: [
        Row(
          children: List.generate(totalDays + 2, (index) {
            final date = cleanVisibleStart.add(Duration(days: index));
            final isMajor = index % 5 == 0 || date.day == 1;
            final isWorkingDay = _isWorkingDayForProject(
              date: date,
              calendar: calendar,
              exceptions: exceptions,
              periods: periods,
            );
            final exception = _findExceptionForDate(
              date: date,
              exceptions: exceptions,
            );
            final period = _findPeriodForDate(
              date: date,
              periods: periods,
            );

            return Container(
              width: dayWidth,
              decoration: BoxDecoration(
                color: period != null && exception == null
                    ? Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: 0.32)
                    : !isWorkingDay
                        ? Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.55)
                        : exception != null
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.20)
                        : null,
                border: Border(
                  left: BorderSide(
                    color: isMajor
                        ? Theme.of(context).dividerColor.withValues(alpha: 0.7)
                        : Theme.of(context).dividerColor.withValues(alpha: 0.25),
                  ),
                ),
              ),
            );
          }),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Aucune tâche liée pour le moment.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}

class _StructuredGanttLeftRow extends StatelessWidget {
  final bool canEdit;
  final StructuredGanttItem item;
  final bool compactPanel;
  final bool showStartColumn;
  final bool showEndColumn;
  final bool showDurationColumn;
  final bool showProgressColumn;
  final bool showDeadlineColumn;
  final List<StructuredGanttItem> possibleParents;
  final Future<void> Function({
    required StructuredGanttItem item,
    required List<StructuredGanttItem> possibleParents,
  }) onMoveItem;
  final Future<void> Function(StructuredGanttItem item) onEditTask;
  final Future<void> Function(StructuredGanttItem item) onDeleteTask;

  const _StructuredGanttLeftRow({
    required this.canEdit,
    required this.item,
    required this.compactPanel,
    required this.showStartColumn,
    required this.showEndColumn,
    required this.showDurationColumn,
    required this.showProgressColumn,
    required this.showDeadlineColumn,
    required this.possibleParents,
    required this.onMoveItem,
    required this.onEditTask,
    required this.onDeleteTask,
  });

  IconData _getIcon() {
    switch (item.type) {
      case 'Section':
        return Icons.folder;
      case 'Phase':
        return Icons.timeline_outlined;
      case 'Zone':
        return Icons.folder_open;
      case 'Floor':
        return Icons.layers_outlined;
      case 'Lot':
        return Icons.inventory_2_outlined;
      case 'Task':
        return Icons.task_alt;
      default:
        return Icons.account_tree_outlined;
    }
  }

  Color _getIconColor(BuildContext context) {
    switch (item.type) {
      case 'Section':
        return Colors.blueGrey;
      case 'Phase':
        return Colors.deepPurple;
      case 'Zone':
        return Colors.indigo;
      case 'Floor':
        return Colors.teal;
      case 'Lot':
        return Colors.brown;
    }

    final task = item.task;

    if (task == null) {
      return Theme.of(context).colorScheme.primary;
    }

    if (task.isDone) {
      return Colors.green;
    }

    if (task.isLate) {
      return Colors.red;
    }

    if (task.isCritical) {
      return Colors.orange;
    }

    return Theme.of(context).colorScheme.primary;
  }

  FontWeight _getFontWeight() {
    if (item.type == 'Section') {
      return FontWeight.bold;
    }

    if (_isStructuralPlanningItemType(item.type)) {
      return FontWeight.w600;
    }

    return FontWeight.normal;
  }

  String _taskStatus(StructuredGanttTask task) {
    if (task.isDone) {
      return 'Terminée';
    }

    if (task.isLate) {
      return 'En retard';
    }

    if (task.isCritical) {
      return 'Critique';
    }

    return 'En cours';
  }

  Widget _textCell({
    required double width,
    required String text,
    TextAlign textAlign = TextAlign.left,
    TextStyle? style,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style,
      ),
    );
  }

  Widget _actionButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: 32,
        height: 32,
      ),
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 17,
      ),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final rowFontWeight = _getFontWeight();

    final taskTooltip = task == null
        ? item.name
        : '${item.name}\n'
            'Statut : ${_taskStatus(task)}\n'
            'Début : ${DateFormat('dd/MM/yyyy').format(task.startDate)}\n'
            'Fin : ${DateFormat('dd/MM/yyyy').format(task.endDate)}\n'
            'Durée : ${task.duration} jour(s) ouvré(s)\n'
            'Progression : ${task.progressPercent}%\n'
            'Float : ${task.totalFloat}\n'
            'Deadline : ${task.deadline == null ? '-' : DateFormat('dd/MM/yyyy').format(task.deadline!)}\n'
            'Retard : ${task.isLate ? '+${task.delayDays}j' : '-'}';

    final taskTextColor = task == null
        ? null
        : task.isLate
            ? Colors.red
            : task.isCritical
                ? Colors.orange.shade800
                : null;

    return Container(
      height: _ganttRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: item.type == 'Section'
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.45)
            : _isStructuralPlanningItemType(item.type)
                ? Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.22)
                : null,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context)
                .dividerColor
                .withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          _textCell(
            width: 60,
            text: item.wbsCode,
            style: TextStyle(
              fontWeight: rowFontWeight,
              fontSize: 11,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: item.level * 14.0,
                right: 8,
              ),
              child: Tooltip(
                message: taskTooltip,
                child: Row(
                  children: [
                    Icon(
                      _getIcon(),
                      size: 17,
                      color: _getIconColor(context),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: rowFontWeight,
                          fontSize: 12,
                          color: taskTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!compactPanel && showStartColumn)
            _textCell(
              width: _ganttStartColumnWidth,
              text: task == null
                  ? ''
                  : DateFormat('dd/MM/yy').format(task.startDate),
              style: TextStyle(
                fontSize: 11,
                color: taskTextColor,
              ),
            ),
          if (!compactPanel && showEndColumn)
            _textCell(
              width: _ganttEndColumnWidth,
              text: task == null
                  ? ''
                  : DateFormat('dd/MM/yy').format(task.endDate),
              style: TextStyle(
                fontSize: 11,
                color: taskTextColor,
              ),
            ),
          if (!compactPanel && showDurationColumn)
            _textCell(
              width: _ganttDurationColumnWidth,
              text: task == null ? '' : '${task.duration}j',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          if (!compactPanel && showProgressColumn)
            _textCell(
              width: _ganttProgressColumnWidth,
              text: task == null ? '' : '${task.progressPercent}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    task?.isDone == true ? FontWeight.bold : FontWeight.normal,
                color: task?.isDone == true ? Colors.green : taskTextColor,
              ),
            ),
          if (!compactPanel && showDeadlineColumn)
            _textCell(
              width: _ganttDeadlineColumnWidth,
              text: task?.deadline == null
                  ? ''
                  : DateFormat('dd/MM/yy').format(task!.deadline!),
              style: TextStyle(
                fontSize: 11,
                color: task?.isLate == true ? Colors.red : null,
                fontWeight:
                    task?.isLate == true ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          if (canEdit)
          SizedBox(
            width: 100,
            child: item.type == 'Task'
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _actionButton(
                        tooltip: 'Modifier',
                        icon: Icons.edit_outlined,
                        onPressed: () {
                          onEditTask(item);
                        },
                      ),
                      _actionButton(
                        tooltip: 'Déplacer',
                        icon: Icons.drive_file_move_outline,
                        onPressed: () {
                          onMoveItem(
                            item: item,
                            possibleParents: possibleParents,
                          );
                        },
                      ),
                      _actionButton(
                        tooltip: 'Supprimer',
                        icon: Icons.delete_outline,
                        onPressed: () {
                          onDeleteTask(item);
                        },
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _actionButton(
                        tooltip: 'Déplacer',
                        icon: Icons.drive_file_move_outline,
                        onPressed: () {
                          onMoveItem(
                            item: item,
                            possibleParents: possibleParents,
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StructuredGanttDateHeader extends StatelessWidget {
  final DateTime visibleStart;
  final int totalDays;
  final double dayWidth;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;
  final List<ProjectCalendarPeriodModel> periods;

  const _StructuredGanttDateHeader({
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
    required this.calendar,
    required this.exceptions,
    required this.periods,
  });

  String _weekdayLabel(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'L';
      case DateTime.tuesday:
        return 'M';
      case DateTime.wednesday:
        return 'M';
      case DateTime.thursday:
        return 'J';
      case DateTime.friday:
        return 'V';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'D';
      default:
        return '';
    }
  }

  String _monthLabel(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final cleanVisibleStart = _dateOnly(visibleStart);

    return Container(
      height: _ganttHeaderHeight,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: List.generate(totalDays + 2, (index) {
          final date = cleanVisibleStart.add(Duration(days: index));
          final isWorkingDay = _isWorkingDayForProject(
            date: date,
            calendar: calendar,
            exceptions: exceptions,
            periods: periods,
          );
          final exception = _findExceptionForDate(
            date: date,
            exceptions: exceptions,
          );
          final period = _findPeriodForDate(
            date: date,
            periods: periods,
          );

          final showMonth = index == 0 || date.day == 1;
          final isToday = _isSameDay(date, DateTime.now());

          return Tooltip(
            message: exception != null
                ? '${DateFormat('EEEE dd/MM/yyyy').format(date)} · '
                    '${exception.label.isEmpty ? 'Exception calendrier' : exception.label} · '
                    '${exception.isWorkingDay ? 'Jour travaillé' : 'Jour non travaillé'}'
                : period != null
                    ? '${DateFormat('EEEE dd/MM/yyyy').format(date)} · '
                        '${period.label.isEmpty ? 'Période non ouvrée' : period.label} · '
                        '${DateFormat('dd/MM/yyyy').format(period.startDate)} → '
                        '${DateFormat('dd/MM/yyyy').format(period.endDate)}'
                    : '${DateFormat('EEEE dd/MM/yyyy').format(date)} · '
                        '${isWorkingDay ? 'Jour ouvré' : 'Jour non ouvré'}',
            child: Container(
              width: dayWidth,
              decoration: BoxDecoration(
                color: period != null && exception == null
                    ? Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: 0.55)
                    : isWorkingDay
                        ? null
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.85),
                border: Border(
                  left: BorderSide(
                    color: date.day == 1
                        ? Theme.of(context).dividerColor.withValues(alpha: 0.9)
                        : Theme.of(context).dividerColor.withValues(alpha: 0.35),
                  ),
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
                  ),
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 26,
                    child: Center(
                      child: showMonth
                          ? RotatedBox(
                              quarterTurns: dayWidth < 22 ? 3 : 0,
                              child: Text(
                                _monthLabel(date),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: dayWidth < 22 ? 9 : 10,
                                    ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.65)
                          : null,
                      border: Border(
                        top: BorderSide(
                          color:
                              Theme.of(context).dividerColor.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    child: Text(
                      '${date.day}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isWorkingDay
                                ? null
                                : Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withValues(alpha: 0.55),
                          ),
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekdayLabel(date),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isWorkingDay
                                      ? null
                                      : Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.color
                                          ?.withValues(alpha: 0.55),
                                ),
                          ),
                          if (exception != null)
                            Icon(
                              exception.isWorkingDay
                                  ? Icons.work_outline
                                  : Icons.block,
                              size: 10,
                              color: exception.isWorkingDay
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.red,
                            )
                          else if (period != null)
                            const Icon(
                              Icons.date_range,
                              size: 10,
                              color: Colors.red,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StructuredGanttBarRow extends StatelessWidget {
  final StructuredGanttItem item;
  final ProjectBaselineComparisonRowModel? baselineRow;
  final DateTime visibleStart;
  final int totalDays;
  final double dayWidth;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;
  final List<ProjectCalendarPeriodModel> periods;

  const _StructuredGanttBarRow({
    required this.item,
    required this.baselineRow,
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
    required this.calendar,
    required this.exceptions,
    required this.periods,
  });

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final cleanVisibleStart = _dateOnly(visibleStart);

    return Container(
      height: _ganttRowHeight,
      decoration: BoxDecoration(
        color: item.type == 'Section'
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.45)
            : _isStructuralPlanningItemType(item.type)
                ? Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.22)
                : null,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Stack(
        children: [
          Row(
            children: List.generate(totalDays + 2, (index) {
              final date = cleanVisibleStart.add(Duration(days: index));
              final isMajor = index % 5 == 0 || date.day == 1;
              final isWorkingDay = _isWorkingDayForProject(
                date: date,
                calendar: calendar,
                exceptions: exceptions,
                periods: periods,
              );
              final exception = _findExceptionForDate(
                date: date,
                exceptions: exceptions,
              );
              final period = _findPeriodForDate(
                date: date,
                periods: periods,
              );

              return Container(
                width: dayWidth,
                decoration: BoxDecoration(
                  color: period != null && exception == null
                      ? Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.32)
                      : !isWorkingDay
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.55)
                          : exception != null
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.20)
                          : null,
                  border: Border(
                    left: BorderSide(
                      color: isMajor
                          ? Theme.of(context).dividerColor.withValues(alpha: 0.7)
                          : Theme.of(context).dividerColor.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (baselineRow?.baselineStartDate != null &&
              baselineRow?.baselineEndDate != null)
            _BaselineTaskBar(
              row: baselineRow!,
              visibleStart: visibleStart,
              dayWidth: dayWidth,
            ),
          if (task != null)
            _TaskBar(
              item: item,
              task: task,
              visibleStart: visibleStart,
              dayWidth: dayWidth,
              hasBaseline:
                  baselineRow?.baselineStartDate != null &&
                      baselineRow?.baselineEndDate != null,
            ),
        ],
      ),
    );
  }
}

class _BaselineTaskBar extends StatelessWidget {
  final ProjectBaselineComparisonRowModel row;
  final DateTime visibleStart;
  final double dayWidth;

  const _BaselineTaskBar({
    required this.row,
    required this.visibleStart,
    required this.dayWidth,
  });

  @override
  Widget build(BuildContext context) {
    final baselineStart =
        _dateOnly(row.baselineStartDate!);
    final baselineEnd =
        _dateOnly(row.baselineEndDate!);
    final cleanVisibleStart =
        _dateOnly(visibleStart);

    final offsetDays = _calendarDaysBetween(
      cleanVisibleStart,
      baselineStart,
    );

    final rawDays = _calendarDaysBetween(
          baselineStart,
          baselineEnd,
        ) +
        1;

    final baselineDays = rawDays <= 0 ? 1 : rawDays;
    final left = offsetDays * dayWidth;
    final width = baselineDays * dayWidth;

    return Positioned(
      left: left < 0 ? 0 : left,
      top: 34,
      child: Tooltip(
        message: 'Baseline · ${row.taskTitle}\n'
            '${DateFormat('dd/MM/yyyy').format(baselineStart)} '
            '→ ${DateFormat('dd/MM/yyyy').format(baselineEnd)}\n'
            'Durée : ${row.baselineDuration}j\n'
            'Δ début : ${row.startVarianceDays ?? 0}j\n'
            'Δ fin : ${row.endVarianceDays ?? 0}j',
        child: Container(
          width: width,
          height: 8,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.20),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskBar extends StatelessWidget {
  final StructuredGanttItem item;
  final StructuredGanttTask task;
  final DateTime visibleStart;
  final double dayWidth;
  final bool hasBaseline;

  const _TaskBar({
    required this.item,
    required this.task,
    required this.visibleStart,
    required this.dayWidth,
    required this.hasBaseline,
  });

  Color _barColor(BuildContext context) {
    if (task.isDone) {
      return Colors.green;
    }

    if (task.isLate) {
      return Colors.red;
    }

    if (task.isCritical) {
      return Colors.orange;
    }

    return Theme.of(context).colorScheme.primary;
  }

  String _barLabel() {
    if (task.isDone) {
      return 'OK';
    }

    if (task.isLate) {
      return '+${task.delayDays}j';
    }

    return '${task.progressPercent}%';
  }

  String _statusLabel() {
    if (task.isDone) {
      return 'Terminée';
    }

    if (task.isLate) {
      return 'En retard';
    }

    if (task.isCritical) {
      return 'Critique';
    }

    return 'En cours';
  }

  @override
  Widget build(BuildContext context) {
    final cleanVisibleStart = _dateOnly(visibleStart);
    final taskStart = _dateOnly(task.startDate);
    final taskEnd = _dateOnly(task.endDate);

    final offsetDays = _calendarDaysBetween(cleanVisibleStart, taskStart);

    // Les dates de tâche sont inclusives :
    // du 24 au 27, la barre couvre les 24, 25, 26 et 27.
    final rawTaskDays =
        _calendarDaysBetween(taskStart, taskEnd) + 1;
    final taskDays = rawTaskDays <= 0 ? 1 : rawTaskDays;

    final left = offsetDays * dayWidth;
    final width = taskDays * dayWidth;

    return Positioned(
      left: left < 0 ? 0 : left,
      top: hasBaseline ? 6 : 11,
      child: Tooltip(
        message: '${item.name}\n'
            'Tâche liée : ${task.title}\n'
            'Statut : ${_statusLabel()}\n'
            'Progression : ${task.progressPercent}%\n'
            'Durée : ${task.duration}j\n'
            'Float : ${task.totalFloat}\n'
            'Deadline : ${task.deadline == null ? '-' : DateFormat('dd/MM/yyyy').format(task.deadline!)}\n'
            'Retard : ${task.isLate ? '+${task.delayDays}j' : '-'}',
        child: Container(
          width: width,
          height: hasBaseline ? 22 : 26,
          decoration: BoxDecoration(
            color: _barColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: width >= 26
              ? Text(
                  _barLabel(),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}