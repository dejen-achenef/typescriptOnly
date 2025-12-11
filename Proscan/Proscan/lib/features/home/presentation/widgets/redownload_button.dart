// features/home/presentation/widgets/redownload_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_download_service.dart';
import 'package:thyscan/models/document_model.dart';

/// Button to re-download cloud documents
class RedownloadButton extends ConsumerStatefulWidget {
  const RedownloadButton({
    super.key,
    required this.document,
    this.size = 20,
    this.onDownloaded,
  });

  final DocumentModel document;
  final double size;
  final VoidCallback? onDownloaded;

  @override
  ConsumerState<RedownloadButton> createState() => _RedownloadButtonState();
}

class _RedownloadButtonState extends ConsumerState<RedownloadButton> {
  bool _isDownloading = false;

  Future<void> _redownload() async {
    if (!widget.document.isCloudDocument) return;

    setState(() => _isDownloading = true);

    try {
      // Queue download with high priority (user-initiated)
      DocumentDownloadService.instance.queueDownload(
        documentId: widget.document.id,
        fileUrl: widget.document.filePath,
        thumbnailUrl: widget.document.thumbnailPath.isNotEmpty &&
                (widget.document.thumbnailPath.startsWith('http://') ||
                    widget.document.thumbnailPath.startsWith('https://'))
            ? widget.document.thumbnailPath
            : null,
        format: widget.document.format,
        priority: DownloadPriority.high,
      );

      AppLogger.info(
        'Document re-download queued',
        data: {'documentId': widget.document.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Download started...'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Wait a bit for download to complete (optional)
        // In production, you might want to listen to progress stream
        await Future.delayed(const Duration(seconds: 1));
        widget.onDownloaded?.call();
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to queue document re-download',
        error: e,
        stack: stack,
        data: {'documentId': widget.document.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start download: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.document.isCloudDocument || !widget.document.needsRedownload) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: _isDownloading ? null : _redownload,
      icon: _isDownloading
          ? SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          : Icon(
              Iconsax.document_download,
              size: widget.size,
              color: colorScheme.primary,
            ),
      tooltip: 'Re-download from cloud',
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: widget.size + 8,
        minHeight: widget.size + 8,
      ),
    );
  }
}

