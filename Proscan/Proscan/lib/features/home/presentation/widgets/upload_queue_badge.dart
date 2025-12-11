// features/home/presentation/widgets/upload_queue_badge.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:thyscan/features/home/controllers/upload_queue_provider.dart';
import 'package:thyscan/features/home/presentation/screens/upload_queue_screen.dart';

/// Badge showing pending upload count in app bar (like Google Drive)
class UploadQueueBadge extends ConsumerWidget {
  const UploadQueueBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(uploadQueueProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return queueAsync.when(
      data: (state) {
        if (!state.hasPending) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => context.push('/upload-queue'),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_upload,
                  size: 16,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  '${state.pendingCount} pending',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
