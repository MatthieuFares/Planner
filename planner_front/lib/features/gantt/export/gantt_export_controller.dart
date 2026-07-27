import '../../project_baseline/data/project_baseline_model.dart';
import '../../project_calendar/data/project_calendar_exception_model.dart';
import '../../project_calendar/data/project_calendar_model.dart';
import '../../project_calendar/data/project_calendar_period_model.dart';
import '../data/structured_gantt_model.dart';
import 'gantt_pdf_builder.dart';

import '../../../core/export/planner_export_service.dart';

class GanttExportController {
  final PlannerExportService _exportService;
  final GanttPdfBuilder _pdfBuilder;

  GanttExportController({
    PlannerExportService? exportService,
    GanttPdfBuilder? pdfBuilder,
  })  : _exportService =
            exportService ?? const PlannerExportService(),
        _pdfBuilder = pdfBuilder ?? const GanttPdfBuilder();

  Future<String> saveGanttPdf({
    required StructuredGanttResponse data,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
    ProjectBaselineComparisonModel? baselineComparison,
    bool showBaseline = true,
    String? fileName,
  }) async {
    final bytes = await _pdfBuilder.build(
      data: data,
      calendar: calendar,
      exceptions: exceptions,
      periods: periods,
      baselineComparison: baselineComparison,
      showBaseline: showBaseline,
    );

    final resolvedFileName = _resolveFileName(
      data: data,
      customFileName: fileName,
    );

    await _exportService.savePdf(
      fileName: resolvedFileName,
      bytes: bytes,
    );

    return '$resolvedFileName.pdf';
  }

  Future<void> printGanttPdf({
    required StructuredGanttResponse data,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
    ProjectBaselineComparisonModel? baselineComparison,
    bool showBaseline = true,
  }) async {
    final bytes = await _pdfBuilder.build(
      data: data,
      calendar: calendar,
      exceptions: exceptions,
      periods: periods,
      baselineComparison: baselineComparison,
      showBaseline: showBaseline,
    );

    await _exportService.printPdf(
      bytes: bytes,
    );
  }

  Future<void> shareGanttPdf({
    required StructuredGanttResponse data,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
    ProjectBaselineComparisonModel? baselineComparison,
    bool showBaseline = true,
    String? fileName,
  }) async {
    final bytes = await _pdfBuilder.build(
      data: data,
      calendar: calendar,
      exceptions: exceptions,
      periods: periods,
      baselineComparison: baselineComparison,
      showBaseline: showBaseline,
    );

    final resolvedFileName = _resolveFileName(
      data: data,
      customFileName: fileName,
    );

    await _exportService.sharePdf(
      fileName: resolvedFileName,
      bytes: bytes,
    );
  }

  String _resolveFileName({
    required StructuredGanttResponse data,
    required String? customFileName,
  }) {
    final requestedName = customFileName?.trim();

    if (requestedName != null && requestedName.isNotEmpty) {
      final withoutPdfExtension =
          requestedName.toLowerCase().endsWith('.pdf')
              ? requestedName.substring(
                  0,
                  requestedName.length - 4,
                )
              : requestedName;

      return _exportService.sanitizeFileName(
        withoutPdfExtension,
      );
    }

    final projectName = data.projectName.trim();

    final baseName = projectName.isEmpty
        ? 'Gantt_Projet_${data.projectId}'
        : 'Gantt_$projectName';

    return _exportService.buildTimestampedFileName(
      baseName: baseName,
    );
  }
}
