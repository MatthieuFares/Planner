import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final ProjectBaselineApi _api = ProjectBaselineApi();

  List<ProjectBaselineModel> _baselines = [];
  ProjectBaselineComparisonModel? _comparison;

  bool _isLoading = true;
  bool _isCreating = false;
  bool _isComparing = false;
  String? _error;

  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

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
      final baselines = await _api.getByProjectId(widget.projectId);

      if (!mounted) return;

      setState(() {
        _baselines = baselines;
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
    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      await _api.create(
        projectId: widget.projectId,
        name: name,
        description: description,
        setAsActive: setAsActive,
      );

      final baselines = await _api.getByProjectId(widget.projectId);

      if (!mounted) return;

      setState(() {
        _baselines = baselines;
        _comparison = null;
        _isCreating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baseline créée.'),
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
    setState(() {
      _error = null;
    });

    try {
      await _api.setActive(baseline.id);

      final baselines = await _api.getByProjectId(widget.projectId);

      if (!mounted) return;

      setState(() {
        _baselines = baselines;
      });

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

      final baselines = await _api.getByProjectId(widget.projectId);

      if (!mounted) return;

      setState(() {
        _baselines = baselines;
        if (_comparison?.baselineId == baseline.id) {
          _comparison = null;
        }
      });

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

  Future<void> _compareBaseline(ProjectBaselineModel baseline) async {
    setState(() {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LinearProgressIndicator();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
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
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _isCreating ? null : _showCreateBaselineDialog,
          icon: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: Text(_isCreating ? 'Création...' : 'Créer baseline'),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.withOpacity(0.08),
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
              const Text('Aucune baseline créée pour ce projet.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _showCreateBaselineDialog,
                icon: const Icon(Icons.add),
                label: const Text('Créer la première baseline'),
              ),
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
            return ListTile(
              contentPadding: EdgeInsets.zero,
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
                    onPressed:
                        _isComparing ? null : () => _compareBaseline(baseline),
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Comparer'),
                  ),
                  if (!baseline.isActive)
                    OutlinedButton.icon(
                      onPressed: () => _setActive(baseline),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Activer'),
                    ),
                  IconButton(
                    tooltip: 'Supprimer',
                    onPressed: () => _deleteBaseline(baseline),
                    icon: const Icon(Icons.delete_outline),
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
    final changedRows = comparison.rows.where(_hasAnyVariance).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.compare_arrows),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comparaison : ${comparison.baselineName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${comparison.rows.length} tâche(s)')),
                Chip(label: Text('$changedRows modifiée(s)')),
                Chip(label: Text('$delayedRows retardée(s)')),
                if (missingRows > 0)
                  Chip(label: Text('$missingRows supprimée(s)')),
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
                    color: WidgetStateProperty.resolveWith<Color?>(
                      (states) {
                        if (row.isMissingFromCurrentPlanning) {
                          return Colors.grey.withOpacity(0.18);
                        }

                        if (row.isDelayedComparedToBaseline ||
                            row.currentIsLate) {
                          return Colors.red.withOpacity(0.08);
                        }

                        if (_hasAnyVariance(row)) {
                          return Colors.orange.withOpacity(0.08);
                        }

                        return null;
                      },
                    ),
                    cells: [
                      DataCell(Text(row.wbsCode ?? '-')),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            row.taskTitle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${_formatDate(row.baselineStartDate)} → ${_formatDate(row.currentStartDate)}',
                        ),
                      ),
                      DataCell(
                        Text(
                          '${_formatDate(row.baselineEndDate)} → ${_formatDate(row.currentEndDate)}',
                        ),
                      ),
                      DataCell(_varianceText(row.endVarianceDays)),
                      DataCell(
                        Text(
                          '${row.baselineDuration}j → ${row.currentDuration}j',
                        ),
                      ),
                      DataCell(_varianceText(row.durationVarianceDays)),
                      DataCell(
                        Text(
                          '${row.baselineProgressPercent}% → ${row.currentProgressPercent}%',
                        ),
                      ),
                      DataCell(
                        Text(
                          '${row.baselineTotalFloat} → ${row.currentTotalFloat}',
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
    );
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