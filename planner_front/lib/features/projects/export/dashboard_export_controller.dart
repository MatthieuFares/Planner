import 'dart:typed_data';

import '../../../core/export/planner_export_service.dart';
import '../data/project_insights_api.dart';
import 'dashboard_pdf_builder.dart';

class DashboardExportController {
  final ProjectInsightsApi _insightsApi;
  final PlannerExportService _exportService;
  final DashboardPdfBuilder _pdfBuilder;

  DashboardExportController({
    ProjectInsightsApi? insightsApi,
    PlannerExportService? exportService,
    DashboardPdfBuilder? pdfBuilder,
  })  : _insightsApi = insightsApi ?? ProjectInsightsApi(),
        _exportService =
            exportService ?? const PlannerExportService(),
        _pdfBuilder = pdfBuilder ?? const DashboardPdfBuilder();

  Future<String> saveDashboardPdf(
    int projectId, {
    String? fileName,
  }) async {
    final export = await _buildDashboardExport(
      projectId,
      customFileName: fileName,
    );

    await _exportService.savePdf(
      fileName: export.fileName,
      bytes: export.bytes,
    );

    return '${export.fileName}.pdf';
  }

  Future<void> printDashboardPdf(int projectId) async {
    final export = await _buildDashboardExport(projectId);

    await _exportService.printPdf(
      bytes: export.bytes,
    );
  }

  Future<void> shareDashboardPdf(
    int projectId, {
    String? fileName,
  }) async {
    final export = await _buildDashboardExport(
      projectId,
      customFileName: fileName,
    );

    await _exportService.sharePdf(
      fileName: export.fileName,
      bytes: export.bytes,
    );
  }

  Future<_DashboardExportData> _buildDashboardExport(
    int projectId, {
    String? customFileName,
  }) async {
    final results = await Future.wait<dynamic>([
      _insightsApi.getSummary(projectId),
      _insightsApi.getWarnings(projectId),
      _insightsApi.getResourceAnalysis(projectId),
    ]);

    final summary = Map<String, dynamic>.from(
      results[0] as Map,
    );

    final warnings = List<dynamic>.from(
      results[1] as List,
    );

    final resourceAnalysis = Map<String, dynamic>.from(
      results[2] as Map,
    );

    final bytes = await _pdfBuilder.build(
      summary: summary,
      warnings: warnings,
      resourceAnalysis: resourceAnalysis,
    );

    final requestedName = customFileName?.trim();

    final String fileName;

    if (requestedName != null && requestedName.isNotEmpty) {
      final withoutPdfExtension = requestedName.toLowerCase().endsWith('.pdf')
          ? requestedName.substring(
              0,
              requestedName.length - 4,
            )
          : requestedName;

      fileName = _exportService.sanitizeFileName(
        withoutPdfExtension,
      );
    } else {
      final projectName =
          summary['projectName']?.toString().trim() ?? '';

      final baseName = projectName.isEmpty
          ? 'Dashboard_Projet_$projectId'
          : 'Dashboard_$projectName';

      fileName = _exportService.buildTimestampedFileName(
        baseName: baseName,
      );
    }

    return _DashboardExportData(
      bytes: bytes,
      fileName: fileName,
    );
  }
}

class _DashboardExportData {
  final Uint8List bytes;
  final String fileName;

  const _DashboardExportData({
    required this.bytes,
    required this.fileName,
  });
}
