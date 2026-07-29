import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../projects/data/project_access_api.dart';
import '../../projects/data/project_access_model.dart';
import '../data/project_calendar_api.dart';
import '../data/project_calendar_exception_api.dart';
import '../data/project_calendar_exception_model.dart';
import '../data/project_calendar_model.dart';
import '../data/project_calendar_period_api.dart';
import '../data/project_calendar_period_model.dart';

class ProjectCalendarView extends StatefulWidget {
  final int projectId;
  final VoidCallback? onCalendarChanged;

  const ProjectCalendarView({
    super.key,
    required this.projectId,
    this.onCalendarChanged,
  });

  @override
  State<ProjectCalendarView> createState() => _ProjectCalendarViewState();
}

class _ProjectCalendarViewState extends State<ProjectCalendarView> {
  final ProjectAccessApi _projectAccessApi =
      ProjectAccessApi();
  final ProjectCalendarApi _calendarApi = ProjectCalendarApi();
  final ProjectCalendarExceptionApi _exceptionApi =
      ProjectCalendarExceptionApi();
  final ProjectCalendarPeriodApi _periodApi = ProjectCalendarPeriodApi();

  final TextEditingController _exceptionLabelController =
      TextEditingController();
  final TextEditingController _periodLabelController =
      TextEditingController();

  ProjectAccessModel? _access;
  ProjectCalendarModel? _calendar;
  List<ProjectCalendarPeriodModel> _periods = [];
  List<ProjectCalendarExceptionModel> _exceptions = [];

  DateTime? _selectedPeriodStartDate;
  DateTime? _selectedPeriodEndDate;

  DateTime? _selectedExceptionDate;
  bool _selectedExceptionIsWorkingDay = false;

  bool _isLoading = true;
  bool _isSavingCalendar = false;
  bool _isSavingPeriod = false;
  bool _isSavingException = false;

  String? _error;

  bool get _canEdit =>
      _access?.canEditPlanning == true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _exceptionLabelController.dispose();
    _periodLabelController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final access = await _projectAccessApi
          .getProjectAccess(widget.projectId);
      final calendar = await _calendarApi
          .getByProjectId(widget.projectId);
      final periods = await _periodApi
          .getByProjectId(widget.projectId);
      final exceptions = await _exceptionApi
          .getByProjectId(widget.projectId);

      if (!mounted) return;

      setState(() {
        _access = access;
        _calendar = calendar;
        _periods = periods;
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
    if (!_canEdit) return;

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

      widget.onCalendarChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Calendrier enregistré et planning recalculé.',
          ),
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

  Future<void> _pickPeriodStartDate() async {
    if (!_canEdit) return;

    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedPeriodStartDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );

    if (!mounted || pickedDate == null) return;

    final normalizedDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
    );

    setState(() {
      _selectedPeriodStartDate = normalizedDate;

      if (_selectedPeriodEndDate == null ||
          _selectedPeriodEndDate!.isBefore(normalizedDate)) {
        _selectedPeriodEndDate = normalizedDate;
      }
    });
  }

  Future<void> _pickPeriodEndDate() async {
    if (!_canEdit) return;

    final startDate = _selectedPeriodStartDate;

    if (startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choisis d’abord la date de début de la période.',
          ),
        ),
      );
      return;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedPeriodEndDate ?? startDate,
      firstDate: startDate,
      lastDate: DateTime(startDate.year + 10),
    );

    if (!mounted || pickedDate == null) return;

    setState(() {
      _selectedPeriodEndDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }

  Future<void> _addPeriod() async {
    if (!_canEdit) return;

    final startDate = _selectedPeriodStartDate;
    final endDate = _selectedPeriodEndDate;

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choisis une date de début et une date de fin.',
          ),
        ),
      );
      return;
    }

    if (endDate.isBefore(startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La date de fin doit être postérieure ou égale au début.',
          ),
        ),
      );
      return;
    }

    final label = _periodLabelController.text.trim();

    setState(() {
      _isSavingPeriod = true;
      _error = null;
    });

    try {
      await _periodApi.create(
        projectId: widget.projectId,
        period: ProjectCalendarPeriodModel(
          id: 0,
          projectCalendarId: 0,
          startDate: startDate,
          endDate: endDate,
          label: label.isEmpty ? 'Période non ouvrée' : label,
        ),
      );

      final periods = await _periodApi.getByProjectId(widget.projectId);

      if (!mounted) return;

      setState(() {
        _periods = periods;
        _selectedPeriodStartDate = null;
        _selectedPeriodEndDate = null;
        _periodLabelController.clear();
        _isSavingPeriod = false;
      });

      widget.onCalendarChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Période ajoutée et planning recalculé.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isSavingPeriod = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur ajout période : $error'),
        ),
      );
    }
  }

  Future<void> _deletePeriod(
    ProjectCalendarPeriodModel period,
  ) async {
    if (!_canEdit) return;

    setState(() {
      _error = null;
    });

    try {
      await _periodApi.delete(period.id);

      final periods = await _periodApi.getByProjectId(widget.projectId);

      if (!mounted) return;

      setState(() {
        _periods = periods;
      });

      widget.onCalendarChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Période supprimée et planning recalculé.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur suppression période : $error'),
        ),
      );
    }
  }

  Future<void> _pickExceptionDate() async {
    if (!_canEdit) return;

    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedExceptionDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );

    if (!mounted || pickedDate == null) return;

    setState(() {
      _selectedExceptionDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }

  Future<void> _addException() async {
    if (!_canEdit) return;

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

      widget.onCalendarChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Exception ajoutée et planning recalculé.',
          ),
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

  Future<void> _deleteException(
    ProjectCalendarExceptionModel exception,
  ) async {
    if (!_canEdit) return;

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

      widget.onCalendarChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Exception supprimée et planning recalculé.',
          ),
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
    if (!_canEdit) return;

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
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_canEdit) ...[
                const _ReadOnlyCalendarBanner(),
                const SizedBox(height: 16),
              ],
              _buildCalendarCard(context, calendar),
              const SizedBox(height: 16),
              _buildPeriodsCard(context),
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
              onChanged: _canEdit
                  ? (value) {
                      _updateCalendar(
                        calendar.copyWith(
                          workMonday: value,
                        ),
                      );
                    }
                  : null,
            ),
            _WorkingDayCheckbox(
              label: 'Mardi',
              value: calendar.workTuesday,
              onChanged: _canEdit
                  ? (value) {
                      _updateCalendar(
                        calendar.copyWith(
                          workTuesday: value,
                        ),
                      );
                    }
                  : null,
            ),
            _WorkingDayCheckbox(
              label: 'Mercredi',
              value: calendar.workWednesday,
              onChanged: _canEdit
                  ? (value) {
                      _updateCalendar(
                        calendar.copyWith(
                          workWednesday: value,
                        ),
                      );
                    }
                  : null,
            ),
            _WorkingDayCheckbox(
              label: 'Jeudi',
              value: calendar.workThursday,
              onChanged: _canEdit
                  ? (value) {
                      _updateCalendar(
                        calendar.copyWith(
                          workThursday: value,
                        ),
                      );
                    }
                  : null,
            ),
            _WorkingDayCheckbox(
              label: 'Vendredi',
              value: calendar.workFriday,
              onChanged: _canEdit
                  ? (value) {
                      _updateCalendar(
                        calendar.copyWith(
                          workFriday: value,
                        ),
                      );
                    }
                  : null,
            ),
            _WorkingDayCheckbox(
              label: 'Samedi',
              value: calendar.workSaturday,
              onChanged: _canEdit
                  ? (value) {
                      _updateCalendar(
                        calendar.copyWith(
                          workSaturday: value,
                        ),
                      );
                    }
                  : null,
            ),
            _WorkingDayCheckbox(
              label: 'Dimanche',
              value: calendar.workSunday,
              onChanged: _canEdit
                  ? (value) {
                      _updateCalendar(
                        calendar.copyWith(
                          workSunday: value,
                        ),
                      );
                    }
                  : null,
            ),
            if (_canEdit) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isSavingCalendar
                        ? null
                        : _saveCalendar,
                    icon: _isSavingCalendar
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSavingCalendar
                          ? 'Enregistrement...'
                          : 'Enregistrer et recalculer',
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isSavingCalendar
                        ? null
                        : _loadAll,
                    icon: const Icon(Icons.undo),
                    label: const Text(
                      'Annuler les changements',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodsCard(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.date_range),
                const SizedBox(width: 8),
                Text(
                  'Périodes non ouvrées',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoute une plage complète de congés, fermeture chantier '
              'ou indisponibilité collective.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_canEdit) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _isSavingPeriod ? null : _pickPeriodStartDate,
                  icon: const Icon(Icons.first_page),
                  label: Text(
                    _selectedPeriodStartDate == null
                        ? 'Date de début'
                        : dateFormatter.format(
                            _selectedPeriodStartDate!,
                          ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isSavingPeriod ? null : _pickPeriodEndDate,
                  icon: const Icon(Icons.last_page),
                  label: Text(
                    _selectedPeriodEndDate == null
                        ? 'Date de fin'
                        : dateFormatter.format(
                            _selectedPeriodEndDate!,
                          ),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _periodLabelController,
                    enabled: !_isSavingPeriod,
                    decoration: const InputDecoration(
                      labelText: 'Libellé',
                      hintText: 'Ex : Congés d’été...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isSavingPeriod ? null : _addPeriod,
                  icon: _isSavingPeriod
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add),
                  label: Text(
                    _isSavingPeriod ? 'Ajout...' : 'Ajouter',
                  ),
                ),
              ],
            ),
              const SizedBox(height: 20),
            ],
            if (_periods.isEmpty)
              Text(
                'Aucune période non ouvrée pour ce projet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Column(
                children: _periods.map((period) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.block,
                      color: Colors.red,
                    ),
                    title: Text(
                      period.label.isEmpty
                          ? 'Période non ouvrée'
                          : period.label,
                    ),
                    subtitle: Text(
                      '${dateFormatter.format(period.startDate)} → '
                      '${dateFormatter.format(period.endDate)}',
                    ),
                    trailing: _canEdit
                        ? IconButton(
                            tooltip: 'Supprimer',
                            icon: const Icon(
                              Icons.delete_outline,
                            ),
                            onPressed: () =>
                                _deletePeriod(period),
                          )
                        : null,
                  );
                }).toList(),
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
              'Ajoute un jour férié, un pont ou un jour travaillé '
              'exceptionnellement. Une exception précise est prioritaire '
              'sur une période non ouvrée.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_canEdit) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _isSavingException ? null : _pickExceptionDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _selectedExceptionDate == null
                        ? 'Choisir une date'
                        : dateFormatter.format(
                            _selectedExceptionDate!,
                          ),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _exceptionLabelController,
                    enabled: !_isSavingException,
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
                  onPressed:
                      _isSavingException ? null : _addException,
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
            ],
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
                    trailing: _canEdit
                        ? IconButton(
                            tooltip: 'Supprimer',
                            icon: const Icon(
                              Icons.delete_outline,
                            ),
                            onPressed: () =>
                                _deleteException(exception),
                          )
                        : null,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyCalendarBanner
    extends StatelessWidget {
  const _ReadOnlyCalendarBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            color: Theme.of(context)
                .colorScheme
                .onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode lecture seule : vous pouvez consulter '
              'les jours ouvrés, périodes et exceptions.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkingDayCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

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
      onChanged: onChanged == null
          ? null
          : (newValue) {
              if (newValue == null) return;
              onChanged!(newValue);
            },
    );
  }
}
