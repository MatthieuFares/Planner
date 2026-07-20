import 'package:flutter/material.dart';

import '../../../core/utils/working_day_utils.dart';

import '../../dependencies/data/dependency_api.dart';
import '../../dependencies/data/dependency_model.dart';
import '../../gantt/data/structured_gantt_model.dart';
import '../../project_calendar/data/project_calendar_api.dart';
import '../../project_calendar/data/project_calendar_exception_api.dart';
import '../../project_calendar/data/project_calendar_exception_model.dart';
import '../../project_calendar/data/project_calendar_model.dart';
import '../../project_calendar/data/project_calendar_period_api.dart';
import '../../project_calendar/data/project_calendar_period_model.dart';
import '../../project_calendar/utils/project_working_day_calculator.dart';
import '../../resources/data/resource_api.dart';
import '../../resources/data/resource_assignment_api.dart';
import '../../resources/data/resource_assignment_model.dart';
import '../../resources/data/resource_group_api.dart';
import '../../resources/data/resource_group_model.dart';
import '../../resources/data/resource_model.dart';

import '../data/task_api.dart';
import '../data/task_model.dart';
import 'task_edit_result.dart';

class TaskEditDialog extends StatefulWidget {
  final PlannerTask task;
  final StructuredGanttItem? planningItem;
  final List<StructuredGanttItem> planningItems;

  const TaskEditDialog({
    super.key,
    required this.task,
    this.planningItem,
    this.planningItems = const <StructuredGanttItem>[],
  });

  bool get hasGanttContext => planningItem != null;

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final ProjectCalendarApi _calendarApi = ProjectCalendarApi();
  final ProjectCalendarExceptionApi _exceptionApi =
      ProjectCalendarExceptionApi();
  final ProjectCalendarPeriodApi _periodApi =
      ProjectCalendarPeriodApi();

  final TaskApi _taskApi = TaskApi();
  final DependencyApi _dependencyApi = DependencyApi();
  final ResourceAssignmentApi _assignmentApi =
      ResourceAssignmentApi();
  final ResourceApi _resourceApi = ResourceApi();
  final ResourceGroupApi _groupApi = ResourceGroupApi();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _durationController;

  _TaskEditCalendarData? _calendarData;

  List<PlannerTask> _projectTasks = const <PlannerTask>[];
  List<Resource> _resources = const <Resource>[];
  List<ResourceGroup> _groups = const <ResourceGroup>[];

  final List<_EditableDependency> _dependencies =
      <_EditableDependency>[];
  final List<_EditableAssignment> _assignments =
      <_EditableAssignment>[];

  final Set<int> _dependencyIdsToDelete = <int>{};
  final Set<int> _assignmentIdsToDelete = <int>{};

  bool _isLoading = true;
  String? _loadError;
  String? _validationMessage;

  late DateTime _startDate;
  DateTime? _deadline;
  late double _progressPercent;
  int? _selectedParentId;

  List<StructuredGanttItem> get _structuralParents {
    final parents = widget.planningItems
        .where((item) => item.type != 'Task')
        .toList();

    parents.sort((a, b) {
      final wbsComparison = a.wbsCode.compareTo(b.wbsCode);

      if (wbsComparison != 0) {
        return wbsComparison;
      }

      return a.name.compareTo(b.name);
    });

    return parents;
  }

  List<PlannerTask> get _possiblePredecessorTasks {
    final tasks = _projectTasks
        .where((task) => task.id != widget.task.id)
        .toList();

    tasks.sort((a, b) => a.title.compareTo(b.title));

    return tasks;
  }

  bool get _hasAssignmentTargets =>
      _resources.isNotEmpty || _groups.isNotEmpty;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.task.title,
    );

    _descriptionController = TextEditingController(
      text: widget.task.description ?? '',
    );

    _durationController = TextEditingController(
      text: (widget.task.duration ?? 1).toString(),
    );

    _startDate = widget.task.startDate ?? DateTime.now();
    _deadline = widget.task.deadline;
    _progressPercent = widget.task.progressPercent
        .toDouble()
        .clamp(0.0, 100.0)
        .toDouble();

    _selectedParentId = widget.planningItem?.parentId;

    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();

    _disposeEditableRows();

    super.dispose();
  }

  void _disposeEditableRows() {
    for (final dependency in _dependencies) {
      dependency.dispose();
    }

    for (final assignment in _assignments) {
      assignment.dispose();
    }

    _dependencies.clear();
    _assignments.clear();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
        _validationMessage = null;
      });
    }

    try {
      final calendar = await _calendarApi.getByProjectId(
        widget.task.projectId,
      );

      final exceptions = await _exceptionApi.getByProjectId(
        widget.task.projectId,
      );

      final periods = await _periodApi.getByProjectId(
        widget.task.projectId,
      );

      final projectTasks = await _taskApi.getTasksByProject(
        widget.task.projectId,
      );

      final loadedDependencies =
          await _dependencyApi.getDependenciesByTask(
        widget.task.id,
      );

      final loadedAssignments =
          await _assignmentApi.getAssignmentsByTask(
        widget.task.id,
      );

      final resources = await _resourceApi.getResources();
      final groups = await _groupApi.getGroups();

      final calendarData = _TaskEditCalendarData(
        calendar: calendar,
        exceptions: exceptions,
        periods: periods,
      );

      final normalizedStartDate =
          ProjectWorkingDayCalculator.normalizeToWorkingDay(
        date: _startDate,
        calendar: calendar,
        exceptions: exceptions,
        periods: periods,
        forward: true,
      );

      final incomingDependencies = loadedDependencies
          .where(
            (dependency) =>
                dependency.successorId == widget.task.id,
          )
          .toList();

      if (!mounted) return;

      _disposeEditableRows();

      setState(() {
        _calendarData = calendarData;
        _projectTasks = projectTasks;
        _resources = resources;
        _groups = groups;
        _startDate = normalizedStartDate;

        _dependencies.addAll(
          incomingDependencies.map(
            _EditableDependency.fromExisting,
          ),
        );

        _assignments.addAll(
          loadedAssignments.map(
            _EditableAssignment.fromExisting,
          ),
        );

        if (widget.hasGanttContext) {
          final parentExists = _structuralParents.any(
            (parent) => parent.id == _selectedParentId,
          );

          if (!parentExists &&
              _structuralParents.isNotEmpty) {
            _selectedParentId = _structuralParents.first.id;
          }
        }

        _dependencyIdsToDelete.clear();
        _assignmentIdsToDelete.clear();

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  DateTime _computeEndDate(
    DateTime startDate,
    int duration,
  ) {
    final calendarData = _calendarData;

    if (calendarData == null) {
      return WorkingDayUtils.calculateTaskEndDate(
        startDate,
        duration,
      );
    }

    return ProjectWorkingDayCalculator.calculateTaskEndDate(
      startDate: startDate,
      duration: duration,
      calendar: calendarData.calendar,
      exceptions: calendarData.exceptions,
      periods: calendarData.periods,
    );
  }

  DateTime _normalizeStartDate(DateTime date) {
    final calendarData = _calendarData;

    if (calendarData == null) {
      return WorkingDayUtils.normalizeToWorkingDay(
        date,
        forward: true,
      );
    }

    return ProjectWorkingDayCalculator.normalizeToWorkingDay(
      date: date,
      calendar: calendarData.calendar,
      exceptions: calendarData.exceptions,
      periods: calendarData.periods,
      forward: true,
    );
  }

  DateTime _normalizeDeadlineForPreview(DateTime date) {
    final calendarData = _calendarData;

    if (calendarData == null) {
      return WorkingDayUtils.normalizeToWorkingDay(
        date,
        forward: false,
      );
    }

    return ProjectWorkingDayCalculator.normalizeToWorkingDay(
      date: date,
      calendar: calendarData.calendar,
      exceptions: calendarData.exceptions,
      periods: calendarData.periods,
      forward: false,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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
      default:
        return type;
    }
  }

  String _targetKey({
    required bool targetsGroup,
    required int targetId,
  }) {
    return targetsGroup
        ? 'group:$targetId'
        : 'resource:$targetId';
  }

  String _assignmentTargetLabel(_EditableAssignment assignment) {
    if (assignment.targetsGroup) {
      for (final group in _groups) {
        if (group.id == assignment.targetId) {
          return group.name;
        }
      }

      return 'Groupe #${assignment.targetId}';
    }

    for (final resource in _resources) {
      if (resource.id == assignment.targetId) {
        return resource.name;
      }
    }

    return 'Ressource #${assignment.targetId}';
  }

  Future<void> _pickStartDate() async {
    if (_calendarData == null) return;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (!mounted || pickedDate == null) {
      return;
    }

    final normalizedDate = _normalizeStartDate(pickedDate);
    final dateWasAdjusted =
        !ProjectWorkingDayCalculator.isSameDay(
      pickedDate,
      normalizedDate,
    );

    setState(() {
      _startDate = normalizedDate;

      if (_deadline != null &&
          _deadline!.isBefore(_startDate)) {
        _deadline = null;
      }
    });

    if (dateWasAdjusted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La date choisie est non ouvrée. '
            'Début ajusté au ${_formatDate(normalizedDate)}.',
          ),
        ),
      );
    }
  }

  Future<void> _pickDeadline() async {
    if (_calendarData == null) return;

    final parsedDuration =
        int.tryParse(_durationController.text) ?? 1;

    final duration =
        parsedDuration > 0 ? parsedDuration : 1;

    final endDate = _computeEndDate(
      _startDate,
      duration,
    );

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _deadline ?? endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (!mounted || pickedDate == null) {
      return;
    }

    setState(() {
      _deadline = pickedDate;
    });
  }

  void _clearDeadline() {
    setState(() {
      _deadline = null;
    });
  }

  void _addDependency() {
    final usedPredecessorIds = _dependencies
        .map((dependency) => dependency.predecessorId)
        .toSet();

    PlannerTask? defaultTask;

    for (final task in _possiblePredecessorTasks) {
      if (!usedPredecessorIds.contains(task.id)) {
        defaultTask = task;
        break;
      }
    }

    if (defaultTask == null) {
      setState(() {
        _validationMessage =
            'Aucune autre tâche disponible comme prédécesseur.';
      });
      return;
    }

    setState(() {
      _validationMessage = null;
      _dependencies.add(
        _EditableDependency.newDependency(
          predecessorId: defaultTask!.id,
        ),
      );
    });
  }

  void _removeDependency(_EditableDependency dependency) {
    setState(() {
      if (dependency.id != null) {
        _dependencyIdsToDelete.add(dependency.id!);
      }

      _dependencies.remove(dependency);
      dependency.dispose();
    });
  }

  void _addAssignment() {
    if (!_hasAssignmentTargets) {
      setState(() {
        _validationMessage =
            'Aucune ressource ni aucun groupe disponible.';
      });
      return;
    }

    final usedTargets = _assignments
        .map(
          (assignment) => _targetKey(
            targetsGroup: assignment.targetsGroup,
            targetId: assignment.targetId,
          ),
        )
        .toSet();

    for (final resource in _resources) {
      final key = _targetKey(
        targetsGroup: false,
        targetId: resource.id,
      );

      if (!usedTargets.contains(key)) {
        setState(() {
          _validationMessage = null;
          _assignments.add(
            _EditableAssignment.newAssignment(
              targetsGroup: false,
              targetId: resource.id,
            ),
          );
        });
        return;
      }
    }

    for (final group in _groups) {
      final key = _targetKey(
        targetsGroup: true,
        targetId: group.id,
      );

      if (!usedTargets.contains(key)) {
        setState(() {
          _validationMessage = null;
          _assignments.add(
            _EditableAssignment.newAssignment(
              targetsGroup: true,
              targetId: group.id,
            ),
          );
        });
        return;
      }
    }

    setState(() {
      _validationMessage =
          'Toutes les ressources et tous les groupes '
          'sont déjà assignés.';
    });
  }

  void _removeAssignment(_EditableAssignment assignment) {
    setState(() {
      if (assignment.id != null) {
        _assignmentIdsToDelete.add(assignment.id!);
      }

      _assignments.remove(assignment);
      assignment.dispose();
    });
  }

  String? _validateBusinessRules() {
    if (widget.hasGanttContext &&
        _selectedParentId == null) {
      return 'La tâche doit être rattachée à un élément '
          'structurel du Gantt.';
    }

    final predecessorIds = <int>{};

    for (final dependency in _dependencies) {
      if (!predecessorIds.add(dependency.predecessorId)) {
        return 'Une même tâche ne peut être ajoutée '
            'plusieurs fois comme prédécesseur.';
      }

      if (dependency.predecessorId == widget.task.id) {
        return 'Une tâche ne peut pas dépendre d’elle-même.';
      }

      if (int.tryParse(
            dependency.offsetController.text.trim(),
          ) ==
          null) {
        return 'Chaque offset de dépendance doit être '
            'un nombre entier.';
      }
    }

    final targets = <String>{};

    for (final assignment in _assignments) {
      final targetKey = _targetKey(
        targetsGroup: assignment.targetsGroup,
        targetId: assignment.targetId,
      );

      if (!targets.add(targetKey)) {
        return 'Une même ressource ou un même groupe '
            'ne peut être assigné plusieurs fois.';
      }

      final workload = double.tryParse(
        assignment.workloadController.text
            .trim()
            .replaceAll(',', '.'),
      );

      if (workload == null || workload <= 0) {
        return 'La charge de chaque assignation doit être '
            'supérieure à 0 heure.';
      }

      final allocation = int.tryParse(
        assignment.allocationController.text.trim(),
      );

      if (allocation == null ||
          allocation <= 0 ||
          allocation > 100) {
        return 'Le taux d’allocation doit être compris '
            'entre 1 et 100 %.';
      }
    }

    return null;
  }

  void _submit() {
    if (_calendarData == null) {
      setState(() {
        _validationMessage =
            'Le calendrier projet doit être chargé avant '
            'd’enregistrer la tâche.';
      });
      return;
    }

    final formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      setState(() {
        _validationMessage =
            'Certains champs contiennent une valeur invalide.';
      });
      return;
    }

    final businessError = _validateBusinessRules();

    if (businessError != null) {
      setState(() {
        _validationMessage = businessError;
      });
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final duration = int.parse(
      _durationController.text.trim(),
    );

    final normalizedStartDate =
        _normalizeStartDate(_startDate);

    final endDate = _computeEndDate(
      normalizedStartDate,
      duration,
    );

    final progress = _progressPercent.round();

    final taskRequest = TaskUpdateRequest(
      title: title,
      description:
          description.isEmpty ? null : description,
      projectId: widget.task.projectId,
      startDate: normalizedStartDate,
      endDate: endDate,
      duration: duration,
      isDone: progress >= 100,
      progressPercent: progress,
      deadline: _deadline,
    );

    // Compatibilité avec l'ancien onglet Liste des tâches.
    // Cet écran attend encore directement un TaskUpdateRequest.
    if (!widget.hasGanttContext) {
      Navigator.of(context).pop(taskRequest);
      return;
    }

    final dependenciesToCreate =
        <DependencyCreateRequest>[];
    final dependenciesToUpdate =
        <TaskDependencyUpdateAction>[];

    for (final dependency in _dependencies) {
      final offsetDays = int.parse(
        dependency.offsetController.text.trim(),
      );

      if (dependency.id == null) {
        dependenciesToCreate.add(
          DependencyCreateRequest(
            predecessorId: dependency.predecessorId,
            successorId: widget.task.id,
            type: dependency.type,
            offsetDays: offsetDays,
          ),
        );
        continue;
      }

      if (dependency.hasChanged(offsetDays)) {
        dependenciesToUpdate.add(
          TaskDependencyUpdateAction(
            dependencyId: dependency.id!,
            request: DependencyUpdateRequest(
              predecessorId: dependency.predecessorId,
              successorId: widget.task.id,
              type: dependency.type,
              offsetDays: offsetDays,
            ),
          ),
        );
      }
    }

    final assignmentsToCreate =
        <ResourceAssignmentCreateRequest>[];
    final assignmentsToUpdate =
        <ResourceAssignmentUpdateAction>[];

    for (final assignment in _assignments) {
      final workload = double.parse(
        assignment.workloadController.text
            .trim()
            .replaceAll(',', '.'),
      );

      final allocation = int.parse(
        assignment.allocationController.text.trim(),
      );

      final resourceId =
          assignment.targetsGroup ? null : assignment.targetId;

      final resourceGroupId =
          assignment.targetsGroup ? assignment.targetId : null;

      if (assignment.id == null) {
        assignmentsToCreate.add(
          ResourceAssignmentCreateRequest(
            taskId: widget.task.id,
            resourceId: resourceId,
            resourceGroupId: resourceGroupId,
            workloadHours: workload,
            allocationPercent: allocation,
          ),
        );
        continue;
      }

      if (assignment.hasChanged(
        workloadHours: workload,
        allocationPercent: allocation,
      )) {
        assignmentsToUpdate.add(
          ResourceAssignmentUpdateAction(
            assignmentId: assignment.id!,
            request: ResourceAssignmentUpdateRequest(
              taskId: widget.task.id,
              resourceId: resourceId,
              resourceGroupId: resourceGroupId,
              workloadHours: workload,
              allocationPercent: allocation,
            ),
          ),
        );
      }
    }

    Navigator.of(context).pop(
      TaskEditResult(
        taskRequest: taskRequest,
        parentId: _selectedParentId!,
        dependencyIdsToDelete:
            _dependencyIdsToDelete.toList(),
        dependenciesToUpdate: dependenciesToUpdate,
        dependenciesToCreate: dependenciesToCreate,
        assignmentIdsToDelete:
            _assignmentIdsToDelete.toList(),
        assignmentsToUpdate: assignmentsToUpdate,
        assignmentsToCreate: assignmentsToCreate,
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            icon: Icons.info_outline,
            title: 'Informations générales',
            subtitle:
                'Titre, description et état d’avancement.',
          ),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titre',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le titre est obligatoire.';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            minLines: 5,
            maxLines: 8,
          ),
          const SizedBox(height: 20),
          Text(
            'Progression : ${_progressPercent.round()} %',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Slider(
            value: _progressPercent,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${_progressPercent.round()} %',
            onChanged: (value) {
              setState(() {
                _progressPercent = value;
              });
            },
          ),
          Row(
            children: [
              Icon(
                _progressPercent >= 100
                    ? Icons.check_circle
                    : Icons.timelapse,
                color: _progressPercent >= 100
                    ? Colors.green
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _progressPercent >= 100
                      ? 'La tâche sera marquée comme terminée.'
                      : 'La tâche restera en cours.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningTab() {
    final parsedDuration =
        int.tryParse(_durationController.text) ?? 1;

    final duration =
        parsedDuration > 0 ? parsedDuration : 1;

    final endDate = _computeEndDate(
      _startDate,
      duration,
    );

    final deadlineForPreview =
        _deadline == null
            ? null
            : _normalizeDeadlineForPreview(_deadline!);

    final isLatePreview =
        deadlineForPreview != null &&
        endDate.isAfter(deadlineForPreview);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            icon: Icons.calendar_month_outlined,
            title: 'Planning et position',
            subtitle:
                'Dates en jours ouvrés et emplacement dans le Gantt.',
          ),
          if (widget.hasGanttContext) ...[
            DropdownButtonFormField<int>(
              initialValue: _selectedParentId,
              decoration: const InputDecoration(
                labelText: 'Parent dans le Gantt',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: _structuralParents.map((parent) {
                return DropdownMenuItem<int>(
                  value: parent.id,
                  child: Text(
                    '${parent.wbsCode} · '
                    '${_planningItemTypeLabel(parent.type)} · '
                    '${parent.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedParentId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Choisis un parent structurel.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
          ] else ...[
            const Card(
              child: ListTile(
                leading: Icon(Icons.account_tree_outlined),
                title: Text('Position dans le Gantt'),
                subtitle: Text(
                  'Le changement de parent est disponible '
                  'depuis le Gantt structuré.',
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _durationController,
            decoration: const InputDecoration(
              labelText: 'Durée en jours ouvrés',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
            },
            validator: (value) {
              final duration = int.tryParse(value ?? '');

              if (duration == null || duration <= 0) {
                return 'La durée doit être supérieure à 0.';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickStartDate,
            icon: const Icon(Icons.event_available),
            label: Text(
              'Début : ${_formatDate(_startDate)}',
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Fin calculée'),
              subtitle: Text(
                '${_formatDate(endDate)} '
                'selon le calendrier du projet',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.event_busy),
                  label: Text(
                    _deadline == null
                        ? 'Deadline : aucune'
                        : 'Deadline : '
                            '${_formatDate(_deadline!)}',
                  ),
                ),
              ),
              if (_deadline != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Retirer la deadline',
                  onPressed: _clearDeadline,
                  icon: const Icon(Icons.clear),
                ),
              ],
            ],
          ),
          if (isLatePreview) ...[
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  'Retard probable',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'La fin calculée dépasse la deadline '
                  'ramenée au dernier jour ouvré.',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDependenciesTab() {
    final possibleTasks = _possiblePredecessorTasks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            icon: Icons.account_tree_outlined,
            title: 'Dépendances',
            subtitle:
                'Plusieurs prédécesseurs, types de liens et offsets.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed:
                  possibleTasks.isEmpty ? null : _addDependency,
              icon: const Icon(Icons.add_link),
              label: const Text('Ajouter un prédécesseur'),
            ),
          ),
          const SizedBox(height: 12),
          if (_dependencies.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.link_off),
                title: Text('Aucun prédécesseur'),
                subtitle: Text(
                  'La tâche peut commencer sans dépendance.',
                ),
              ),
            ),
          ..._dependencies.map((dependency) {
            return Card(
              key: ObjectKey(dependency),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<int>(
                        initialValue:
                            dependency.predecessorId,
                        decoration: const InputDecoration(
                          labelText: 'Prédécesseur',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: possibleTasks.map((task) {
                          return DropdownMenuItem<int>(
                            value: task.id,
                            child: Text(
                              task.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            dependency.predecessorId = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<String>(
                        initialValue: dependency.type,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'FS',
                            child: Text('FS'),
                          ),
                          DropdownMenuItem(
                            value: 'SS',
                            child: Text('SS'),
                          ),
                          DropdownMenuItem(
                            value: 'FF',
                            child: Text('FF'),
                          ),
                          DropdownMenuItem(
                            value: 'SF',
                            child: Text('SF'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            dependency.type = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller:
                            dependency.offsetController,
                        decoration: const InputDecoration(
                          labelText: 'Offset',
                          suffixText: 'j',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          signed: true,
                        ),
                        validator: (value) {
                          if (int.tryParse(value ?? '') == null) {
                            return 'Entier requis';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Supprimer cette dépendance',
                      onPressed: () =>
                          _removeDependency(dependency),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_dependencies.isNotEmpty)
            Text(
              'FS : fin-début · SS : début-début · '
              'FF : fin-fin · SF : début-fin.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _buildResourcesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            icon: Icons.groups_outlined,
            title: 'Ressources et groupes',
            subtitle:
                'Charge prévue et pourcentage d’allocation.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed:
                  _hasAssignmentTargets ? _addAssignment : null,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Ajouter une assignation'),
            ),
          ),
          const SizedBox(height: 12),
          if (_assignments.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.person_off_outlined),
                title: Text('Aucune assignation'),
                subtitle: Text(
                  'Ajoute une ressource ou un groupe.',
                ),
              ),
            ),
          ..._assignments.map((assignment) {
            final currentKey = _targetKey(
              targetsGroup: assignment.targetsGroup,
              targetId: assignment.targetId,
            );

            return Card(
              key: ObjectKey(assignment),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        initialValue: currentKey,
                        decoration: const InputDecoration(
                          labelText: 'Ressource ou groupe',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: [
                          ..._resources.map((resource) {
                            return DropdownMenuItem<String>(
                              value: _targetKey(
                                targetsGroup: false,
                                targetId: resource.id,
                              ),
                              child: Text(
                                'Ressource · ${resource.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                          ..._groups.map((group) {
                            return DropdownMenuItem<String>(
                              value: _targetKey(
                                targetsGroup: true,
                                targetId: group.id,
                              ),
                              child: Text(
                                'Groupe · ${group.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          final parts = value.split(':');

                          setState(() {
                            assignment.targetsGroup =
                                parts.first == 'group';
                            assignment.targetId =
                                int.parse(parts.last);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 135,
                      child: TextFormField(
                        controller:
                            assignment.workloadController,
                        decoration: const InputDecoration(
                          labelText: 'Charge',
                          suffixText: 'h',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final workload = double.tryParse(
                            (value ?? '').replaceAll(',', '.'),
                          );

                          if (workload == null ||
                              workload <= 0) {
                            return '> 0 requis';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 135,
                      child: TextFormField(
                        controller:
                            assignment.allocationController,
                        decoration: const InputDecoration(
                          labelText: 'Allocation',
                          suffixText: '%',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final allocation =
                              int.tryParse(value ?? '');

                          if (allocation == null ||
                              allocation <= 0 ||
                              allocation > 100) {
                            return '1 à 100';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Supprimer cette assignation',
                      onPressed: () =>
                          _removeAssignment(assignment),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_assignments.isNotEmpty)
            Text(
              '${_assignments.length} assignation(s) · '
              '${_assignments.map(_assignmentTargetLabel).join(' · ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingContent() {
    return const SizedBox(
      width: 920,
      height: 520,
      child: Center(
        child: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 18),
              Text(
                'Chargement du calendrier, des dépendances '
                'et des ressources…',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContent() {
    return SizedBox(
      width: 720,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              'Impossible de charger la tâche complète.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? 'Erreur inconnue',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_calendar_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Modifier la tâche · ${widget.task.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: _isLoading
          ? _buildLoadingContent()
          : _loadError != null
              ? _buildErrorContent()
              : SizedBox(
                  width: 920,
                  height: 640,
                  child: Form(
                    key: _formKey,
                    child: DefaultTabController(
                      length: widget.hasGanttContext ? 4 : 2,
                      child: Column(
                        children: [
                          TabBar(
                            tabs: [
                              const Tab(
                                icon: Icon(Icons.info_outline),
                                text: 'Informations',
                              ),
                              const Tab(
                                icon: Icon(
                                  Icons.calendar_month_outlined,
                                ),
                                text: 'Planning',
                              ),
                              if (widget.hasGanttContext)
                                const Tab(
                                  icon: Icon(
                                    Icons.account_tree_outlined,
                                  ),
                                  text: 'Dépendances',
                                ),
                              if (widget.hasGanttContext)
                                const Tab(
                                  icon: Icon(Icons.groups_outlined),
                                  text: 'Ressources',
                                ),
                            ],
                          ),
                          if (_validationMessage != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                0,
                              ),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Text(
                                _validationMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildInformationTab(),
                                _buildPlanningTab(),
                                if (widget.hasGanttContext)
                                  _buildDependenciesTab(),
                                if (widget.hasGanttContext)
                                  _buildResourcesTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed:
              !_isLoading && _loadError == null ? _submit : null,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Enregistrer tout'),
        ),
      ],
    );
  }
}

class _TaskEditCalendarData {
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;
  final List<ProjectCalendarPeriodModel> periods;

  const _TaskEditCalendarData({
    required this.calendar,
    required this.exceptions,
    required this.periods,
  });
}

class _EditableDependency {
  final int? id;

  int predecessorId;
  String type;
  final TextEditingController offsetController;

  final int? originalPredecessorId;
  final String? originalType;
  final int? originalOffsetDays;

  _EditableDependency({
    required this.id,
    required this.predecessorId,
    required this.type,
    required this.offsetController,
    required this.originalPredecessorId,
    required this.originalType,
    required this.originalOffsetDays,
  });

  factory _EditableDependency.fromExisting(
    TaskDependency dependency,
  ) {
    return _EditableDependency(
      id: dependency.id,
      predecessorId: dependency.predecessorId,
      type: dependency.type,
      offsetController: TextEditingController(
        text: dependency.offsetDays.toString(),
      ),
      originalPredecessorId: dependency.predecessorId,
      originalType: dependency.type,
      originalOffsetDays: dependency.offsetDays,
    );
  }

  factory _EditableDependency.newDependency({
    required int predecessorId,
  }) {
    return _EditableDependency(
      id: null,
      predecessorId: predecessorId,
      type: 'FS',
      offsetController: TextEditingController(text: '0'),
      originalPredecessorId: null,
      originalType: null,
      originalOffsetDays: null,
    );
  }

  bool hasChanged(int offsetDays) {
    return predecessorId != originalPredecessorId ||
        type != originalType ||
        offsetDays != originalOffsetDays;
  }

  void dispose() {
    offsetController.dispose();
  }
}

class _EditableAssignment {
  final int? id;

  bool targetsGroup;
  int targetId;

  final TextEditingController workloadController;
  final TextEditingController allocationController;

  final bool? originalTargetsGroup;
  final int? originalTargetId;
  final double? originalWorkloadHours;
  final int? originalAllocationPercent;

  _EditableAssignment({
    required this.id,
    required this.targetsGroup,
    required this.targetId,
    required this.workloadController,
    required this.allocationController,
    required this.originalTargetsGroup,
    required this.originalTargetId,
    required this.originalWorkloadHours,
    required this.originalAllocationPercent,
  });

  factory _EditableAssignment.fromExisting(
    ResourceAssignment assignment,
  ) {
    final targetsGroup = assignment.resourceGroupId != null;
    final targetId = assignment.resourceGroupId ??
        assignment.resourceId ??
        0;

    return _EditableAssignment(
      id: assignment.id,
      targetsGroup: targetsGroup,
      targetId: targetId,
      workloadController: TextEditingController(
        text: assignment.workloadHours.toString(),
      ),
      allocationController: TextEditingController(
        text: assignment.allocationPercent.toString(),
      ),
      originalTargetsGroup: targetsGroup,
      originalTargetId: targetId,
      originalWorkloadHours: assignment.workloadHours,
      originalAllocationPercent:
          assignment.allocationPercent,
    );
  }

  factory _EditableAssignment.newAssignment({
    required bool targetsGroup,
    required int targetId,
  }) {
    return _EditableAssignment(
      id: null,
      targetsGroup: targetsGroup,
      targetId: targetId,
      workloadController: TextEditingController(text: '8'),
      allocationController:
          TextEditingController(text: '100'),
      originalTargetsGroup: null,
      originalTargetId: null,
      originalWorkloadHours: null,
      originalAllocationPercent: null,
    );
  }

  bool hasChanged({
    required double workloadHours,
    required int allocationPercent,
  }) {
    return targetsGroup != originalTargetsGroup ||
        targetId != originalTargetId ||
        workloadHours != originalWorkloadHours ||
        allocationPercent != originalAllocationPercent;
  }

  void dispose() {
    workloadController.dispose();
    allocationController.dispose();
  }
}
