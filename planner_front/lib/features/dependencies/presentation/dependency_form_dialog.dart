import 'package:flutter/material.dart';

import '../../tasks/data/task_model.dart';
import '../data/dependency_model.dart';

class DependencyFormDialog extends StatefulWidget {
  final List<PlannerTask> tasks;
  final TaskDependency? dependency;

  const DependencyFormDialog({
    super.key,
    required this.tasks,
    this.dependency,
  });

  @override
  State<DependencyFormDialog> createState() => _DependencyFormDialogState();
}

class _DependencyFormDialogState extends State<DependencyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _offsetController = TextEditingController(text: '0');

  int? _predecessorId;
  int? _successorId;
  String _type = 'FS';

  bool get _isEditMode => widget.dependency != null;

  final List<String> _types = ['FS', 'SS', 'FF', 'SF'];

  @override
  void initState() {
    super.initState();

    final dependency = widget.dependency;

    if (dependency != null) {
      _predecessorId = dependency.predecessorId;
      _successorId = dependency.successorId;
      _type = dependency.type;
      _offsetController.text = dependency.offsetDays.toString();
    }
  }

  @override
  void dispose() {
    _offsetController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_predecessorId == null || _successorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de sélectionner deux tâches.'),
        ),
      );
      return;
    }

    if (_predecessorId == _successorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Une tâche ne peut pas dépendre d’elle-même.'),
        ),
      );
      return;
    }

    final offsetDays = int.parse(_offsetController.text);

    if (_isEditMode) {
      Navigator.of(context).pop(
        DependencyUpdateRequest(
          predecessorId: _predecessorId!,
          successorId: _successorId!,
          type: _type,
          offsetDays: offsetDays,
        ),
      );
    } else {
      Navigator.of(context).pop(
        DependencyCreateRequest(
          predecessorId: _predecessorId!,
          successorId: _successorId!,
          type: _type,
          offsetDays: offsetDays,
        ),
      );
    }
  }

  String _taskLabel(PlannerTask task) {
    return '#${task.id} - ${task.title}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Modifier la dépendance' : 'Nouvelle dépendance'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _predecessorId,
                decoration: const InputDecoration(
                  labelText: 'Tâche prédécesseur',
                  border: OutlineInputBorder(),
                ),
                items: widget.tasks.map((task) {
                  return DropdownMenuItem<int>(
                    value: task.id,
                    child: Text(_taskLabel(task)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _predecessorId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'La tâche prédécesseur est obligatoire.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<int>(
                initialValue: _successorId,
                decoration: const InputDecoration(
                  labelText: 'Tâche successeur',
                  border: OutlineInputBorder(),
                ),
                items: widget.tasks.map((task) {
                  return DropdownMenuItem<int>(
                    value: task.id,
                    child: Text(_taskLabel(task)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _successorId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'La tâche successeur est obligatoire.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type de dépendance',
                  border: OutlineInputBorder(),
                ),
                items: _types.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _type = value;
                  });
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _offsetController,
                decoration: const InputDecoration(
                  labelText: 'Offset en jours',
                  border: OutlineInputBorder(),
                  helperText: 'Exemple : 0, 1, -1',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final offset = int.tryParse(value ?? '');

                  if (offset == null) {
                    return 'Offset invalide.';
                  }

                  return null;
                },
              ),
            ],
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
          child: Text(_isEditMode ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }
}