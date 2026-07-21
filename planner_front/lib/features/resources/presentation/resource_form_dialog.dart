import 'package:flutter/material.dart';

import '../data/resource_model.dart';

class ResourceFormDialog extends StatefulWidget {
  final Resource? resource;

  const ResourceFormDialog({
    super.key,
    this.resource,
  });

  @override
  State<ResourceFormDialog> createState() =>
      _ResourceFormDialogState();
}

class _ResourceFormDialogState
    extends State<ResourceFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _capacityController;
  late final TextEditingController _costController;

  String _type = 'Person';

  bool get _isEditMode => widget.resource != null;

  static const List<String> _resourceTypes = [
    'Person',
    'Team',
    'Material',
  ];

  @override
  void initState() {
    super.initState();

    final resource = widget.resource;

    _nameController = TextEditingController(
      text: resource?.name ?? '',
    );

    _capacityController = TextEditingController(
      text: resource == null
          ? '35'
          : resource.capacityHoursPerWeek.toString(),
    );

    _costController = TextEditingController(
      text: resource == null
          ? '0'
          : _formatEditableNumber(resource.costPerHour),
    );

    final existingType = resource?.type.trim();

    if (existingType != null &&
        _resourceTypes.contains(existingType)) {
      _type = existingType;
    } else if (existingType != null &&
        existingType.isNotEmpty) {
      _type = existingType;
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();

    final capacityHoursPerWeek = int.parse(
      _capacityController.text.trim(),
    );

    final costPerHour = double.parse(
      _costController.text
          .trim()
          .replaceAll(',', '.'),
    );

    if (_isEditMode) {
      Navigator.of(context).pop(
        ResourceUpdateRequest(
          name: name,
          type: _type,
          capacityHoursPerWeek:
              capacityHoursPerWeek,
          costPerHour: costPerHour,
        ),
      );

      return;
    }

    Navigator.of(context).pop(
      ResourceCreateRequest(
        name: name,
        type: _type,
        capacityHoursPerWeek:
            capacityHoursPerWeek,
        costPerHour: costPerHour,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableTypes = <String>{
      ..._resourceTypes,
      _type,
    }.toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isEditMode
                ? Icons.edit_outlined
                : Icons.person_add_alt_outlined,
          ),
          const SizedBox(width: 10),
          Text(
            _isEditMode
                ? 'Modifier la ressource'
                : 'Nouvelle ressource',
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isEditMode,
                  textInputAction:
                      TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la ressource',
                    prefixIcon:
                        Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Le nom de la ressource est obligatoire.';
                    }

                    if (value.trim().length > 100) {
                      return 'Le nom ne peut pas dépasser 100 caractères.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type de ressource',
                    prefixIcon:
                        Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: availableTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        _resourceTypeLabel(type),
                      ),
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
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller:
                            _capacityController,
                        keyboardType:
                            TextInputType.number,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Capacité hebdomadaire',
                          suffixText: 'h/semaine',
                          prefixIcon:
                              Icon(Icons.schedule),
                          border:
                              OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final capacity = int.tryParse(
                            value?.trim() ?? '',
                          );

                          if (capacity == null) {
                            return 'Capacité invalide.';
                          }

                          if (capacity < 0) {
                            return 'La capacité ne peut pas être négative.';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText: 'Coût horaire',
                          suffixText: '€/h',
                          prefixIcon:
                              Icon(Icons.euro_outlined),
                          border:
                              OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final cost = double.tryParse(
                            (value ?? '')
                                .trim()
                                .replaceAll(',', '.'),
                          );

                          if (cost == null) {
                            return 'Coût invalide.';
                          }

                          if (cost < 0) {
                            return 'Le coût ne peut pas être négatif.';
                          }

                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ResourceTypeNotice(type: _type),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(
            _isEditMode
                ? Icons.save_outlined
                : Icons.add,
          ),
          label: Text(
            _isEditMode
                ? 'Enregistrer'
                : 'Créer',
          ),
        ),
      ],
    );
  }
}

class _ResourceTypeNotice extends StatelessWidget {
  final String type;

  const _ResourceTypeNotice({
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final message = switch (type.toLowerCase()) {
      'person' =>
        'Ressource individuelle avec une capacité et un coût propres.',
      'team' =>
        'Équipe considérée comme une ressource unique dans les assignations.',
      'material' =>
        'Ressource matérielle utilisable dans le planning.',
      _ =>
        'Type personnalisé conservé depuis les données existantes.',
    };

    final icon = switch (type.toLowerCase()) {
      'team' => Icons.groups_outlined,
      'material' => Icons.build_outlined,
      _ => Icons.person_outline,
    };

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color:
                Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style:
                  Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

String _resourceTypeLabel(String type) {
  switch (type.toLowerCase()) {
    case 'person':
      return 'Personne';
    case 'team':
      return 'Équipe';
    case 'material':
      return 'Matériel';
    default:
      return type;
  }
}

String _formatEditableNumber(num value) {
  final doubleValue = value.toDouble();

  if (doubleValue ==
      doubleValue.roundToDouble()) {
    return doubleValue.toInt().toString();
  }

  return doubleValue.toString();
}
