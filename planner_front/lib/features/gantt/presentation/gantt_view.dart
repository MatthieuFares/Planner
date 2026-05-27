import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/gantt_api.dart';
import '../data/gantt_task_model.dart';

enum GanttDisplayMode {
  auto,
  month,
  quarter,
  year,
}

class GanttView extends StatefulWidget {
  final int projectId;

  const GanttView({
    super.key,
    required this.projectId,
  });

  @override
  State<GanttView> createState() => _GanttViewState();
}

class _GanttViewState extends State<GanttView> {
  final GanttApi _ganttApi = GanttApi();

  late Future<List<GanttTask>> _ganttFuture;

  double _dayWidth = 24;
  GanttDisplayMode _displayMode = GanttDisplayMode.auto;

  @override
  void initState() {
    super.initState();
    _loadGantt();
  }

  void _loadGantt() {
    _ganttFuture = _ganttApi.getProjectGantt(widget.projectId);
  }

  void _zoomIn() {
    setState(() {
      _dayWidth = (_dayWidth + 4).clamp(12, 48);
    });
  }

  void _zoomOut() {
    setState(() {
      _dayWidth = (_dayWidth - 4).clamp(12, 48);
    });
  }

  void _changeDisplayMode(GanttDisplayMode? mode) {
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GanttTask>>(
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

        final tasks = snapshot.data ?? [];

        if (tasks.isEmpty) {
          return const Center(
            child: Text('Aucune tâche à afficher dans le Gantt.'),
          );
        }

        return _SimpleGantt(
          tasks: tasks,
          dayWidth: _dayWidth,
          displayMode: _displayMode,
          onDisplayModeChanged: _changeDisplayMode,
          onRefresh: _refreshGantt,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
        );
      },
    );
  }
}

class _SimpleGantt extends StatefulWidget {
  final List<GanttTask> tasks;
  final double dayWidth;
  final GanttDisplayMode displayMode;
  final ValueChanged<GanttDisplayMode?> onDisplayModeChanged;
  final VoidCallback onRefresh;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _SimpleGantt({
    required this.tasks,
    required this.dayWidth,
    required this.displayMode,
    required this.onDisplayModeChanged,
    required this.onRefresh,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  State<_SimpleGantt> createState() => _SimpleGanttState();
}

class _SimpleGanttState extends State<_SimpleGantt> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
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
      case GanttDisplayMode.auto:
        return (start: projectStart, end: projectEnd);

      case GanttDisplayMode.month:
        return (
          start: _startOfMonth(projectStart),
          end: _endOfMonth(projectEnd),
        );

      case GanttDisplayMode.quarter:
        return (
          start: _startOfQuarter(projectStart),
          end: _endOfQuarter(projectEnd),
        );

      case GanttDisplayMode.year:
        return (
          start: _startOfYear(projectStart),
          end: _endOfYear(projectEnd),
        );
    }
  }

  String _displayModeLabel(GanttDisplayMode mode) {
    switch (mode) {
      case GanttDisplayMode.auto:
        return 'Auto';
      case GanttDisplayMode.month:
        return 'Mois';
      case GanttDisplayMode.quarter:
        return 'Trimestre';
      case GanttDisplayMode.year:
        return 'Année';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedTasks = [...widget.tasks]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final projectStart = sortedTasks
        .map((task) => task.startDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    final projectEnd = sortedTasks
        .map((task) => task.endDate)
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
                'Gantt projet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(width: 16),
              Text(
                '${DateFormat('dd/MM/yyyy').format(visibleStart)} → ${DateFormat('dd/MM/yyyy').format(visibleEnd)}',
              ),
              const Spacer(),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<GanttDisplayMode>(
                  value: widget.displayMode,
                  decoration: const InputDecoration(
                    labelText: 'Affichage',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: GanttDisplayMode.values.map((mode) {
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
                width: 260,
                child: Column(
                  children: [
                    Container(
                      height: 64 ,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Text(
                        'Tâche',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: sortedTasks.length,
                        itemBuilder: (context, index) {
                          final task = sortedTasks[index];

                          return Container(
                            height: 64 ,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.4),
                                ),
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  if (task.isCritical)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Icon(
                                        Icons.priority_high,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                    ),

                                    Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: task.isCritical
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          task.assignmentSummary,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.grey.shade700,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Scrollbar(
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
                      width: chartWidth,
                      child: Column(
                        children: [
                          _GanttDateHeader(
                            visibleStart: visibleStart,
                            totalDays: totalDays,
                            dayWidth: widget.dayWidth,
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: sortedTasks.length,
                              itemBuilder: (context, index) {
                                final task = sortedTasks[index];

                                return _GanttBarRow(
                                  task: task,
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
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GanttDateHeader extends StatelessWidget {
  final DateTime visibleStart;
  final int totalDays;
  final double dayWidth;

  const _GanttDateHeader({
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM');

    return Container(
      height: 64 ,
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

class _GanttBarRow extends StatelessWidget {
  final GanttTask task;
  final DateTime visibleStart;
  final int totalDays;
  final double dayWidth;

  const _GanttBarRow({
    required this.task,
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
  });

  @override
  Widget build(BuildContext context) {
    final offsetDays = task.startDate.difference(visibleStart).inDays;
    final rawTaskDays = task.endDate.difference(task.startDate).inDays;
    final taskDays = rawTaskDays <= 0 ? 1 : rawTaskDays;

    final left = offsetDays * dayWidth;
    final width = taskDays * dayWidth;

    return Container(
      height: 64 ,
      decoration: BoxDecoration(
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
          Positioned(
            left: left,
            top: 14,
            child: Tooltip(
              message:
                  '${task.title}\n'
                  'Statut : ${task.isDone ? 'Terminée' : 'En cours'}\n'
                  'Progression : ${task.progressPercent}%\n'
                  'Durée : ${task.duration}j\n'
                  'Float : ${task.totalFloat ?? '-'}\n'
                  '${task.assignmentTooltip}',
              child: Container(
                width: width < 22 ? 22 : width,
                height: 26,
                decoration: BoxDecoration(
                  color: task.isDone
                      ? Colors.green
                      : task.isCritical
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  task.isDone ? 'OK' : '${task.progressPercent}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}