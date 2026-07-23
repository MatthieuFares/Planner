import 'package:flutter/material.dart';

import '../data/planning_version_api.dart';
import '../data/planning_version_model.dart';
import 'planning_version_form_dialog.dart';

class PlanningVersionsView extends StatefulWidget {
  final int projectId;

  const PlanningVersionsView({
    super.key,
    required this.projectId,
  });

  @override
  State<PlanningVersionsView> createState() =>
      _PlanningVersionsViewState();
}

class _PlanningVersionsViewState
    extends State<PlanningVersionsView> {
  final PlanningVersionApi _api = PlanningVersionApi();

  List<PlanningVersionSummaryModel> _versions = const [];
  bool _isLoading = true;
  bool _isCreating = false;
  int? _busyVersionId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  @override
  void didUpdateWidget(covariant PlanningVersionsView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId) {
      _loadVersions();
    }
  }

  Future<void> _loadVersions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final versions = await _api.getByProjectId(widget.projectId);

      if (!mounted) {
        return;
      }

      setState(() {
        _versions = versions;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  Future<void> _createVersion() async {
    if (_isCreating) {
      return;
    }

    final result = await showDialog<PlanningVersionFormResult>(
      context: context,
      builder: (context) => const PlanningVersionFormDialog(),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final created = await _api.create(
        projectId: widget.projectId,
        name: result.name,
        description: result.description,
        createdBy: result.createdBy,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Version V${created.versionNumber} créée avec succès.',
      );

      await _loadVersions();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _showDetail(
    PlanningVersionSummaryModel version,
  ) async {
    if (_busyVersionId != null) {
      return;
    }

    setState(() {
      _busyVersionId = version.id;
    });

    try {
      final detail = await _api.getById(version.id);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => _PlanningVersionDetailDialog(
          detail: detail,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busyVersionId = null;
        });
      }
    }
  }

  Future<void> _compareWithCurrent(
    PlanningVersionSummaryModel version,
  ) async {
    if (_busyVersionId != null) {
      return;
    }

    setState(() {
      _busyVersionId = version.id;
    });

    try {
      final comparison =
          await _api.compareWithCurrent(version.id);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) =>
            _PlanningVersionComparisonDialog(
          comparison: comparison,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busyVersionId = null;
        });
      }
    }
  }

  Future<void> _restoreVersion(
    PlanningVersionSummaryModel version,
  ) async {
    if (_busyVersionId != null) {
      return;
    }

    final request = await showDialog<_RestoreDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RestorePlanningVersionDialog(
        version: version,
      ),
    );

    if (request == null || !mounted) {
      return;
    }

    setState(() {
      _busyVersionId = version.id;
    });

    try {
      final result = await _api.restore(
        versionId: version.id,
        confirmRestore: true,
        createSafetyVersion: request.createSafetyVersion,
        safetyVersionName: request.safetyVersionName,
        restoredBy: request.restoredBy,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => _RestoreResultDialog(
          result: result,
        ),
      );

      if (!mounted) {
        return;
      }

      await _loadVersions();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busyVersionId = null;
        });
      }
    }
  }

  Future<void> _deleteVersion(
    PlanningVersionSummaryModel version,
  ) async {
    if (_busyVersionId != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la version ?'),
        content: Text(
          'La version V${version.versionNumber} '
          '« ${version.name} » sera supprimée définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busyVersionId = version.id;
    });

    try {
      await _api.delete(version.id);

      if (!mounted) {
        return;
      }

      _showMessage(
        'Version V${version.versionNumber} supprimée.',
      );

      await _loadVersions();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busyVersionId = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _cleanError(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1),
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.history),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Versions du planning',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  'Historique, comparaison et restauration '
                  'du planning complet.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _isLoading ? null : _loadVersions,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed:
                _isCreating || _isLoading ? null : _createVersion,
            icon: _isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add),
            label: const Text('Nouvelle version'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _ErrorState(
        message: _errorMessage!,
        onRetry: _loadVersions,
      );
    }

    if (_versions.isEmpty) {
      return _EmptyState(
        onCreate: _createVersion,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVersions,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _versions.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final version = _versions[index];

          return _PlanningVersionCard(
            version: version,
            isBusy: _busyVersionId == version.id,
            onDetail: () => _showDetail(version),
            onCompare: () => _compareWithCurrent(version),
            onRestore: () => _restoreVersion(version),
            onDelete: () => _deleteVersion(version),
          );
        },
      ),
    );
  }
}

class _PlanningVersionCard extends StatelessWidget {
  final PlanningVersionSummaryModel version;
  final bool isBusy;
  final VoidCallback onDetail;
  final VoidCallback onCompare;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _PlanningVersionCard({
    required this.version,
    required this.isBusy,
    required this.onDetail,
    required this.onCompare,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isBusy ? null : onDetail,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    colorScheme.primaryContainer,
                foregroundColor:
                    colorScheme.onPrimaryContainer,
                child: Text(
                  'V${version.versionNumber}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            version.name,
                            style:
                                theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isBusy)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        PopupMenuButton<_VersionAction>(
                          enabled: !isBusy,
                          tooltip: 'Actions',
                          onSelected: (action) {
                            switch (action) {
                              case _VersionAction.detail:
                                onDetail();
                              case _VersionAction.compare:
                                onCompare();
                              case _VersionAction.restore:
                                onRestore();
                              case _VersionAction.delete:
                                onDelete();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _VersionAction.detail,
                              child: ListTile(
                                dense: true,
                                leading:
                                    Icon(Icons.visibility_outlined),
                                title: Text('Voir le détail'),
                              ),
                            ),
                            PopupMenuItem(
                              value: _VersionAction.compare,
                              child: ListTile(
                                dense: true,
                                leading:
                                    Icon(Icons.compare_arrows),
                                title: Text(
                                  'Comparer au planning courant',
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: _VersionAction.restore,
                              child: ListTile(
                                dense: true,
                                leading:
                                    Icon(Icons.settings_backup_restore),
                                title: Text('Restaurer'),
                              ),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem(
                              value: _VersionAction.delete,
                              child: ListTile(
                                dense: true,
                                leading:
                                    Icon(Icons.delete_outline),
                                title: Text('Supprimer'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(version.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (version.createdBy != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Créée par ${version.createdBy}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (version.description != null) ...[
                      const SizedBox(height: 10),
                      Text(version.description!),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CountChip(
                          icon: Icons.task_alt_outlined,
                          label: '${version.taskCount} tâches',
                        ),
                        _CountChip(
                          icon: Icons.account_tree_outlined,
                          label: '${version.itemCount} éléments',
                        ),
                        _CountChip(
                          icon: Icons.link,
                          label:
                              '${version.dependencyCount} dépendances',
                        ),
                        _CountChip(
                          icon: Icons.groups_outlined,
                          label:
                              '${version.assignmentCount} assignations',
                        ),
                        _CountChip(
                          icon: Icons.calendar_month_outlined,
                          label: version.hasCalendar
                              ? 'Calendrier inclus'
                              : 'Sans calendrier',
                        ),
                      ],
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
}

enum _VersionAction {
  detail,
  compare,
  restore,
  delete,
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CountChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        icon,
        size: 17,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PlanningVersionDetailDialog extends StatelessWidget {
  final PlanningVersionDetailModel detail;

  const _PlanningVersionDetailDialog({
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        'V${detail.versionNumber} — ${detail.name}',
      ),
      content: SizedBox(
        width: 760,
        height: 600,
        child: DefaultTabController(
          length: 5,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatDateTime(detail.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (detail.description != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(detail.description!),
                ),
              ],
              const SizedBox(height: 12),
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Tâches'),
                  Tab(text: 'Structure'),
                  Tab(text: 'Dépendances'),
                  Tab(text: 'Assignations'),
                  Tab(text: 'Calendrier'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _VersionTasksTab(tasks: detail.tasks),
                    _VersionItemsTab(items: detail.items),
                    _VersionDependenciesTab(
                      dependencies: detail.dependencies,
                    ),
                    _VersionAssignmentsTab(
                      assignments: detail.assignments,
                    ),
                    _VersionCalendarTab(
                      calendar: detail.calendar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _VersionTasksTab extends StatelessWidget {
  final List<PlanningVersionTaskModel> tasks;

  const _VersionTasksTab({
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text('Aucune tâche enregistrée.'),
      );
    }

    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final task = tasks[index];

        return ListTile(
          title: Text(task.title),
          subtitle: Text(
            '${_formatDate(task.startDate)} → '
            '${_formatDate(task.endDate)}'
            ' • ${task.duration ?? 0} j'
            ' • ${task.progressPercent} %',
          ),
          trailing: Wrap(
            spacing: 6,
            children: [
              if (task.isCritical)
                const Tooltip(
                  message: 'Tâche critique',
                  child: Icon(Icons.warning_amber),
                ),
              if (task.isLate)
                const Tooltip(
                  message: 'Tâche en retard',
                  child: Icon(Icons.schedule),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _VersionItemsTab extends StatelessWidget {
  final List<PlanningVersionItemModel> items;

  const _VersionItemsTab({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Aucun élément de structure.'),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];

        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            child: Text(item.wbsCode),
          ),
          title: Text(item.name),
          subtitle: Text(
            '${item.typeLabel} • ordre ${item.sortOrder}',
          ),
        );
      },
    );
  }
}

class _VersionDependenciesTab extends StatelessWidget {
  final List<PlanningVersionDependencyModel> dependencies;

  const _VersionDependenciesTab({
    required this.dependencies,
  });

  @override
  Widget build(BuildContext context) {
    if (dependencies.isEmpty) {
      return const Center(
        child: Text('Aucune dépendance enregistrée.'),
      );
    }

    return ListView.separated(
      itemCount: dependencies.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final dependency = dependencies[index];
        final offsetText = dependency.offsetDays == 0
            ? ''
            : ' • décalage ${dependency.offsetDays} j';

        return ListTile(
          leading: const Icon(Icons.link),
          title: Text(
            'Tâche ${dependency.originalPredecessorTaskId} '
            '→ tâche ${dependency.originalSuccessorTaskId}',
          ),
          subtitle: Text(
            '${dependency.type}$offsetText',
          ),
        );
      },
    );
  }
}

class _VersionAssignmentsTab extends StatelessWidget {
  final List<PlanningVersionAssignmentModel> assignments;

  const _VersionAssignmentsTab({
    required this.assignments,
  });

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return const Center(
        child: Text('Aucune assignation enregistrée.'),
      );
    }

    return ListView.separated(
      itemCount: assignments.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final assignment = assignments[index];

        return ListTile(
          leading: Icon(
            assignment.originalResourceGroupId != null
                ? Icons.groups_outlined
                : Icons.person_outline,
          ),
          title: Text(assignment.targetName),
          subtitle: Text(
            'Tâche ${assignment.originalTaskId} • '
            '${_formatNumber(assignment.workloadHours)} h • '
            '${assignment.allocationPercent} %',
          ),
        );
      },
    );
  }
}

class _VersionCalendarTab extends StatelessWidget {
  final PlanningVersionCalendarModel? calendar;

  const _VersionCalendarTab({
    required this.calendar,
  });

  @override
  Widget build(BuildContext context) {
    final value = calendar;

    if (value == null) {
      return const Center(
        child: Text('Aucun calendrier enregistré.'),
      );
    }

    final workedDays = <String>[
      if (value.workMonday) 'Lun',
      if (value.workTuesday) 'Mar',
      if (value.workWednesday) 'Mer',
      if (value.workThursday) 'Jeu',
      if (value.workFriday) 'Ven',
      if (value.workSaturday) 'Sam',
      if (value.workSunday) 'Dim',
    ];

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Text(
          'Jours travaillés : ${workedDays.join(', ')}',
        ),
        const SizedBox(height: 16),
        Text(
          'Exceptions (${value.exceptions.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        if (value.exceptions.isEmpty)
          const Text('Aucune exception.')
        else
          ...value.exceptions.map(
            (exception) => ListTile(
              dense: true,
              leading: Icon(
                exception.isWorkingDay
                    ? Icons.event_available
                    : Icons.event_busy,
              ),
              title: Text(exception.label),
              subtitle: Text(_formatDate(exception.date)),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Périodes non ouvrées (${value.periods.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        if (value.periods.isEmpty)
          const Text('Aucune période.')
        else
          ...value.periods.map(
            (period) => ListTile(
              dense: true,
              leading: const Icon(Icons.date_range),
              title: Text(period.label),
              subtitle: Text(
                '${_formatDate(period.startDate)} → '
                '${_formatDate(period.endDate)}',
              ),
            ),
          ),
      ],
    );
  }
}

class _PlanningVersionComparisonDialog extends StatelessWidget {
  final PlanningVersionComparisonModel comparison;

  const _PlanningVersionComparisonDialog({
    required this.comparison,
  });

  @override
  Widget build(BuildContext context) {
    final changedTasks = comparison.tasks
        .where((task) => !task.isUnchanged)
        .toList();

    return AlertDialog(
      title: Text(
        'Comparaison V${comparison.versionNumber}',
      ),
      content: SizedBox(
        width: 760,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ComparisonSummary(
              comparison: comparison,
            ),
            const SizedBox(height: 16),
            Text(
              changedTasks.isEmpty
                  ? 'Aucun changement détecté'
                  : 'Tâches modifiées (${changedTasks.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: changedTasks.isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 64,
                      ),
                    )
                  : ListView.separated(
                      itemCount: changedTasks.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final task = changedTasks[index];

                        return ExpansionTile(
                          leading: Icon(
                            _statusIcon(task.status),
                          ),
                          title: Text(task.title),
                          subtitle: Text(
                            _statusLabel(task.status),
                          ),
                          children: [
                            if (task.changedFields.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Champs modifiés : '
                                    '${task.changedFields.join(', ')}',
                                  ),
                                ),
                              ),
                            _TaskStateComparison(
                              versionState: task.versionState,
                              currentState: task.currentState,
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _ComparisonSummary extends StatelessWidget {
  final PlanningVersionComparisonModel comparison;

  const _ComparisonSummary({
    required this.comparison,
  });

  @override
  Widget build(BuildContext context) {
    final summary = comparison.summary;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CountChip(
          icon: Icons.add_circle_outline,
          label: '${summary.addedTaskCount} ajoutées',
        ),
        _CountChip(
          icon: Icons.remove_circle_outline,
          label: '${summary.removedTaskCount} supprimées',
        ),
        _CountChip(
          icon: Icons.edit_outlined,
          label: '${summary.modifiedTaskCount} modifiées',
        ),
        _CountChip(
          icon: Icons.check_circle_outline,
          label: '${summary.unchangedTaskCount} inchangées',
        ),
        _ChangeFlagChip(
          changed: comparison.structureChanged,
          label: 'Structure',
        ),
        _ChangeFlagChip(
          changed: comparison.dependenciesChanged,
          label: 'Dépendances',
        ),
        _ChangeFlagChip(
          changed: comparison.assignmentsChanged,
          label: 'Assignations',
        ),
        _ChangeFlagChip(
          changed: comparison.calendarChanged,
          label: 'Calendrier',
        ),
      ],
    );
  }
}

class _ChangeFlagChip extends StatelessWidget {
  final bool changed;
  final String label;

  const _ChangeFlagChip({
    required this.changed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        changed ? Icons.change_circle : Icons.check_circle,
        size: 17,
      ),
      label: Text(
        changed ? '$label modifié' : '$label identique',
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TaskStateComparison extends StatelessWidget {
  final PlanningVersionTaskStateModel? versionState;
  final PlanningVersionTaskStateModel? currentState;

  const _TaskStateComparison({
    required this.versionState,
    required this.currentState,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _TaskStateCard(
              title: 'Version',
              state: versionState,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TaskStateCard(
              title: 'Actuel',
              state: currentState,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskStateCard extends StatelessWidget {
  final String title;
  final PlanningVersionTaskStateModel? state;

  const _TaskStateCard({
    required this.title,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final value = state;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: value == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Tâche absente'),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(value.title),
                  Text(
                    '${_formatDate(value.startDate)} → '
                    '${_formatDate(value.endDate)}',
                  ),
                  Text('Durée : ${value.duration ?? 0} j'),
                  Text(
                    'Progression : ${value.progressPercent} %',
                  ),
                  Text(
                    'Charge : '
                    '${value.workloadHours == null ? '—' : '${_formatNumber(value.workloadHours!)} h'}',
                  ),
                  Text(
                    'Deadline : ${_formatDate(value.deadline)}',
                  ),
                ],
              ),
      ),
    );
  }
}

class _RestoreDialogResult {
  final bool createSafetyVersion;
  final String? safetyVersionName;
  final String? restoredBy;

  const _RestoreDialogResult({
    required this.createSafetyVersion,
    required this.safetyVersionName,
    required this.restoredBy,
  });
}

class _RestorePlanningVersionDialog extends StatefulWidget {
  final PlanningVersionSummaryModel version;

  const _RestorePlanningVersionDialog({
    required this.version,
  });

  @override
  State<_RestorePlanningVersionDialog> createState() =>
      _RestorePlanningVersionDialogState();
}

class _RestorePlanningVersionDialogState
    extends State<_RestorePlanningVersionDialog> {
  final _safetyNameController = TextEditingController();
  final _restoredByController = TextEditingController();

  bool _createSafetyVersion = true;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _safetyNameController.text =
        'Sauvegarde avant restauration V${widget.version.versionNumber}';
  }

  @override
  void dispose() {
    _safetyNameController.dispose();
    _restoredByController.dispose();
    super.dispose();
  }

  String? _normalize(String value) {
    final text = value.trim();

    return text.isEmpty ? null : text;
  }

  void _submit() {
    if (!_confirmed) {
      return;
    }

    Navigator.of(context).pop(
      _RestoreDialogResult(
        createSafetyVersion: _createSafetyVersion,
        safetyVersionName: _createSafetyVersion
            ? _normalize(_safetyNameController.text)
            : null,
        restoredBy: _normalize(_restoredByController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber),
          SizedBox(width: 10),
          Expanded(
            child: Text('Restaurer cette version ?'),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Le planning courant sera remplacé par '
                'V${widget.version.versionNumber} '
                '« ${widget.version.name} ».',
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _createSafetyVersion,
                onChanged: (value) {
                  setState(() {
                    _createSafetyVersion = value;
                  });
                },
                title: const Text(
                  'Créer une version de sécurité',
                ),
                subtitle: const Text(
                  'Recommandé avant toute restauration.',
                ),
              ),
              if (_createSafetyVersion) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _safetyNameController,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText:
                        'Nom de la version de sécurité',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _restoredByController,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Restaurée par',
                  hintText: 'Ex. Matthieu',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                onChanged: (value) {
                  setState(() {
                    _confirmed = value ?? false;
                  });
                },
                title: const Text(
                  'Je confirme la restauration complète '
                  'du planning.',
                ),
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
        FilledButton.icon(
          onPressed: _confirmed ? _submit : null,
          icon: const Icon(Icons.settings_backup_restore),
          label: const Text('Restaurer'),
        ),
      ],
    );
  }
}

class _RestoreResultDialog extends StatelessWidget {
  final RestorePlanningVersionResponseModel result;

  const _RestoreResultDialog({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle_outline),
          SizedBox(width: 10),
          Expanded(
            child: Text('Restauration terminée'),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'V${result.versionNumber} '
                '« ${result.versionName} » a été restaurée.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CountChip(
                    icon: Icons.edit_outlined,
                    label:
                        '${result.updatedTaskCount} tâches mises à jour',
                  ),
                  _CountChip(
                    icon: Icons.add_task,
                    label:
                        '${result.createdTaskCount} tâches créées',
                  ),
                  _CountChip(
                    icon: Icons.delete_sweep_outlined,
                    label:
                        '${result.deletedTaskCount} tâches supprimées',
                  ),
                  _CountChip(
                    icon: Icons.account_tree_outlined,
                    label:
                        '${result.restoredItemCount} éléments',
                  ),
                  _CountChip(
                    icon: Icons.link,
                    label:
                        '${result.restoredDependencyCount} dépendances',
                  ),
                  _CountChip(
                    icon: Icons.groups_outlined,
                    label:
                        '${result.restoredAssignmentCount} assignations',
                  ),
                ],
              ),
              if (result.safetyVersionId != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Version de sécurité créée : '
                  '#${result.safetyVersionId}',
                ),
              ],
              if (result.warnings.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Avertissements',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                ...result.warnings.map(
                  (warning) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.warning_amber),
                    title: Text(warning),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history_toggle_off,
                size: 72,
              ),
              const SizedBox(height: 16),
              Text(
                'Aucune version enregistrée',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Crée une première version pour figer '
                'l’état actuel du planning.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Créer une version'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
              ),
              const SizedBox(height: 14),
              Text(
                'Impossible de charger les versions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'Added':
      return Icons.add_circle_outline;
    case 'Removed':
      return Icons.remove_circle_outline;
    case 'Modified':
      return Icons.edit_outlined;
    default:
      return Icons.check_circle_outline;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'Added':
      return 'Ajoutée après la version';
    case 'Removed':
      return 'Supprimée depuis la version';
    case 'Modified':
      return 'Modifiée depuis la version';
    default:
      return 'Inchangée';
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/'
      '${local.year} à ${_twoDigits(local.hour)}:'
      '${_twoDigits(local.minute)}';
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return '—';
  }

  final local = value.toLocal();

  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/'
      '${local.year}';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(2);
}
