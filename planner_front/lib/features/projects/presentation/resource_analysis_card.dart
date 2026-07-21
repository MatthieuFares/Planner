import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResourceAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> analysis;

  const ResourceAnalysisCard({
    super.key,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    final data = _ResourceAnalysisData.fromMap(analysis);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, data),
        const SizedBox(height: 12),
        _buildMetrics(context, data),
        const SizedBox(height: 16),
        if (data.resources.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Aucune donnée ressource disponible pour ce projet.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;

              final workloadChart = _AnalysisSectionCard(
                title: 'Charge et capacité',
                subtitle:
                    'Comparaison entre la charge affectée et la capacité '
                    'hebdomadaire renvoyée par l’API.',
                icon: Icons.stacked_bar_chart_outlined,
                child: _ResourceCapacityChart(
                  resources: data.resources,
                ),
              );

              final workloadDonut = _AnalysisSectionCard(
                title: 'Répartition de la charge',
                subtitle: 'Part des heures affectées par ressource.',
                icon: Icons.donut_large_outlined,
                child: _ResourceDonutChart(
                  resources: data.resources,
                  valueSelector: (resource) =>
                      resource.assignedHours,
                  valueFormatter: (value) =>
                      '${_formatNumber(value)} h',
                ),
              );

              final costDonut = _AnalysisSectionCard(
                title: 'Répartition des coûts',
                subtitle: 'Part du coût estimé par ressource.',
                icon: Icons.pie_chart_outline,
                child: _ResourceDonutChart(
                  resources: data.resources,
                  valueSelector: (resource) =>
                      resource.estimatedCost,
                  valueFormatter: (value) =>
                      '${_formatNumber(value)} €',
                ),
              );

              if (!isWide) {
                return Column(
                  children: [
                    workloadChart,
                    const SizedBox(height: 16),
                    workloadDonut,
                    const SizedBox(height: 16),
                    costDonut,
                  ],
                );
              }

              return Column(
                children: [
                  workloadChart,
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: workloadDonut),
                      const SizedBox(width: 16),
                      Expanded(child: costDonut),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _AnalysisSectionCard(
            title: 'Détail des ressources',
            subtitle:
                'Charge, coût, utilisation et état de surcharge.',
            icon: Icons.table_chart_outlined,
            child: _ResourceDetailsTable(
              resources: data.resources,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    _ResourceAnalysisData data,
  ) {
    return Row(
      children: [
        Icon(
          Icons.groups_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Analyse ressources',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Chip(
          avatar: const Icon(
            Icons.people_outline,
            size: 17,
          ),
          label: Text(
            '${data.resources.length} ressource(s)',
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildMetrics(
    BuildContext context,
    _ResourceAnalysisData data,
  ) {
    final overloadedCount = data.resources
        .where((resource) => resource.isOverloaded)
        .length;

    final averageUtilization = data.resources.isEmpty
        ? 0.0
        : data.resources
                .map((resource) => resource.utilizationPercent)
                .fold<double>(0, (sum, value) => sum + value) /
            data.resources.length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(
          label: 'Charge totale',
          value: '${_formatNumber(data.totalWorkloadHours)} h',
          icon: Icons.schedule_outlined,
        ),
        _MetricCard(
          label: 'Coût estimé',
          value: '${_formatNumber(data.estimatedCost)} €',
          icon: Icons.euro_outlined,
        ),
        _MetricCard(
          label: 'Utilisation moyenne',
          value: '${_formatNumber(averageUtilization)} %',
          icon: Icons.speed_outlined,
          isWarning: averageUtilization > 100,
        ),
        _MetricCard(
          label: 'Ressources surchargées',
          value: '$overloadedCount',
          icon: Icons.warning_amber_outlined,
          isWarning: overloadedCount > 0,
        ),
      ],
    );
  }
}

class _ResourceAnalysisData {
  final int projectId;
  final double totalWorkloadHours;
  final double estimatedCost;
  final List<_ResourceAnalysisEntry> resources;

  const _ResourceAnalysisData({
    required this.projectId,
    required this.totalWorkloadHours,
    required this.estimatedCost,
    required this.resources,
  });

  factory _ResourceAnalysisData.fromMap(
    Map<String, dynamic> json,
  ) {
    final rawResources = json['resources'];

    return _ResourceAnalysisData(
      projectId: _readInt(json['projectId']),
      totalWorkloadHours:
          _readDouble(json['totalWorkloadHours']),
      estimatedCost: _readDouble(json['estimatedCost']),
      resources: rawResources is List
          ? rawResources
              .whereType<Map>()
              .map(
                (item) => _ResourceAnalysisEntry.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const <_ResourceAnalysisEntry>[],
    );
  }
}

class _ResourceAnalysisEntry {
  final int resourceId;
  final String resourceName;
  final String resourceType;
  final double assignedHours;
  final double capacityHoursPerWeek;
  final double costPerHour;
  final double estimatedCost;
  final double utilizationPercent;
  final bool isOverloaded;

  const _ResourceAnalysisEntry({
    required this.resourceId,
    required this.resourceName,
    required this.resourceType,
    required this.assignedHours,
    required this.capacityHoursPerWeek,
    required this.costPerHour,
    required this.estimatedCost,
    required this.utilizationPercent,
    required this.isOverloaded,
  });

  factory _ResourceAnalysisEntry.fromMap(
    Map<String, dynamic> json,
  ) {
    return _ResourceAnalysisEntry(
      resourceId: _readInt(json['resourceId']),
      resourceName:
          json['resourceName']?.toString() ?? 'Ressource',
      resourceType:
          json['resourceType']?.toString() ?? 'Inconnu',
      assignedHours: _readDouble(json['assignedHours']),
      capacityHoursPerWeek:
          _readDouble(json['capacityHoursPerWeek']),
      costPerHour: _readDouble(json['costPerHour']),
      estimatedCost: _readDouble(json['estimatedCost']),
      utilizationPercent:
          _readDouble(json['utilizationPercent']),
      isOverloaded: json['isOverloaded'] == true,
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isWarning;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Container(
      width: 215,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWarning
            ? Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: 0.35)
            : Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
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
                        color: isWarning ? color : null,
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

class _AnalysisSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _AnalysisSectionCard({
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

class _ResourceCapacityChart extends StatelessWidget {
  final List<_ResourceAnalysisEntry> resources;

  const _ResourceCapacityChart({
    required this.resources,
  });

  @override
  Widget build(BuildContext context) {
    final maximumValue = resources.fold<double>(
      1,
      (currentMaximum, resource) {
        return math.max(
          currentMaximum,
          math.max(
            resource.assignedHours,
            resource.capacityHoursPerWeek,
          ),
        );
      },
    );

    return Column(
      children: resources.map((resource) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Tooltip(
            message:
                '${resource.resourceName}\n'
                'Type : ${_resourceTypeLabel(resource.resourceType)}\n'
                'Charge affectée : '
                '${_formatNumber(resource.assignedHours)} h\n'
                'Capacité hebdomadaire : '
                '${_formatNumber(resource.capacityHoursPerWeek)} h\n'
                'Utilisation API : '
                '${_formatNumber(resource.utilizationPercent)} %\n'
                'Coût estimé : '
                '${_formatNumber(resource.estimatedCost)} €',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        resource.resourceName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ResourceStatusChip(resource: resource),
                  ],
                ),
                const SizedBox(height: 9),
                _ComparisonBar(
                  label: 'Charge',
                  value: resource.assignedHours,
                  maximumValue: maximumValue,
                  trailing:
                      '${_formatNumber(resource.assignedHours)} h',
                  color:
                      resource.isOverloaded
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 6),
                _ComparisonBar(
                  label: 'Capacité',
                  value: resource.capacityHoursPerWeek,
                  maximumValue: maximumValue,
                  trailing:
                      '${_formatNumber(resource.capacityHoursPerWeek)} h/sem.',
                  color: Theme.of(context)
                      .colorScheme
                      .tertiary,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  final String label;
  final double value;
  final double maximumValue;
  final String trailing;
  final Color color;

  const _ComparisonBar({
    required this.label,
    required this.value,
    required this.maximumValue,
    required this.trailing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maximumValue <= 0
        ? 0.0
        : (value / maximumValue).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: constraints.maxWidth * ratio,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: Text(
            trailing,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ResourceDonutChart extends StatelessWidget {
  final List<_ResourceAnalysisEntry> resources;
  final double Function(_ResourceAnalysisEntry resource)
      valueSelector;
  final String Function(double value) valueFormatter;

  const _ResourceDonutChart({
    required this.resources,
    required this.valueSelector,
    required this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _chartPalette(context);

    final values = resources
        .map(valueSelector)
        .map((value) => value < 0 ? 0.0 : value)
        .toList();

    final total = values.fold<double>(
      0,
      (sum, value) => sum + value,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 470;

        final chart = SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(180),
                painter: _DonutPainter(
                  values: values,
                  colors: palette,
                  trackColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    valueFormatter(total),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Total',
                    style:
                        Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        );

        final legend = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(resources.length, (index) {
            final resource = resources[index];
            final value = values[index];
            final percent =
                total <= 0 ? 0.0 : value / total * 100;

            return Tooltip(
              message:
                  '${resource.resourceName}\n'
                  '${valueFormatter(value)}\n'
                  '${_formatNumber(percent)} % du total',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: palette[index % palette.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        resource.resourceName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatNumber(percent)} %',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );

        if (compact) {
          return Column(
            children: [
              chart,
              const SizedBox(height: 12),
              legend,
            ],
          );
        }

        return Row(
          children: [
            chart,
            const SizedBox(width: 18),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color trackColor;

  const _DonutPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final strokeWidth = math.max(18.0, radius * 0.24);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, trackPaint);

    final total = values.fold<double>(
      0,
      (sum, value) => sum + math.max(0, value),
    );

    if (total <= 0) return;

    var startAngle = -math.pi / 2;
    const gap = 0.025;

    for (var index = 0; index < values.length; index++) {
      final value = math.max(0, values[index]);

      if (value <= 0) continue;

      final sweepAngle = value / total * math.pi * 2;
      final visibleSweep =
          math.max(0.0, sweepAngle - gap);

      final paint = Paint()
        ..color = colors[index % colors.length]
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

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.trackColor != trackColor;
  }
}

class _ResourceDetailsTable extends StatelessWidget {
  final List<_ResourceAnalysisEntry> resources;

  const _ResourceDetailsTable({
    required this.resources,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Ressource')),
          DataColumn(label: Text('Type')),
          DataColumn(
            label: Text('Charge'),
            numeric: true,
          ),
          DataColumn(
            label: Text('Capacité/sem.'),
            numeric: true,
          ),
          DataColumn(
            label: Text('Utilisation'),
            numeric: true,
          ),
          DataColumn(
            label: Text('Coût/h'),
            numeric: true,
          ),
          DataColumn(
            label: Text('Coût estimé'),
            numeric: true,
          ),
          DataColumn(label: Text('État')),
        ],
        rows: resources.map((resource) {
          return DataRow(
            color: WidgetStateProperty.resolveWith<Color?>(
              (states) {
                if (!resource.isOverloaded) return null;

                return Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.25);
              },
            ),
            cells: [
              DataCell(
                Tooltip(
                  message:
                      'ID ressource : ${resource.resourceId}',
                  child: Text(
                    resource.resourceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              DataCell(
                Text(
                  _resourceTypeLabel(resource.resourceType),
                ),
              ),
              DataCell(
                Text(
                  '${_formatNumber(resource.assignedHours)} h',
                ),
              ),
              DataCell(
                Text(
                  '${_formatNumber(resource.capacityHoursPerWeek)} h',
                ),
              ),
              DataCell(
                Text(
                  '${_formatNumber(resource.utilizationPercent)} %',
                  style: TextStyle(
                    color: resource.isOverloaded
                        ? Theme.of(context).colorScheme.error
                        : null,
                    fontWeight: resource.isOverloaded
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              DataCell(
                Text(
                  '${_formatNumber(resource.costPerHour)} €',
                ),
              ),
              DataCell(
                Text(
                  '${_formatNumber(resource.estimatedCost)} €',
                ),
              ),
              DataCell(
                _ResourceStatusChip(resource: resource),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ResourceStatusChip extends StatelessWidget {
  final _ResourceAnalysisEntry resource;

  const _ResourceStatusChip({
    required this.resource,
  });

  @override
  Widget build(BuildContext context) {
    final overloaded = resource.isOverloaded;
    final color = overloaded
        ? Theme.of(context).colorScheme.error
        : Colors.green;

    return Tooltip(
      message: overloaded
          ? 'Utilisation supérieure à 100 % selon le calcul API.'
          : 'Utilisation inférieure ou égale à 100 %.',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withValues(alpha: 0.30),
          ),
        ),
        child: Text(
          overloaded ? 'Surchargée' : 'Disponible',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

List<Color> _chartPalette(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;

  return [
    scheme.primary,
    scheme.tertiary,
    scheme.secondary,
    Colors.orange,
    Colors.teal,
    Colors.deepPurple,
    Colors.pink,
    Colors.blueGrey,
  ];
}

String _resourceTypeLabel(String value) {
  switch (value.toLowerCase()) {
    case 'person':
      return 'Personne';
    case 'team':
      return 'Équipe';
    case 'material':
      return 'Matériel';
    default:
      return value;
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

String _formatNumber(num value) {
  final doubleValue = value.toDouble();

  if (doubleValue == doubleValue.roundToDouble()) {
    return doubleValue.toInt().toString();
  }

  return doubleValue.toStringAsFixed(1);
}
