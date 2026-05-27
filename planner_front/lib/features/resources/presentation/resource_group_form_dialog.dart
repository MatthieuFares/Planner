import 'package:flutter/material.dart';

import '../data/resource_group_model.dart';

class ResourceGroupFormDialog extends StatefulWidget {
  final ResourceGroup? group;

  const ResourceGroupFormDialog({
    super.key,
    this.group,
  });

  @override
  State<ResourceGroupFormDialog> createState() =>
      _ResourceGroupFormDialogState();
}

class _ResourceGroupFormDialogState extends State<ResourceGroupFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  bool get _isEditMode => widget.group != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.group?.name ?? '',
    );

    _descriptionController = TextEditingController(
      text: widget.group?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (_isEditMode) {
      Navigator.of(context).pop(
        ResourceGroupUpdateRequest(
          name: name,
          description: description.isEmpty ? null : description,
        ),
      );
    } else {
      Navigator.of(context).pop(
        ResourceGroupCreateRequest(
          name: name,
          description: description.isEmpty ? null : description,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Modifier le groupe' : 'Nouveau groupe'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du groupe',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom du groupe est obligatoire.';
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