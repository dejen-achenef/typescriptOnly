import 'package:flutter/material.dart';

/// Shimmer placeholder for document list items (CamScanner/Microsoft Lens style)
class DocumentShimmerPlaceholder extends StatefulWidget {
  const DocumentShimmerPlaceholder({super.key});

  @override
  State<DocumentShimmerPlaceholder> createState() =>
      _DocumentShimmerPlaceholderState();
}

class _DocumentShimmerPlaceholderState
    extends State<DocumentShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Thumbnail placeholder
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surfaceVariant.withOpacity(0.3),
                      colorScheme.surfaceVariant.withOpacity(0.5),
                      colorScheme.surfaceVariant.withOpacity(0.3),
                    ],
                    stops: [
                      0.0,
                      _shimmerController.value,
                      1.0,
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          // Content placeholder
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title placeholder
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return Container(
                      height: 20,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.surfaceVariant.withOpacity(0.3),
                            colorScheme.surfaceVariant.withOpacity(0.5),
                            colorScheme.surfaceVariant.withOpacity(0.3),
                          ],
                          stops: [
                            0.0,
                            _shimmerController.value,
                            1.0,
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Date placeholder
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.surfaceVariant.withOpacity(0.3),
                            colorScheme.surfaceVariant.withOpacity(0.5),
                            colorScheme.surfaceVariant.withOpacity(0.3),
                          ],
                          stops: [
                            0.0,
                            _shimmerController.value,
                            1.0,
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Metadata placeholder
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return Container(
                      height: 14,
                      width: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.surfaceVariant.withOpacity(0.3),
                            colorScheme.surfaceVariant.withOpacity(0.5),
                            colorScheme.surfaceVariant.withOpacity(0.3),
                          ],
                          stops: [
                            0.0,
                            _shimmerController.value,
                            1.0,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

