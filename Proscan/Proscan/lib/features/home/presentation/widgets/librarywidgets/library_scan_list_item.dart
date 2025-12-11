import 'dart:io';

import 'package:flutter/material.dart';
import 'package:thyscan/core/widgets/error_boundary.dart';
import 'package:thyscan/features/home/presentation/widgets/corrupted_document_tile.dart';
import 'package:thyscan/features/home/presentation/widgets/document_thumbnail.dart';
import 'package:thyscan/features/home/presentation/widgets/file_status_badge.dart';
import 'package:thyscan/features/home/presentation/widgets/redownload_button.dart';
import 'package:thyscan/features/home/presentation/widgets/sync_status_badge.dart';
import 'package:thyscan/features/scan/model/scans.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/models/file_status.dart';

class LibraryScanListItem extends StatelessWidget {
  final Scan scan;
  final DocumentModel? document; // Optional DocumentModel for validation
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const LibraryScanListItem({
    super.key,
    required this.scan,
    this.document,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.onEdit,
    this.onDelete,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap in error boundary for bulletproof error handling
    return ListItemErrorBoundary(
      fallback: (context, error) {
        // Show corrupted document tile if this widget crashes
        return CorruptedDocumentTile(
          documentId: scan.id,
          documentTitle: scan.title,
          onDeleted: onDelete,
          onRetry: () {
            // Retry by rebuilding (will be handled by parent)
          },
        );
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.08)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 2)
              : Border.all(color: colorScheme.outline.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Selection Indicator
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: isSelectionMode
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: colorScheme.onPrimary,
                            )
                          : null,
                      key: ValueKey('selected-$isSelected'),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
            if (isSelectionMode) const SizedBox(width: 16),

            // Thumbnail with professional styling and file validation
            Container(
              width: 64,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Check if thumbnail is valid (bulletproof validation)
                    _buildThumbnailContent(colorScheme),
                    // Premium Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                    // Sync status badge (top-right) - like CamScanner
                    SyncStatusBadge(
                      documentId: scan.id,
                      document: document,
                      size: 20,
                      position: BadgePosition.topRight,
                    ),
                    // File status badge overlay (top-left if file is invalid)
                    if (document != null && document!.fileStatus != FileStatus.valid)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: FileStatusBadge(
                          status: document!.fileStatus,
                          size: 12,
                        ),
                      ),
                    // Page count badge (bottom-right)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          scan.pageCount.split(' ').first,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Document Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Metadata row
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        scan.date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.description_rounded,
                        size: 14,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        scan.pageCount,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Status indicator with file validation
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Scanned',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // File status badge
                      if (document != null && document!.fileStatus != FileStatus.valid) ...[
                        const SizedBox(width: 8),
                        FileStatusBadge(
                          status: document!.fileStatus,
                          size: 14,
                        ),
                      ],
                      // Re-download button for cloud documents
                      if (document != null && document!.needsRedownload) ...[
                        const SizedBox(width: 8),
                        RedownloadButton(
                          document: document!,
                          size: 16,
                          onDownloaded: () {
                            // Refresh the UI after download
                            // This will be handled by the parent widget
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // More options button (only in normal mode)
            if (!isSelectionMode)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => _showOptionsMenu(context),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildMenuOption(
                context,
                icon: Icons.edit_rounded,
                label: 'Edit',
                onTap: () {
                  Navigator.pop(context);
                  onEdit?.call();
                },
              ),
              _buildMenuOption(
                context,
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {
                  Navigator.pop(context);
                  onShare?.call();
                },
              ),
              _buildMenuOption(
                context,
                icon: Icons.delete_rounded,
                label: 'Delete',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDestructive
                    ? colorScheme.error.withOpacity(0.1)
                    : colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: colorScheme.error),
            const SizedBox(width: 12),
            const Text('Delete Document?'),
          ],
        ),
        content: Text(
          'This will permanently delete "${scan.title}" and all its pages. This action cannot be undone.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Builds thumbnail content with bulletproof file validation
  Widget _buildThumbnailContent(ColorScheme colorScheme) {
    // Use DocumentModel validation if available
    if (document != null) {
      final hasValidThumb = document!.hasValidThumbnail;
      final thumbnailStatus = document!.thumbnailStatus;

      // Show placeholder if thumbnail is missing or corrupted
      if (!hasValidThumb || thumbnailStatus != FileStatus.valid) {
        return Container(
          width: 64,
          height: 84,
          color: colorScheme.surfaceVariant,
          child: Icon(
            Icons.image_not_supported_rounded,
            size: 32,
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
        );
      }
    }

    // Original logic for Scan model
    if (scan.tags.contains('Text')) {
      return Container(
        width: 64,
        height: 84,
        color: colorScheme.primaryContainer,
        child: Icon(
          Icons.description_rounded,
          size: 32,
          color: colorScheme.primary,
        ),
      );
    }

    // Check if file exists (bulletproof validation)
    if (scan.imagePath.isNotEmpty) {
      // If it's a URL, show thumbnail (can be downloaded)
      if (scan.imagePath.startsWith('http://') ||
          scan.imagePath.startsWith('https://')) {
        return SizedBox(
          width: 64,
          height: 84,
          child: DocumentThumbnail(
            imagePath: scan.imagePath,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(12),
            placeholder: Container(
              color: colorScheme.surfaceVariant,
              child: Icon(
                Icons.image_not_supported_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      // Check if local file exists
      final file = File(scan.imagePath);
      if (file.existsSync()) {
        return SizedBox(
          width: 64,
          height: 84,
          child: DocumentThumbnail(
            imagePath: scan.imagePath,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(12),
            placeholder: Container(
              color: colorScheme.surfaceVariant,
              child: Icon(
                Icons.image_not_supported_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
    }

    // Fallback placeholder
    return Container(
      width: 64,
      height: 84,
      color: colorScheme.surfaceVariant,
      child: Icon(
        Icons.image_not_supported_rounded,
        size: 32,
        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
      ),
    );
  }
}
