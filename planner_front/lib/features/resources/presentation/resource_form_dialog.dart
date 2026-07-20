import 'package:flutter/material.dart';

import '../data/resource_model.dart';

class ResourceFormDialog extends StatefulWidget {
  final Resource? resource;

  const ResourceFormDialog({
    super.key,
    this.resource,
  });

  @override
  State<ResourceFormDialog> createState() => _ResourceFormDialogState();
}

class _ResourceFormDialogState extends State<ResourceFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _capacityController;
  late final TextEditingController _costController;

  final List<String> _resourceTypes = [
    'Person',
    'Team',
    'Material',
  ];

  String _selectedType = 'Person';

  bool get _isEditMode => widget.resource != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.resource?.name ?? '',
    );

    _capacityController = TextEditingController(
      text: widget.resource?.capacityHoursPerWeek.toString() ?? '35',
    );

    _costController = TextEditingController(
      text: widget.resource?.costPerHour.toString() ?? '0',
    );

    final existingType = widget.resource?.type;

    if (existingType != null &&
        existingType.isNotEmpty &&
        _resourceTypes.contains(existingType)) {
      _selectedType = existingType;
    } else {
      _selectedType = 'Person';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final type = _selectedType;
    final capacity = int.parse(_capacityController.text);
    final cost = double.parse(_costController.text.replaceAll(',', '.'));

    if (_isEditMode) {
      Navigator.of(context).pop(
        ResourceUpdateRequest(
          name: name,
          type: type,
          capacityHoursPerWeek: capacity,
          costPerHour: cost,
        ),
      );
    } else {
      Navigator.of(context).pop(
        ResourceCreateRequest(
          name: name,
          type: type,
          capacityHoursPerWeek: capacity,
          costPerHour: cost,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Modifier la ressource' : 'Nouvelle ressource'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom est obligatoire.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _resourceTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedType = value;
                    });
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Capacité heures / semaine',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final capacity = int.tryParse(value ?? '');

                    if (capacity == null || capacity < 0) {
                      return 'La capacité doit être un nombre positif.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _costController,
                  decoration: const InputDecoration(
                    labelText: 'Coût horaire',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final cost = double.tryParse(
                      (value ?? '').replaceAll(',', '.'),
                    );

                    if (cost == null || cost < 0) {
                      return 'Le coût horaire doit être un nombre positif.';
                    }

                    return null;
                  },
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
          child: Text(_isEditMode ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }
}