import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/structured_gantt_api.dart';
import '../data/structured_gantt_model.dart';

import '../../project_calendar/data/project_calendar_api.dart';
import '../../project_calendar/data/project_calendar_exception_api.dart';
import '../../project_calendar/data/project_calendar_exception_model.dart';
import '../../project_calendar/data/project_calendar_model.dart';

import '../../tasks/data/task_api.dart';
import '../../tasks/data/task_model.dart';
import '../../tasks/presentation/task_form_dialog.dart';
import '../../tasks/presentation/task_form_result.dart';
import '../../tasks/presentation/task_edit_dialog.dart';

import '../../dependencies/data/dependency_api.dart';
import '../../dependencies/data/dependency_model.dart';

import '../../resources/data/resource_assignment_api.dart';
import '../../resources/data/resource_assignment_model.dart';

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

bool _isWorkingDayForProject({
  required DateTime date,
  required ProjectCalendarModel calendar,
  required List<ProjectCalendarExceptionModel> exceptions,
}) {
  final exception = _findExceptionForDate(
    date: date,
    exceptions: exceptions,
  );

  if (exception != null) {
    return exception.isWorkingDay;
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
  final StructuredGanttResponse gantt;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;

  const _StructuredGanttLoadedData({
    required this.gantt,
    required this.calendar,
    required this.exceptions,
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
  final StructuredGanttApi _ganttApi = StructuredGanttApi();
  final TaskApi _taskApi = TaskApi();
  final DependencyApi _dependencyApi = DependencyApi();
  final ResourceAssignmentApi _resourceAssignmentApi = ResourceAssignmentApi();

  final ProjectCalendarApi _calendarApi = ProjectCalendarApi();
  final ProjectCalendarExceptionApi _exceptionApi =
      ProjectCalendarExceptionApi();

  late Future<_StructuredGanttLoadedData> _ganttFuture;

  double _dayWidth = 24;
  StructuredGanttDisplayMode _displayMode = StructuredGanttDisplayMode.auto;

  @override
  void initState() {
    super.initState();
    _loadGantt();
  }

  void _loadGantt() {
    _ganttFuture = _loadGanttData();
  }

  Future<_StructuredGanttLoadedData> _loadGanttData() async {
    final gantt = await _ganttApi.getStructuredGantt(widget.projectId);
    final calendar = await _calendarApi.getByProjectId(widget.projectId);
    final exceptions = await _exceptionApi.getByProjectId(widget.projectId);

    return _StructuredGanttLoadedData(
      gantt: gantt,
      calendar: calendar,
      exceptions: exceptions,
    );
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
          resourceGroupId: null,
          workloadHours: result.workloadHours!,
          allocationPercent: result.allocationPercent,
        ),
      );
    }
  }

  Future<void> _syncTasks() async {
    try {
      await _ganttApi.syncProjectTasks(widget.projectId);

      setState(() {
        _loadGantt();
      });

      if (!mounted) return;

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
    final result = await showDialog<TaskFormResult>(
      context: context,
      builder: (context) {
        return TaskFormDialog(projectId: widget.projectId);
      },
    );

    if (result == null) return;

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

      if (createdPlanningItem == null) {
        if (!mounted) return;

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

  Future<void> _editTaskFromGantt(StructuredGanttItem item) async {
    final task = item.task;

    if (task == null) return;

    try {
      final plannerTask = await _loadPlannerTaskForEdit(task);

      if (!mounted) return;

      final request = await showDialog<TaskUpdateRequest>(
        context: context,
        builder: (context) {
          return TaskEditDialog(task: plannerTask);
        },
      );

      if (request == null) return;

      await _taskApi.updateTask(plannerTask.id, request);
      await _ganttApi.syncProjectTasks(widget.projectId);

      if (!mounted) return;

      setState(() {
        _loadGantt();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tâche "${request.title}" modifiée.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur modification tâche : $error'),
        ),
      );
    }
  }

  Future<void> _deleteTaskFromGantt(StructuredGanttItem item) async {
    final task = item.task;

    if (task == null) return;

    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la tâche'),
          content: Text(
            'Supprimer définitivement la tâche "${task.title}" ?\n\n'
            'Cette action peut aussi impacter les dépendances et le planning.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur suppression tâche : $error'),
        ),
      );
    }
  }

  Future<void> _createPlanningItem(List<StructuredGanttItem> items) async {
    final nameController = TextEditingController();

    String selectedType = 'Section';
    StructuredGanttItem? selectedParent;

    List<StructuredGanttItem> getPossibleParentsForType(String type) {
      if (type == 'Zone') {
        return items.where((item) => item.type == 'Section').toList();
      }

      if (type == 'Task') {
        return items
            .where((item) => item.type == 'Section' || item.type == 'Zone')
            .toList();
      }

      return [];
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isSection = selectedType == 'Section';
            final isZone = selectedType == 'Zone';
            final isTask = selectedType == 'Task';

            final possibleParents = getPossibleParentsForType(selectedType);
            final needsParent = isZone || isTask;

            final selectedParentStillValid = selectedParent == null ||
                possibleParents.any(
                  (parent) => parent.id == selectedParent!.id,
                );

            if (!selectedParentStillValid) {
              selectedParent = null;
            }

            return AlertDialog(
              title: const Text('Ajouter au Gantt'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Section',
                          child: Text('Section'),
                        ),
                        DropdownMenuItem(
                          value: 'Zone',
                          child: Text('Zone'),
                        ),
                        DropdownMenuItem(
                          value: 'Task',
                          child: Text('Tâche'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedType = value;
                          selectedParent = null;
                        });
                      },
                    ),
                    if (!isTask) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText:
                              isSection ? 'Nom de la section' : 'Nom de la zone',
                          hintText:
                              isSection ? 'Ex : Production MVP' : 'Ex : Front Flutter',
                          border: const OutlineInputBorder(),
                        ),
                        autofocus: true,
                      ),
                    ],
                    if (needsParent) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<StructuredGanttItem>(
                        value: selectedParent,
                        decoration: InputDecoration(
                          labelText:
                              isTask ? 'Créer la tâche dans' : 'Section parent',
                          border: const OutlineInputBorder(),
                        ),
                        items: possibleParents.map((parent) {
                          return DropdownMenuItem(
                            value: parent,
                            child: Text('${parent.wbsCode} - ${parent.name}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedParent = value;
                          });
                        },
                      ),
                      if (possibleParents.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          isTask
                              ? 'Crée d’abord une Section ou une Zone avant d’ajouter une tâche dans le Gantt.'
                              : 'Crée d’abord une Section avant d’ajouter une Zone.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.red,
                                  ),
                        ),
                      ],
                    ],
                    if (isTask) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Après validation, le formulaire de tâche va s’ouvrir. '
                          'La tâche sera ensuite créée directement dans le parent choisi.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (needsParent && selectedParent == null) return;

                    if (isTask) {
                      final parentId = selectedParent!.id;

                      Navigator.of(context).pop();

                      await Future<void>.delayed(Duration.zero);

                      await _createTaskUnderParent(parentId: parentId);
                      return;
                    }

                    final name = nameController.text.trim();

                    if (name.isEmpty) return;

                    final parentId = isZone ? selectedParent!.id : null;
                    final sortOrder = _getNextSortOrder(
                      items: items,
                      parentId: parentId,
                    );

                    Navigator.of(context).pop();

                    try {
                      await _ganttApi.createPlanningItem(
                        projectId: widget.projectId,
                        name: name,
                        type: selectedType,
                        parentId: parentId,
                        sortOrder: sortOrder,
                      );

                      if (!mounted) return;

                      setState(() {
                        _loadGantt();
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            selectedType == 'Section'
                                ? 'Section ajoutée au Gantt.'
                                : 'Zone ajoutée au Gantt.',
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
                  },
                  child: Text(isTask ? 'Continuer' : 'Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Future<void> _moveItem({
    required StructuredGanttItem item,
    required List<StructuredGanttItem> possibleParents,
  }) async {
    StructuredGanttItem? selectedParent;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Déplacer "${item.name}"'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return DropdownButtonFormField<StructuredGanttItem>(
                value: selectedParent,
                decoration: const InputDecoration(
                  labelText: 'Déplacer vers',
                  border: OutlineInputBorder(),
                ),
                items: possibleParents.map((parent) {
                  return DropdownMenuItem(
                    value: parent,
                    child: Text('${parent.wbsCode} - ${parent.name}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedParent = value;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedParent == null) return;

                Navigator.of(context).pop();

                try {
                  await _ganttApi.movePlanningItem(
                    itemId: item.id,
                    newParentId: selectedParent!.id,
                  );

                  if (!mounted) return;

                  setState(() {
                    _loadGantt();
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tâche déplacée avec succès.'),
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
              },
              child: const Text('Déplacer'),
            ),
          ],
        );
      },
    );
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
          data: data,
          calendar: loadedData.calendar,
          exceptions: loadedData.exceptions,
          dayWidth: _dayWidth,
          displayMode: _displayMode,
          onDisplayModeChanged: _changeDisplayMode,
          onRefresh: _refreshGantt,
          onSyncTasks: _syncTasks,
          onCreateItem: _createPlanningItem,
          onMoveItem: _moveItem,
          onEditTask: _editTaskFromGantt,
          onDeleteTask: _deleteTaskFromGantt,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
        );
      },
    );
  }
}

class _StructuredGanttChart extends StatefulWidget {
  final StructuredGanttResponse data;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;
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
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _StructuredGanttChart({
    required this.data,
    required this.calendar,
    required this.exceptions,
    required this.dayWidth,
    required this.displayMode,
    required this.onDisplayModeChanged,
    required this.onRefresh,
    required this.onSyncTasks,
    required this.onCreateItem,
    required this.onMoveItem,
    required this.onEditTask,
    required this.onDeleteTask,
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
    if (taskItems.isNotEmpty) {
      final taskStart = _dateOnly(
        taskItems
            .map((item) => item.task!.startDate)
            .reduce((a, b) => a.isBefore(b) ? a : b),
      );

      final taskEnd = _dateOnly(
        taskItems
            .map((item) => item.task!.endDate)
            .reduce((a, b) => a.isAfter(b) ? a : b),
      );

      return (
        start: taskStart,
        end: taskEnd.isAfter(taskStart)
            ? taskEnd
            : taskStart.add(const Duration(days: 30)),
      );
    }

    final fallbackStart =
        _tryReadProjectDate('projectStartDate') ?? _dateOnly(DateTime.now());

    final fallbackEnd = _tryReadProjectDate('projectEndDate');

    return (
      start: fallbackStart,
      end: fallbackEnd != null && fallbackEnd.isAfter(fallbackStart)
          ? fallbackEnd
          : fallbackStart.add(const Duration(days: 30)),
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

  @override
  Widget build(BuildContext context) {
    final items = widget.data.items;

    final taskItems = items.where((item) => item.task != null).toList();

    final possibleParents = items
        .where((item) => item.type == 'Section' || item.type == 'Zone')
        .toList();

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
                  value: widget.displayMode,
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
              FilledButton.icon(
                onPressed: () => widget.onCreateItem(items),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  widget.onSyncTasks();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Synchroniser'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Rafraîchir'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 390,
                child: Column(
                  children: [
                    Container(
                      height: _ganttHeaderHeight,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(
                              'WBS',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Élément',
                              style: TextStyle(fontWeight: FontWeight.bold),
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
                                  'Aucune structure pour le moment.\nAjoute une section ou synchronise les tâches.',
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
                                  item: item,
                                  possibleParents: possibleParents
                                      .where((parent) => parent.id != item.id)
                                      .toList(),
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
                              ),
                              Expanded(
                                child: items.isEmpty
                                    ? _StructuredGanttEmptyBarArea(
                                        visibleStart: visibleStart,
                                        totalDays: totalDays,
                                        dayWidth: widget.dayWidth,
                                        calendar: widget.calendar,
                                        exceptions: widget.exceptions,
                                      )
                                    : ListView.builder(
                                        controller: _rightVerticalController,
                                        itemCount: items.length,
                                        itemBuilder: (context, index) {
                                          final item = items[index];

                                          return _StructuredGanttBarRow(
                                            item: item,
                                            visibleStart: visibleStart,
                                            totalDays: totalDays,
                                            dayWidth: widget.dayWidth,
                                            calendar: widget.calendar,
                                            exceptions: widget.exceptions,
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

class _StructuredGanttEmptyBarArea extends StatelessWidget {
  final DateTime visibleStart;
  final int totalDays;
  final double dayWidth;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;

  const _StructuredGanttEmptyBarArea({
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
    required this.calendar,
    required this.exceptions,
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
            );
            final exception = _findExceptionForDate(
              date: date,
              exceptions: exceptions,
            );

            return Container(
              width: dayWidth,
              decoration: BoxDecoration(
                color: !isWorkingDay
                    ? Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.55)
                    : exception != null
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.20)
                        : null,
                border: Border(
                  left: BorderSide(
                    color: isMajor
                        ? Theme.of(context).dividerColor.withOpacity(0.7)
                        : Theme.of(context).dividerColor.withOpacity(0.25),
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
              color: Theme.of(context).colorScheme.surface.withOpacity(0.88),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.35),
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
  final StructuredGanttItem item;
  final List<StructuredGanttItem> possibleParents;
  final Future<void> Function({
    required StructuredGanttItem item,
    required List<StructuredGanttItem> possibleParents,
  }) onMoveItem;
  final Future<void> Function(StructuredGanttItem item) onEditTask;
  final Future<void> Function(StructuredGanttItem item) onDeleteTask;

  const _StructuredGanttLeftRow({
    required this.item,
    required this.possibleParents,
    required this.onMoveItem,
    required this.onEditTask,
    required this.onDeleteTask,
  });

  IconData _getIcon() {
    switch (item.type) {
      case 'Section':
        return Icons.folder;
      case 'Zone':
        return Icons.folder_open;
      case 'Task':
        return Icons.task_alt;
      default:
        return Icons.circle;
    }
  }

  Color _getIconColor(BuildContext context) {
    if (item.type == 'Section') {
      return Colors.blueGrey;
    }

    if (item.type == 'Zone') {
      return Colors.indigo;
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
    if (item.type == 'Section') return FontWeight.bold;
    if (item.type == 'Zone') return FontWeight.w600;
    return FontWeight.normal;
  }

  String _formatTaskSubtitle(StructuredGanttTask task) {
    final dates =
        '${DateFormat('dd/MM').format(task.startDate)} → ${DateFormat('dd/MM').format(task.endDate)}';

    if (task.isLate) {
      return '$dates · Retard +${task.delayDays}j · Float ${task.totalFloat}';
    }

    if (task.isCritical) {
      return '$dates · Critique · Float ${task.totalFloat}';
    }

    return '$dates · ${task.progressPercent}% · Float ${task.totalFloat}';
  }

  @override
  Widget build(BuildContext context) {
    final task = item.task;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: item.type == 'Section'
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.45)
            : item.type == 'Zone'
                ? Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.25)
                : null,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              item.wbsCode,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: _getFontWeight(),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: item.level * 18.0),
              child: Row(
                children: [
                  Icon(
                    _getIcon(),
                    size: 18,
                    color: _getIconColor(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: task == null
                          ? item.name
                          : '${item.name}\n'
                              'Tâche liée : ${task.title}\n'
                              'Statut : ${task.isDone ? 'Terminée' : task.isLate ? 'En retard' : task.isCritical ? 'Critique' : 'En cours'}\n'
                              'Progression : ${task.progressPercent}%\n'
                              'Float : ${task.totalFloat}\n'
                              'Deadline : ${task.deadline == null ? '-' : DateFormat('dd/MM/yyyy').format(task.deadline!)}\n'
                              'Retard : ${task.isLate ? '+${task.delayDays}j' : '-'}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: _getFontWeight(),
                            ),
                          ),
                          if (task != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _formatTaskSubtitle(task),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: task.isLate
                                        ? Colors.red
                                        : task.isCritical
                                            ? Colors.orange.shade800
                                            : Colors.grey.shade700,
                                    fontSize: 11,
                                    fontWeight: task.isLate
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (item.type == 'Task') ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Modifier',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                      ),
                      onPressed: () {
                        onEditTask(item);
                      },
                    ),
                    IconButton(
                      tooltip: 'Déplacer',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.drive_file_move_outline,
                        size: 18,
                      ),
                      onPressed: () {
                        onMoveItem(
                          item: item,
                          possibleParents: possibleParents,
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Supprimer',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                      ),
                      onPressed: () {
                        onDeleteTask(item);
                      },
                    ),
                  ],
                ],
              ),
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

  const _StructuredGanttDateHeader({
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
    required this.calendar,
    required this.exceptions,
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
          );
          final exception = _findExceptionForDate(
            date: date,
            exceptions: exceptions,
          );

          final showMonth = index == 0 || date.day == 1;
          final isToday = _isSameDay(date, DateTime.now());

          return Tooltip(
            message: exception == null
                ? '${DateFormat('EEEE dd/MM/yyyy').format(date)} · ${isWorkingDay ? 'Jour ouvré' : 'Jour non ouvré'}'
                : '${DateFormat('EEEE dd/MM/yyyy').format(date)} · ${exception.label.isEmpty ? 'Exception calendrier' : exception.label} · ${exception.isWorkingDay ? 'Jour travaillé' : 'Jour non travaillé'}',
            child: Container(
              width: dayWidth,
              decoration: BoxDecoration(
                color: isWorkingDay
                    ? null
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.85),
                border: Border(
                  left: BorderSide(
                    color: date.day == 1
                        ? Theme.of(context).dividerColor.withOpacity(0.9)
                        : Theme.of(context).dividerColor.withOpacity(0.35),
                  ),
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.45),
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
                              .withOpacity(0.65)
                          : null,
                      border: Border(
                        top: BorderSide(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.25),
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
                                    ?.withOpacity(0.55),
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
                                          ?.withOpacity(0.55),
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
  final DateTime visibleStart;
  final int totalDays;
  final double dayWidth;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;

  const _StructuredGanttBarRow({
    required this.item,
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
    required this.calendar,
    required this.exceptions,
  });

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final cleanVisibleStart = _dateOnly(visibleStart);

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: item.type == 'Section'
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.45)
            : item.type == 'Zone'
                ? Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.25)
                : null,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.4),
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
              );
              final exception = _findExceptionForDate(
                date: date,
                exceptions: exceptions,
              );

              return Container(
                width: dayWidth,
                decoration: BoxDecoration(
                  color: !isWorkingDay
                      ? Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withOpacity(0.55)
                      : exception != null
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.20)
                          : null,
                  border: Border(
                    left: BorderSide(
                      color: isMajor
                          ? Theme.of(context).dividerColor.withOpacity(0.7)
                          : Theme.of(context).dividerColor.withOpacity(0.25),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (task != null)
            _TaskBar(
              item: item,
              task: task,
              visibleStart: visibleStart,
              dayWidth: dayWidth,
            ),
        ],
      ),
    );
  }
}

class _TaskBar extends StatelessWidget {
  final StructuredGanttItem item;
  final StructuredGanttTask task;
  final DateTime visibleStart;
  final double dayWidth;

  const _TaskBar({
    required this.item,
    required this.task,
    required this.visibleStart,
    required this.dayWidth,
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
    final rawTaskDays = _calendarDaysBetween(taskStart, taskEnd);
    final taskDays = rawTaskDays <= 0 ? 1 : rawTaskDays;

    final left = offsetDays * dayWidth;
    final width = taskDays * dayWidth;

    return Positioned(
      left: left < 0 ? 0 : left,
      top: 14,
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
          width: width < 26 ? 26 : width,
          height: 26,
          decoration: BoxDecoration(
            color: _barColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            _barLabel(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}