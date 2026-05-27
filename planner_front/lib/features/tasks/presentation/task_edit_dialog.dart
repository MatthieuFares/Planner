import 'package:flutter/material.dart';

import '../data/task_model.dart';

class TaskEditDialog extends StatefulWidget {
  final PlannerTask task;

  const TaskEditDialog({
    super.key,
    required this.task,
  });

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _durationController;

  late DateTime _startDate;
  late double _progressPercent;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.task.title);

    _descriptionController = TextEditingController(
      text: widget.task.description ?? '',
    );

    _durationController = TextEditingController(
      text: (widget.task.duration ?? 1).toString(),
    );

    _startDate = widget.task.startDate ?? DateTime.now();
    _progressPercent = widget.task.progressPercent.toDouble();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  DateTime _computeEndDate(DateTime startDate, int duration) {
    return startDate.add(Duration(days: duration));
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
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final duration = int.parse(_durationController.text);

    final endDate = _computeEndDate(_startDate, duration);
    final progress = _progressPercent.round();

    final request = TaskUpdateRequest(
      title: title,
      description: description.isEmpty ? null : description,
      projectId: widget.task.projectId,
      startDate: _startDate,
      endDate: endDate,
      duration: duration,
      isDone: progress >= 100,
      progressPercent: progress,
    );

    Navigator.of(context).pop(request);
  }

  @override
  Widget build(BuildContext context) {
    final duration = int.tryParse(_durationController.text) ?? 1;
    final endDate = _computeEndDate(_startDate, duration);

    return AlertDialog(
      title: const Text('Modifier la tâche'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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

                TextFormField(
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
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickStartDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          'Début : ${_startDate.day.toString().padLeft(2, '0')}/'
                          '${_startDate.month.toString().padLeft(2, '0')}/'
                          '${_startDate.year}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Fin calculée : ${endDate.day.toString().padLeft(2, '0')}/'
                    '${endDate.month.toString().padLeft(2, '0')}/'
                    '${endDate.year}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),

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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}