// core/services/document_health_check_service.dart
import 'dart:io';

import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/models/file_status.dart';

/// Health check results
class DocumentHealthCheckResult {
  final int totalDocuments;
  final int validDocuments;
  final int missingDocuments;
  final int corruptedDocuments;
  final List<String> problematicDocumentIds;

  DocumentHealthCheckResult({
    required this.totalDocuments,
    required this.validDocuments,
    required this.missingDocuments,
    required this.corruptedDocuments,
    required this.problematicDocumentIds,
  });

  bool get hasIssues => problematicDocumentIds.isNotEmpty;
  double get healthPercentage => totalDocuments > 0
      ? (validDocuments / totalDocuments) * 100
      : 100.0;
}

/// Service for checking document file health (runs on startup)
class DocumentHealthCheckService {
  static final DocumentHealthCheckService instance =
      DocumentHealthCheckService._();
  DocumentHealthCheckService._();

  bool _isRunning = false;
  DocumentHealthCheckResult? _lastResult;

  /// Runs health check on all documents (background, non-blocking)
  Future<DocumentHealthCheckResult> runHealthCheck({
    bool force = false,
  }) async {
    if (_isRunning && !force) {
      return _lastResult ?? DocumentHealthCheckResult(
        totalDocuments: 0,
        validDocuments: 0,
        missingDocuments: 0,
        corruptedDocuments: 0,
        problematicDocumentIds: [],
      );
    }

    _isRunning = true;

    try {
      AppLogger.info('Starting document health check...');

      // Get all documents (async, in isolate)
      final documents = await DocumentRepository.instance.getAllDocuments(
        includeDeleted: false,
      );

      int validCount = 0;
      int missingCount = 0;
      int corruptedCount = 0;
      final problematicIds = <String>[];

      // Check each document
      for (final doc in documents) {
        final fileStatus = doc.fileStatus;

        switch (fileStatus) {
          case FileStatus.valid:
            validCount++;
            break;
          case FileStatus.missing:
            missingCount++;
            problematicIds.add(doc.id);
            break;
          case FileStatus.corrupted:
            corruptedCount++;
            problematicIds.add(doc.id);
            break;
        }
      }

      final result = DocumentHealthCheckResult(
        totalDocuments: documents.length,
        validDocuments: validCount,
        missingDocuments: missingCount,
        corruptedDocuments: corruptedCount,
        problematicDocumentIds: problematicIds,
      );

      _lastResult = result;

      AppLogger.info(
        'Document health check completed',
        data: {
          'total': result.totalDocuments,
          'valid': result.validDocuments,
          'missing': result.missingDocuments,
          'corrupted': result.corruptedDocuments,
          'healthPercentage': result.healthPercentage.toStringAsFixed(1),
        },
      );

      if (result.hasIssues) {
        AppLogger.warning(
          'Found ${result.problematicDocumentIds.length} problematic documents',
          error: null,
          data: {
            'problematicIds': result.problematicDocumentIds,
          },
        );
      }

      return result;
    } catch (e, stack) {
      AppLogger.error(
        'Error during document health check',
        error: e,
        stack: stack,
      );
      return DocumentHealthCheckResult(
        totalDocuments: 0,
        validDocuments: 0,
        missingDocuments: 0,
        corruptedDocuments: 0,
        problematicDocumentIds: [],
      );
    } finally {
      _isRunning = false;
    }
  }

  /// Gets last health check result (cached)
  DocumentHealthCheckResult? get lastResult => _lastResult;

  /// Checks if health check is currently running
  bool get isRunning => _isRunning;
}

