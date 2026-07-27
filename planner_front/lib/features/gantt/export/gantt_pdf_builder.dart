import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../project_baseline/data/project_baseline_model.dart';
import '../../project_calendar/data/project_calendar_exception_model.dart';
import '../../project_calendar/data/project_calendar_model.dart';
import '../../project_calendar/data/project_calendar_period_model.dart';
import '../data/structured_gantt_model.dart';

class GanttPdfBuilder {
  const GanttPdfBuilder();

  static const int _daysPerPage = 28;
  static const int _rowsPerPage = 24;

  static const double _wbsWidth = 46;
  static const double _nameWidth = 160;
  static const double _dateWidth = 56;
  static const double _durationWidth = 38;
  static const double _progressWidth = 42;
  static const double _deadlineWidth = 56;

  Future<Uint8List> build({
    required StructuredGanttResponse data,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
    ProjectBaselineComparisonModel? baselineComparison,
    bool showBaseline = true,
    DateTime? generatedAt,
  }) async {
    final generated = generatedAt ?? DateTime.now();
    final range = _resolveRange(
      data: data,
      baselineComparison: baselineComparison,
    );

    final dateWindows = _buildDateWindows(
      start: range.start,
      end: range.end,
    );

    final rowChunks = data.items.isEmpty
        ? <List<StructuredGanttItem>>[<StructuredGanttItem>[]]
        : _chunkList(data.items, _rowsPerPage);

    final baselineByTaskId =
        <int, ProjectBaselineComparisonRowModel>{};

    if (showBaseline && baselineComparison != null) {
      for (final row in baselineComparison.rows) {
        baselineByTaskId[row.taskId] = row;
      }
    }

    final document = pw.Document();
    final totalPages = dateWindows.length * rowChunks.length;

    for (final dateWindow in dateWindows) {
      for (var chunkIndex = 0;
          chunkIndex < rowChunks.length;
          chunkIndex++) {
        final rows = rowChunks[chunkIndex];

        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a3.landscape,
            margin: const pw.EdgeInsets.all(22),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(
                    data: data,
                    dateWindow: dateWindow,
                    baselineComparison:
                        showBaseline ? baselineComparison : null,
                    pageNumber: context.pageNumber,
                    totalPages: totalPages,
                    rowStart: data.items.isEmpty
                        ? 0
                        : chunkIndex * _rowsPerPage + 1,
                    rowEnd: data.items.isEmpty
                        ? 0
                        : math.min(
                            (chunkIndex + 1) * _rowsPerPage,
                            data.items.length,
                          ),
                    totalRows: data.items.length,
                  ),
                  pw.SizedBox(height: 8),
                  _buildLegend(
                    showBaseline && baselineComparison != null,
                  ),
                  pw.SizedBox(height: 8),
                  _buildTableHeader(
                    dateWindow: dateWindow,
                    calendar: calendar,
                    exceptions: exceptions,
                    periods: periods,
                  ),
                  ...rows.map(
                    (item) => _buildItemRow(
                      item: item,
                      dateWindow: dateWindow,
                      calendar: calendar,
                      exceptions: exceptions,
                      periods: periods,
                      baselineRow: item.task == null
                          ? null
                          : baselineByTaskId[item.task!.id],
                    ),
                  ),
                  if (rows.isEmpty)
                    pw.Container(
                      height: 70,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.grey300,
                        ),
                      ),
                      child: pw.Text(
                        'Aucun élément Gantt à exporter.',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  pw.Spacer(),
                  _buildFooter(
                    context: context,
                    generatedAt: generated,
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    return document.save();
  }

  ({DateTime start, DateTime end}) _resolveRange({
    required StructuredGanttResponse data,
    required ProjectBaselineComparisonModel? baselineComparison,
  }) {
    final dates = <DateTime>[];

    for (final item in data.items) {
      final task = item.task;
      if (task == null) continue;
      dates.add(_dateOnly(task.startDate));
      dates.add(_dateOnly(task.endDate));
    }

    if (baselineComparison != null) {
      for (final row in baselineComparison.rows) {
        if (row.baselineStartDate != null) {
          dates.add(_dateOnly(row.baselineStartDate!));
        }
        if (row.baselineEndDate != null) {
          dates.add(_dateOnly(row.baselineEndDate!));
        }
      }
    }

    if (dates.isNotEmpty) {
      final start = dates.reduce((a, b) => a.isBefore(b) ? a : b);
      final end = dates.reduce((a, b) => a.isAfter(b) ? a : b);
      return (start: start, end: end);
    }

    final start = data.projectStartDate != null
        ? _dateOnly(data.projectStartDate!)
        : _dateOnly(DateTime.now());
    final end = data.projectEndDate != null
        ? _dateOnly(data.projectEndDate!)
        : start.add(const Duration(days: 27));

    return (
      start: start,
      end: end.isBefore(start) ? start : end,
    );
  }

  List<_DateWindow> _buildDateWindows({
    required DateTime start,
    required DateTime end,
  }) {
    final result = <_DateWindow>[];
    var cursor = _dateOnly(start);
    final cleanEnd = _dateOnly(end);

    while (!cursor.isAfter(cleanEnd)) {
      final candidateEnd =
          cursor.add(const Duration(days: _daysPerPage - 1));
      final windowEnd = candidateEnd.isAfter(cleanEnd)
          ? cleanEnd
          : candidateEnd;

      result.add(_DateWindow(start: cursor, end: windowEnd));
      cursor = windowEnd.add(const Duration(days: 1));
    }

    return result.isEmpty
        ? <_DateWindow>[_DateWindow(start: start, end: start)]
        : result;
  }

  pw.Widget _buildHeader({
    required StructuredGanttResponse data,
    required _DateWindow dateWindow,
    required ProjectBaselineComparisonModel? baselineComparison,
    required int pageNumber,
    required int totalPages,
    required int rowStart,
    required int rowEnd,
    required int totalRows,
  }) {
    final meta = <String>[
      if (data.projectCode.trim().isNotEmpty)
        'Code : ${data.projectCode.trim()}',
      if (data.clientName.trim().isNotEmpty)
        'Client : ${data.clientName.trim()}',
      if (totalRows > 0) 'Lignes : $rowStart-$rowEnd / $totalRows',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Gantt - ${data.projectName}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    '${_formatDate(dateWindow.start)} - '
                    '${_formatDate(dateWindow.end)}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      meta.join(' · '),
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Page $pageNumber / $totalPages',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey700,
                  ),
                ),
                if (baselineComparison != null) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Baseline : ${baselineComparison.baselineName}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 0.8, color: PdfColors.grey400),
      ],
    );
  }

  pw.Widget _buildLegend(bool hasBaseline) {
    return pw.Wrap(
      spacing: 14,
      runSpacing: 5,
      children: [
        _legend(PdfColors.blue700, 'En cours'),
        _legend(PdfColors.orange700, 'Critique'),
        _legend(PdfColors.red700, 'En retard'),
        _legend(PdfColors.green700, 'Terminée'),
        _legend(PdfColors.grey300, 'Jour non ouvré'),
        if (hasBaseline) _legend(PdfColors.grey700, 'Baseline'),
      ],
    );
  }

  pw.Widget _legend(PdfColor color, String label) {
    return pw.Row(
      children: [
        pw.Container(width: 14, height: 7, color: color),
        pw.SizedBox(width: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableHeader({
    required _DateWindow dateWindow,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
  }) {
    final dates = _datesInWindow(dateWindow);

    return pw.Container(
      height: 40,
      color: PdfColors.blueGrey700,
      child: pw.Row(
        children: [
          _headerCell(_wbsWidth, 'WBS'),
          _headerCell(_nameWidth, 'Élément'),
          _headerCell(_dateWidth, 'Début'),
          _headerCell(_dateWidth, 'Fin'),
          _headerCell(_durationWidth, 'Durée'),
          _headerCell(_progressWidth, 'Avanc.'),
          _headerCell(_deadlineWidth, 'Deadline'),
          ...dates.map(
            (date) => pw.Expanded(
              child: _dateHeaderCell(
                date: date,
                calendar: calendar,
                exceptions: exceptions,
                periods: periods,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _headerCell(double width, String label) {
    return pw.Container(
      width: width,
      height: double.infinity,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(
            color: PdfColors.grey500,
            width: 0.5,
          ),
        ),
      ),
      child: pw.Text(
        label,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7.2,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _dateHeaderCell({
    required DateTime date,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
  }) {
    final working = _isWorkingDay(
      date: date,
      calendar: calendar,
      exceptions: exceptions,
      periods: periods,
    );
    final period = _periodForDate(date: date, periods: periods);
    final exception = _exceptionForDate(
      date: date,
      exceptions: exceptions,
    );

    final background = period != null && exception == null
        ? PdfColors.red700
        : working
            ? PdfColors.blueGrey700
            : PdfColors.grey500;

    return pw.Container(
      height: double.infinity,
      alignment: pw.Alignment.center,
      color: background,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            '${date.day}',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            _weekdayLabel(date),
            style: const pw.TextStyle(
              fontSize: 5.8,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemRow({
    required StructuredGanttItem item,
    required _DateWindow dateWindow,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
    required ProjectBaselineComparisonRowModel? baselineRow,
  }) {
    final task = item.task;
    final structural = task == null;
    final background = item.type == 'Section'
        ? PdfColors.grey300
        : structural
            ? PdfColors.grey100
            : PdfColors.white;
    final textColor = task == null
        ? PdfColors.blueGrey900
        : task.isLate
            ? PdfColors.red800
            : task.isCritical
                ? PdfColors.orange800
                : PdfColors.blueGrey900;

    return pw.Container(
      height: 23,
      color: background,
      child: pw.Row(
        children: [
          _bodyCell(
            width: _wbsWidth,
            text: item.wbsCode,
            bold: structural,
            color: textColor,
          ),
          _nameCell(item: item, color: textColor),
          _bodyCell(
            width: _dateWidth,
            text: task == null ? '' : _formatShortDate(task.startDate),
            color: textColor,
          ),
          _bodyCell(
            width: _dateWidth,
            text: task == null ? '' : _formatShortDate(task.endDate),
            color: textColor,
          ),
          _bodyCell(
            width: _durationWidth,
            text: task == null ? '' : '${task.duration}j',
            center: true,
          ),
          _bodyCell(
            width: _progressWidth,
            text: task == null ? '' : '${task.progressPercent}%',
            center: true,
            bold: task?.isDone == true,
            color: task?.isDone == true
                ? PdfColors.green800
                : textColor,
          ),
          _bodyCell(
            width: _deadlineWidth,
            text: task?.deadline == null
                ? ''
                : _formatShortDate(task!.deadline!),
            bold: task?.isLate == true,
            color: task?.isLate == true
                ? PdfColors.red800
                : textColor,
          ),
          ..._datesInWindow(dateWindow).map(
            (date) => pw.Expanded(
              child: _timelineCell(
                item: item,
                date: date,
                calendar: calendar,
                exceptions: exceptions,
                periods: periods,
                baselineRow: baselineRow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _bodyCell({
    required double width,
    required String text,
    bool center = false,
    bool bold = false,
    PdfColor color = PdfColors.blueGrey900,
  }) {
    return pw.Container(
      width: width,
      height: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3),
      alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(
            color: PdfColors.grey300,
            width: 0.45,
          ),
          bottom: pw.BorderSide(
            color: PdfColors.grey300,
            width: 0.45,
          ),
        ),
      ),
      child: pw.Text(
        text,
        maxLines: 1,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 6.7,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  pw.Widget _nameCell({
    required StructuredGanttItem item,
    required PdfColor color,
  }) {
    final structural = item.task == null;
    final indent = math.min(item.level * 7.0, 42.0);

    return pw.Container(
      width: _nameWidth,
      height: double.infinity,
      padding: pw.EdgeInsets.only(left: 4 + indent, right: 3),
      alignment: pw.Alignment.centerLeft,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(
            color: PdfColors.grey300,
            width: 0.45,
          ),
          bottom: pw.BorderSide(
            color: PdfColors.grey300,
            width: 0.45,
          ),
        ),
      ),
      child: pw.Text(
        item.name,
        maxLines: 1,
        style: pw.TextStyle(
          fontSize: 6.9,
          fontWeight:
              structural ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  pw.Widget _timelineCell({
    required StructuredGanttItem item,
    required DateTime date,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
    required ProjectBaselineComparisonRowModel? baselineRow,
  }) {
    final task = item.task;
    final working = _isWorkingDay(
      date: date,
      calendar: calendar,
      exceptions: exceptions,
      periods: periods,
    );
    final period = _periodForDate(date: date, periods: periods);
    final exception = _exceptionForDate(
      date: date,
      exceptions: exceptions,
    );

    final background = period != null && exception == null
        ? PdfColors.red50
        : working
            ? PdfColors.white
            : PdfColors.grey200;

    final currentDay = task != null &&
        _dateIsInside(
          date: date,
          start: task.startDate,
          end: task.endDate,
        );

    final baselineDay = baselineRow?.baselineStartDate != null &&
        baselineRow?.baselineEndDate != null &&
        _dateIsInside(
          date: date,
          start: baselineRow!.baselineStartDate!,
          end: baselineRow.baselineEndDate!,
        );

    final taskColor = task == null
        ? PdfColors.blue700
        : task.isDone
            ? PdfColors.green700
            : task.isLate
                ? PdfColors.red700
                : task.isCritical
                    ? PdfColors.orange700
                    : PdfColors.blue700;

    return pw.Container(
      height: double.infinity,
      color: background,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          currentDay
              ? pw.Container(height: 9, color: taskColor)
              : pw.SizedBox(height: 9),
          pw.SizedBox(height: 2),
          baselineDay
              ? pw.Container(height: 3, color: PdfColors.grey700)
              : pw.SizedBox(height: 3),
        ],
      ),
    );
  }

  pw.Widget _buildFooter({
    required pw.Context context,
    required DateTime generatedAt,
  }) {
    return pw.Column(
      children: [
        pw.Container(height: 0.6, color: PdfColors.grey400),
        pw.SizedBox(height: 5),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'Généré le ${_formatDateTime(generatedAt)}',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey600,
                ),
              ),
            ),
            pw.Text(
              'Page PDF ${context.pageNumber}',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<DateTime> _datesInWindow(_DateWindow window) {
    final count = window.end.difference(window.start).inDays + 1;
    return List<DateTime>.generate(
      count,
      (index) => window.start.add(Duration(days: index)),
    );
  }

  bool _dateIsInside({
    required DateTime date,
    required DateTime start,
    required DateTime end,
  }) {
    final value = _dateOnly(date);
    final cleanStart = _dateOnly(start);
    final cleanEnd = _dateOnly(end);
    return !value.isBefore(cleanStart) && !value.isAfter(cleanEnd);
  }

  bool _isWorkingDay({
    required DateTime date,
    required ProjectCalendarModel calendar,
    required List<ProjectCalendarExceptionModel> exceptions,
    required List<ProjectCalendarPeriodModel> periods,
  }) {
    final exception = _exceptionForDate(
      date: date,
      exceptions: exceptions,
    );
    if (exception != null) return exception.isWorkingDay;

    if (_periodForDate(date: date, periods: periods) != null) {
      return false;
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

  ProjectCalendarExceptionModel? _exceptionForDate({
    required DateTime date,
    required List<ProjectCalendarExceptionModel> exceptions,
  }) {
    for (final exception in exceptions) {
      if (_sameDay(exception.date, date)) return exception;
    }
    return null;
  }

  ProjectCalendarPeriodModel? _periodForDate({
    required DateTime date,
    required List<ProjectCalendarPeriodModel> periods,
  }) {
    final cleanDate = _dateOnly(date);
    for (final period in periods) {
      final start = _dateOnly(period.startDate);
      final end = _dateOnly(period.endDate);
      if (!cleanDate.isBefore(start) && !cleanDate.isAfter(end)) {
        return period;
      }
    }
    return null;
  }
}

class _DateWindow {
  final DateTime start;
  final DateTime end;

  const _DateWindow({
    required this.start,
    required this.end,
  });
}

List<List<T>> _chunkList<T>(List<T> values, int chunkSize) {
  final result = <List<T>>[];
  for (var index = 0; index < values.length; index += chunkSize) {
    result.add(
      values.sublist(
        index,
        math.min(index + chunkSize, values.length),
      ),
    );
  }
  return result;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool _sameDay(DateTime a, DateTime b) {
  return _dateOnly(a) == _dateOnly(b);
}

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

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}

String _formatShortDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year.toString().substring(2)}';
}

String _formatDateTime(DateTime value) {
  return '${_formatDate(value)} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
