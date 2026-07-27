import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DashboardPdfBuilder {
  const DashboardPdfBuilder();

  static const int _warningsPerPage = 5;
  static const int _resourcesPerPage = 8;

  Future<Uint8List> build({
    required Map<String, dynamic> summary,
    required List<dynamic> warnings,
    required Map<String, dynamic> resourceAnalysis,
    DateTime? generatedAt,
  }) async {
    final summaryData = _SummaryData.fromMap(summary);
    final warningData =
        warnings.map(_WarningData.fromDynamic).toList();
    final resourcesData =
        _ResourceAnalysisData.fromMap(resourceAnalysis);
    final generated = generatedAt ?? DateTime.now();

    final document = pw.Document();

    document.addPage(
      _page(
        projectName: summaryData.projectName,
        projectId: summaryData.projectId,
        generatedAt: generated,
        title: 'Tableau de bord projet',
        subtitle: summaryData.projectName.isEmpty
            ? 'Projet #${summaryData.projectId}'
            : summaryData.projectName,
        children: [
          _buildProjectPeriod(summaryData),
          pw.SizedBox(height: 14),
          _sectionTitle('Résumé projet'),
          pw.SizedBox(height: 8),
          _buildSummaryMetrics(summaryData),
          pw.SizedBox(height: 14),
          _sectionTitle('Avancement et criticité'),
          pw.SizedBox(height: 8),
          _buildProgress(summaryData),
        ],
      ),
    );

    if (warningData.isEmpty) {
      document.addPage(
        _page(
          projectName: summaryData.projectName,
          projectId: summaryData.projectId,
          generatedAt: generated,
          title: 'Alertes projet',
          subtitle: 'État des anomalies détectées',
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                border: pw.Border.all(
                  color: PdfColors.green300,
                ),
              ),
              child: pw.Text(
                'Aucune anomalie détectée.',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      final warningChunks =
          _chunkList(warningData, _warningsPerPage);

      for (var pageIndex = 0;
          pageIndex < warningChunks.length;
          pageIndex++) {
        final chunk = warningChunks[pageIndex];

        document.addPage(
          _page(
            projectName: summaryData.projectName,
            projectId: summaryData.projectId,
            generatedAt: generated,
            title: 'Alertes projet',
            subtitle:
                'Page ${pageIndex + 1} sur ${warningChunks.length}',
            children: [
              if (pageIndex == 0) ...[
                _buildWarningCounters(warningData),
                pw.SizedBox(height: 12),
              ],
              ...chunk.map(
                (warning) => pw.Padding(
                  padding:
                      const pw.EdgeInsets.only(bottom: 8),
                  child: _warningTile(warning),
                ),
              ),
            ],
          ),
        );
      }
    }

    if (resourcesData.resources.isEmpty) {
      document.addPage(
        _page(
          projectName: summaryData.projectName,
          projectId: summaryData.projectId,
          generatedAt: generated,
          title: 'Analyse ressources',
          subtitle: 'Charge, capacité et coûts',
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(
                  color: PdfColors.grey300,
                ),
              ),
              child: pw.Text(
                'Aucune donnée ressource disponible pour ce projet.',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      final resourceChunks =
          _chunkList(resourcesData.resources, _resourcesPerPage);

      for (var pageIndex = 0;
          pageIndex < resourceChunks.length;
          pageIndex++) {
        final chunk = resourceChunks[pageIndex];

        document.addPage(
          _page(
            projectName: summaryData.projectName,
            projectId: summaryData.projectId,
            generatedAt: generated,
            title: 'Analyse ressources',
            subtitle:
                'Page ${pageIndex + 1} sur ${resourceChunks.length}',
            children: [
              if (pageIndex == 0) ...[
                _buildResourceMetrics(resourcesData),
                pw.SizedBox(height: 14),
              ],
              _buildResourceTable(chunk),
            ],
          ),
        );
      }
    }

    return document.save();
  }

  pw.Page _page({
    required String projectName,
    required int projectId,
    required DateTime generatedAt,
    required String title,
    required String subtitle,
    required List<pw.Widget> children,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(
              projectName: projectName,
              projectId: projectId,
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 16),
            ...children,
            pw.Spacer(),
            _footer(
              context: context,
              generatedAt: generatedAt,
            ),
          ],
        );
      },
    );
  }

  pw.Widget _header({
    required String projectName,
    required int projectId,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.grey400,
            width: 0.7,
          ),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              projectName.isEmpty
                  ? 'Planner - Projet #$projectId'
                  : 'Planner - $projectName',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
          ),
          pw.Text(
            'Dashboard',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer({
    required pw.Context context,
    required DateTime generatedAt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.grey400,
            width: 0.7,
          ),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'Généré le ${_formatDateTime(generatedAt)}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildProjectPeriod(_SummaryData data) {
    return pw.Text(
      'Période : ${_formatDate(data.projectStart)} '
      '→ ${_formatDate(data.projectEnd)}',
      style: const pw.TextStyle(
        fontSize: 10,
        color: PdfColors.grey700,
      ),
    );
  }

  pw.Widget _sectionTitle(String value) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      color: PdfColors.blueGrey50,
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey900,
        ),
      ),
    );
  }

  pw.Widget _buildSummaryMetrics(_SummaryData data) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metric(
          'Progression globale',
          '${_formatNumber(data.globalProgressPercent)} %',
          emphasized: true,
        ),
        _metric('Tâches', '${data.taskCount}'),
        _metric(
          'Durée projet',
          '${data.projectDurationDays} j',
        ),
        _metric(
          'Charge totale',
          '${_formatNumber(data.totalWorkloadHours)} h',
        ),
        _metric(
          'Coût estimé',
          '${_formatNumber(data.estimatedCost)} EUR',
        ),
        _metric(
          'Ressources',
          '${data.resourceCount}',
          warning: data.overloadedResourceCount > 0,
        ),
        _metric(
          'Terminées',
          '${data.completedTaskCount}',
        ),
        _metric(
          'Restantes',
          '${data.remainingTaskCount}',
        ),
        _metric(
          'Critiques',
          '${data.criticalTaskCount}',
        ),
        _metric(
          'Dépendances',
          '${data.dependencyCount}',
        ),
        _metric(
          'Groupes',
          '${data.resourceGroupCount}',
        ),
        _metric(
          'Ressources surchargées',
          '${data.overloadedResourceCount}',
          warning: data.overloadedResourceCount > 0,
        ),
      ],
    );
  }

  pw.Widget _metric(
    String label,
    String value, {
    bool emphasized = false,
    bool warning = false,
  }) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: warning
            ? PdfColors.red50
            : emphasized
                ? PdfColors.blue50
                : PdfColors.grey100,
        border: pw.Border.all(
          color: warning
              ? PdfColors.red300
              : emphasized
                  ? PdfColors.blue300
                  : PdfColors.grey300,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: warning
                  ? PdfColors.red800
                  : PdfColors.blueGrey900,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildProgress(_SummaryData data) {
    final completedPercent = data.taskCount <= 0
        ? 0.0
        : data.completedTaskCount / data.taskCount * 100;

    final criticalPercent = data.taskCount <= 0
        ? 0.0
        : data.criticalTaskCount / data.taskCount * 100;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _progressRow(
          'Progression globale',
          data.globalProgressPercent,
          PdfColors.blue700,
        ),
        pw.SizedBox(height: 9),
        _progressRow(
          'Tâches terminées',
          completedPercent,
          PdfColors.green700,
        ),
        pw.SizedBox(height: 9),
        _progressRow(
          'Tâches critiques',
          criticalPercent,
          PdfColors.orange700,
        ),
      ],
    );
  }

  pw.Widget _progressRow(
    String label,
    double percent,
    PdfColor color,
  ) {
    final value = percent.clamp(0, 100).toDouble();

    return pw.Row(
      children: [
        pw.SizedBox(
          width: 135,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Row(
            children: List.generate(
              20,
              (index) {
                final threshold = (index + 1) * 5;

                return pw.Expanded(
                  child: pw.Container(
                    height: 10,
                    margin: const pw.EdgeInsets.only(right: 1),
                    color: value >= threshold
                        ? color
                        : PdfColors.grey200,
                  ),
                );
              },
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.SizedBox(
          width: 55,
          child: pw.Text(
            '${_formatNumber(value)} %',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildWarningCounters(
    List<_WarningData> warnings,
  ) {
    final critical = warnings
        .where(
          (warning) =>
              warning.severity == _WarningSeverity.critical,
        )
        .length;

    final attention = warnings
        .where(
          (warning) =>
              warning.severity == _WarningSeverity.warning,
        )
        .length;

    final info = warnings
        .where(
          (warning) =>
              warning.severity == _WarningSeverity.info,
        )
        .length;

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _warningCounter(
          'Critiques',
          critical,
          PdfColors.red700,
        ),
        _warningCounter(
          'À surveiller',
          attention,
          PdfColors.orange700,
        ),
        _warningCounter(
          'Informations',
          info,
          PdfColors.blue700,
        ),
      ],
    );
  }

  pw.Widget _warningCounter(
    String label,
    int value,
    PdfColor color,
  ) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: color),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Text(
            '$value',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _warningTile(_WarningData warning) {
    final color = switch (warning.severity) {
      _WarningSeverity.critical => PdfColors.red700,
      _WarningSeverity.warning => PdfColors.orange700,
      _WarningSeverity.info => PdfColors.blue700,
    };

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(
          color: PdfColors.grey300,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 4,
            height: 48,
            color: color,
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        warning.title,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Text(
                      _severityLabel(warning.severity),
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  _limitText(warning.message, 500),
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  warning.contextLabel == null
                      ? _categoryLabel(warning.category)
                      : '${_categoryLabel(warning.category)} · '
                          '${warning.contextLabel}',
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildResourceMetrics(
    _ResourceAnalysisData data,
  ) {
    final overloaded = data.resources
        .where((resource) => resource.isOverloaded)
        .length;

    final averageUtilization = data.resources.isEmpty
        ? 0.0
        : data.resources
                .map((resource) => resource.utilizationPercent)
                .fold<double>(0, (sum, value) => sum + value) /
            data.resources.length;

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metric(
          'Charge totale',
          '${_formatNumber(data.totalWorkloadHours)} h',
        ),
        _metric(
          'Coût estimé',
          '${_formatNumber(data.estimatedCost)} EUR',
        ),
        _metric(
          'Utilisation moyenne',
          '${_formatNumber(averageUtilization)} %',
          warning: averageUtilization > 100,
        ),
        _metric(
          'Surchargées',
          '$overloaded',
          warning: overloaded > 0,
        ),
      ],
    );
  }

  pw.Widget _buildResourceTable(
    List<_ResourceEntry> resources,
  ) {
    return pw.TableHelper.fromTextArray(
      data: <List<dynamic>>[
        <dynamic>[
          'Ressource',
          'Type',
          'Charge',
          'Capacité/sem.',
          'Utilisation',
          'Coût/h',
          'Coût estimé',
          'État',
        ],
        ...resources.map(
          (resource) => <dynamic>[
            resource.resourceName,
            _resourceTypeLabel(resource.resourceType),
            '${_formatNumber(resource.assignedHours)} h',
            '${_formatNumber(resource.capacityHoursPerWeek)} h',
            '${_formatNumber(resource.utilizationPercent)} %',
            '${_formatNumber(resource.costPerHour)} EUR',
            '${_formatNumber(resource.estimatedCost)} EUR',
            resource.isOverloaded
                ? 'Surchargée'
                : 'Disponible',
          ],
        ),
      ],
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.blueGrey700,
      ),
      cellStyle: const pw.TextStyle(
        fontSize: 7.2,
      ),
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 5,
      ),
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.5,
      ),
      oddRowDecoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
      ),
    );
  }
}

class _SummaryData {
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

  const _SummaryData({
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

  factory _SummaryData.fromMap(
    Map<String, dynamic> json,
  ) {
    return _SummaryData(
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

class _ResourceAnalysisData {
  final int projectId;
  final double totalWorkloadHours;
  final double estimatedCost;
  final List<_ResourceEntry> resources;

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
                (item) => _ResourceEntry.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const <_ResourceEntry>[],
    );
  }
}

class _ResourceEntry {
  final int resourceId;
  final String resourceName;
  final String resourceType;
  final double assignedHours;
  final double capacityHoursPerWeek;
  final double costPerHour;
  final double estimatedCost;
  final double utilizationPercent;
  final bool isOverloaded;

  const _ResourceEntry({
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

  factory _ResourceEntry.fromMap(
    Map<String, dynamic> json,
  ) {
    return _ResourceEntry(
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

class _WarningData {
  final String title;
  final String message;
  final String? contextLabel;
  final _WarningSeverity severity;
  final _WarningCategory category;

  const _WarningData({
    required this.title,
    required this.message,
    required this.contextLabel,
    required this.severity,
    required this.category,
  });

  factory _WarningData.fromDynamic(dynamic raw) {
    if (raw is String) {
      final category = _deriveCategory(raw);

      return _WarningData(
        title: _defaultTitle(category),
        message: raw,
        contextLabel: null,
        severity: _deriveSeverity(
          explicitValue: null,
          searchableText: raw,
          category: category,
        ),
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

      return _WarningData(
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

    return _WarningData(
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
    if (text.isNotEmpty) return text;
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

List<List<T>> _chunkList<T>(
  List<T> values,
  int chunkSize,
) {
  final result = <List<T>>[];

  for (var index = 0;
      index < values.length;
      index += chunkSize) {
    result.add(
      values.sublist(
        index,
        math.min(index + chunkSize, values.length),
      ),
    );
  }

  return result;
}

String _limitText(String value, int maxLength) {
  if (value.length <= maxLength) return value;

  return '${value.substring(0, maxLength - 1)}…';
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
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}

String _formatDate(DateTime? date) {
  if (date == null) return '-';

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatDateTime(DateTime value) {
  return '${_formatDate(value)} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

String _formatNumber(num value) {
  final doubleValue = value.toDouble();

  if (doubleValue == doubleValue.roundToDouble()) {
    return doubleValue.toInt().toString();
  }

  return doubleValue.toStringAsFixed(1);
}
