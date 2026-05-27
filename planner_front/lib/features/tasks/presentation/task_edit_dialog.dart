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

  late bool _isDone;

  DateTime? _startDate;
  DateTime? _endDate;

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

    _isDone = widget.task.isDone;
    _startDate = widget.task.startDate;
    _endDate = widget.task.endDate;

    _durationController.addListener(_recalculateEndDate);
  }

  @override
  void dispose() {
    _durationController.removeListener(_recalculateEndDate);
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _recalculateEndDate() {
    if (_startDate == null) return;

    final duration = int.tryParse(_durationController.text);

    if (duration == null || duration <= 0) return;

    setState(() {
      _endDate = _startDate!.add(Duration(days: duration));
    });
  }

  Future<void> _pickStartDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (selectedDate != null) {
      setState(() {
        _startDate = selectedDate;
      });

      _recalculateEndDate();
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de sélectionner une date de début.'),
        ),
      );
      return;
    }

    final duration = int.parse(_durationController.text);
    final calculatedEndDate = _startDate!.add(Duration(days: duration));

    final request = TaskUpdateRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      projectId: widget.task.projectId,
      startDate: _startDate!,
      endDate: calculatedEndDate,
      duration: duration,
      isDone: _isDone,
    );

    Navigator.of(context).pop(request);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Non calculée';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier la tâche'),
      content: SizedBox(
        width: 520,
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
                  validator: (value) {
                    final duration = int.tryParse(value ?? '');

                    if (duration == null || duration <= 0) {
                      return 'La durée doit être un nombre supérieur à 0.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickStartDate,
                        child: Text('Début : ${_formatDate(_startDate)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Fin calculée : ${_formatDate(_endDate)}',
                  ),
                ),
                const SizedBox(height: 12),

                CheckboxListTile(
                  value: _isDone,
                  onChanged: (value) {
                    setState(() {
                      _isDone = value ?? false;
                    });
                  },
                  title: const Text('Tâche terminée'),
                  controlAffinity: ListTileControlAffinity.leading,
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