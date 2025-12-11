import 'dart:async';

import 'package:system_info2/system_info2.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/storage_service.dart';

/// Priority levels for operations
enum OperationPriority {
  userInitiated, // User-initiated operations (highest priority)
  background, // Background operations (lower priority)
}

class ResourceGuard {
  ResourceGuard._();
  static final ResourceGuard instance = ResourceGuard._();

  // Concurrent operation limits
  static const int maxConcurrentImageProcessing = 2;
  static const int maxConcurrentUploads = 3;
  static const int maxConcurrentDownloads = 2;

  // Active operation tracking
  final Set<String> _activeImageProcessing = {};
  final Set<String> _activeUploads = {};
  final Set<String> _activeDownloads = {};

  // Operation queues with priority
  final List<_QueuedOperation> _imageProcessingQueue = [];
  final List<_QueuedOperation> _uploadQueue = [];
  final List<_QueuedOperation> _downloadQueue = [];

  Future<bool> hasSufficientDiskSpace({
    required int requiredBytes,
    double headroomMultiplier = 1.5,
  }) async {
    try {
      final freeBytes = await StorageService.instance.getFreeStorage();
      final requiredWithHeadroom = (requiredBytes * headroomMultiplier).round();
      final hasSpace = freeBytes > requiredWithHeadroom;

      if (!hasSpace) {
        AppLogger.warning(
          error: null,
          'Insufficient disk space',
          data: {'freeBytes': freeBytes, 'requiredBytes': requiredWithHeadroom},
        );
      }

      return hasSpace;
    } catch (e) {
      // If storage info unavailable, assume sufficient to avoid false negatives.
      // This is a fail-safe approach for production.
      AppLogger.warning(
        error: null,
        'Could not determine disk space, assuming sufficient',
        data: {'error': e},
      );
      return true;
    }
  }

  bool hasSufficientMemory({int minFreeMb = 200}) {
    try {
      final freeMb = SysInfo.getFreePhysicalMemory() / (1024 * 1024);
      final hasMemory = freeMb >= minFreeMb;

      if (!hasMemory) {
        AppLogger.warning(
          error: null,
          'Insufficient memory',
          data: {'freeMb': freeMb, 'minFreeMb': minFreeMb},
        );
      }

      return hasMemory;
    } catch (e) {
      // If memory info unavailable, assume sufficient to avoid false negatives.
      AppLogger.warning(
        error: null,
        'Could not determine memory, assuming sufficient',
        data: {'error': e},
      );
      return true;
    }
  }

  /// Acquires a slot for image processing operation
  /// Returns a completer that completes when the operation can proceed
  Future<void> acquireImageProcessingSlot({
    required String operationId,
    OperationPriority priority = OperationPriority.background,
  }) async {
    if (_activeImageProcessing.length < maxConcurrentImageProcessing) {
      _activeImageProcessing.add(operationId);
      return;
    }

    // Queue the operation
    final completer = Completer<void>();
    final operation = _QueuedOperation(
      id: operationId,
      priority: priority,
      completer: completer,
    );

    _imageProcessingQueue.add(operation);
    _imageProcessingQueue.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    AppLogger.info(
      'Image processing operation queued',
      data: {
        'operationId': operationId,
        'queueLength': _imageProcessingQueue.length,
        'activeCount': _activeImageProcessing.length,
      },
    );

    return completer.future;
  }

  /// Releases an image processing slot
  void releaseImageProcessingSlot(String operationId) {
    _activeImageProcessing.remove(operationId);
    _processImageProcessingQueue();
  }

  /// Acquires a slot for upload operation
  Future<void> acquireUploadSlot({
    required String operationId,
    OperationPriority priority = OperationPriority.background,
  }) async {
    if (_activeUploads.length < maxConcurrentUploads) {
      _activeUploads.add(operationId);
      return;
    }

    final completer = Completer<void>();
    final operation = _QueuedOperation(
      id: operationId,
      priority: priority,
      completer: completer,
    );

    _uploadQueue.add(operation);
    _uploadQueue.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    AppLogger.info(
      'Upload operation queued',
      data: {
        'operationId': operationId,
        'queueLength': _uploadQueue.length,
        'activeCount': _activeUploads.length,
      },
    );

    return completer.future;
  }

  /// Releases an upload slot
  void releaseUploadSlot(String operationId) {
    _activeUploads.remove(operationId);
    _processUploadQueue();
  }

  /// Acquires a slot for download operation
  Future<void> acquireDownloadSlot({
    required String operationId,
    OperationPriority priority = OperationPriority.background,
  }) async {
    if (_activeDownloads.length < maxConcurrentDownloads) {
      _activeDownloads.add(operationId);
      return;
    }

    final completer = Completer<void>();
    final operation = _QueuedOperation(
      id: operationId,
      priority: priority,
      completer: completer,
    );

    _downloadQueue.add(operation);
    _downloadQueue.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    AppLogger.info(
      'Download operation queued',
      data: {
        'operationId': operationId,
        'queueLength': _downloadQueue.length,
        'activeCount': _activeDownloads.length,
      },
    );

    return completer.future;
  }

  /// Releases a download slot
  void releaseDownloadSlot(String operationId) {
    _activeDownloads.remove(operationId);
    _processDownloadQueue();
  }

  /// Processes the image processing queue
  void _processImageProcessingQueue() {
    while (_activeImageProcessing.length < maxConcurrentImageProcessing &&
        _imageProcessingQueue.isNotEmpty) {
      final operation = _imageProcessingQueue.removeAt(0);
      _activeImageProcessing.add(operation.id);
      if (!operation.completer.isCompleted) {
        operation.completer.complete();
      }
    }
  }

  /// Processes the upload queue
  void _processUploadQueue() {
    while (_activeUploads.length < maxConcurrentUploads && _uploadQueue.isNotEmpty) {
      final operation = _uploadQueue.removeAt(0);
      _activeUploads.add(operation.id);
      if (!operation.completer.isCompleted) {
        operation.completer.complete();
      }
    }
  }

  /// Processes the download queue
  void _processDownloadQueue() {
    while (_activeDownloads.length < maxConcurrentDownloads &&
        _downloadQueue.isNotEmpty) {
      final operation = _downloadQueue.removeAt(0);
      _activeDownloads.add(operation.id);
      if (!operation.completer.isCompleted) {
        operation.completer.complete();
      }
    }
  }

  /// Gets current operation statistics
  Map<String, dynamic> getOperationStats() {
    return {
      'imageProcessing': {
        'active': _activeImageProcessing.length,
        'max': maxConcurrentImageProcessing,
        'queued': _imageProcessingQueue.length,
      },
      'uploads': {
        'active': _activeUploads.length,
        'max': maxConcurrentUploads,
        'queued': _uploadQueue.length,
      },
      'downloads': {
        'active': _activeDownloads.length,
        'max': maxConcurrentDownloads,
        'queued': _downloadQueue.length,
      },
    };
  }

  /// Clears all queues (for logout)
  void clearAllQueues() {
    _imageProcessingQueue.clear();
    _uploadQueue.clear();
    _downloadQueue.clear();
    _activeImageProcessing.clear();
    _activeUploads.clear();
    _activeDownloads.clear();
  }
}

/// Queued operation with priority
class _QueuedOperation {
  final String id;
  final OperationPriority priority;
  final Completer<void> completer;

  _QueuedOperation({
    required this.id,
    required this.priority,
    required this.completer,
  });
}
