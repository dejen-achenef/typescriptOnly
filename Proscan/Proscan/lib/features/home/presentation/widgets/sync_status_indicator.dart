// features/home/presentation/widgets/sync_status_indicator.dart
import 'package:flutter/material.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';

/// Widget that displays sync status for a document
class SyncStatusIndicator extends StatelessWidget {
  final String documentId;
  final double size;

  const SyncStatusIndicator({
    super.key,
    required this.documentId,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final status = DocumentSyncStateService.instance.getSyncStatus(documentId);

    IconData iconData;
    Color color;
    String? tooltip;

    switch (status) {
      case DocumentSyncStatus.synced:
        iconData = Icons.check_circle;
        color = Colors.green;
        tooltip = 'Synced';
        break;
      case DocumentSyncStatus.pendingUpload:
        iconData = Icons.cloud_upload;
        color = Colors.orange;
        tooltip = 'Pending upload';
        break;
      case DocumentSyncStatus.pendingDownload:
        iconData = Icons.cloud_download;
        color = Colors.blue;
        tooltip = 'Downloading...';
        break;
      case DocumentSyncStatus.syncing:
        iconData = Icons.sync;
        color = Colors.blue;
        tooltip = 'Syncing...';
        break;
      case DocumentSyncStatus.uploadingFile:
        iconData = Icons.cloud_upload;
        color = Colors.blue;
        tooltip = 'Uploading file...';
        break;
      case DocumentSyncStatus.uploadingThumbnail:
        iconData = Icons.image;
        color = Colors.blue;
        tooltip = 'Uploading thumbnail...';
        break;
      case DocumentSyncStatus.syncingMetadata:
        iconData = Icons.sync;
        color = Colors.blue;
        tooltip = 'Syncing metadata...';
        break;
      case DocumentSyncStatus.conflict:
        iconData = Icons.warning;
        color = Colors.red;
        tooltip = 'Conflict detected';
        break;
      case DocumentSyncStatus.pendingConflictResolution:
        iconData = Icons.warning;
        color = Colors.orange;
        tooltip = 'Conflict - resolution pending';
        break;
      case DocumentSyncStatus.error:
        iconData = Icons.error;
        color = Colors.red;
        tooltip = 'Sync error';
        break;
      case DocumentSyncStatus.failedRetry:
        iconData = Icons.refresh;
        color = Colors.orange;
        tooltip = 'Retrying...';
        break;
      case DocumentSyncStatus.failedSyncDelete:
        iconData = Icons.error;
        color = Colors.red;
        tooltip = 'Delete sync failed';
        break;
      case DocumentSyncStatus.failed:
        iconData = Icons.error_outline;
        color = Colors.red;
        tooltip = 'Sync failed after multiple attempts';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(
        iconData,
        size: size,
        color: color,
      ),
    );
  }
}

/// Global sync status indicator for app bar
class GlobalSyncStatusIndicator extends StatelessWidget {
  const GlobalSyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = DocumentSyncStateService.instance.getStatistics();

    if (stats.total == 0) {
      return const SizedBox.shrink();
    }

    // Show indicator if there are pending operations or issues
    if (!stats.hasPendingOperations && !stats.hasIssues) {
      return const SizedBox.shrink();
    }

    IconData iconData;
    Color color;
    String tooltip;

    if (stats.hasIssues) {
      iconData = Icons.warning;
      color = Colors.red;
      tooltip = '${stats.conflict + stats.error} sync issue(s)';
    } else if (stats.syncing > 0) {
      iconData = Icons.sync;
      color = Colors.blue;
      tooltip = 'Syncing ${stats.syncing} document(s)...';
    } else if (stats.pendingUpload > 0 || stats.pendingDownload > 0) {
      iconData = Icons.cloud_sync;
      color = Colors.orange;
      final pending = stats.pendingUpload + stats.pendingDownload;
      tooltip = '$pending document(s) pending sync';
    } else {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: tooltip,
      child: Icon(
        iconData,
        size: 20,
        color: color,
      ),
    );
  }
}

