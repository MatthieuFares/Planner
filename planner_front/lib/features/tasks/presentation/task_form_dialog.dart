import 'package:flutter/material.dart';

import '../../../core/utils/working_day_utils.dart';

import '../data/task_api.dart';
import '../data/task_model.dart';

import '../../project_calendar/data/project_calendar_api.dart';
import '../../project_calendar/data/project_calendar_exception_api.dart';
import '../../project_calendar/data/project_calendar_exception_model.dart';
import '../../project_calendar/data/project_calendar_model.dart';
import '../../project_calendar/data/project_calendar_period_api.dart';
import '../../project_calendar/data/project_calendar_period_model.dart';
import '../../project_calendar/utils/project_working_day_calculator.dart';

import '../../resources/data/resource_api.dart';
import '../../resources/data/resource_model.dart';

import 'task_form_result.dart';

class TaskFormDialog extends StatefulWidget {
  final int projectId;

  const TaskFormDialog({
    super.key,
    required this.projectId,
  });

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TaskApi _taskApi = TaskApi();
  final ResourceApi _resourceApi = ResourceApi();

  final ProjectCalendarApi _calendarApi = ProjectCalendarApi();
  final ProjectCalendarExceptionApi _exceptionApi =
      ProjectCalendarExceptionApi();
  final ProjectCalendarPeriodApi _periodApi =
      ProjectCalendarPeriodApi();

  final TextEditingController _titleController =
      TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();
  final TextEditingController _durationController =
      TextEditingController(text: '1');
  final TextEditingController _workloadHoursController =
      TextEditingController();
  final TextEditingController _allocationPercentController =
      TextEditingController(text: '100');

  _TaskFormOptions? _options;
  bool _isLoadingOptions = true;
  String? _optionsError;

  DateTime _startDate = DateTime.now();
  DateTime? _deadline;

  double _progressPercent = 0;

  int? _selectedPredecessorTaskId;
  int? _selectedResourceId;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _workloadHoursController.dispose();
    _allocationPercentController.dispose();

    super.dispose();
  }

  Future<void> _loadOptions() async {
    if (mounted) {
      setState(() {
        _isLoadingOptions = true;
        _optionsError = null;
      });
    }

    try {
      final calendar =
          await _calendarApi.getByProjectId(widget.projectId);

      final exceptions =
          await _exceptionApi.getByProjectId(widget.projectId);

      final periods =
          await _periodApi.getByProjectId(widget.projectId);

      final tasks =
          await _taskApi.getTasksByProject(widget.projectId);

      final resources = await _resourceApi.getResources();

      final options = _TaskFormOptions(
        tasks: tasks,
        resources: resources,
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

      if (!mounted) return;

      setState(() {
        _options = options;
        _startDate = normalizedStartDate;
        _isLoadingOptions = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _optionsError = error.toString();
        _isLoadingOptions = false;
      });
    }
  }

  DateTime _computeEndDate(
    DateTime startDate,
    int duration,
  ) {
    final options = _options;

    if (options == null) {
      return WorkingDayUtils.calculateTaskEndDate(
        startDate,
        duration,
      );
    }

    return ProjectWorkingDayCalculator.calculateTaskEndDate(
      startDate: startDate,
      duration: duration,
      calendar: options.calendar,
      exceptions: options.exceptions,
      periods: options.periods,
    );
  }

  DateTime _normalizeStartDate(DateTime date) {
    final options = _options;

    if (options == null) {
      return WorkingDayUtils.normalizeToWorkingDay(
        date,
        forward: true,
      );
    }

    return ProjectWorkingDayCalculator.normalizeToWorkingDay(
      date: date,
      calendar: options.calendar,
      exceptions: options.exceptions,
      periods: options.periods,
      forward: true,
    );
  }

  DateTime _normalizeDeadlineForPreview(DateTime date) {
    final options = _options;

    if (options == null) {
      return WorkingDayUtils.normalizeToWorkingDay(
        date,
        forward: false,
      );
    }

    return ProjectWorkingDayCalculator.normalizeToWorkingDay(
      date: date,
      calendar: options.calendar,
      exceptions: options.exceptions,
      periods: options.periods,
      forward: false,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _pickStartDate() async {
    if (_options == null) return;

    final DateTime? pickedDate = await showDatePicker(
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
    if (_options == null) return;

    final int parsedDuration =
        int.tryParse(_durationController.text) ?? 1;

    final int duration =
        parsedDuration > 0 ? parsedDuration : 1;

    final DateTime endDate = _computeEndDate(
      _startDate,
      duration,
    );

    final DateTime? pickedDate = await showDatePicker(
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

  double? _parseNullableDouble(String value) {
    final String normalized =
        value.trim().replaceAll(',', '.');

    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  void _submit() {
    if (_options == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le calendrier projet doit être chargé '
            'avant de créer la tâche.',
          ),
        ),
      );
      return;
    }

    final FormState? formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    final String title = _titleController.text.trim();
    final String description =
        _descriptionController.text.trim();

    final int duration =
        int.parse(_durationController.text);

    final DateTime normalizedStartDate =
        _normalizeStartDate(_startDate);

    final DateTime endDate = _computeEndDate(
      normalizedStartDate,
      duration,
    );

    final int progress = _progressPercent.round();

    final double? workloadHours =
        _parseNullableDouble(
      _workloadHoursController.text,
    );

    final int allocationPercent =
        _selectedResourceId == null
            ? 100
            : int.parse(
                _allocationPercentController.text,
              );

    final TaskCreateRequest taskRequest =
        TaskCreateRequest(
      title: title,
      description:
          description.isEmpty ? null : description,
      projectId: widget.projectId,
      startDate: normalizedStartDate,
      endDate: endDate,
      duration: duration,
      isDone: progress >= 100,
      progressPercent: progress,
      deadline: _deadline,
    );

    final TaskFormResult result = TaskFormResult(
      taskRequest: taskRequest,
      predecessorTaskId:
          _selectedPredecessorTaskId,
      dependencyType: 'FS',
      offsetDays: 0,
      resourceId: _selectedResourceId,
      workloadHours: workloadHours,
      allocationPercent: allocationPercent,
    );

    Navigator.of(context).pop(result);
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final int parsedDuration =
        int.tryParse(_durationController.text) ?? 1;

    final int duration =
        parsedDuration > 0 ? parsedDuration : 1;

    final DateTime endDate = _computeEndDate(
      _startDate,
      duration,
    );

    final DateTime? deadlineForPreview =
        _deadline == null
            ? null
            : _normalizeDeadlineForPreview(_deadline!);

    final bool isLatePreview =
        deadlineForPreview != null &&
        endDate.isAfter(deadlineForPreview);

    final options = _options;
    final tasks =
        options?.tasks ?? const <PlannerTask>[];
    final resources =
        options?.resources ?? const <Resource>[];

    return AlertDialog(
      title: const Text('Nouvelle tâche'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_isLoadingOptions)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),

                if (_optionsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Impossible de charger le calendrier '
                          'et les options : $_optionsError',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed:
                              _isLoadingOptions ? null : _loadOptions,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),

                TextFormField(
                  controller: _titleController,
                  enabled: !_isLoadingOptions,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Le titre est obligatoire.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isLoadingOptions,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        enabled: !_isLoadingOptions,
                        decoration: const InputDecoration(
                          labelText: 'Durée en jours ouvrés',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType:
                            TextInputType.number,
                        onChanged: (String value) {
                          setState(() {});
                        },
                        validator: (String? value) {
                          final int? duration =
                              int.tryParse(value ?? '');

                          if (duration == null ||
                              duration <= 0) {
                            return 'La durée doit être '
                                'supérieure à 0.';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            options == null ? null : _pickStartDate,
                        icon: const Icon(
                          Icons.calendar_month,
                        ),
                        label: Text(
                          'Début : '
                          '${_formatDate(_startDate)}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    options == null
                        ? 'Fin calculée après chargement '
                            'du calendrier projet.'
                        : 'Fin calculée : '
                            '${_formatDate(endDate)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            options == null ? null : _pickDeadline,
                        icon: const Icon(
                          Icons.event_busy,
                        ),
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cette tâche sera probablement '
                      'en retard par rapport à sa deadline.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Planification',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall,
                  ),
                ),
                const SizedBox(height: 8),

                DropdownButtonFormField<int?>(
                  initialValue:
                      _selectedPredecessorTaskId,
                  decoration: const InputDecoration(
                    labelText: 'Prédécesseur',
                    helperText:
                        'Optionnel — lien FS avec offset 0 jour',
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Aucun prédécesseur'),
                    ),
                    ...tasks.map(
                      (PlannerTask task) {
                        final DateTime? taskStartDate =
                            task.startDate;
                        final DateTime? taskEndDate =
                            task.endDate;

                        final String dateLabel =
                            taskStartDate != null &&
                                    taskEndDate != null
                                ? '${_formatDate(taskStartDate)} '
                                    '→ '
                                    '${_formatDate(taskEndDate)}'
                                : 'dates indisponibles';

                        return DropdownMenuItem<int?>(
                          value: task.id,
                          child: Text(
                            '${task.title} ($dateLabel)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ],
                  onChanged: options == null
                      ? null
                      : (int? value) {
                          setState(() {
                            _selectedPredecessorTaskId =
                                value;
                          });
                        },
                ),

                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Assignation',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall,
                  ),
                ),
                const SizedBox(height: 8),

                DropdownButtonFormField<int?>(
                  initialValue: _selectedResourceId,
                  decoration: const InputDecoration(
                    labelText: 'Ressource assignée',
                    helperText:
                        'Optionnel — une ressource à la création',
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Aucune ressource'),
                    ),
                    ...resources.map(
                      (Resource resource) {
                        return DropdownMenuItem<int?>(
                          value: resource.id,
                          child: Text(
                            '${resource.name} · '
                            '${resource.type} · '
                            '${resource.costPerHour.toStringAsFixed(0)} €/h',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ],
                  onChanged: options == null
                      ? null
                      : (int? value) {
                          setState(() {
                            _selectedResourceId = value;

                            if (_selectedResourceId == null) {
                              _workloadHoursController.clear();
                              _allocationPercentController.text =
                                  '100';
                            }
                          });
                        },
                ),

                if (_selectedResourceId != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller:
                              _workloadHoursController,
                          decoration:
                              const InputDecoration(
                            labelText: 'Charge en heures',
                            hintText: 'Ex : 14',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                          ),
                          validator: (String? value) {
                            if (_selectedResourceId == null) {
                              return null;
                            }

                            final double? workload =
                                _parseNullableDouble(
                              value ?? '',
                            );

                            if (workload == null ||
                                workload <= 0) {
                              return 'La charge doit être '
                                  'supérieure à 0.';
                            }

                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller:
                              _allocationPercentController,
                          decoration:
                              const InputDecoration(
                            labelText: 'Allocation %',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType:
                              TextInputType.number,
                          validator: (String? value) {
                            if (_selectedResourceId == null) {
                              return null;
                            }

                            final int? allocation =
                                int.tryParse(value ?? '');

                            if (allocation == null ||
                                allocation <= 0 ||
                                allocation > 100) {
                              return 'Entre 1 et 100.';
                            }

                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Progression : '
                    '${_progressPercent.round()}%',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall,
                  ),
                ),
                Slider(
                  value: _progressPercent,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label:
                      '${_progressPercent.round()}%',
                  onChanged: options == null
                      ? null
                      : (double value) {
                          setState(() {
                            _progressPercent = value;
                          });
                        },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _progressPercent >= 100
                        ? 'La tâche sera marquée '
                            'comme terminée.'
                        : 'La tâche sera marquée '
                            'comme en cours.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _cancel,
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed:
              options == null || _isLoadingOptions
                  ? null
                  : _submit,
          child: const Text('Créer'),
        ),
      ],
    );
  }
}

class _TaskFormOptions {
  final List<PlannerTask> tasks;
  final List<Resource> resources;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;
  final List<ProjectCalendarPeriodModel> periods;

  const _TaskFormOptions({
    required this.tasks,
    required this.resources,
    required this.calendar,
    required this.exceptions,
    required this.periods,
  });
}
