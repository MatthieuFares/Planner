import 'dart:math' as math;

import 'package:flutter/material.dart';

enum WarningsNavigationTarget {
  tasks,
  dependencies,
  resources,
  calendar,
  gantt,
}

class WarningsPanel extends StatefulWidget {
  final List<dynamic> warnings;
  final ValueChanged<WarningsNavigationTarget>? onNavigate;

  const WarningsPanel({
    super.key,
    required this.warnings,
    this.onNavigate,
  });

  @override
  State<WarningsPanel> createState() => _WarningsPanelState();
}

class _WarningsPanelState extends State<WarningsPanel> {
  _WarningSeverity? _selectedSeverity;
  _WarningCategory? _selectedCategory;

  List<_ProjectWarning> get _parsedWarnings {
    return widget.warnings
        .map(_ProjectWarning.fromDynamic)
        .toList();
  }

  List<_ProjectWarning> get _filteredWarnings {
    return _parsedWarnings.where((warning) {
      final severityMatches = _selectedSeverity == null ||
          warning.severity == _selectedSeverity;

      final categoryMatches = _selectedCategory == null ||
          warning.category == _selectedCategory;

      return severityMatches && categoryMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final warnings = _parsedWarnings;
    final filteredWarnings = _filteredWarnings;

    final criticalCount = warnings
        .where((warning) =>
            warning.severity == _WarningSeverity.critical)
        .length;

    final warningCount = warnings
        .where((warning) =>
            warning.severity == _WarningSeverity.warning)
        .length;

    final infoCount = warnings
        .where((warning) =>
            warning.severity == _WarningSeverity.info)
        .length;

    final categoryCounts = <_WarningCategory, int>{};

    for (final warning in warnings) {
      categoryCounts.update(
        warning.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, warnings.length),
        const SizedBox(height: 12),
        if (warnings.isEmpty)
          _buildEmptyState(context)
        else ...[
          _buildOverview(
            context: context,
            total: warnings.length,
            criticalCount: criticalCount,
            warningCount: warningCount,
            infoCount: infoCount,
          ),
          const SizedBox(height: 14),
          _buildSeverityFilters(
            criticalCount: criticalCount,
            warningCount: warningCount,
            infoCount: infoCount,
          ),
          const SizedBox(height: 10),
          _buildCategoryFilters(categoryCounts),
          const SizedBox(height: 14),
          _buildWarningList(
            context,
            filteredWarnings,
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int warningCount,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: warningCount > 0
                ? Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.55)
                : Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            warningCount > 0
                ? Icons.notification_important_outlined
                : Icons.verified_outlined,
            color: warningCount > 0
                ? Theme.of(context).colorScheme.error
                : Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alertes projet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                warningCount == 0
                    ? 'Aucune anomalie détectée.'
                    : '$warningCount alerte(s) à examiner.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Chip(
          avatar: Icon(
            warningCount > 0
                ? Icons.warning_amber_outlined
                : Icons.check_circle_outline,
            size: 17,
          ),
          label: Text('$warningCount'),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.verified_outlined,
              size: 44,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            Text(
              'Planning sous contrôle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Le backend ne remonte actuellement aucune alerte '
              'pour ce projet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview({
    required BuildContext context,
    required int total,
    required int criticalCount,
    required int warningCount,
    required int infoCount,
  }) {
    final values = <double>[
      criticalCount.toDouble(),
      warningCount.toDouble(),
      infoCount.toDouble(),
    ];

    final colors = <Color>[
      Theme.of(context).colorScheme.error,
      Colors.orange,
      Theme.of(context).colorScheme.primary,
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 650;

            final chart = SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(170),
                    painter: _WarningDonutPainter(
                      values: values,
                      colors: colors,
                      trackColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'alertes',
                        style:
                            Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            );

            final metrics = Column(
              children: [
                _WarningMetric(
                  label: 'Critiques',
                  value: criticalCount,
                  color: colors[0],
                  icon: Icons.error_outline,
                ),
                const SizedBox(height: 9),
                _WarningMetric(
                  label: 'À surveiller',
                  value: warningCount,
                  color: colors[1],
                  icon: Icons.warning_amber_outlined,
                ),
                const SizedBox(height: 9),
                _WarningMetric(
                  label: 'Informations',
                  value: infoCount,
                  color: colors[2],
                  icon: Icons.info_outline,
                ),
              ],
            );

            if (compact) {
              return Column(
                children: [
                  chart,
                  const SizedBox(height: 14),
                  metrics,
                ],
              );
            }

            return Row(
              children: [
                chart,
                const SizedBox(width: 22),
                Expanded(child: metrics),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSeverityFilters({
    required int criticalCount,
    required int warningCount,
    required int infoCount,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: Text(
            'Toutes (${criticalCount + warningCount + infoCount})',
          ),
          selected: _selectedSeverity == null,
          onSelected: (_) {
            setState(() {
              _selectedSeverity = null;
            });
          },
        ),
        FilterChip(
          avatar: const Icon(
            Icons.error_outline,
            size: 16,
          ),
          label: Text('Critiques ($criticalCount)'),
          selected:
              _selectedSeverity == _WarningSeverity.critical,
          onSelected: (_) {
            setState(() {
              _selectedSeverity =
                  _WarningSeverity.critical;
            });
          },
        ),
        FilterChip(
          avatar: const Icon(
            Icons.warning_amber_outlined,
            size: 16,
          ),
          label: Text('À surveiller ($warningCount)'),
          selected:
              _selectedSeverity == _WarningSeverity.warning,
          onSelected: (_) {
            setState(() {
              _selectedSeverity =
                  _WarningSeverity.warning;
            });
          },
        ),
        FilterChip(
          avatar: const Icon(
            Icons.info_outline,
            size: 16,
          ),
          label: Text('Informations ($infoCount)'),
          selected: _selectedSeverity == _WarningSeverity.info,
          onSelected: (_) {
            setState(() {
              _selectedSeverity = _WarningSeverity.info;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCategoryFilters(
    Map<_WarningCategory, int> counts,
  ) {
    if (counts.length <= 1) {
      return const SizedBox.shrink();
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Toutes catégories'),
          selected: _selectedCategory == null,
          onSelected: (_) {
            setState(() {
              _selectedCategory = null;
            });
          },
        ),
        ...sortedEntries.map((entry) {
          return ChoiceChip(
            avatar: Icon(
              _categoryIcon(entry.key),
              size: 16,
            ),
            label: Text(
              '${_categoryLabel(entry.key)} (${entry.value})',
            ),
            selected: _selectedCategory == entry.key,
            onSelected: (_) {
              setState(() {
                _selectedCategory = entry.key;
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildWarningList(
    BuildContext context,
    List<_ProjectWarning> warnings,
  ) {
    if (warnings.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.filter_alt_off_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aucune alerte ne correspond aux filtres.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: warnings.map((warning) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _WarningTile(
            warning: warning,
            onOpen: widget.onNavigate == null
                ? null
                : () {
                    widget.onNavigate!(
                      _navigationTargetForCategory(
                        warning.category,
                      ),
                    );
                  },
          ),
        );
      }).toList(),
    );
  }
}

class _WarningMetric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _WarningMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '$value',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _WarningTile extends StatelessWidget {
  final _ProjectWarning warning;
  final VoidCallback? onOpen;

  const _WarningTile({
    required this.warning,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(
      context,
      warning.severity,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 5,
                color: color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _categoryIcon(warning.category),
                          size: 20,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    warning.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _SeverityBadge(
                                  severity: warning.severity,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              warning.message,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                            if (warning.contextLabel != null) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  Chip(
                                    avatar: const Icon(
                                      Icons.label_outline,
                                      size: 15,
                                    ),
                                    label: Text(
                                      warning.contextLabel!,
                                    ),
                                    visualDensity:
                                        VisualDensity.compact,
                                  ),
                                  Chip(
                                    avatar: Icon(
                                      _categoryIcon(
                                        warning.category,
                                      ),
                                      size: 15,
                                    ),
                                    label: Text(
                                      _categoryLabel(
                                        warning.category,
                                      ),
                                    ),
                                    visualDensity:
                                        VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (onOpen != null) ...[
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            size: 15,
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
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final _WarningSeverity severity;

  const _SeverityBadge({
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(context, severity);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        _severityLabel(severity),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProjectWarning {
  final String title;
  final String message;
  final String? contextLabel;
  final _WarningSeverity severity;
  final _WarningCategory category;

  const _ProjectWarning({
    required this.title,
    required this.message,
    required this.contextLabel,
    required this.severity,
    required this.category,
  });

  factory _ProjectWarning.fromDynamic(dynamic raw) {
    if (raw is String) {
      final category = _deriveCategory(raw);
      final severity = _deriveSeverity(
        explicitValue: null,
        searchableText: raw,
        category: category,
      );

      return _ProjectWarning(
        title: _defaultTitle(category),
        message: raw,
        contextLabel: null,
        severity: severity,
        category: category,
      );
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      final message = _firstText(
            map,
            const [
              'message',
              'description',
              'details',
              'warning',
              'text',
              'reason',
            ],
          ) ??
          map.toString();

      final explicitTitle = _firstText(
        map,
        const [
          'title',
          'name',
          'label',
          'warningTitle',
        ],
      );

      final contextLabel = _firstText(
        map,
        const [
          'taskTitle',
          'taskName',
          'resourceName',
          'groupName',
          'calendarLabel',
          'entityName',
        ],
      );

      final searchableText = [
        ...map.keys,
        ...map.values.map((value) => value.toString()),
      ].join(' ');

      final category = _deriveCategory(searchableText);

      final explicitSeverity = _firstText(
        map,
        const [
          'severity',
          'level',
          'priority',
          'status',
        ],
      );

      return _ProjectWarning(
        title: explicitTitle ?? _defaultTitle(category),
        message: message,
        contextLabel: contextLabel,
        severity: _deriveSeverity(
          explicitValue: explicitSeverity,
          searchableText: searchableText,
          category: category,
        ),
        category: category,
      );
    }

    final text = raw?.toString() ?? 'Alerte inconnue';
    final category = _deriveCategory(text);

    return _ProjectWarning(
      title: _defaultTitle(category),
      message: text,
      contextLabel: null,
      severity: _deriveSeverity(
        explicitValue: null,
        searchableText: text,
        category: category,
      ),
      category: category,
    );
  }
}

enum _WarningSeverity {
  critical,
  warning,
  info,
}

enum _WarningCategory {
  delay,
  criticalPath,
  resource,
  assignment,
  calendar,
  dependency,
  planning,
  other,
}

String? _firstText(
  Map<String, dynamic> map,
  List<String> keys,
) {
  for (final key in keys) {
    final value = map[key];

    if (value == null) continue;

    final text = value.toString().trim();

    if (text.isNotEmpty) {
      return text;
    }
  }

  return null;
}

_WarningCategory _deriveCategory(String text) {
  final normalized = text.toLowerCase();

  if (_containsAny(
    normalized,
    const [
      'overload',
      'surcharge',
      'capacity',
      'capacité',
      'utilization',
      'utilisation',
      'resource',
      'ressource',
    ],
  )) {
    return _WarningCategory.resource;
  }

  if (_containsAny(
    normalized,
    const [
      'unassigned',
      'sans assignation',
      'non assign',
      'aucune ressource',
      'assignment',
      'assignation',
    ],
  )) {
    return _WarningCategory.assignment;
  }

  if (_containsAny(
    normalized,
    const [
      'deadline',
      'late',
      'retard',
      'delay',
      'échéance',
      'echeance',
      'dépasse',
      'depasse',
    ],
  )) {
    return _WarningCategory.delay;
  }

  if (_containsAny(
    normalized,
    const [
      'critical',
      'critique',
      'float',
      'marge',
    ],
  )) {
    return _WarningCategory.criticalPath;
  }

  if (_containsAny(
    normalized,
    const [
      'calendar',
      'calendrier',
      'working day',
      'jour ouvré',
      'jour ouvre',
      'holiday',
      'vacation',
      'fermeture',
    ],
  )) {
    return _WarningCategory.calendar;
  }

  if (_containsAny(
    normalized,
    const [
      'dependency',
      'dépendance',
      'dependance',
      'predecessor',
      'prédécesseur',
      'predecesseur',
      'cycle',
    ],
  )) {
    return _WarningCategory.dependency;
  }

  if (_containsAny(
    normalized,
    const [
      'planning',
      'schedule',
      'date',
      'duration',
      'durée',
      'duree',
    ],
  )) {
    return _WarningCategory.planning;
  }

  return _WarningCategory.other;
}

_WarningSeverity _deriveSeverity({
  required String? explicitValue,
  required String searchableText,
  required _WarningCategory category,
}) {
  final explicit = explicitValue?.toLowerCase() ?? '';

  if (_containsAny(
    explicit,
    const [
      'critical',
      'critique',
      'error',
      'erreur',
      'high',
      'élevé',
      'eleve',
      'danger',
    ],
  )) {
    return _WarningSeverity.critical;
  }

  if (_containsAny(
    explicit,
    const [
      'warning',
      'warn',
      'medium',
      'moyen',
      'attention',
    ],
  )) {
    return _WarningSeverity.warning;
  }

  if (_containsAny(
    explicit,
    const [
      'info',
      'low',
      'faible',
    ],
  )) {
    return _WarningSeverity.info;
  }

  final normalized = searchableText.toLowerCase();

  if (_containsAny(
    normalized,
    const [
      'overloaded',
      'surcharg',
      'en retard',
      'late',
      'deadline dépass',
      'deadline depass',
      'erreur',
      'error',
    ],
  )) {
    return _WarningSeverity.critical;
  }

  if (category == _WarningCategory.criticalPath ||
      category == _WarningCategory.assignment ||
      category == _WarningCategory.dependency) {
    return _WarningSeverity.warning;
  }

  return _WarningSeverity.info;
}

bool _containsAny(
  String source,
  List<String> values,
) {
  for (final value in values) {
    if (source.contains(value)) {
      return true;
    }
  }

  return false;
}

String _defaultTitle(_WarningCategory category) {
  switch (category) {
    case _WarningCategory.delay:
      return 'Retard ou échéance';
    case _WarningCategory.criticalPath:
      return 'Chemin critique';
    case _WarningCategory.resource:
      return 'Charge ressource';
    case _WarningCategory.assignment:
      return 'Assignation manquante';
    case _WarningCategory.calendar:
      return 'Calendrier projet';
    case _WarningCategory.dependency:
      return 'Dépendance';
    case _WarningCategory.planning:
      return 'Planification';
    case _WarningCategory.other:
      return 'Alerte projet';
  }
}

String _categoryLabel(_WarningCategory category) {
  switch (category) {
    case _WarningCategory.delay:
      return 'Retards';
    case _WarningCategory.criticalPath:
      return 'Criticité';
    case _WarningCategory.resource:
      return 'Ressources';
    case _WarningCategory.assignment:
      return 'Assignations';
    case _WarningCategory.calendar:
      return 'Calendrier';
    case _WarningCategory.dependency:
      return 'Dépendances';
    case _WarningCategory.planning:
      return 'Planning';
    case _WarningCategory.other:
      return 'Autres';
  }
}

IconData _categoryIcon(_WarningCategory category) {
  switch (category) {
    case _WarningCategory.delay:
      return Icons.event_busy_outlined;
    case _WarningCategory.criticalPath:
      return Icons.route_outlined;
    case _WarningCategory.resource:
      return Icons.groups_outlined;
    case _WarningCategory.assignment:
      return Icons.person_off_outlined;
    case _WarningCategory.calendar:
      return Icons.calendar_month_outlined;
    case _WarningCategory.dependency:
      return Icons.account_tree_outlined;
    case _WarningCategory.planning:
      return Icons.timeline_outlined;
    case _WarningCategory.other:
      return Icons.info_outline;
  }
}

WarningsNavigationTarget _navigationTargetForCategory(
  _WarningCategory category,
) {
  switch (category) {
    case _WarningCategory.resource:
    case _WarningCategory.assignment:
      return WarningsNavigationTarget.resources;
    case _WarningCategory.calendar:
      return WarningsNavigationTarget.calendar;
    case _WarningCategory.dependency:
      return WarningsNavigationTarget.dependencies;
    case _WarningCategory.delay:
    case _WarningCategory.criticalPath:
    case _WarningCategory.planning:
      return WarningsNavigationTarget.gantt;
    case _WarningCategory.other:
      return WarningsNavigationTarget.tasks;
  }
}

String _severityLabel(_WarningSeverity severity) {
  switch (severity) {
    case _WarningSeverity.critical:
      return 'CRITIQUE';
    case _WarningSeverity.warning:
      return 'ATTENTION';
    case _WarningSeverity.info:
      return 'INFO';
  }
}

Color _severityColor(
  BuildContext context,
  _WarningSeverity severity,
) {
  switch (severity) {
    case _WarningSeverity.critical:
      return Theme.of(context).colorScheme.error;
    case _WarningSeverity.warning:
      return Colors.orange;
    case _WarningSeverity.info:
      return Theme.of(context).colorScheme.primary;
  }
}

class _WarningDonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color trackColor;

  const _WarningDonutPainter({
    required this.values,
    required this.colors,
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

    final total = values.fold<double>(
      0,
      (sum, value) => sum + math.max(0, value),
    );

    if (total <= 0) return;

    var startAngle = -math.pi / 2;
    const gap = 0.028;

    for (var index = 0; index < values.length; index++) {
      final value = math.max(0, values[index]);

      if (value <= 0) continue;

      final sweep = value / total * math.pi * 2;
      final visibleSweep = math.max(0.0, sweep - gap);

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

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(
    covariant _WarningDonutPainter oldDelegate,
  ) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.trackColor != trackColor;
  }
}
