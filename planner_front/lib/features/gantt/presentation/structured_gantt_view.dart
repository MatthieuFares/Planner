import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/structured_gantt_api.dart';
import '../data/structured_gantt_model.dart';

import '../../project_calendar/data/project_calendar_api.dart';
import '../../project_calendar/data/project_calendar_exception_api.dart';
import '../../project_calendar/data/project_calendar_exception_model.dart';
import '../../project_calendar/data/project_calendar_model.dart';

enum StructuredGanttDisplayMode {
  auto,
  month,
  quarter,
  year,
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

int _calendarDaysBetween(DateTime start, DateTime end) {
  return _dateOnly(end).difference(_dateOnly(start)).inDays;
}

const double _ganttHeaderHeight = 92;

bool _isSameDay(DateTime a, DateTime b) {
  final cleanA = _dateOnly(a);
  final cleanB = _dateOnly(b);

  return cleanA.year == cleanB.year &&
      cleanA.month == cleanB.month &&
      cleanA.day == cleanB.day;
}

ProjectCalendarExceptionModel? _findExceptionForDate({
  required DateTime date,
  required List<ProjectCalendarExceptionModel> exceptions,
}) {
  final cleanDate = _dateOnly(date);

  for (final exception in exceptions) {
    if (_isSameDay(exception.date, cleanDate)) {
      return exception;
    }
  }

  return null;
}

bool _isWorkingDayForProject({
  required DateTime date,
  required ProjectCalendarModel calendar,
  required List<ProjectCalendarExceptionModel> exceptions,
}) {
  final exception = _findExceptionForDate(
    date: date,
    exceptions: exceptions,
  );

  if (exception != null) {
    return exception.isWorkingDay;
  }

  switch (_dateOnly(date).weekday) {
    case DateTime.monday:
      return calendar.workMonday;
    case DateTime.tuesday:
      return calendar.workTuesday;
    case DateTime.wednesday:
      return calendar.workWednesday;
    case DateTime.thursday:
      return calendar.workThursday;
    case DateTime.friday:
      return calendar.workFriday;
    case DateTime.saturday:
      return calendar.workSaturday;
    case DateTime.sunday:
      return calendar.workSunday;
    default:
      return false;
  }
}

class _StructuredGanttLoadedData {
  final StructuredGanttResponse gantt;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;

  const _StructuredGanttLoadedData({
    required this.gantt,
    required this.calendar,
    required this.exceptions,
  });
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
  final ProjectCalendarApi _calendarApi = ProjectCalendarApi();
  final ProjectCalendarExceptionApi _exceptionApi = ProjectCalendarExceptionApi();

  late Future<_StructuredGanttLoadedData> _ganttFuture;

  double _dayWidth = 24;
  StructuredGanttDisplayMode _displayMode = StructuredGanttDisplayMode.auto;

  @override
  void initState() {
    super.initState();
    _loadGantt();
  }

  void _loadGantt() {
    _ganttFuture = _loadGanttData();
  }

  Future<_StructuredGanttLoadedData> _loadGanttData() async {
    final gantt = await _ganttApi.getStructuredGantt(widget.projectId);
    final calendar = await _calendarApi.getByProjectId(widget.projectId);
    final exceptions = await _exceptionApi.getByProjectId(widget.projectId);

    return _StructuredGanttLoadedData(
      gantt: gantt,
      calendar: calendar,
      exceptions: exceptions,
    );
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

  int _getNextSortOrder({
    required List<StructuredGanttItem> items,
    required int? parentId,
  }) {
    final siblings = items.where((item) => item.parentId == parentId).toList();

    if (siblings.isEmpty) {
      return 1;
    }

    return siblings.fold<int>(
          0,
          (maxSortOrder, item) =>
              item.sortOrder > maxSortOrder ? item.sortOrder : maxSortOrder,
        ) +
        1;
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

  Future<void> _createPlanningItem(List<StructuredGanttItem> items) async {
    final nameController = TextEditingController();
    final possibleParents = items
        .where((item) => item.type == 'Section' || item.type == 'Zone')
        .toList();

    String selectedType = 'Section';
    StructuredGanttItem? selectedParent;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isZone = selectedType == 'Zone';

            return AlertDialog(
              title: const Text('Ajouter au Gantt'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Section',
                          child: Text('Section'),
                        ),
                        DropdownMenuItem(
                          value: 'Zone',
                          child: Text('Zone'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedType = value;
                          if (selectedType == 'Section') {
                            selectedParent = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        hintText: 'Ex : Gros œuvre, Bâtiment A, Phase recette...',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    if (isZone) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<StructuredGanttItem>(
                        value: selectedParent,
                        decoration: const InputDecoration(
                          labelText: 'Parent',
                          border: OutlineInputBorder(),
                        ),
                        items: possibleParents.map((parent) {
                          return DropdownMenuItem(
                            value: parent,
                            child: Text('${parent.wbsCode} - ${parent.name}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedParent = value;
                          });
                        },
                      ),
                      if (possibleParents.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Crée d’abord une Section avant d’ajouter une Zone.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.red,
                              ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();

                    if (name.isEmpty) return;
                    if (isZone && selectedParent == null) return;

                    final parentId = isZone ? selectedParent!.id : null;
                    final sortOrder = _getNextSortOrder(
                      items: items,
                      parentId: parentId,
                    );

                    Navigator.of(context).pop();

                    try {
                      await _ganttApi.createPlanningItem(
                        projectId: widget.projectId,
                        name: name,
                        type: selectedType,
                        parentId: parentId,
                        sortOrder: sortOrder,
                      );

                      setState(() {
                        _loadGantt();
                      });

                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$selectedType ajoutée au Gantt.'),
                        ),
                      );
                    } catch (error) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur création : $error'),
                        ),
                      );
                    }
                  },
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Future<void> _moveItem({
    required StructuredGanttItem item,
    required List<StructuredGanttItem> possibleParents,
  }) async {
    StructuredGanttItem? selectedParent;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Déplacer "${item.name}"'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return DropdownButtonFormField<StructuredGanttItem>(
                value: selectedParent,
                decoration: const InputDecoration(
                  labelText: 'Déplacer vers',
                  border: OutlineInputBorder(),
                ),
                items: possibleParents.map((parent) {
                  return DropdownMenuItem(
                    value: parent,
                    child: Text('${parent.wbsCode} - ${parent.name}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedParent = value;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedParent == null) return;

                Navigator.of(context).pop();

                try {
                  await _ganttApi.movePlanningItem(
                    itemId: item.id,
                    newParentId: selectedParent!.id,
                  );

                  setState(() {
                    _loadGantt();
                  });

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tâche déplacée avec succès.'),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur déplacement : $error'),
                    ),
                  );
                }
              },
              child: const Text('Déplacer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StructuredGanttLoadedData>(
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

        final loadedData = snapshot.data!;
        final data = loadedData.gantt;

        if (data.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Aucun élément à afficher dans le Gantt.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _createPlanningItem(data.items),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une section'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _syncTasks,
                  icon: const Icon(Icons.sync),
                  label: const Text('Synchroniser les tâches'),
                ),
              ],
            ),
          );
        }

        return _StructuredGanttChart(
          data: data,
          calendar: loadedData.calendar,
          exceptions: loadedData.exceptions,
          dayWidth: _dayWidth,
          displayMode: _displayMode,
          onDisplayModeChanged: _changeDisplayMode,
          onRefresh: _refreshGantt,
          onSyncTasks: _syncTasks,
          onCreateItem: _createPlanningItem,
          onMoveItem: _moveItem,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
        );
      },
    );
  }
}

class _StructuredGanttChart extends StatefulWidget {
  final StructuredGanttResponse data;
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;
  final double dayWidth;
  final StructuredGanttDisplayMode displayMode;
  final ValueChanged<StructuredGanttDisplayMode?> onDisplayModeChanged;
  final VoidCallback onRefresh;
  final Future<void> Function() onSyncTasks;
  final Future<void> Function(List<StructuredGanttItem> items) onCreateItem;
  final Future<void> Function({
    required StructuredGanttItem item,
    required List<StructuredGanttItem> possibleParents,
  }) onMoveItem;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _StructuredGanttChart({
    required this.data,
    required this.calendar,
    required this.exceptions,
    required this.dayWidth,
    required this.displayMode,
    required this.onDisplayModeChanged,
    required this.onRefresh,
    required this.onSyncTasks,
    required this.onCreateItem,
    required this.onMoveItem,
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
    final cleanProjectStart = _dateOnly(projectStart);
    final cleanProjectEnd = _dateOnly(projectEnd);

    switch (widget.displayMode) {
      case StructuredGanttDisplayMode.auto:
        final rawDays = _calendarDaysBetween(
          cleanProjectStart,
          cleanProjectEnd,
        );

        if (rawDays < 14) {
          return (
            start: cleanProjectStart.subtract(const Duration(days: 3)),
            end: cleanProjectStart.add(const Duration(days: 18)),
          );
        }

        return (
          start: cleanProjectStart.subtract(const Duration(days: 2)),
          end: cleanProjectEnd.add(const Duration(days: 5)),
        );

      case StructuredGanttDisplayMode.month:
        return (
          start: _startOfMonth(cleanProjectStart),
          end: _endOfMonth(cleanProjectEnd),
        );

      case StructuredGanttDisplayMode.quarter:
        return (
          start: _startOfQuarter(cleanProjectStart),
          end: _endOfQuarter(cleanProjectEnd),
        );

      case StructuredGanttDisplayMode.year:
        return (
          start: _startOfYear(cleanProjectStart),
          end: _endOfYear(cleanProjectEnd),
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

    final possibleParents = items
        .where((item) => item.type == 'Section' || item.type == 'Zone')
        .toList();

    if (taskItems.isEmpty) {
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
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => widget.onCreateItem(items),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
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
          const Expanded(
            child: Center(
              child: Text('La structure existe, mais aucune tâche n’est liée.'),
            ),
          ),
        ],
      );
    }

    final projectStart = _dateOnly(
      taskItems
          .map((item) => item.task!.startDate)
          .reduce((a, b) => a.isBefore(b) ? a : b),
    );

    final projectEnd = _dateOnly(
      taskItems
          .map((item) => item.task!.endDate)
          .reduce((a, b) => a.isAfter(b) ? a : b),
    );

    final visibleRange = _getVisibleRange(
      projectStart: projectStart,
      projectEnd: projectEnd,
    );

    final visibleStart = _dateOnly(visibleRange.start);
    final visibleEnd = _dateOnly(visibleRange.end);

    final totalDaysRaw = _calendarDaysBetween(visibleStart, visibleEnd);
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
              FilledButton.icon(
                onPressed: () => widget.onCreateItem(items),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
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
                      height: _ganttHeaderHeight,
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

                          return _StructuredGanttLeftRow(
                            item: item,
                            possibleParents: possibleParents
                                .where((parent) => parent.id != item.id)
                                .toList(),
                            onMoveItem: widget.onMoveItem,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final effectiveChartWidth =
                        chartWidth < constraints.maxWidth
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
                                calendar: widget.calendar,
                                exceptions: widget.exceptions,
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
                                      calendar: widget.calendar,
                                      exceptions: widget.exceptions,
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
  final List<StructuredGanttItem> possibleParents;
  final Future<void> Function({
    required StructuredGanttItem item,
    required List<StructuredGanttItem> possibleParents,
  }) onMoveItem;

  const _StructuredGanttLeftRow({
    required this.item,
    required this.possibleParents,
    required this.onMoveItem,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
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
                  if (item.type == 'Task') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Déplacer',
                      icon: const Icon(
                        Icons.drive_file_move_outline,
                        size: 18,
                      ),
                      onPressed: () {
                        onMoveItem(
                          item: item,
                          possibleParents: possibleParents,
                        );
                      },
                    ),
                  ],
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
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;

  const _StructuredGanttDateHeader({
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
    required this.calendar,
    required this.exceptions,
  });

  String _weekdayLabel(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'L';
      case DateTime.tuesday:
        return 'M';
      case DateTime.wednesday:
        return 'M';
      case DateTime.thursday:
        return 'J';
      case DateTime.friday:
        return 'V';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'D';
      default:
        return '';
    }
  }

  String _monthLabel(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final cleanVisibleStart = _dateOnly(visibleStart);

    return Container(
      height: _ganttHeaderHeight,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: List.generate(totalDays + 2, (index) {
          final date = cleanVisibleStart.add(Duration(days: index));
          final isWorkingDay = _isWorkingDayForProject(
            date: date,
            calendar: calendar,
            exceptions: exceptions,
          );
          final exception = _findExceptionForDate(
            date: date,
            exceptions: exceptions,
          );

          final showMonth = index == 0 || date.day == 1;
          final isToday = _isSameDay(date, DateTime.now());

          return Tooltip(
            message: exception == null
                ? '${DateFormat('EEEE dd/MM/yyyy').format(date)} · ${isWorkingDay ? 'Jour ouvré' : 'Jour non ouvré'}'
                : '${DateFormat('EEEE dd/MM/yyyy').format(date)} · ${exception.label.isEmpty ? 'Exception calendrier' : exception.label} · ${exception.isWorkingDay ? 'Jour travaillé' : 'Jour non travaillé'}',
            child: Container(
              width: dayWidth,
              decoration: BoxDecoration(
                color: isWorkingDay
                    ? null
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.85),
                border: Border(
                  left: BorderSide(
                    color: date.day == 1
                        ? Theme.of(context).dividerColor.withOpacity(0.9)
                        : Theme.of(context).dividerColor.withOpacity(0.35),
                  ),
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.45),
                  ),
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 26,
                    child: Center(
                      child: showMonth
                          ? RotatedBox(
                              quarterTurns: dayWidth < 22 ? 3 : 0,
                              child: Text(
                                _monthLabel(date),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: dayWidth < 22 ? 9 : 10,
                                    ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.65)
                          : null,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context)
                              .dividerColor
                              .withOpacity(0.25),
                        ),
                      ),
                    ),
                    child: Text(
                      '${date.day}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isWorkingDay
                                ? null
                                : Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withOpacity(0.55),
                          ),
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekdayLabel(date),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isWorkingDay
                                      ? null
                                      : Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.color
                                          ?.withOpacity(0.55),
                                ),
                          ),
                          if (exception != null)
                            Icon(
                              exception.isWorkingDay
                                  ? Icons.work_outline
                                  : Icons.block,
                              size: 10,
                              color: exception.isWorkingDay
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.red,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
  final ProjectCalendarModel calendar;
  final List<ProjectCalendarExceptionModel> exceptions;

  const _StructuredGanttBarRow({
    required this.item,
    required this.visibleStart,
    required this.totalDays,
    required this.dayWidth,
    required this.calendar,
    required this.exceptions,
  });

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final cleanVisibleStart = _dateOnly(visibleStart);

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
              final date = cleanVisibleStart.add(Duration(days: index));
              final isMajor = index % 5 == 0 || date.day == 1;
              final isWorkingDay = _isWorkingDayForProject(
                date: date,
                calendar: calendar,
                exceptions: exceptions,
              );
              final exception = _findExceptionForDate(
                date: date,
                exceptions: exceptions,
              );

              return Container(
                width: dayWidth,
                decoration: BoxDecoration(
                  color: !isWorkingDay
                      ? Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withOpacity(0.55)
                      : exception != null
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.20)
                          : null,
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
    final cleanVisibleStart = _dateOnly(visibleStart);
    final taskStart = _dateOnly(task.startDate);
    final taskEnd = _dateOnly(task.endDate);

    final offsetDays = _calendarDaysBetween(cleanVisibleStart, taskStart);
    final rawTaskDays = _calendarDaysBetween(taskStart, taskEnd);
    final taskDays = rawTaskDays <= 0 ? 1 : rawTaskDays;

    final left = offsetDays * dayWidth;
    final width = taskDays * dayWidth;

    return Positioned(
      left: left < 0 ? 0 : left,
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
