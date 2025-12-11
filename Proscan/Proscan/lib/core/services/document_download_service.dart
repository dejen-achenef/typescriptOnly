// core/services/document_download_service.dart

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/core/services/resource_guard.dart';
import 'package:http/http.dart' as http;

/// Download priority levels
enum DownloadPriority {
  /// High priority - user is actively trying to open this document
  high,

  /// Normal priority - background download
  normal,

  /// Low priority - prefetch/preload
  low,
}

/// Download queue item
class _DownloadQueueItem {
  final String documentId;
  final String fileUrl;
  final String? thumbnailUrl;
  final String format;
  final DownloadPriority priority;
  final DateTime queuedAt;
  int attempts;

  _DownloadQueueItem({
    required this.documentId,
    required this.fileUrl,
    this.thumbnailUrl,
    required this.format,
    this.priority = DownloadPriority.normal,
    DateTime? queuedAt,
    this.attempts = 0,
  }) : queuedAt = queuedAt ?? DateTime.now();
}

/// Download progress information
class DownloadProgress {
  final String documentId;
  final double progress; // 0.0 to 1.0
  final int bytesDownloaded;
  final int? totalBytes;
  final bool isComplete;
  final String? error;

  DownloadProgress({
    required this.documentId,
    required this.progress,
    required this.bytesDownloaded,
    this.totalBytes,
    this.isComplete = false,
    this.error,
  });
}

/// Production-ready service for downloading documents and thumbnails from Supabase Storage.
///
/// **Features:**
/// - Queue management with prioritization
/// - Progress tracking via stream
/// - Automatic retry with exponential backoff
/// - Concurrent download limits
/// - Connectivity-aware
/// - Caches files locally for offline access
///
/// **Usage:**
/// ```dart
/// // Queue a download
/// DocumentDownloadService.instance.queueDownload(
///   documentId: 'uuid',
///   fileUrl: 'https://...',
///   format: 'pdf',
///   priority: DownloadPriority.high,
/// );
///
/// // Listen to progress
/// DocumentDownloadService.instance.progressStream.listen((progress) {
///   print('${progress.documentId}: ${progress.progress * 100}%');
/// });
/// ```
class DocumentDownloadService {
  DocumentDownloadService._();
  static final DocumentDownloadService instance = DocumentDownloadService._();

  final Connectivity _connectivity = Connectivity();
  final _downloadQueue = <_DownloadQueueItem>[];
  final _progressController = StreamController<DownloadProgress>.broadcast();
  final _activeDownloads = <String, Future<void>>{};
  final _isProcessing = <String, bool>{};
  
  static const int _maxConcurrentDownloads = 3;
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  
  bool _isInitialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Stream of download progress events
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  /// Number of items in download queue
  int get queueLength => _downloadQueue.length;

  /// Number of active downloads
  int get activeDownloadsCount => _activeDownloads.length;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Initializes the download service
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.info('Initializing DocumentDownloadService');

    // Listen to connectivity changes to resume downloads when online
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final isOnline = results.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (isOnline) {
        AppLogger.info(
          'Network connectivity restored, resuming download queue',
        );
        _processQueue();
      }
    });

    _isInitialized = true;
    AppLogger.info('DocumentDownloadService initialized');

    // Start processing queue
    _processQueue();
  }

  /// Disposes the download service
  void dispose() {
    _connectivitySubscription?.cancel();
    _progressController.close();
    _isInitialized = false;
  }

  /// Clears all download queues and resets service state
  /// Called during logout to clear user data
  Future<void> clearAll() async {
    try {
      AppLogger.info('Clearing DocumentDownloadService data');
      
      // Clear download queue
      _downloadQueue.clear();
      
      // Cancel active downloads
      for (final download in _activeDownloads.values) {
        try {
          await download.timeout(const Duration(seconds: 1));
        } catch (_) {
          // Ignore timeout errors
        }
      }
      _activeDownloads.clear();
      
      // Clear processing flags
      _isProcessing.clear();
      
      // Cancel connectivity subscription
      _connectivitySubscription?.cancel();
      _connectivitySubscription = null;
      
      AppLogger.info('DocumentDownloadService data cleared');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to clear DocumentDownloadService data',
        error: e,
        stack: stack,
      );
    }
  }

  /// Queues a document for download
  ///
  /// Downloads are processed in priority order with concurrent limits.
  Future<void> queueDownload({
    required String documentId,
    required String fileUrl,
    String? thumbnailUrl,
    required String format,
    DownloadPriority priority = DownloadPriority.normal,
  }) async {
    // Check if already downloaded or in queue
    if (_isProcessing.containsKey(documentId) ||
        _activeDownloads.containsKey(documentId)) {
      AppLogger.info(
        'Document already in download queue or being downloaded',
        data: {'documentId': documentId},
      );
      return;
    }

    // Check if file already exists locally
    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory('${appDocsDir.path}/scanned_documents');
    final localFilePath = '${documentsDir.path}/$documentId/$documentId.$format';
    final localFile = File(localFilePath);
    
    if (await localFile.exists()) {
      AppLogger.info(
        'Document already downloaded locally',
        data: {'documentId': documentId, 'path': localFilePath},
      );
      DocumentSyncStateService.instance.setSyncStatus(
        documentId,
        DocumentSyncStatus.synced,
      );
      return;
    }

    // Add to queue
    final queueItem = _DownloadQueueItem(
      documentId: documentId,
      fileUrl: fileUrl,
      thumbnailUrl: thumbnailUrl,
      format: format,
      priority: priority,
    );

    _downloadQueue.add(queueItem);
    
    // Sort queue by priority (high first, then by queued time)
    _downloadQueue.sort((a, b) {
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      return a.queuedAt.compareTo(b.queuedAt);
    });

    DocumentSyncStateService.instance.setSyncStatus(
      documentId,
      DocumentSyncStatus.pendingDownload,
    );

    AppLogger.info(
      'Document queued for download',
      data: {
        'documentId': documentId,
        'priority': priority.name,
        'queuePosition': _downloadQueue.length,
      },
    );

    // Start processing if not already processing
    _processQueue();
  }

  /// Processes the download queue
  Future<void> _processQueue() async {
    if (!_isInitialized) return;

    // Check connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final isOnline = connectivityResults.any(
      (result) =>
          result != ConnectivityResult.none &&
          result != ConnectivityResult.bluetooth,
    );

    if (!isOnline) {
      AppLogger.info('No internet connection, pausing download queue');
      return;
    }

    // Process queue up to concurrent limit (using ResourceGuard)
    while (_downloadQueue.isNotEmpty &&
        _activeDownloads.length < ResourceGuard.maxConcurrentDownloads) {
      final queueItem = _downloadQueue.removeAt(0);
      
      if (_activeDownloads.containsKey(queueItem.documentId)) {
        continue; // Already downloading
      }

      // Acquire download slot
      await ResourceGuard.instance.acquireDownloadSlot(
        operationId: queueItem.documentId,
        priority: queueItem.priority == DownloadPriority.high
            ? OperationPriority.userInitiated
            : OperationPriority.background,
      );

      // Start download
      final downloadFuture = _downloadWithRetry(queueItem);
      _activeDownloads[queueItem.documentId] = downloadFuture;

      // Remove from active downloads when complete
      downloadFuture.whenComplete(() {
        _activeDownloads.remove(queueItem.documentId);
        _isProcessing.remove(queueItem.documentId);
        // Release download slot
        ResourceGuard.instance.releaseDownloadSlot(queueItem.documentId);
        // Continue processing queue
        _processQueue();
      });
    }
  }

  /// Downloads a document with retry logic
  Future<void> _downloadWithRetry(_DownloadQueueItem queueItem) async {
    _isProcessing[queueItem.documentId] = true;
    DocumentSyncStateService.instance.setSyncStatus(
      queueItem.documentId,
      DocumentSyncStatus.syncing,
    );

    while (queueItem.attempts < _maxRetryAttempts) {
      try {
        await downloadDocumentFiles(
          fileUrl: queueItem.fileUrl,
          thumbnailUrl: queueItem.thumbnailUrl,
          documentId: queueItem.documentId,
          format: queueItem.format,
        );

        // Success
        DocumentSyncStateService.instance.setSyncStatus(
          queueItem.documentId,
          DocumentSyncStatus.synced,
        );

        _emitProgress(
          queueItem.documentId,
          progress: 1.0,
          isComplete: true,
        );

        AppLogger.info(
          '✅ Document downloaded successfully',
          data: {'documentId': queueItem.documentId},
        );
        return;
      } catch (e, stack) {
        queueItem.attempts++;
        
        if (queueItem.attempts >= _maxRetryAttempts) {
          // Max attempts reached
          final errorMessage = 'Download failed after $_maxRetryAttempts attempts: $e';
          DocumentSyncStateService.instance.setSyncStatus(
            queueItem.documentId,
            DocumentSyncStatus.error,
            errorMessage: errorMessage,
          );

          _emitProgress(
            queueItem.documentId,
            progress: 0.0,
            error: errorMessage,
          );

          AppLogger.error(
            '❌ Document download failed after max retries',
            error: e,
            stack: stack,
            data: {'documentId': queueItem.documentId},
          );
          return;
        }

        // Wait before retry (exponential backoff)
        final delay = Duration(
          seconds: _retryDelay.inSeconds * (1 << (queueItem.attempts - 1)),
        );
        AppLogger.info(
          'Retrying download after ${delay.inSeconds}s (attempt ${queueItem.attempts}/$_maxRetryAttempts)',
          data: {'documentId': queueItem.documentId},
        );
        await Future.delayed(delay);
      }
    }
  }

  /// Emits a progress event
  void _emitProgress(
    String documentId, {
    double progress = 0.0,
    int bytesDownloaded = 0,
    int? totalBytes,
    bool isComplete = false,
    String? error,
  }) {
    _progressController.add(
      DownloadProgress(
        documentId: documentId,
        progress: progress,
        bytesDownloaded: bytesDownloaded,
        totalBytes: totalBytes,
        isComplete: isComplete,
        error: error,
      ),
    );
  }

  /// Downloads a file from Supabase Storage URL to local storage.
  ///
  /// **Parameters:**
  /// - `url`: Supabase Storage URL
  /// - `documentId`: Document UUID (for organizing files)
  /// - `fileName`: Optional file name (if not provided, extracts from URL)
  ///
  /// **Returns:**
  /// - Local file path on success
  /// - `null` if download fails or offline
  ///
  /// **Throws:**
  /// - `Exception` if critical error occurs
  Future<String?> downloadFile({
    required String url,
    required String documentId,
    String? fileName,
  }) async {
    try {
      // Check connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        AppLogger.info('No internet connection, cannot download file');
        return null;
      }

      // Extract file name from URL if not provided
      final finalFileName =
          fileName ??
          url.split('/').last.split('?').first; // Remove query params

      // Get app documents directory
      final appDocsDir = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${appDocsDir.path}/scanned_documents');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }

      // Create local file path
      final localFilePath = '${documentsDir.path}/$documentId/$finalFileName';
      final localFile = File(localFilePath);

      // Create parent directory if it doesn't exist
      await localFile.parent.create(recursive: true);

      // Check if file already exists
      if (await localFile.exists()) {
        AppLogger.info(
          'File already downloaded, using cached version',
          data: {'path': localFilePath},
        );
        return localFilePath;
      }

      AppLogger.info(
        '📥 Downloading file from Supabase Storage',
        data: {
          'url': url.substring(0, url.length > 100 ? 100 : url.length) + '...',
          'documentId': documentId,
          'fileName': finalFileName,
        },
      );

      // Emit initial progress
      _emitProgress(documentId, progress: 0.0);

      // Download file with progress tracking
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await http.Client()
          .send(request)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception('Download timeout');
            },
          );

      final totalBytes = streamedResponse.contentLength;
      int bytesDownloaded = 0;

      // Read response with progress tracking
      final List<int> bytes = [];
      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        bytesDownloaded += chunk.length;

        // Emit progress
        if (totalBytes != null && totalBytes > 0) {
          final progress = bytesDownloaded / totalBytes;
          _emitProgress(
            documentId,
            progress: progress,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
          );
        } else {
          // Unknown total, just track bytes
          _emitProgress(
            documentId,
            progress: 0.5, // Indeterminate progress
            bytesDownloaded: bytesDownloaded,
          );
        }
      }

      final response = http.Response.bytes(
        bytes,
        streamedResponse.statusCode,
        headers: streamedResponse.headers,
        request: request,
      );

      if (response.statusCode != 200) {
        AppLogger.error(
          'Failed to download file',
          data: {
            'statusCode': response.statusCode,
            'url': url.substring(0, 100) + '...',
          },
        );
        return null;
      }

      // Write to local file
      await localFile.writeAsBytes(response.bodyBytes);

      AppLogger.info(
        '✅ File downloaded successfully',
        data: {'path': localFilePath, 'size': await localFile.length()},
      );

      return localFilePath;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to download file',
        error: e,
        stack: stack,
        data: {
          'url': url.substring(0, url.length > 100 ? 100 : url.length) + '...',
          'documentId': documentId,
        },
      );
      return null;
    }
  }

  /// Downloads a thumbnail image from Supabase Storage URL to local storage.
  ///
  /// **Parameters:**
  /// - `url`: Supabase Storage URL for thumbnail
  /// - `documentId`: Document UUID (for organizing files)
  ///
  /// **Returns:**
  /// - Local file path on success
  /// - `null` if download fails, offline, or URL is empty
  Future<String?> downloadThumbnail({
    required String url,
    required String documentId,
  }) async {
    if (url.isEmpty) {
      return null;
    }

    try {
      // Check connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        AppLogger.info('No internet connection, cannot download thumbnail');
        return null;
      }

      // Get app documents directory
      final appDocsDir = await getApplicationDocumentsDirectory();
      final thumbsDir = Directory('${appDocsDir.path}/thumbnails');
      if (!await thumbsDir.exists()) {
        await thumbsDir.create(recursive: true);
      }

      // Create local file path
      final extension = url.split('.').last.split('?').first;
      final localFilePath =
          '${thumbsDir.path}/${documentId}_thumb.${extension == 'jpg' || extension == 'jpeg' ? 'jpg' : 'png'}';
      final localFile = File(localFilePath);

      // Check if file already exists
      if (await localFile.exists()) {
        AppLogger.info(
          'Thumbnail already downloaded, using cached version',
          data: {'path': localFilePath},
        );
        return localFilePath;
      }

      AppLogger.info(
        '📥 Downloading thumbnail from Supabase Storage',
        data: {
          'url': url.substring(0, url.length > 100 ? 100 : url.length) + '...',
          'documentId': documentId,
        },
      );

      // Download thumbnail
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Download timeout');
            },
          );

      if (response.statusCode != 200) {
        AppLogger.error(
          'Failed to download thumbnail',
          data: {
            'statusCode': response.statusCode,
            'url': url.substring(0, 100) + '...',
          },
        );
        return null;
      }

      // Write to local file
      await localFile.writeAsBytes(response.bodyBytes);

      AppLogger.info(
        '✅ Thumbnail downloaded successfully',
        data: {'path': localFilePath, 'size': await localFile.length()},
      );

      return localFilePath;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to download thumbnail',
        error: e,
        stack: stack,
        data: {
          'url': url.substring(0, url.length > 100 ? 100 : url.length) + '...',
          'documentId': documentId,
        },
      );
      return null;
    }
  }

  /// Downloads both file and thumbnail for a document.
  ///
  /// **Parameters:**
  /// - `fileUrl`: Supabase Storage URL for document file
  /// - `thumbnailUrl`: Optional Supabase Storage URL for thumbnail
  /// - `documentId`: Document UUID
  /// - `format`: Document format ('pdf' or 'docx')
  ///
  /// **Returns:**
  /// - Map with 'filePath' and 'thumbnailPath' keys
  /// - Values are local file paths or null if download failed
  ///
  /// **Throws:**
  /// - Exception if download fails
  Future<Map<String, String?>> downloadDocumentFiles({
    required String fileUrl,
    String? thumbnailUrl,
    required String documentId,
    required String format,
  }) async {
    AppLogger.info(
      '📥 Downloading document files',
      data: {
        'documentId': documentId,
        'format': format,
        'hasThumbnail': thumbnailUrl != null && thumbnailUrl.isNotEmpty,
      },
    );

    try {
      // Download file and thumbnail in parallel
      final results = await Future.wait([
        downloadFile(
          url: fileUrl,
          documentId: documentId,
          fileName: '$documentId.$format',
        ),
        thumbnailUrl != null && thumbnailUrl.isNotEmpty
            ? downloadThumbnail(url: thumbnailUrl, documentId: documentId)
            : Future<String?>.value(null),
      ]);

      final downloadedFilePath = results[0];
      final downloadedThumbnailPath = results[1];

      if (downloadedFilePath == null) {
        throw Exception('Failed to download document file');
      }

      AppLogger.info(
        '✅ Document files download completed',
        data: {
          'documentId': documentId,
          'fileDownloaded': downloadedFilePath != null,
          'thumbnailDownloaded': downloadedThumbnailPath != null,
        },
      );

      return {
        'filePath': downloadedFilePath,
        'thumbnailPath': downloadedThumbnailPath ?? '',
      };
    } catch (e, stack) {
      AppLogger.error(
        'Failed to download document files',
        error: e,
        stack: stack,
        data: {'documentId': documentId},
      );
      rethrow;
    }
  }

  /// Cancels a queued download
  void cancelDownload(String documentId) {
    _downloadQueue.removeWhere((item) => item.documentId == documentId);
    _activeDownloads.remove(documentId);
    _isProcessing.remove(documentId);
    
    AppLogger.info(
      'Download cancelled',
      data: {'documentId': documentId},
    );
  }

  /// Clears the download queue
  void clearQueue() {
    final cancelledCount = _downloadQueue.length;
    _downloadQueue.clear();
    
    AppLogger.info(
      'Download queue cleared',
      data: {'cancelledCount': cancelledCount},
    );
  }
}
