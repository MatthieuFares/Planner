import 'package:flutter/material.dart';

class PlanningVersionFormResult {
  final String name;
  final String? description;
  final String? createdBy;

  const PlanningVersionFormResult({
    required this.name,
    required this.description,
    required this.createdBy,
  });
}

class PlanningVersionFormDialog extends StatefulWidget {
  const PlanningVersionFormDialog({
    super.key,
  });

  @override
  State<PlanningVersionFormDialog> createState() =>
      _PlanningVersionFormDialogState();
}

class _PlanningVersionFormDialogState
    extends State<PlanningVersionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _createdByController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _createdByController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Le nom de la version est obligatoire.';
    }

    if (text.length > 150) {
      return 'Le nom ne peut pas dépasser 150 caractères.';
    }

    return null;
  }

  String? _validateDescription(String? value) {
    final text = value?.trim() ?? '';

    if (text.length > 1000) {
      return 'La description ne peut pas dépasser 1000 caractères.';
    }

    return null;
  }

  String? _validateCreatedBy(String? value) {
    final text = value?.trim() ?? '';

    if (text.length > 150) {
      return 'Le nom de l’auteur ne peut pas dépasser 150 caractères.';
    }

    return null;
  }

  String? _normalizeOptional(String value) {
    final text = value.trim();

    return text.isEmpty ? null : text;
  }

  void _submit() {
    if (_isSubmitting) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = PlanningVersionFormResult(
      name: _nameController.text.trim(),
      description: _normalizeOptional(
        _descriptionController.text,
      ),
      createdBy: _normalizeOptional(
        _createdByController.text,
      ),
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.history),
          SizedBox(width: 12),
          Expanded(
            child: Text('Créer une version du planning'),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cette version conservera les tâches, la hiérarchie, '
                          'les dépendances, les assignations et le calendrier '
                          'dans leur état actuel.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 150,
                  validator: _validateName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la version',
                    hintText: 'Ex. Planning avant modifications client',
                    prefixIcon: Icon(Icons.label_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 5,
                  validator: _validateDescription,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Décris les changements ou le contexte '
                        'de cette version.',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _createdByController,
                  maxLength: 150,
                  validator: _validateCreatedBy,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Auteur',
                    hintText: 'Ex. Stéphane',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Créer la version'),
        ),
      ],
    );
  }
}
