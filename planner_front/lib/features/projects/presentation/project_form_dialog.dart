import 'package:flutter/material.dart';

import '../data/project_model.dart';

class ProjectFormDialog extends StatefulWidget {
  final Project? project;

  const ProjectFormDialog({
    super.key,
    this.project,
  });

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _clientNameController;
  late final TextEditingController _projectCodeController;

  DateTime? _startDate;
  DateTime? _endDate;

  bool get _isEditMode => widget.project != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.project?.name ?? '',
    );

    _descriptionController = TextEditingController(
      text: widget.project?.description ?? '',
    );

    _clientNameController = TextEditingController(
      text: widget.project?.clientName ?? '',
    );

    _projectCodeController = TextEditingController(
      text: widget.project?.projectCode ?? '',
    );

    _startDate = widget.project?.startDate;
    _endDate = widget.project?.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    _projectCodeController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Non définie';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _pickStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null) return;

    setState(() {
      _startDate = pickedDate;

      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null) return;

    setState(() {
      _endDate = pickedDate;
    });
  }

  void _clearStartDate() {
    setState(() {
      _startDate = null;
    });
  }

  void _clearEndDate() {
    setState(() {
      _endDate = null;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final clientName = _clientNameController.text.trim();
    final projectCode = _projectCodeController.text.trim();

    if (_isEditMode) {
      final request = ProjectUpdateRequest(
        name: name,
        description: description.isEmpty ? null : description,
        clientName: clientName.isEmpty ? null : clientName,
        projectCode: projectCode.isEmpty ? null : projectCode,
        startDate: _startDate,
        endDate: _endDate,
      );

      Navigator.of(context).pop(request);
    } else {
      final request = ProjectCreateRequest(
        name: name,
        description: description.isEmpty ? null : description,
        clientName: clientName.isEmpty ? null : clientName,
        projectCode: projectCode.isEmpty ? null : projectCode,
        startDate: _startDate,
        endDate: _endDate,
      );

      Navigator.of(context).pop(request);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Modifier le projet' : 'Nouveau projet'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du projet',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom du projet est obligatoire.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _projectCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Code projet / ID client',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _clientNameController,
                  decoration: const InputDecoration(
                    labelText: 'Client',
                    border: OutlineInputBorder(),
                  ),
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
                      child: OutlinedButton.icon(
                        onPressed: _pickStartDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text('Début : ${_formatDate(_startDate)}'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Effacer la date de début',
                      onPressed: _clearStartDate,
                      icon: const Icon(Icons.clear),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickEndDate,
                        icon: const Icon(Icons.event_available),
                        label: Text('Fin : ${_formatDate(_endDate)}'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Effacer la date de fin',
                      onPressed: _clearEndDate,
                      icon: const Icon(Icons.clear),
                    ),
                  ],
                ),

                if (_startDate != null &&
                    _endDate != null &&
                    _endDate!.isBefore(_startDate!))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'La date de fin ne peut pas être avant la date de début.',
                      style: TextStyle(color: Colors.red),
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
          child: Text(_isEditMode ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }
}