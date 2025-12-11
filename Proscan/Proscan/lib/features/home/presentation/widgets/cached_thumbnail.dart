import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:thyscan/core/services/document_download_service.dart';
import 'package:thyscan/core/services/thumbnail_cache_service.dart';

class CachedThumbnail extends StatelessWidget {
  const CachedThumbnail({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  final String path;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return placeholder ?? const SizedBox.shrink();
    }

    // Check if path is a URL
    final isUrl = path.startsWith('http://') || path.startsWith('https://');

    return FutureBuilder<String?>(
      future: isUrl ? _downloadAndGetLocalPath() : Future.value(path),
      builder: (context, pathSnapshot) {
        if (pathSnapshot.connectionState == ConnectionState.waiting) {
          return placeholder ??
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: borderRadius ?? BorderRadius.circular(12),
                ),
              );
        }

        final localPath = pathSnapshot.data ?? path;
        if (localPath.isEmpty) {
          return placeholder ?? const SizedBox.shrink();
        }

        return FutureBuilder<Uint8List?>(
          future: ThumbnailCacheService.instance.load(localPath),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final image = Image.memory(snapshot.data!, fit: fit);

              if (borderRadius != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: image,
                );
              }
              return image;
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return placeholder ??
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: borderRadius ?? BorderRadius.circular(12),
                    ),
                  );
            }

            // Fallback: show placeholder if decoding failed
            return placeholder ??
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: borderRadius ?? BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.image_not_supported_outlined),
                );
          },
        );
      },
    );
  }

  Future<String?> _downloadAndGetLocalPath() async {
    try {
      // Extract document ID from URL
      final uri = Uri.parse(path);
      final pathSegments = uri.pathSegments;
      final documentId = pathSegments.isNotEmpty
          ? pathSegments.last.split('.').first
          : 'temp_${path.hashCode}';

      final downloadedPath = await DocumentDownloadService.instance
          .downloadThumbnail(
        url: path,
        documentId: documentId,
      );

      return downloadedPath;
    } catch (e) {
      return null;
    }
  }
}
