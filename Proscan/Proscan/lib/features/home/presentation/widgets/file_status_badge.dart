// features/home/presentation/widgets/file_status_badge.dart
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:thyscan/models/file_status.dart';

/// Badge showing file status (missing/corrupted)
class FileStatusBadge extends StatelessWidget {
  const FileStatusBadge({
    super.key,
    required this.status,
    this.size = 16,
  });

  final FileStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (status == FileStatus.valid) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color backgroundColor;
    Color iconColor;
    IconData icon;
    String label;

    switch (status) {
      case FileStatus.missing:
        backgroundColor = colorScheme.errorContainer;
        iconColor = colorScheme.onErrorContainer;
        icon = Iconsax.document_download;
        label = 'File Missing';
        break;
      case FileStatus.corrupted:
        backgroundColor = colorScheme.errorContainer;
        iconColor = colorScheme.onErrorContainer;
        icon = Iconsax.warning_2;
        label = 'File Corrupted';
        break;
      case FileStatus.valid:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: iconColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

