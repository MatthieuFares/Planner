import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/project_calendar_api.dart';
import '../data/project_calendar_exception_api.dart';
import '../data/project_calendar_exception_model.dart';
import '../data/project_calendar_model.dart';

class ProjectCalendarView extends StatefulWidget {
  final int projectId;

  const ProjectCalendarView({
    super.key,
    required this.projectId,
  });

  @override
  State<ProjectCalendarView> createState() => _ProjectCalendarViewState();
}

class _ProjectCalendarViewState extends State<ProjectCalendarView> {
  final ProjectCalendarApi _calendarApi = ProjectCalendarApi();
  final ProjectCalendarExceptionApi _exceptionApi =
      ProjectCalendarExceptionApi();

  final TextEditingController _exceptionLabelController =
      TextEditingController();

  ProjectCalendarModel? _calendar;
  List<ProjectCalendarExceptionModel> _exceptions = [];

  DateTime? _selectedExceptionDate;
  bool _selectedExceptionIsWorkingDay = false;

  bool _isLoading = true;
  bool _isSavingCalendar = false;
  bool _isSavingException = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _exceptionLabelController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final calendar = await _calendarApi.getByProjectId(widget.projectId);
      final exceptions = await _exceptionApi.getByProjectId(widget.projectId);

      if (!mounted) return;

      setState(() {
        _calendar = calendar;
        _exceptions = exceptions;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCalendar() async {
    final calendar = _calendar;

    if (calendar == null) return;

    setState(() {
      _isSavingCalendar = true;
      _error = null;
    });

    try {
      final updatedCalendar = await _calendarApi.updateByProjectId(
        projectId: widget.projectId,
        calendar: calendar,
      );

      if (!mounted) return;

      setState(() {
        _calendar = updatedCalendar;
        _isSavingCalendar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calendrier projet enregistré.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isSavingCalendar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur sauvegarde calendrier : $error'),
        ),
      );
    }
  }

  Future<void> _pickExceptionDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedExceptionDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedExceptionDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }

  Future<void> _addException() async {
    final selectedDate = _selectedExceptionDate;

    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisis une date pour l’exception.'),
        ),
      );
      return;
    }

    final label = _exceptionLabelController.text.trim();

    setState(() {
      _isSavingException = true;
      _error = null;
    });

    try {
      await _exceptionApi.create(
        projectId: widget.projectId,
        exception: ProjectCalendarExceptionModel(
          id: 0,
          projectCalendarId: 0,
          date: selectedDate,
          label: label.isEmpty ? 'Exception calendrier' : label,
          isWorkingDay: _selectedExceptionIsWorkingDay,
        ),
      );

      final exceptions = await _exceptionApi.getByProjectId(widget.projectId);

      if (!mounted) return;

      setState(() {
        _exceptions = exceptions;
        _selectedExceptionDate = null;
        _selectedExceptionIsWorkingDay = false;
        _exceptionLabelController.clear();
        _isSavingException = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exception calendrier ajoutée.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isSavingException = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur ajout exception : $error'),
        ),
      );
    }
  }

  Future<void> _deleteException(ProjectCalendarExceptionModel exception) async {
    setState(() {
      _error = null;
    });

    try {
      await _exceptionApi.delete(exception.id);

      final exceptions = await _exceptionApi.getByProjectId(widget.projectId);

      if (!mounted) return;

      setState(() {
        _exceptions = exceptions;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exception supprimée.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur suppression exception : $error'),
        ),
      );
    }
  }

  void _updateCalendar(ProjectCalendarModel calendar) {
    setState(() {
      _calendar = calendar;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LinearProgressIndicator();
    }

    if (_error != null && _calendar == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Erreur calendrier projet : $_error',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final calendar = _calendar;

    if (calendar == null) {
      return const Center(
        child: Text('Aucun calendrier projet à afficher.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCalendarCard(context, calendar),
              const SizedBox(height: 16),
              _buildExceptionsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarCard(
    BuildContext context,
    ProjectCalendarModel calendar,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month),
                const SizedBox(width: 8),
                Text(
                  'Calendrier projet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Rafraîchir',
                  onPressed: _isSavingCalendar ? null : _loadAll,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Définis les jours ouvrés standards du projet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 20),
            _WorkingDayCheckbox(
              label: 'Lundi',
              value: calendar.workMonday,
              onChanged: (value) {
                _updateCalendar(calendar.copyWith(workMonday: value));
              },
            ),
            _WorkingDayCheckbox(
              label: 'Mardi',
              value: calendar.workTuesday,
              onChanged: (value) {
                _updateCalendar(calendar.copyWith(workTuesday: value));
              },
            ),
            _WorkingDayCheckbox(
              label: 'Mercredi',
              value: calendar.workWednesday,
              onChanged: (value) {
                _updateCalendar(calendar.copyWith(workWednesday: value));
              },
            ),
            _WorkingDayCheckbox(
              label: 'Jeudi',
              value: calendar.workThursday,
              onChanged: (value) {
                _updateCalendar(calendar.copyWith(workThursday: value));
              },
            ),
            _WorkingDayCheckbox(
              label: 'Vendredi',
              value: calendar.workFriday,
              onChanged: (value) {
                _updateCalendar(calendar.copyWith(workFriday: value));
              },
            ),
            _WorkingDayCheckbox(
              label: 'Samedi',
              value: calendar.workSaturday,
              onChanged: (value) {
                _updateCalendar(calendar.copyWith(workSaturday: value));
              },
            ),
            _WorkingDayCheckbox(
              label: 'Dimanche',
              value: calendar.workSunday,
              onChanged: (value) {
                _updateCalendar(calendar.copyWith(workSunday: value));
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isSavingCalendar ? null : _saveCalendar,
                  icon: _isSavingCalendar
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSavingCalendar
                        ? 'Enregistrement...'
                        : 'Enregistrer',
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _isSavingCalendar ? null : _loadAll,
                  icon: const Icon(Icons.undo),
                  label: const Text('Annuler les changements'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExceptionsCard(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_busy),
                const SizedBox(width: 8),
                Text(
                  'Exceptions calendrier',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoute ici les jours fériés, fermetures chantier, ponts, ou jours travaillés exceptionnellement.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSavingException ? null : _pickExceptionDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _selectedExceptionDate == null
                        ? 'Choisir une date'
                        : dateFormatter.format(_selectedExceptionDate!),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _exceptionLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Libellé',
                      hintText: 'Ex : Noël, fermeture chantier...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                FilterChip(
                  label: Text(
                    _selectedExceptionIsWorkingDay
                        ? 'Jour travaillé'
                        : 'Jour non travaillé',
                  ),
                  selected: _selectedExceptionIsWorkingDay,
                  onSelected: _isSavingException
                      ? null
                      : (value) {
                          setState(() {
                            _selectedExceptionIsWorkingDay = value;
                          });
                        },
                ),
                FilledButton.icon(
                  onPressed: _isSavingException ? null : _addException,
                  icon: _isSavingException
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add),
                  label: Text(
                    _isSavingException ? 'Ajout...' : 'Ajouter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_exceptions.isEmpty)
              Text(
                'Aucune exception calendrier pour ce projet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Column(
                children: _exceptions.map((exception) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      exception.isWorkingDay
                          ? Icons.work_outline
                          : Icons.block,
                      color: exception.isWorkingDay
                          ? Theme.of(context).colorScheme.primary
                          : Colors.red,
                    ),
                    title: Text(
                      exception.label.isEmpty
                          ? 'Exception calendrier'
                          : exception.label,
                    ),
                    subtitle: Text(
                      '${dateFormatter.format(exception.date)} · '
                      '${exception.isWorkingDay ? 'Jour travaillé' : 'Jour non travaillé'}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteException(exception),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkingDayCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _WorkingDayCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value ? 'Jour ouvré' : 'Jour non ouvré'),
      value: value,
      onChanged: (newValue) {
        if (newValue == null) return;
        onChanged(newValue);
      },
    );
  }
}