// features/home/presentation/widgets/sync_status_badge.dart
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_download_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/models/document_model.dart';

/// Sync status badge shown in the corner of document thumbnails
/// Like CamScanner - shows sync status with tap to retry
/// Reactive to status changes via StreamBuilder
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({
    super.key,
    required this.documentId,
    this.document,
    this.size = 20.0,
    this.position = BadgePosition.topRight,
  });

  final String documentId;
  final DocumentModel? document;
  final double size;
  final BadgePosition position;

  @override
  Widget build(BuildContext context) {
    // Listen to status changes reactively
    return StreamBuilder<DocumentSyncStatusUpdate>(
      stream: DocumentSyncStateService.instance.statusStream
          .where((update) => update.documentId == documentId),
      initialData: null,
      builder: (context, snapshot) {
        // Get current status
        DocumentSyncStatus status;
        if (snapshot.hasData && snapshot.data != null) {
          status = snapshot.data!.status;
        } else {
          // Get initial status
          status = DocumentSyncStateService.instance.getSyncStatus(documentId);
        }

        // Don't show badge if synced (clean UI)
        if (status == DocumentSyncStatus.synced) {
          return const SizedBox.shrink();
        }

        return Positioned(
      top: position == BadgePosition.topRight || position == BadgePosition.topLeft
          ? 4
          : null,
      bottom: position == BadgePosition.bottomRight || position == BadgePosition.bottomLeft
          ? 4
          : null,
      right: position == BadgePosition.topRight || position == BadgePosition.bottomRight
          ? 4
          : null,
      left: position == BadgePosition.topLeft || position == BadgePosition.bottomLeft
          ? 4
          : null,
      child: GestureDetector(
        onTap: () => _showStatusDialog(context, status),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.95),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getStatusIcon(status),
            size: size * 0.6,
            color: Colors.white,
          ),
        ),
      ),
    );
      },
    );
  }

  IconData _getStatusIcon(DocumentSyncStatus status) {
    switch (status) {
      case DocumentSyncStatus.synced:
        return Iconsax.tick_circle; // Cloud checkmark
      case DocumentSyncStatus.pendingUpload:
      case DocumentSyncStatus.uploadingFile:
      case DocumentSyncStatus.uploadingThumbnail:
        return Iconsax.arrow_up; // Upload arrow
      case DocumentSyncStatus.pendingDownload:
        return Iconsax.arrow_down; // Download arrow
      case DocumentSyncStatus.error:
      case DocumentSyncStatus.failedRetry:
      case DocumentSyncStatus.failedSyncDelete:
      case DocumentSyncStatus.failed:
        return Iconsax.warning_2; // Warning
      case DocumentSyncStatus.syncing:
      case DocumentSyncStatus.syncingMetadata:
        return Iconsax.refresh; // Syncing
      case DocumentSyncStatus.conflict:
      case DocumentSyncStatus.pendingConflictResolution:
        return Iconsax.warning_2; // Warning for conflicts
    }
  }

  Color _getStatusColor(DocumentSyncStatus status) {
    switch (status) {
      case DocumentSyncStatus.synced:
        return Colors.green;
      case DocumentSyncStatus.pendingUpload:
      case DocumentSyncStatus.uploadingFile:
      case DocumentSyncStatus.uploadingThumbnail:
        return Colors.orange;
      case DocumentSyncStatus.pendingDownload:
      case DocumentSyncStatus.syncing:
      case DocumentSyncStatus.syncingMetadata:
        return Colors.blue;
      case DocumentSyncStatus.error:
      case DocumentSyncStatus.failedRetry:
      case DocumentSyncStatus.failedSyncDelete:
      case DocumentSyncStatus.failed:
        return Colors.red;
      case DocumentSyncStatus.conflict:
      case DocumentSyncStatus.pendingConflictResolution:
        return Colors.orange;
    }
  }

  String _getStatusLabel(DocumentSyncStatus status) {
    switch (status) {
      case DocumentSyncStatus.synced:
        return 'Synced';
      case DocumentSyncStatus.pendingUpload:
        return 'Pending Upload';
      case DocumentSyncStatus.uploadingFile:
        return 'Uploading File...';
      case DocumentSyncStatus.uploadingThumbnail:
        return 'Uploading Thumbnail...';
      case DocumentSyncStatus.pendingDownload:
        return 'Pending Download';
      case DocumentSyncStatus.syncing:
        return 'Syncing...';
      case DocumentSyncStatus.syncingMetadata:
        return 'Syncing Metadata...';
      case DocumentSyncStatus.error:
        return 'Sync Error';
      case DocumentSyncStatus.failedRetry:
        return 'Upload Failed - Retrying';
      case DocumentSyncStatus.failedSyncDelete:
        return 'Delete Sync Failed';
      case DocumentSyncStatus.failed:
        return 'Sync Failed';
      case DocumentSyncStatus.conflict:
        return 'Sync Conflict';
      case DocumentSyncStatus.pendingConflictResolution:
        return 'Conflict - Resolution Pending';
    }
  }

  String? _getStatusDescription(DocumentSyncStatus status) {
    final errorMessage = DocumentSyncStateService.instance.getErrorMessage(documentId);
    
    switch (status) {
      case DocumentSyncStatus.synced:
        return 'This document is fully synced with the cloud.';
      case DocumentSyncStatus.pendingUpload:
        return 'This document will be uploaded to the cloud when online.';
      case DocumentSyncStatus.uploadingFile:
        return 'Uploading document file to cloud storage...';
      case DocumentSyncStatus.uploadingThumbnail:
        return 'Uploading thumbnail to cloud storage...';
      case DocumentSyncStatus.pendingDownload:
        return 'This document needs to be downloaded from the cloud.';
      case DocumentSyncStatus.syncing:
        return 'Synchronizing with cloud...';
      case DocumentSyncStatus.syncingMetadata:
        return 'Syncing document metadata...';
      case DocumentSyncStatus.error:
        return errorMessage ?? 'An error occurred during sync.';
      case DocumentSyncStatus.failedRetry:
        return errorMessage ?? 'Upload failed. Will retry automatically.';
      case DocumentSyncStatus.failedSyncDelete:
        return errorMessage ?? 'Failed to sync deletion to cloud.';
      case DocumentSyncStatus.conflict:
        return 'This document has conflicting versions. Manual resolution may be required.';
      case DocumentSyncStatus.pendingConflictResolution:
        return 'Waiting for conflict resolution...';
      case DocumentSyncStatus.failed:
        return errorMessage ?? 'Sync failed after multiple retry attempts. Please try again manually.';
    }
  }

  Future<void> _showStatusDialog(BuildContext context, DocumentSyncStatus status) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusLabel = _getStatusLabel(status);
    final statusDescription = _getStatusDescription(status);
    final canRetry = _canRetry(status);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusLabel,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (statusDescription != null) ...[
              Text(
                statusDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Show last sync time if available
            if (status == DocumentSyncStatus.synced) ...[
              Builder(
                builder: (context) {
                  final lastSync = DocumentSyncStateService.instance
                      .getLastSyncTime(documentId);
                  if (lastSync == null) return const SizedBox.shrink();
                  
                  final timeAgo = _getTimeAgo(lastSync);
                  return Text(
                    'Last synced: $timeAgo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (canRetry)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _retrySync(context, status);
              },
              icon: const Icon(Iconsax.refresh, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: _getStatusColor(status),
              ),
            ),
        ],
      ),
    );
  }

  bool _canRetry(DocumentSyncStatus status) {
    return status == DocumentSyncStatus.error ||
        status == DocumentSyncStatus.failedRetry ||
        status == DocumentSyncStatus.failedSyncDelete ||
        status == DocumentSyncStatus.failed ||
        status == DocumentSyncStatus.pendingUpload ||
        status == DocumentSyncStatus.pendingDownload;
  }

  Future<void> _retrySync(BuildContext context, DocumentSyncStatus status) async {
    if (document == null) {
      // Try to get document from repository
      try {
        final doc = await DocumentRepository.instance.getDocumentById(documentId);
        if (doc == null) {
          _showError(context, 'Document not found');
          return;
        }
        await _performRetry(context, status, doc);
      } catch (e) {
        _showError(context, 'Failed to load document: ${e.toString()}');
      }
    } else {
      await _performRetry(context, status, document!);
    }
  }

  Future<void> _performRetry(
    BuildContext context,
    DocumentSyncStatus status,
    DocumentModel doc,
  ) async {
    try {
      if (status == DocumentSyncStatus.pendingDownload ||
          status == DocumentSyncStatus.error) {
        // Retry download
        AppLogger.info(
          'Retrying document download',
          data: {'documentId': documentId},
        );
        // Check if document has cloud URLs
        if (doc.filePath.startsWith('http://') || doc.filePath.startsWith('https://')) {
          await DocumentDownloadService.instance.downloadDocumentFiles(
            documentId: doc.id,
            fileUrl: doc.filePath,
            thumbnailUrl: doc.thumbnailPath.startsWith('http') ? doc.thumbnailPath : null,
            format: doc.format,
          );
        } else {
          // Queue download if we have URLs from backend
          DocumentDownloadService.instance.queueDownload(
            documentId: doc.id,
            fileUrl: doc.filePath,
            thumbnailUrl: doc.thumbnailPath.startsWith('http') ? doc.thumbnailPath : null,
            format: doc.format,
            priority: DownloadPriority.high,
          );
        }
      } else if (status == DocumentSyncStatus.pendingUpload ||
          status == DocumentSyncStatus.failedRetry ||
          status == DocumentSyncStatus.error) {
        // Retry upload
        AppLogger.info(
          'Retrying document upload',
          data: {'documentId': documentId},
        );
        await DocumentUploadService.instance.uploadDocument(doc);
      } else if (status == DocumentSyncStatus.failedSyncDelete) {
        // Retry delete sync
        AppLogger.info(
          'Retrying delete sync',
          data: {'documentId': documentId},
        );
        // Delete sync is handled by DocumentService
        // Just update status to trigger retry
        DocumentSyncStateService.instance.setSyncStatus(
          documentId,
          DocumentSyncStatus.pendingUpload,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sync retry initiated'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to retry sync',
        error: e,
        stack: stack,
        data: {'documentId': documentId, 'status': status.name},
      );

      if (context.mounted) {
        _showError(context, 'Failed to retry: ${e.toString()}');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

/// Position of the sync status badge
enum BadgePosition {
  topRight,
  topLeft,
  bottomRight,
  bottomLeft,
}

