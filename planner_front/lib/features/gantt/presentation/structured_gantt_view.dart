import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/structured_gantt_api.dart';
import '../data/structured_gantt_model.dart';

enum StructuredGanttDisplayMode {
  auto,
  month,
  quarter,
  year,
}

class StructuredGanttView extends StatefulWidget {
  final int projectId;

  const StructuredGanttView({
    super.key,
    required this.projectId,
  });

  @override
  State<StructuredGanttView> createState() => _StructuredGanttViewState();
}

class _StructuredGanttViewState extends State<StructuredGanttView> {
  final StructuredGanttApi _ganttApi = StructuredGanttApi();

  late Future<StructuredGanttResponse> _ganttFuture;

  double _dayWidth = 24;
  StructuredGanttDisplayMode _displayMode = StructuredGanttDisplayMode.auto;

  @override
  void initState() {
    super.initState();
    _loadGantt();
  }

  void _loadGantt() {
    _ganttFuture = _ganttApi.getStructuredGantt(widget.projectId);
  }

  void _zoomIn() {
    setState(() {
      _dayWidth = (_dayWidth + 4).clamp(12, 48).toDouble();
    });
  }

  void _zoomOut() {
    setState(() {
      _dayWidth = (_dayWidth - 4).clamp(12, 48).toDouble();
    });
  }

  void _changeDisplayMode(StructuredGanttDisplayMode? mode) {
    if (mode == null) return;

    setState(() {
      _displayMode = mode;
    });
  }

  Future<void> _refreshGantt() async {
    setState(() {
      _loadGantt();
    });
  }

  Future<void> _syncTasks() async {
    try {
      await _ganttApi.syncProjectTasks(widget.projectId);

      setState(() {
        _loadGantt();
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tâches synchronisées avec le Gantt.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur synchronisation : $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StructuredGanttResponse>(
      future: _ganttFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur Gantt : ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text('Aucune donnée à afficher dans le Gantt.'),
          );
        }

        final data = snapshot.data!;

        if (data.items.isEmpty) {
          return const Center(
            child: Text('Aucun élément à afficher dans le Gantt.'),
          );
        }

        return _StructuredGanttChart(
          data: data,
          dayWidth: _dayWidth,
          displayMode: _displayMode,
          onDisplayModeChanged: _changeDisplayMode,
          onRefresh: _refreshGantt,
          onSyncTasks: _syncTasks,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
        );
      },
    );
  }
}

class _StructuredGanttChart extends StatefulWidget {
  final StructuredGanttResponse data;
  final double dayWidth;
  final StructuredGanttDisplayMode displayMode;
  final ValueChanged<StructuredGanttDisplayMode?> onDisplayModeChanged;
  final VoidCallback onRefresh;
  final Future<void> Function() onSyncTasks;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _StructuredGanttChart({
    required this.data,
    required this.dayWidth,
    required this.displayMode,
    required this.onDisplayModeChanged,
    required this.onRefresh,
    required this.onSyncTasks,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  State<_StructuredGanttChart> createState() => _StructuredGanttChartState();
}

class _StructuredGanttChartState extends State<_StructuredGanttChart> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _leftVerticalController = ScrollController();
  final ScrollController _rightVerticalController = ScrollController();

  bool _isSyncingLeft = false;
  bool _isSyncingRight = false;

  @override
  void initState() {
    super.initState();

    _leftVerticalController.addListener(() {
      if (_isSyncingRight) return;
      if (!_rightVerticalController.hasClients) return;

      _isSyncingLeft = true;
      _rightVerticalController.jumpTo(_leftVerticalController.offset);
      _isSyncingLeft = false;
    });

    _rightVerticalController.addListener(() {
      if (_isSyncingLeft) return;
      if (!_leftVerticalController.hasClients) return;

      _isSyncingRight = true;
      _leftVerticalController.jumpTo(_rightVerticalController.offset);
      _isSyncingRight = false;
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _leftVerticalController.dispose();
    _rightVerticalController.dispose();
    super.dispose();
  }

  DateTime _startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  DateTime _startOfQuarter(DateTime date) {
    final quarterStartMonth = ((date.month - 1) ~/ 3) * 3 + 1;
    return DateTime(date.year, quarterStartMonth, 1);
  }

  DateTime _endOfQuarter(DateTime date) {
    final quarterStartMonth = ((date.month - 1) ~/ 3) * 3 + 1;
    final nextQuarterStart = DateTime(date.year, quarterStartMonth + 3, 1);
    return nextQuarterStart.subtract(const Duration(days: 1));
  }

  DateTime _startOfYear(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  DateTime _endOfYear(DateTime date) {
    return DateTime(date.year, 12, 31);
  }

  ({DateTime start, DateTime end}) _getVisibleRange({
    required DateTime projectStart,
    required DateTime projectEnd,
  }) {
    switch (widget.displayMode) {
      case StructuredGanttDisplayMode.auto:
        final rawDays = projectEnd.difference(projectStart).inDays;

        if (rawDays < 14) {
          return (
            start: projectStart.subtract(const Duration(days: 3)),
            end: projectStart.add(const Duration(days: 18)),
          );
        }

        return (
          start: projectStart.subtract(const Duration(days: 2)),
          end: projectEnd.add(const Duration(days: 5)),
        );

      case StructuredGanttDisplayMode.month:
        return (
          start: _startOfMonth(projectStart),
          end: _endOfMonth(projectEnd),
        );

      case StructuredGanttDisplayMode.quarter:
        return (
          start: _startOfQuarter(projectStart),
          end: _endOfQuarter(projectEnd),
        );

      case StructuredGanttDisplayMode.year:
        return (
          start: _startOfYear(projectStart),
          end: _endOfYear(projectEnd),
        );
    }
  }

  String _displayModeLabel(StructuredGanttDisplayMode mode) {
    switch (mode) {
      case StructuredGanttDisplayMode.auto:
        return 'Auto';
      case StructuredGanttDisplayMode.month:
        return 'Mois';
      case StructuredGanttDisplayMode.quarter:
        return 'Trimestre';
      case StructuredGanttDisplayMode.year:
        return 'Année';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.data.items;
    final taskItems = items.where((item) => item.task != null).toList();

    if (taskItems.isEmpty) {
      return const Center(
        child: Text('La structure existe, mais aucune tâche n’est liée.'),
      );
    }

    final projectStart = taskItems
        .map((item) => item.task!.startDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    final projectEnd = taskItems
        .map((item) => item.task!.endDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    final visibleRange = _getVisibleRange(
      projectStart: projectStart,
      projectEnd: projectEnd,
    );

    final visibleStart = visibleRange.start;
    final visibleEnd = visibleRange.end;

    final totalDaysRaw = visibleEnd.difference(visibleStart).inDays;
    final totalDays = totalDaysRaw <= 0 ? 1 : totalDaysRaw;

    final chartWidth = (totalDays + 2) * widget.dayWidth;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Gantt',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${widget.data.projectName} — '
                  '${DateFormat('dd/MM/yyyy').format(visibleStart)} → '
                  '${DateFormat('dd/MM/yyyy').format(visibleEnd)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<StructuredGanttDisplayMode>(
                  value: widget.displayMode,
                  decoration: const InputDecoration(
                    labelText: 'Affichage',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: StructuredGanttDisplayMode.values.map((mode) {
                    return DropdownMenuItem(
                      value: mode,
                      child: Text(_displayModeLabel(mode)),
                    );
                  }).toList(),
                  onChanged: widget.onDisplayModeChanged,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.onZoomOut,
                icon: const Icon(Icons.zoom_out),
                label: const Text('Zoom -'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.onZoomIn,
                icon: const Icon(Icons.zoom_in),
                label: const Text('Zoom +'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  widget.onSyncTasks();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Synchroniser'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Rafraîchir'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 390,
                child: Column(
                  children: [
                    Container(
                      height: 64,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(
                              'WBS',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Élément',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _leftVerticalController,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _StructuredGanttLeftRow(item: item);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final effectiveChartWidth = chartWidth < constraints.maxWidth
                        ? constraints.maxWidth
                        : chartWidth;

                    return Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      notificationPredicate: (notification) {
                        return notification.metrics.axis == Axis.horizontal;
                      },
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: effectiveChartWidth,
                          child: Column(
                            children: [
                              _StructuredGanttDateHeader(
                                visibleStart: visibleStart,
                                totalDays: totalDays,
                                dayWidth: widget.dayWidth,
                              ),
                              Expanded(
                                child: ListView.builder(
                                  controller: _rightVerticalController,
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];

                                    return _StructuredGanttBarRow(
                                      item: item,
                                      visibleStart: visibleStart,
                                      totalDays: totalDays,
                                      dayWidth: widget.dayWidth,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StructuredGanttLeftRow extends StatelessWidget {
  final StructuredGanttItem item;

  const _StructuredGanttLeftRow({
    required this.item,
  });

  IconData _getIcon() {
    switch (item.type) {
      case 'Section':
        return Icons.folder;
      case 'Zone':
        return Icons.folder_open;
      case 'Task':
        return Icons.task_alt;
      default:
        return Icons.circle;
    }
  }

  Color _getIconColor(BuildContext context) {
    if (item.type == 'Section') {
      return Colors.blueGrey;
    }

    if (item.type == 'Zone') {
      return Colors.indigo;
    }

    final task = item.task;

    if (task == null) {
      return Theme.of(context).colorScheme.primary;
    }

    if (task.isDone) {
      return Colors.green;
    }

    if (task.isLate) {
      return Colors.red;
    }

    if (task.isCritical) {
      return Colors.orange;
    }

    return Theme.of(context).colorScheme.primary;
  }

  FontWeight _getFontWeight() {
    if (item.type == 'Section') return FontWeight.bold;
    if (item.type == 'Zone') return FontWeight.w600;
    return FontWeight.normal;
  }

  String _formatTaskSubtitle(StructuredGanttTask task) {
    final dates =
        '${DateFormat('dd/MM').format(task.startDate)} → ${DateFormat('dd/MM').format(task.endDate)}';

    if (task.isLate) {
      return '$dates · Retard +${task.delayDays}j · Float ${task.totalFloat}';
    }

    if (task.isCritical) {
      return '$dates · Critique · Float ${task.totalFloat}';
    }

    return '$dates · ${task.progressPercent}% · Float ${task.totalFloat}';
  }

  @override
  Widget build(BuildContext context) {
    final task = item.task;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: item.type == 'Section'
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.45)
            : item.type == 'Zone'
                ? Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.25)
                : null,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              item.wbsCode,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: _getFontWeight(),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: item.level * 18.0),
              child: Row(
                children: [
                  Icon(
                    _getIcon(),
                    size: 18,
                    color: _getIconColor(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: task == null
                          ? item.name
                          : '${item.name}\n'
                              'Tâche liée : ${task.title}\n'
                              'Statut : ${task.isDone ? 'Terminée' : task.isLate ? 'En retard' : task.isCritical ? 'Critique' : 'En cours'}\n'
                              'Progression : ${task.progressPercent}%\n'
                              'Float : ${task.totalFloat}\n'
                              'Deadline : ${task.deadline == null ? '-' : DateFormat('dd/MM/yyyy').format(task.deadline!)}\n'
                              'Retard : ${task.isLate ? '+${task.delayDays}j' : '-'}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: _getFontWeight(),
                            ),
                          ),
                          if (task != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _formatTaskSubtitle(task),
                              overflow: TextOverflow.ellipsis,
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: task.isLate
                                            ? Colors.red
                                            : task.isCritical
                                                ? Colors.orange.shade800
                                                : Colors.grey.shade700,
                                        fontSize: 11,
                                        fontWeight: task.isLate
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StructuredGanttDateHeader extends StatelessWidget {
  final DateTime visibleStart;
  final int totalDays;
  final double dayWidth;

  const _StructuredGanttDateHeader({
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM');

    return Container(
      height: 64,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: List.generate(totalDays + 2, (index) {
          final date = visibleStart.add(Duration(days: index));

          final showLabel = index == 0 ||
              index == totalDays ||
              date.day == 1 ||
              index % 5 == 0;

          return Container(
            width: dayWidth,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.35),
                ),
              ),
            ),
            child: showLabel
                ? RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      formatter.format(date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : const SizedBox.shrink(),
          );
        }),
      ),
    );
  }
}

class _StructuredGanttBarRow extends StatelessWidget {
  final StructuredGanttItem item;
  final DateTime visibleStart;
  final int totalDays;
  final double dayWidth;

  const _StructuredGanttBarRow({
    required this.item,
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
  });

  @override
  Widget build(BuildContext context) {
    final task = item.task;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: item.type == 'Section'
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.45)
            : item.type == 'Zone'
                ? Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.25)
                : null,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.4),
          ),
        ),
      ),
      child: Stack(
        children: [
          Row(
            children: List.generate(totalDays + 2, (index) {
              final isMajor = index % 5 == 0;

              return Container(
                width: dayWidth,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: isMajor
                          ? Theme.of(context).dividerColor.withOpacity(0.7)
                          : Theme.of(context).dividerColor.withOpacity(0.25),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (task != null)
            _TaskBar(
              item: item,
              task: task,
              visibleStart: visibleStart,
              dayWidth: dayWidth,
            ),
        ],
      ),
    );
  }
}

class _TaskBar extends StatelessWidget {
  final StructuredGanttItem item;
  final StructuredGanttTask task;
  final DateTime visibleStart;
  final double dayWidth;

  const _TaskBar({
    required this.item,
    required this.task,
    required this.visibleStart,
    required this.dayWidth,
  });

  Color _barColor(BuildContext context) {
    if (task.isDone) {
      return Colors.green;
    }

    if (task.isLate) {
      return Colors.red;
    }

    if (task.isCritical) {
      return Colors.orange;
    }

    return Theme.of(context).colorScheme.primary;
  }

  String _barLabel() {
    if (task.isDone) {
      return 'OK';
    }

    if (task.isLate) {
      return '+${task.delayDays}j';
    }

    return '${task.progressPercent}%';
  }

  String _statusLabel() {
    if (task.isDone) {
      return 'Terminée';
    }

    if (task.isLate) {
      return 'En retard';
    }

    if (task.isCritical) {
      return 'Critique';
    }

    return 'En cours';
  }

  @override
  Widget build(BuildContext context) {
    final offsetDays = task.startDate.difference(visibleStart).inDays;
    final rawTaskDays = task.endDate.difference(task.startDate).inDays;
    final taskDays = rawTaskDays <= 0 ? 1 : rawTaskDays;

    final left = offsetDays * dayWidth;
    final width = taskDays * dayWidth;

    return Positioned(
      left: left,
      top: 14,
      child: Tooltip(
        message: '${item.name}\n'
            'Tâche liée : ${task.title}\n'
            'Statut : ${_statusLabel()}\n'
            'Progression : ${task.progressPercent}%\n'
            'Durée : ${task.duration}j\n'
            'Float : ${task.totalFloat}\n'
            'Deadline : ${task.deadline == null ? '-' : DateFormat('dd/MM/yyyy').format(task.deadline!)}\n'
            'Retard : ${task.isLate ? '+${task.delayDays}j' : '-'}',
        child: Container(
          width: width < 26 ? 26 : width,
          height: 26,
          decoration: BoxDecoration(
            color: _barColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            _barLabel(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}