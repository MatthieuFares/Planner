import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../projects/data/project_access_api.dart';
import '../../projects/data/project_access_model.dart';
import '../data/project_baseline_api.dart';
import '../data/project_baseline_model.dart';

class ProjectBaselineView extends StatefulWidget {
  final int projectId;

  const ProjectBaselineView({
    super.key,
    required this.projectId,
  });

  @override
  State<ProjectBaselineView> createState() => _ProjectBaselineViewState();
}

class _ProjectBaselineViewState extends State<ProjectBaselineView> {
  final ProjectAccessApi _projectAccessApi =
      ProjectAccessApi();
  final ProjectBaselineApi _api = ProjectBaselineApi();

  ProjectAccessModel? _access;
  List<ProjectBaselineModel> _baselines = [];
  ProjectBaselineComparisonModel? _comparison;
  int? _selectedBaselineId;

  bool _isLoading = true;
  bool _isCreating = false;
  bool _isComparing = false;
  String? _error;

  final DateFormat _dateFormatter =
      DateFormat('dd/MM/yyyy');

  bool get _canEdit =>
      _access?.canEditPlanning == true;

  @override
  void initState() {
    super.initState();
    _loadBaselines();
  }

  Future<void> _loadBaselines() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final access = await _projectAccessApi
          .getProjectAccess(widget.projectId);

      final baselines = await _api.getByProjectId(
        widget.projectId,
      );

      int? selectedBaselineId = _selectedBaselineId;

      final selectedStillExists = baselines.any(
        (baseline) => baseline.id == selectedBaselineId,
      );

      if (!selectedStillExists) {
        ProjectBaselineModel? activeBaseline;

        for (final baseline in baselines) {
          if (baseline.isActive) {
            activeBaseline = baseline;
            break;
          }
        }

        selectedBaselineId = activeBaseline?.id ??
            (baselines.isEmpty ? null : baselines.first.id);
      }

      ProjectBaselineComparisonModel? comparison;

      if (selectedBaselineId != null) {
        comparison = await _api.compare(selectedBaselineId);
      }

      if (!mounted) return;

      setState(() {
        _access = access;
        _baselines = baselines;
        _selectedBaselineId = selectedBaselineId;
        _comparison = comparison;
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

  Future<void> _showCreateBaselineDialog() async {
    if (!_canEdit) return;

    final nameController = TextEditingController(
      text: 'Baseline ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
    );
    final descriptionController = TextEditingController();
    var setAsActive = true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Créer une baseline'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Définir comme baseline active'),
                      value: setAsActive,
                      onChanged: (value) {
                        setDialogState(() {
                          setAsActive = value ?? true;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isCreating
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton.icon(
                  onPressed: _isCreating
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final description =
                              descriptionController.text.trim();

                          if (name.isEmpty) return;

                          Navigator.of(context).pop();

                          await _createBaseline(
                            name: name,
                            description:
                                description.isEmpty ? null : description,
                            setAsActive: setAsActive,
                          );
                        },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _createBaseline({
    required String name,
    String? description,
    required bool setAsActive,
  }) async {
    if (!_canEdit) return;

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final createdBaseline = await _api.create(
        projectId: widget.projectId,
        name: name,
        description: description,
        setAsActive: setAsActive,
      );

      _selectedBaselineId = createdBaseline.id;

      await _loadBaselines();

      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baseline créée et sélectionnée.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isCreating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur création baseline : $error'),
        ),
      );
    }
  }

  Future<void> _setActive(ProjectBaselineModel baseline) async {
    if (!_canEdit) return;

    setState(() {
      _error = null;
    });

    try {
      await _api.setActive(baseline.id);

      _selectedBaselineId = baseline.id;
      await _loadBaselines();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baseline active mise à jour.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur activation baseline : $error'),
        ),
      );
    }
  }

  Future<void> _deleteBaseline(ProjectBaselineModel baseline) async {
    if (!_canEdit) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la baseline ?'),
          content: Text(
            'La baseline "${baseline.name}" sera supprimée définitivement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _error = null;
    });

    try {
      await _api.delete(baseline.id);

      if (_selectedBaselineId == baseline.id) {
        _selectedBaselineId = null;
      }

      await _loadBaselines();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baseline supprimée.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur suppression baseline : $error'),
        ),
      );
    }
  }

  Future<void> _compareBaseline(
    ProjectBaselineModel baseline,
  ) async {
    setState(() {
      _selectedBaselineId = baseline.id;
      _isComparing = true;
      _error = null;
    });

    try {
      final comparison = await _api.compare(baseline.id);

      if (!mounted) return;

      setState(() {
        _comparison = comparison;
        _isComparing = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isComparing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur comparaison baseline : $error'),
        ),
      );
    }
  }

  Future<void> _selectBaselineById(int? baselineId) async {
    if (baselineId == null) return;

    ProjectBaselineModel? selected;

    for (final baseline in _baselines) {
      if (baseline.id == baselineId) {
        selected = baseline;
        break;
      }
    }

    if (selected == null) return;

    await _compareBaseline(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LinearProgressIndicator();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              if (!_canEdit) ...[
                const SizedBox(height: 12),
                const _ReadOnlyBaselineBanner(),
              ],
              const SizedBox(height: 16),
              if (_error != null) _buildErrorCard(),
              _buildBaselinesCard(context),
              const SizedBox(height: 16),
              if (_comparison != null) _buildComparisonCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.camera_alt_outlined),
        const SizedBox(width: 8),
        Text(
          'Baselines / Snapshots',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _isCreating ? null : _loadBaselines,
          icon: const Icon(Icons.refresh),
          label: const Text('Rafraîchir'),
        ),
        if (_canEdit) ...[
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isCreating
                ? null
                : _showCreateBaselineDialog,
            icon: _isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add),
            label: Text(
              _isCreating
                  ? 'Création...'
                  : 'Créer baseline',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildBaselinesCard(BuildContext context) {
    if (_baselines.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                _canEdit
                    ? 'Aucune baseline créée pour ce projet.'
                    : 'Aucune baseline disponible pour ce projet.',
              ),
              if (_canEdit) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      _showCreateBaselineDialog,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Créer la première baseline',
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _baselines.map((baseline) {
            final isSelected =
                baseline.id == _selectedBaselineId;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              selected: isSelected,
              selectedTileColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: Icon(
                baseline.isActive
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: baseline.isActive
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      baseline.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (baseline.isActive) ...[
                    const SizedBox(width: 8),
                    const Chip(
                      label: Text('Active'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                '${_dateFormatter.format(baseline.createdAt)} · '
                '${baseline.taskCount} tâche(s)'
                '${baseline.description == null || baseline.description!.isEmpty ? '' : ' · ${baseline.description}'}',
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isComparing
                        ? null
                        : () =>
                            _compareBaseline(baseline),
                    icon: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.compare_arrows,
                    ),
                    label: Text(
                      isSelected
                          ? 'Sélectionnée'
                          : 'Comparer',
                    ),
                  ),
                  if (_canEdit &&
                      !baseline.isActive)
                    OutlinedButton.icon(
                      onPressed: () =>
                          _setActive(baseline),
                      icon: const Icon(
                        Icons.check_circle_outline,
                      ),
                      label: const Text('Activer'),
                    ),
                  if (_canEdit)
                    IconButton(
                      tooltip: 'Supprimer',
                      onPressed: () =>
                          _deleteBaseline(baseline),
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildComparisonCard(BuildContext context) {
    final comparison = _comparison!;

    final delayedRows = comparison.rows
        .where((row) => row.isDelayedComparedToBaseline)
        .length;

    final missingRows = comparison.rows
        .where((row) => row.isMissingFromCurrentPlanning)
        .length;

    final changedRows = comparison.rows
        .where(_hasAnyVariance)
        .length;

    final comparableRows = comparison.rows
        .where(
          (row) =>
              !row.isMissingFromCurrentPlanning &&
              row.currentEndDate != null,
        )
        .toList();

    final averageStartVariance = _averageVariance(
      comparableRows
          .map((row) => row.startVarianceDays)
          .whereType<int>(),
    );

    final averageEndVariance = _averageVariance(
      comparableRows
          .map((row) => row.endVarianceDays)
          .whereType<int>(),
    );

    final averageDurationVariance = _averageVariance(
      comparableRows.map((row) => row.durationVarianceDays),
    );

    final driftRows = comparableRows
        .where((row) => (row.endVarianceDays ?? 0) != 0)
        .toList()
      ..sort(
        (a, b) => (b.endVarianceDays ?? 0)
            .abs()
            .compareTo((a.endVarianceDays ?? 0).abs()),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.compare_arrows),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Comparaison du planning',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                ),
                SizedBox(
                  width: 340,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey<int?>(
                      _selectedBaselineId,
                    ),
                    initialValue: _selectedBaselineId,
                    decoration: const InputDecoration(
                      labelText: 'Baseline comparée',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: _baselines.map((baseline) {
                      return DropdownMenuItem<int>(
                        value: baseline.id,
                        child: Text(
                          '${baseline.name}'
                          '${baseline.isActive ? ' · active' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _isComparing
                        ? null
                        : _selectBaselineById,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              context: context,
              icon: Icons.task_alt,
              label: 'Tâches capturées',
              value: '${comparison.rows.length}',
              detail:
                  '$changedRows avec au moins une variation',
            ),
            _buildMetricCard(
              context: context,
              icon: Icons.schedule,
              label: 'Dérive moyenne de fin',
              value: _formatSignedAverage(
                averageEndVariance,
              ),
              detail:
                  'Écart entre baseline et planning courant',
              isAlert: averageEndVariance > 0,
              isPositive: averageEndVariance < 0,
            ),
            _buildMetricCard(
              context: context,
              icon: Icons.play_arrow_outlined,
              label: 'Dérive moyenne de début',
              value: _formatSignedAverage(
                averageStartVariance,
              ),
              detail:
                  'Décalage moyen des dates de démarrage',
              isAlert: averageStartVariance > 0,
              isPositive: averageStartVariance < 0,
            ),
            _buildMetricCard(
              context: context,
              icon: Icons.timelapse,
              label: 'Variation de durée',
              value: _formatSignedAverage(
                averageDurationVariance,
              ),
              detail:
                  '$delayedRows tâche(s) retardée(s)',
              isAlert: averageDurationVariance > 0,
              isPositive: averageDurationVariance < 0,
            ),
            _buildMetricCard(
              context: context,
              icon: Icons.delete_sweep_outlined,
              label: 'Absentes du planning',
              value: '$missingRows',
              detail:
                  'Présentes dans la baseline uniquement',
              isAlert: missingRows > 0,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDriftChartCard(
          context: context,
          rows: driftRows.take(12).toList(),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Détail · ${comparison.baselineName}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge,
                      ),
                    ),
                    Text(
                      'Créée le '
                      '${_dateFormatter.format(comparison.createdAt)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('WBS')),
                      DataColumn(label: Text('Tâche')),
                      DataColumn(label: Text('Début')),
                      DataColumn(label: Text('Δ Début')),
                      DataColumn(label: Text('Fin')),
                      DataColumn(label: Text('Δ Fin')),
                      DataColumn(label: Text('Durée')),
                      DataColumn(label: Text('Δ Durée')),
                      DataColumn(label: Text('Progression')),
                      DataColumn(label: Text('Float')),
                      DataColumn(label: Text('Statut')),
                    ],
                    rows: comparison.rows.map((row) {
                      return DataRow(
                        color:
                            WidgetStateProperty.resolveWith<Color?>(
                          (states) {
                            if (row.isMissingFromCurrentPlanning) {
                              return Colors.grey.withValues(
                                alpha: 0.18,
                              );
                            }

                            if (row.isDelayedComparedToBaseline ||
                                row.currentIsLate) {
                              return Colors.red.withValues(
                                alpha: 0.08,
                              );
                            }

                            if (_hasAnyVariance(row)) {
                              return Colors.orange.withValues(
                                alpha: 0.08,
                              );
                            }

                            return null;
                          },
                        ),
                        cells: [
                          DataCell(
                            Text(row.wbsCode ?? '-'),
                          ),
                          DataCell(
                            SizedBox(
                              width: 220,
                              child: Text(
                                row.taskTitle,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${_formatDate(row.baselineStartDate)} '
                              '→ ${_formatDate(row.currentStartDate)}',
                            ),
                          ),
                          DataCell(
                            _varianceText(
                              row.startVarianceDays,
                            ),
                          ),
                          DataCell(
                            Text(
                              '${_formatDate(row.baselineEndDate)} '
                              '→ ${_formatDate(row.currentEndDate)}',
                            ),
                          ),
                          DataCell(
                            _varianceText(
                              row.endVarianceDays,
                            ),
                          ),
                          DataCell(
                            Text(
                              '${row.baselineDuration}j '
                              '→ ${row.currentDuration}j',
                            ),
                          ),
                          DataCell(
                            _varianceText(
                              row.durationVarianceDays,
                            ),
                          ),
                          DataCell(
                            Text(
                              '${row.baselineProgressPercent}% '
                              '→ ${row.currentProgressPercent}%',
                            ),
                          ),
                          DataCell(
                            Text(
                              '${row.baselineTotalFloat} '
                              '→ ${row.currentTotalFloat}',
                            ),
                          ),
                          DataCell(_statusChip(row)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required String detail,
    bool isAlert = false,
    bool isPositive = false,
  }) {
    final color = isAlert
        ? Colors.red
        : isPositive
            ? Colors.green
            : Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 248,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriftChartCard({
    required BuildContext context,
    required List<ProjectBaselineComparisonRowModel> rows,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart),
                const SizedBox(width: 8),
                Text(
                  'Principales dérives de fin',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Les valeurs positives indiquent un retard '
              'par rapport à la baseline.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 18,
                ),
                child: Center(
                  child: Text(
                    'Aucune dérive de fin détectée.',
                  ),
                ),
              )
            else
              _BaselineVarianceChart(
                entries: rows.map((row) {
                  return _BaselineVarianceEntry(
                    label: row.wbsCode == null ||
                            row.wbsCode!.isEmpty
                        ? row.taskTitle
                        : '${row.wbsCode} · '
                            '${row.taskTitle}',
                    value: row.endVarianceDays ?? 0,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  double _averageVariance(Iterable<int> values) {
    final list = values.toList();

    if (list.isEmpty) return 0;

    final total = list.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    return total / list.length;
  }

  String _formatSignedAverage(double value) {
    final rounded = value.abs() < 0.05
        ? '0'
        : value.toStringAsFixed(1);

    if (value > 0) {
      return '+$rounded j';
    }

    return '$rounded j';
  }

  bool _hasAnyVariance(ProjectBaselineComparisonRowModel row) {
    return row.isMissingFromCurrentPlanning ||
        (row.startVarianceDays ?? 0) != 0 ||
        (row.endVarianceDays ?? 0) != 0 ||
        row.durationVarianceDays != 0 ||
        row.progressVariancePercent != 0 ||
        row.totalFloatVariance != 0 ||
        row.baselineIsCritical != row.currentIsCritical ||
        row.baselineIsLate != row.currentIsLate ||
        row.baselineDelayDays != row.currentDelayDays;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return _dateFormatter.format(date);
  }

  Widget _varianceText(int? variance) {
    if (variance == null) {
      return const Text('-');
    }

    if (variance == 0) {
      return const Text('0');
    }

    final text = variance > 0 ? '+$variance' : '$variance';

    return Text(
      text,
      style: TextStyle(
        color: variance > 0 ? Colors.red : Colors.green,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _statusChip(ProjectBaselineComparisonRowModel row) {
    if (row.isMissingFromCurrentPlanning) {
      return const Chip(
        label: Text('Supprimée'),
        visualDensity: VisualDensity.compact,
      );
    }

    if (row.currentIsLate) {
      return Chip(
        label: Text('Retard +${row.currentDelayDays}j'),
        visualDensity: VisualDensity.compact,
      );
    }

    if (row.isDelayedComparedToBaseline) {
      return const Chip(
        label: Text('Décalée'),
        visualDensity: VisualDensity.compact,
      );
    }

    if (row.currentIsCritical) {
      return const Chip(
        label: Text('Critique'),
        visualDensity: VisualDensity.compact,
      );
    }

    return const Chip(
      label: Text('OK'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ReadOnlyBaselineBanner
    extends StatelessWidget {
  const _ReadOnlyBaselineBanner();

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
              'et comparer les baselines existantes.',
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

class _BaselineVarianceEntry {
  final String label;
  final int value;

  const _BaselineVarianceEntry({
    required this.label,
    required this.value,
  });
}

class _BaselineVarianceChart extends StatelessWidget {
  final List<_BaselineVarianceEntry> entries;

  const _BaselineVarianceChart({
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    var maxAbsValue = 1;

    for (final entry in entries) {
      if (entry.value.abs() > maxAbsValue) {
        maxAbsValue = entry.value.abs();
      }
    }

    return Column(
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 260,
                child: Tooltip(
                  message: entry.label,
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final halfWidth =
                        constraints.maxWidth / 2;

                    final barWidth =
                        (entry.value.abs() /
                                maxAbsValue) *
                            (halfWidth - 12);

                    final isDelay = entry.value > 0;
                    final barColor = isDelay
                        ? Colors.red
                        : Colors.green;

                    return SizedBox(
                      height: 24,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: halfWidth,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 1,
                              color: Theme.of(context)
                                  .dividerColor,
                            ),
                          ),
                          Positioned(
                            left: isDelay
                                ? halfWidth
                                : halfWidth - barWidth,
                            width: barWidth,
                            top: 4,
                            bottom: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: barColor.withValues(
                                  alpha: 0.75,
                                ),
                                borderRadius:
                                    BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          Positioned(
                            left: isDelay
                                ? halfWidth + barWidth + 6
                                : null,
                            right: isDelay
                                ? null
                                : halfWidth + barWidth + 6,
                            child: Text(
                              entry.value > 0
                                  ? '+${entry.value}j'
                                  : '${entry.value}j',
                              style: TextStyle(
                                color: barColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

