import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:printing/printing.dart';

class PlannerExportService {
  const PlannerExportService();

  Future<void> savePdf({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeFileName = sanitizeFileName(fileName);

    await FileSaver.instance.saveFile(
      name: safeFileName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  Future<void> printPdf({
    required Uint8List bytes,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
    );
  }

  Future<void> sharePdf({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeFileName = sanitizeFileName(fileName);

    await Printing.sharePdf(
      bytes: bytes,
      filename: '$safeFileName.pdf',
    );
  }

  String buildTimestampedFileName({
    required String baseName,
    DateTime? dateTime,
  }) {
    final value = dateTime ?? DateTime.now();

    final date =
        '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';

    final time =
        '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}';

    return sanitizeFileName(
      '${baseName}_${date}_$time',
    );
  }

  String sanitizeFileName(String value) {
    var sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    while (sanitized.endsWith('.') ||
        sanitized.endsWith(' ')) {
      sanitized = sanitized.substring(
        0,
        sanitized.length - 1,
      );
    }

    if (sanitized.isEmpty) {
      return 'planner_export';
    }

    return sanitized;
  }
}
