import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';

class ProjectInteropApi {
  final Dio _dio;

  ProjectInteropApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
              ),
            );

  Future<ProjectImportPreview> previewImport(
    ProjectImportFile file,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ProjectInterop/import/preview',
        data: FormData.fromMap(
          {
            'file': MultipartFile.fromBytes(
              file.bytes,
              filename: file.name,
            ),
          },
        ),
      );

      final data = response.data;

      if (data == null) {
        throw const ProjectInteropException(
          'Le serveur n’a retourné aucun aperçu.',
        );
      }

      return ProjectImportPreview.fromJson(data);
    } on DioException catch (error) {
      throw ProjectInteropException(
        _extractDioMessage(
          error,
          fallback:
              'Impossible d’analyser le fichier Microsoft Project.',
        ),
      );
    }
  }

  Future<ProjectImportResult> importProject(
    ProjectImportFile file,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ProjectInterop/import',
        data: FormData.fromMap(
          {
            'file': MultipartFile.fromBytes(
              file.bytes,
              filename: file.name,
            ),
          },
        ),
      );

      final data = response.data;

      if (data == null) {
        throw const ProjectInteropException(
          'Le serveur n’a retourné aucun résultat d’import.',
        );
      }

      return ProjectImportResult.fromJson(data);
    } on DioException catch (error) {
      throw ProjectInteropException(
        _extractDioMessage(
          error,
          fallback:
              'Impossible d’importer le projet Microsoft Project.',
        ),
      );
    }
  }

  Future<ProjectInteropExportFile> exportProjectXml(
    int projectId,
  ) async {
    try {
      final response = await _dio.get<List<int>>(
        '/ProjectInterop/project/$projectId/export',
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      final data = response.data;

      if (data == null || data.isEmpty) {
        throw const ProjectInteropException(
          'Le serveur n’a retourné aucun fichier XML.',
        );
      }

      final contentDisposition =
          response.headers.value('content-disposition');

      final fileName = _extractFileName(
        contentDisposition,
        fallback: 'Projet_${projectId}_project.xml',
      );

      return ProjectInteropExportFile(
        fileName: fileName,
        bytes: Uint8List.fromList(data),
      );
    } on DioException catch (error) {
      throw ProjectInteropException(
        _extractDioMessage(
          error,
          fallback:
              'Impossible d’exporter le projet au format Microsoft Project XML.',
        ),
      );
    }
  }

  String _extractFileName(
    String? contentDisposition, {
    required String fallback,
  }) {
    if (contentDisposition == null ||
        contentDisposition.trim().isEmpty) {
      return fallback;
    }

    final utf8Match = RegExp(
      r"filename\\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition);

    if (utf8Match != null) {
      final encoded = utf8Match.group(1);

      if (encoded != null && encoded.isNotEmpty) {
        try {
          return Uri.decodeComponent(encoded);
        } catch (_) {
          return encoded;
        }
      }
    }

    final quotedMatch = RegExp(
      r'filename="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(contentDisposition);

    if (quotedMatch != null) {
      final value = quotedMatch.group(1);

      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final plainMatch = RegExp(
      r'filename=([^;]+)',
      caseSensitive: false,
    ).firstMatch(contentDisposition);

    if (plainMatch != null) {
      final value = plainMatch.group(1);

      if (value != null && value.trim().isNotEmpty) {
        return value
            .trim()
            .replaceAll('"', '');
      }
    }

    return fallback;
  }

  String _extractDioMessage(
    DioException error, {
    required String fallback,
  }) {
    final data = error.response?.data;

    if (data is Map) {
      for (final key in const <String>[
        'message',
        'detail',
        'error',
        'title',
      ]) {
        final value = data[key];

        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Connexion à l’API impossible.';
    }

    return fallback;
  }
}

class ProjectInteropExportFile {
  final String fileName;
  final Uint8List bytes;

  const ProjectInteropExportFile({
    required this.fileName,
    required this.bytes,
  });
}

class ProjectImportFile {
  final String name;
  final Uint8List bytes;

  const ProjectImportFile({
    required this.name,
    required this.bytes,
  });
}

class ProjectImportPreview {
  final String projectName;
  final String? description;
  final String? clientName;
  final String? projectCode;
  final DateTime? startDate;
  final DateTime? endDate;
  final int structureItemCount;
  final int taskCount;
  final int dependencyCount;
  final int resourceCount;
  final int assignmentCount;
  final bool hasCalendar;
  final int calendarExceptionCount;
  final int calendarPeriodCount;
  final bool canImport;
  final int warningCount;
  final int errorCount;
  final List<ProjectImportWarning> warnings;

  const ProjectImportPreview({
    required this.projectName,
    required this.description,
    required this.clientName,
    required this.projectCode,
    required this.startDate,
    required this.endDate,
    required this.structureItemCount,
    required this.taskCount,
    required this.dependencyCount,
    required this.resourceCount,
    required this.assignmentCount,
    required this.hasCalendar,
    required this.calendarExceptionCount,
    required this.calendarPeriodCount,
    required this.canImport,
    required this.warningCount,
    required this.errorCount,
    required this.warnings,
  });

  factory ProjectImportPreview.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProjectImportPreview(
      projectName:
          json['projectName']?.toString() ?? 'Projet importé',
      description: json['description']?.toString(),
      clientName: json['clientName']?.toString(),
      projectCode: json['projectCode']?.toString(),
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
      structureItemCount:
          _parseInt(json['structureItemCount']),
      taskCount: _parseInt(json['taskCount']),
      dependencyCount:
          _parseInt(json['dependencyCount']),
      resourceCount: _parseInt(json['resourceCount']),
      assignmentCount:
          _parseInt(json['assignmentCount']),
      hasCalendar: json['hasCalendar'] == true,
      calendarExceptionCount:
          _parseInt(json['calendarExceptionCount']),
      calendarPeriodCount:
          _parseInt(json['calendarPeriodCount']),
      canImport: json['canImport'] == true,
      warningCount: _parseInt(json['warningCount']),
      errorCount: _parseInt(json['errorCount']),
      warnings: _parseWarnings(json['warnings']),
    );
  }
}

class ProjectImportResult {
  final int projectId;
  final String projectName;
  final int structureItemCount;
  final int taskCount;
  final int dependencyCount;
  final int resourceCount;
  final int createdResourceCount;
  final int reusedResourceCount;
  final int assignmentCount;
  final int calendarExceptionCount;
  final int calendarPeriodCount;
  final List<ProjectImportWarning> warnings;

  const ProjectImportResult({
    required this.projectId,
    required this.projectName,
    required this.structureItemCount,
    required this.taskCount,
    required this.dependencyCount,
    required this.resourceCount,
    required this.createdResourceCount,
    required this.reusedResourceCount,
    required this.assignmentCount,
    required this.calendarExceptionCount,
    required this.calendarPeriodCount,
    required this.warnings,
  });

  factory ProjectImportResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProjectImportResult(
      projectId: _parseInt(json['projectId']),
      projectName:
          json['projectName']?.toString() ?? 'Projet importé',
      structureItemCount:
          _parseInt(json['structureItemCount']),
      taskCount: _parseInt(json['taskCount']),
      dependencyCount:
          _parseInt(json['dependencyCount']),
      resourceCount: _parseInt(json['resourceCount']),
      createdResourceCount:
          _parseInt(json['createdResourceCount']),
      reusedResourceCount:
          _parseInt(json['reusedResourceCount']),
      assignmentCount:
          _parseInt(json['assignmentCount']),
      calendarExceptionCount:
          _parseInt(json['calendarExceptionCount']),
      calendarPeriodCount:
          _parseInt(json['calendarPeriodCount']),
      warnings: _parseWarnings(json['warnings']),
    );
  }
}

class ProjectImportWarning {
  final String code;
  final String message;
  final String severity;
  final String? entityType;
  final String? entityName;
  final int? externalUid;

  const ProjectImportWarning({
    required this.code,
    required this.message,
    required this.severity,
    required this.entityType,
    required this.entityName,
    required this.externalUid,
  });

  bool get isError =>
      severity.toLowerCase() == 'error';

  factory ProjectImportWarning.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProjectImportWarning(
      code: json['code']?.toString() ?? 'WARNING',
      message:
          json['message']?.toString() ?? 'Avertissement',
      severity:
          json['severity']?.toString() ?? 'Warning',
      entityType: json['entityType']?.toString(),
      entityName: json['entityName']?.toString(),
      externalUid: json['externalUid'] is num
          ? (json['externalUid'] as num).toInt()
          : null,
    );
  }
}

class ProjectInteropException implements Exception {
  final String message;

  const ProjectInteropException(this.message);

  @override
  String toString() => message;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;

  return DateTime.tryParse(value.toString());
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<ProjectImportWarning> _parseWarnings(dynamic value) {
  if (value is! List) {
    return const <ProjectImportWarning>[];
  }

  return value
      .whereType<Map>()
      .map(
        (item) => ProjectImportWarning.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
      .toList();
}
