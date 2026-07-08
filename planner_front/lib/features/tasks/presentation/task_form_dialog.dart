import 'package:flutter/material.dart';
import '../../../core/utils/working_day_utils.dart';

import '../data/task_api.dart';
import '../data/task_model.dart';

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
  final _formKey = GlobalKey<FormState>();

  final TaskApi _taskApi = TaskApi();
  final ResourceApi _resourceApi = ResourceApi();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '1');
  final _workloadHoursController = TextEditingController();
  final _allocationPercentController = TextEditingController(text: '100');

  late Future<_TaskFormOptions> _optionsFuture;

  DateTime _startDate = DateTime.now();
  DateTime? _deadline;

  double _progressPercent = 0;

  int? _selectedPredecessorTaskId;
  int? _selectedResourceId;

  @override
  void initState() {
    super.initState();
    _optionsFuture = _loadOptions();
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

  Future<_TaskFormOptions> _loadOptions() async {
    final tasks = await _taskApi.getTasksByProject(widget.projectId);
    final resources = await _resourceApi.getResources();

    return _TaskFormOptions(
      tasks: tasks,
      resources: resources,
    );
  }

  DateTime _computeEndDate(DateTime startDate, int duration) {
    return WorkingDayUtils.addWorkingDays(startDate, duration);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _pickStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null) return;

    setState(() {
      _startDate = pickedDate;

      if (_deadline != null && _deadline!.isBefore(_startDate)) {
        _deadline = null;
      }
    });
  }

  Future<void> _pickDeadline() async {
    final duration = int.tryParse(_durationController.text) ?? 1;
    final endDate = _computeEndDate(_startDate, duration);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _deadline ?? endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null) return;

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
    final normalized = value.trim().replaceAll(',', '.');

    if (normalized.isEmpty) return null;

    return double.tryParse(normalized);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final duration = int.parse(_durationController.text);

    final endDate = _computeEndDate(_startDate, duration);
    final progress = _progressPercent.round();

    final workloadHours = _parseNullableDouble(_workloadHoursController.text);

    final allocationPercent = _selectedResourceId == null
        ? 100
        : int.parse(_allocationPercentController.text);

    final taskRequest = TaskCreateRequest(
      title: title,
      description: description.isEmpty ? null : description,
      projectId: widget.projectId,
      startDate: _startDate,
      endDate: endDate,
      duration: duration,
      isDone: progress >= 100,
      progressPercent: progress,
      deadline: _deadline,
    );

    final result = TaskFormResult(
      taskRequest: taskRequest,
      predecessorTaskId: _selectedPredecessorTaskId,
      dependencyType: 'FS',
      offsetDays: 0,
      resourceId: _selectedResourceId,
      workloadHours: workloadHours,
      allocationPercent: allocationPercent,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final duration = int.tryParse(_durationController.text) ?? 1;
    final endDate = _computeEndDate(_startDate, duration);

    final isLatePreview = _deadline != null && endDate.isAfter(_deadline!);

    return AlertDialog(
      title: const Text('Nouvelle tâche'),
      content: SizedBox(
        width: 620,
        child: FutureBuilder<_TaskFormOptions>(
          future: _optionsFuture,
          builder: (context, snapshot) {
            final options = snapshot.data ??
                const _TaskFormOptions(
                  tasks: [],
                  resources: [],
                );

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),

                    if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Options prédécesseur/ressources indisponibles : ${snapshot.error}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
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
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            decoration: const InputDecoration(
                              labelText: 'Durée en jours',
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
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickStartDate,
                            icon: const Icon(Icons.calendar_month),
                            label: Text('Début : ${_formatDate(_startDate)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Fin calculée : ${_formatDate(endDate)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDeadline,
                            icon: const Icon(Icons.event_busy),
                            label: Text(
                              _deadline == null
                                  ? 'Deadline : aucune'
                                  : 'Deadline : ${_formatDate(_deadline!)}',
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
                          'Cette tâche sera probablement en retard par rapport à sa deadline.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<int?>(
                      value: _selectedPredecessorTaskId,
                      decoration: const InputDecoration(
                        labelText: 'Prédécesseur',
                        helperText: 'Optionnel — lien FS avec offset 0 jour',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Aucun prédécesseur'),
                        ),
                        ...options.tasks.map((task) {
                          return DropdownMenuItem<int?>(
                            value: task.id,
                            child: Text(
                              '${task.title} (${_formatDate(task.startDate ?? DateTime.now())} → ${_formatDate(task.endDate ?? DateTime.now())})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedPredecessorTaskId = value;
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
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<int?>(
                      value: _selectedResourceId,
                      decoration: const InputDecoration(
                        labelText: 'Ressource assignée',
                        helperText: 'Optionnel — une ressource à la création',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Aucune ressource'),
                        ),
                        ...options.resources.map((resource) {
                          return DropdownMenuItem<int?>(
                            value: resource.id,
                            child: Text(
                              '${resource.name} · ${resource.type} · ${resource.costPerHour.toStringAsFixed(0)} €/h',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedResourceId = value;

                          if (_selectedResourceId == null) {
                            _workloadHoursController.clear();
                            _allocationPercentController.text = '100';
                          }
                        });
                      },
                    ),

                    if (_selectedResourceId != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _workloadHoursController,
                              decoration: const InputDecoration(
                                labelText: 'Charge en heures',
                                hintText: 'Ex : 14',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (value) {
                                if (_selectedResourceId == null) return null;

                                final workload =
                                    _parseNullableDouble(value ?? '');

                                if (workload == null || workload <= 0) {
                                  return 'La charge doit être supérieure à 0.';
                                }

                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _allocationPercentController,
                              decoration: const InputDecoration(
                                labelText: 'Allocation %',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (_selectedResourceId == null) return null;

                                final allocation = int.tryParse(value ?? '');

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
                        'Progression : ${_progressPercent.round()}%',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Slider(
                      value: _progressPercent,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${_progressPercent.round()}%',
                      onChanged: (value) {
                        setState(() {
                          _progressPercent = value;
                        });
                      },
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _progressPercent >= 100
                            ? 'La tâche sera marquée comme terminée.'
                            : 'La tâche sera marquée comme en cours.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Créer'),
        ),
      ],
    );
  }
}

class _TaskFormOptions {
  final List<PlannerTask> tasks;
  final List<Resource> resources;

  const _TaskFormOptions({
    required this.tasks,
    required this.resources,
  });
}