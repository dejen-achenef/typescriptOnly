// features/home/controllers/upload_queue_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/core/services/document_upload_service.dart';

/// Provider that tracks upload queue state
final uploadQueueProvider = StreamProvider<UploadQueueState>((ref) {
  final controller = StreamController<UploadQueueState>.broadcast();
  
  // Initial state
  final initialQueue = DocumentUploadService.instance.pendingUploads;
  final initialProgress = <String, UploadProgress>{};
  for (final upload in initialQueue) {
    final progress = DocumentUploadService.instance.getProgress(upload.documentId);
    if (progress != null) {
      initialProgress[upload.documentId] = progress;
    }
  }
  
  controller.add(UploadQueueState(
    pendingCount: initialQueue.length,
    pendingUploads: initialQueue,
    progress: initialProgress,
  ));
  
  // Listen to progress stream
  final progressSubscription = DocumentUploadService.instance.progressStream.listen(
    (progress) {
      // Get updated queue
      final queue = DocumentUploadService.instance.pendingUploads;
      final progressMap = <String, UploadProgress>{};
      
      // Get progress for all items
      for (final upload in queue) {
        final itemProgress = DocumentUploadService.instance.getProgress(upload.documentId);
        if (itemProgress != null) {
          progressMap[upload.documentId] = itemProgress;
        }
      }
      
      // Also add the current progress update
      progressMap[progress.documentId] = progress;
      
      controller.add(UploadQueueState(
        pendingCount: queue.length,
        pendingUploads: queue,
        progress: progressMap,
      ));
    },
  );
  
  // Poll for queue changes (in case queue changes without progress updates)
  Timer? pollTimer;
  pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
    final queue = DocumentUploadService.instance.pendingUploads;
    final progressMap = <String, UploadProgress>{};
    
    for (final upload in queue) {
      final itemProgress = DocumentUploadService.instance.getProgress(upload.documentId);
      if (itemProgress != null) {
        progressMap[upload.documentId] = itemProgress;
      }
    }
    
    controller.add(UploadQueueState(
      pendingCount: queue.length,
      pendingUploads: queue,
      progress: progressMap,
    ));
  });
  
  ref.onDispose(() {
    progressSubscription.cancel();
    pollTimer?.cancel();
    controller.close();
  });
  
  return controller.stream;
});

/// State of the upload queue
class UploadQueueState {
  final int pendingCount;
  final List<PendingUpload> pendingUploads;
  final Map<String, UploadProgress> progress;
  
  UploadQueueState({
    required this.pendingCount,
    required this.pendingUploads,
    required this.progress,
  });
  
  bool get hasPending => pendingCount > 0;
  
  UploadProgress? getProgressFor(String documentId) {
    return progress[documentId];
  }
}

