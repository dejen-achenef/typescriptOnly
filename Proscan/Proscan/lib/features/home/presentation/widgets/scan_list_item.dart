import 'dart:io';

import 'package:flutter/material.dart';
import 'package:thyscan/core/widgets/error_boundary.dart';
import 'package:thyscan/features/home/presentation/widgets/cached_thumbnail.dart';
import 'package:thyscan/features/home/presentation/widgets/corrupted_document_tile.dart';
import 'package:thyscan/features/home/presentation/widgets/file_status_badge.dart';
import 'package:thyscan/features/home/presentation/widgets/redownload_button.dart';
import 'package:thyscan/features/home/presentation/widgets/sync_status_badge.dart';
import 'package:thyscan/features/home/presentation/widgets/sync_status_indicator.dart';
import 'package:thyscan/features/scan/model/scans.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/models/file_status.dart';

class ScanListItem extends StatelessWidget {
  final Scan scan;
  final DocumentModel? document; // Optional DocumentModel for validation
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const ScanListItem({
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
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 2.5,
                )
              : Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.08),
                  width: 1.5,
                ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
          ],
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.03),
                    colorScheme.primary.withValues(alpha: 0.01),
                  ],
                )
              : null,
        ),
        child: Row(
          children: [
            // Premium Selection Indicator
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.elasticOut,
                ),
                child: child,
              ),
              child: isSelectionMode
                  ? Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.primary.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.2),
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: colorScheme.onPrimary,
                            )
                          : null,
                      key: ValueKey('selected-$isSelected'),
                    )
                  : const SizedBox(width: 8, key: ValueKey('empty')),
            ),

            // Premium Thumbnail with Enhanced Styling
            Hero(
              tag: 'scan_thumb_${scan.id}',
              child: Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image or Icon Background with bulletproof validation
                      _buildThumbnailContent(colorScheme),

                      // Premium Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.3),
                            ],
                            stops: const [0.6, 1.0],
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
                          top: 8,
                          left: 8,
                          child: FileStatusBadge(
                            status: document!.fileStatus,
                            size: 12,
                          ),
                        ),

                      // Page Count Badge (bottom-right)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            scan.pageCount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),

            // Enhanced Document Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with sync status indicator
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          scan.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SyncStatusIndicator(
                        documentId: scan.id,
                        size: 16,
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
                        const SizedBox(width: 4),
                        RedownloadButton(
                          document: document!,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Metadata with enhanced styling
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scanned on',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              scan.date,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Enhanced Tags
                  if (scan.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: scan.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary.withValues(alpha: 0.15),
                                colorScheme.primary.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getTagIcon(tag),
                                size: 12,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tag,
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            // Premium More Options Button
            if (!isSelectionMode)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showPremiumOptionsMenu(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surfaceVariant,
                colorScheme.surfaceVariant.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.image_not_supported_rounded,
              size: 36,
              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
        );
      }
    }

    // Original logic for Scan model
    if (scan.tags.contains('Text')) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.primaryContainer.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.description_rounded,
            size: 36,
            color: colorScheme.primary,
          ),
        ),
      );
    }

    // Check if file exists (bulletproof validation)
    if (scan.imagePath.isNotEmpty) {
      // If it's a URL, show thumbnail (can be downloaded)
      if (scan.imagePath.startsWith('http://') ||
          scan.imagePath.startsWith('https://')) {
        return CachedThumbnail(
          path: scan.imagePath,
          fit: BoxFit.cover,
          placeholder: _buildErrorPlaceholder(colorScheme),
        );
      }

      // Check if local file exists
      final file = File(scan.imagePath);
      if (file.existsSync()) {
        return CachedThumbnail(
          path: scan.imagePath,
          fit: BoxFit.cover,
          placeholder: _buildErrorPlaceholder(colorScheme),
        );
      }
    }

    // Fallback placeholder
    return _buildErrorPlaceholder(colorScheme);
  }

  Widget _buildErrorPlaceholder(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceVariant,
            colorScheme.surfaceVariant.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          size: 32,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  IconData _getTagIcon(String tag) {
    switch (tag.toLowerCase()) {
      case 'text':
        return Icons.text_fields_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'important':
        return Icons.label_important_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'personal':
        return Icons.person_rounded;
      default:
        return Icons.label_rounded;
    }
  }

  void _showPremiumOptionsMenu(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.article_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scan.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Document Options',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Menu Options
              _buildPremiumMenuOption(
                context,
                icon: Icons.edit_document,
                title: 'Edit Document',
                subtitle: 'Rename or modify details',
                onTap: () {
                  Navigator.pop(context);
                  onEdit?.call();
                },
              ),
              _buildPremiumMenuOption(
                context,
                icon: Icons.share_rounded,
                title: 'Share',
                subtitle: 'Export or send to others',
                onTap: () {
                  Navigator.pop(context);
                  onShare?.call();
                },
              ),
              _buildPremiumMenuOption(
                context,
                icon: Icons.delete_rounded,
                title: 'Delete',
                subtitle: 'Permanently remove',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _showPremiumDeleteConfirmation(context);
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? colorScheme.error.withValues(alpha: 0.1)
                      : colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPremiumDeleteConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  size: 32,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Delete Document?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                'Are you sure you want to permanently delete "${scan.title}"? This action cannot be undone and all pages will be lost.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete?.call();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
