import 'dart:math' as math;

import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;

  const SummaryCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final data = _ProjectSummaryData.fromMap(summary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, data),
        const SizedBox(height: 14),
        _buildPrimaryMetrics(context, data),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;

            final progressPanel = _ProjectProgressPanel(
              data: data,
            );

            final taskStatusPanel = _SummarySectionCard(
              title: 'État des tâches',
              subtitle:
                  'Répartition entre tâches terminées et restantes.',
              icon: Icons.donut_large_outlined,
              child: _TaskStatusChart(data: data),
            );

            final criticalityPanel = _SummarySectionCard(
              title: 'Criticité',
              subtitle:
                  'Répartition des tâches critiques et non critiques.',
              icon: Icons.warning_amber_outlined,
              child: _CriticalityChart(data: data),
            );

            if (!isWide) {
              return Column(
                children: [
                  progressPanel,
                  const SizedBox(height: 16),
                  taskStatusPanel,
                  const SizedBox(height: 16),
                  criticalityPanel,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: progressPanel,
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: taskStatusPanel,
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: criticalityPanel,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _SummarySectionCard(
          title: 'Structure et ressources',
          subtitle:
              'Dépendances, ressources, groupes et capacité globale.',
          icon: Icons.account_tree_outlined,
          child: _ProjectStructureGrid(data: data),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    _ProjectSummaryData data,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.dashboard_outlined,
            color: Theme.of(context)
                .colorScheme
                .onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Résumé projet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 3),
              Text(
                data.projectName.isEmpty
                    ? 'Projet #${data.projectId}'
                    : data.projectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (data.projectStart != null ||
            data.projectEnd != null)
          Tooltip(
            message:
                'Période actuelle du projet\n'
                'Début : ${_formatDate(data.projectStart)}\n'
                'Fin : ${_formatDate(data.projectEnd)}',
            child: Chip(
              avatar: const Icon(
                Icons.date_range_outlined,
                size: 17,
              ),
              label: Text(
                '${_formatDate(data.projectStart)} → '
                '${_formatDate(data.projectEnd)}',
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }

  Widget _buildPrimaryMetrics(
    BuildContext context,
    _ProjectSummaryData data,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryMetricCard(
          label: 'Progression globale',
          value:
              '${_formatNumber(data.globalProgressPercent)} %',
          icon: Icons.trending_up_outlined,
          emphasize: true,
        ),
        _SummaryMetricCard(
          label: 'Tâches',
          value: '${data.taskCount}',
          icon: Icons.checklist_outlined,
        ),
        _SummaryMetricCard(
          label: 'Durée projet',
          value: '${data.projectDurationDays} j',
          icon: Icons.timelapse_outlined,
        ),
        _SummaryMetricCard(
          label: 'Charge totale',
          value:
              '${_formatNumber(data.totalWorkloadHours)} h',
          icon: Icons.schedule_outlined,
        ),
        _SummaryMetricCard(
          label: 'Coût estimé',
          value: '${_formatNumber(data.estimatedCost)} €',
          icon: Icons.euro_outlined,
        ),
        _SummaryMetricCard(
          label: 'Ressources',
          value: '${data.resourceCount}',
          icon: Icons.groups_outlined,
          warning: data.overloadedResourceCount > 0,
        ),
      ],
    );
  }
}

class _ProjectSummaryData {
  final int projectId;
  final String projectName;
  final DateTime? projectStart;
  final DateTime? projectEnd;
  final int projectDurationDays;
  final int taskCount;
  final int completedTaskCount;
  final double globalProgressPercent;
  final int criticalTaskCount;
  final int nonCriticalTaskCount;
  final int dependencyCount;
  final int resourceCount;
  final int resourceGroupCount;
  final double totalWorkloadHours;
  final double estimatedCost;
  final int overloadedResourceCount;

  const _ProjectSummaryData({
    required this.projectId,
    required this.projectName,
    required this.projectStart,
    required this.projectEnd,
    required this.projectDurationDays,
    required this.taskCount,
    required this.completedTaskCount,
    required this.globalProgressPercent,
    required this.criticalTaskCount,
    required this.nonCriticalTaskCount,
    required this.dependencyCount,
    required this.resourceCount,
    required this.resourceGroupCount,
    required this.totalWorkloadHours,
    required this.estimatedCost,
    required this.overloadedResourceCount,
  });

  int get remainingTaskCount =>
      math.max(0, taskCount - completedTaskCount);

  double get completedTaskPercent {
    if (taskCount <= 0) return 0;

    return completedTaskCount / taskCount * 100;
  }

  double get criticalTaskPercent {
    if (taskCount <= 0) return 0;

    return criticalTaskCount / taskCount * 100;
  }

  factory _ProjectSummaryData.fromMap(
    Map<String, dynamic> json,
  ) {
    return _ProjectSummaryData(
      projectId: _readInt(json['projectId']),
      projectName: json['projectName']?.toString() ?? '',
      projectStart: _readDate(json['projectStart']),
      projectEnd: _readDate(json['projectEnd']),
      projectDurationDays:
          _readInt(json['projectDurationDays']),
      taskCount: _readInt(json['taskCount']),
      completedTaskCount:
          _readInt(json['completedTaskCount']),
      globalProgressPercent:
          _readDouble(json['globalProgressPercent'])
              .clamp(0, 100)
              .toDouble(),
      criticalTaskCount:
          _readInt(json['criticalTaskCount']),
      nonCriticalTaskCount:
          _readInt(json['nonCriticalTaskCount']),
      dependencyCount:
          _readInt(json['dependencyCount']),
      resourceCount: _readInt(json['resourceCount']),
      resourceGroupCount:
          _readInt(json['resourceGroupCount']),
      totalWorkloadHours:
          _readDouble(json['totalWorkloadHours']),
      estimatedCost: _readDouble(json['estimatedCost']),
      overloadedResourceCount:
          _readInt(json['overloadedResourceCount']),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool emphasize;
  final bool warning;

  const _SummaryMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Container(
      width: 205,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning
            ? Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: 0.34)
            : emphasize
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.55)
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        color: warning ? color : null,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectProgressPanel extends StatelessWidget {
  final _ProjectSummaryData data;

  const _ProjectProgressPanel({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        data.globalProgressPercent.clamp(0, 100).toDouble();

    return _SummarySectionCard(
      title: 'Avancement global',
      subtitle:
          'Progression agrégée du projet renvoyée par l’API.',
      icon: Icons.insights_outlined,
      child: Column(
        children: [
          SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(190),
                  painter: _ProgressRingPainter(
                    progressPercent: progress,
                    progressColor:
                        Theme.of(context).colorScheme.primary,
                    trackColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_formatNumber(progress)} %',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'progression',
                      style:
                          Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: progress / 100,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InlineValue(
                  label: 'Terminées',
                  value: '${data.completedTaskCount}',
                  icon: Icons.task_alt_outlined,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InlineValue(
                  label: 'Restantes',
                  value: '${data.remainingTaskCount}',
                  icon: Icons.pending_actions_outlined,
                  color:
                      Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskStatusChart extends StatelessWidget {
  final _ProjectSummaryData data;

  const _TaskStatusChart({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <_DonutEntry>[
      _DonutEntry(
        label: 'Terminées',
        value: data.completedTaskCount.toDouble(),
        color: Colors.green,
      ),
      _DonutEntry(
        label: 'Restantes',
        value: data.remainingTaskCount.toDouble(),
        color: Theme.of(context).colorScheme.primary,
      ),
    ];

    return _SummaryDonut(
      entries: entries,
      centerValue: '${data.taskCount}',
      centerLabel: 'tâches',
      tooltipSuffix: 'tâche(s)',
    );
  }
}

class _CriticalityChart extends StatelessWidget {
  final _ProjectSummaryData data;

  const _CriticalityChart({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <_DonutEntry>[
      _DonutEntry(
        label: 'Critiques',
        value: data.criticalTaskCount.toDouble(),
        color: Colors.orange,
      ),
      _DonutEntry(
        label: 'Non critiques',
        value: data.nonCriticalTaskCount.toDouble(),
        color: Theme.of(context).colorScheme.tertiary,
      ),
    ];

    return Column(
      children: [
        _SummaryDonut(
          entries: entries,
          centerValue:
              '${_formatNumber(data.criticalTaskPercent)} %',
          centerLabel: 'critiques',
          tooltipSuffix: 'tâche(s)',
        ),
        if (data.criticalTaskCount > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.30),
              ),
            ),
            child: Text(
              '${data.criticalTaskCount} tâche(s) '
              'sur le chemin critique.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProjectStructureGrid extends StatelessWidget {
  final _ProjectSummaryData data;

  const _ProjectStructureGrid({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StructureItem(
          label: 'Dépendances',
          value: '${data.dependencyCount}',
          icon: Icons.account_tree_outlined,
        ),
        _StructureItem(
          label: 'Ressources',
          value: '${data.resourceCount}',
          icon: Icons.person_outline,
        ),
        _StructureItem(
          label: 'Groupes',
          value: '${data.resourceGroupCount}',
          icon: Icons.group_work_outlined,
        ),
        _StructureItem(
          label: 'Ressources surchargées',
          value: '${data.overloadedResourceCount}',
          icon: Icons.warning_amber_outlined,
          warning: data.overloadedResourceCount > 0,
        ),
        _StructureItem(
          label: 'Charge moyenne / tâche',
          value: data.taskCount <= 0
              ? '0 h'
              : '${_formatNumber(
                  data.totalWorkloadHours / data.taskCount,
                )} h',
          icon: Icons.av_timer_outlined,
        ),
        _StructureItem(
          label: 'Coût moyen / tâche',
          value: data.taskCount <= 0
              ? '0 €'
              : '${_formatNumber(
                  data.estimatedCost / data.taskCount,
                )} €',
          icon: Icons.price_check_outlined,
        ),
      ],
    );
  }
}

class _SummarySectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SummarySectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _InlineValue extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InlineValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StructureItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool warning;

  const _StructureItem({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: '$label : $value',
      child: Container(
        width: 205,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: warning
              ? Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withValues(alpha: 0.30)
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color: warning ? color : null,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryDonut extends StatelessWidget {
  final List<_DonutEntry> entries;
  final String centerValue;
  final String centerLabel;
  final String tooltipSuffix;

  const _SummaryDonut({
    required this.entries,
    required this.centerValue,
    required this.centerLabel,
    required this.tooltipSuffix,
  });

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(
      0,
      (sum, entry) => sum + math.max(0, entry.value),
    );

    return Column(
      children: [
        SizedBox(
          width: 170,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(170),
                painter: _SummaryDonutPainter(
                  entries: entries,
                  trackColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerValue,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    centerLabel,
                    style:
                        Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...entries.map((entry) {
          final percent = total <= 0
              ? 0.0
              : entry.value / total * 100;

          return Tooltip(
            message:
                '${entry.label}\n'
                '${_formatNumber(entry.value)} $tooltipSuffix\n'
                '${_formatNumber(percent)} %',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: entry.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${_formatNumber(entry.value)} '
                    '(${_formatNumber(percent)} %)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _DonutEntry {
  final String label;
  final double value;
  final Color color;

  const _DonutEntry({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _SummaryDonutPainter extends CustomPainter {
  final List<_DonutEntry> entries;
  final Color trackColor;

  const _SummaryDonutPainter({
    required this.entries,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius =
        math.min(size.width, size.height) / 2 - 11;
    final strokeWidth = math.max(18.0, radius * 0.25);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, trackPaint);

    final total = entries.fold<double>(
      0,
      (sum, entry) => sum + math.max(0, entry.value),
    );

    if (total <= 0) return;

    var startAngle = -math.pi / 2;
    const gap = 0.028;

    for (final entry in entries) {
      final value = math.max(0, entry.value);

      if (value <= 0) continue;

      final sweep = value / total * math.pi * 2;
      final visibleSweep = math.max(0.0, sweep - gap);

      final paint = Paint()
        ..color = entry.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
        startAngle + gap / 2,
        visibleSweep,
        false,
        paint,
      );

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(
    covariant _SummaryDonutPainter oldDelegate,
  ) {
    return oldDelegate.entries != entries ||
        oldDelegate.trackColor != trackColor;
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progressPercent;
  final Color progressColor;
  final Color trackColor;

  const _ProgressRingPainter({
    required this.progressPercent,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius =
        math.min(size.width, size.height) / 2 - 12;
    final strokeWidth = math.max(18.0, radius * 0.18);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progressPercent <= 0) return;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(
        center: center,
        radius: radius,
      ),
      -math.pi / 2,
      progressPercent / 100 * math.pi * 2,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _ProgressRingPainter oldDelegate,
  ) {
    return oldDelegate.progressPercent != progressPercent ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _readDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();

  return double.tryParse(
        value?.toString().replaceAll(',', '.') ?? '',
      ) ??
      0;
}

DateTime? _readDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is! String || value.trim().isEmpty) return null;

  return DateTime.tryParse(value);
}

String _formatDate(DateTime? date) {
  if (date == null) return '-';

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatNumber(num value) {
  final doubleValue = value.toDouble();

  if (doubleValue == doubleValue.roundToDouble()) {
    return doubleValue.toInt().toString();
  }

  return doubleValue.toStringAsFixed(1);
}
