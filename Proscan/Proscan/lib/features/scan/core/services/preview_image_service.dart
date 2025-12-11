// features/scan/core/services/preview_image_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Service for generating and caching downscaled preview images from originals.
///
/// Previews are used for UI display to reduce memory pressure, while keeping
/// original full-resolution images for OCR, export, and image processing.
class PreviewImageService {
  /// Maximum dimension (width or height) for preview images in pixels.
  /// Larger images will be scaled down proportionally to fit within this limit.
  static const int maxPreviewDimension = 1600;

  PreviewImageService._();

  static final PreviewImageService instance = PreviewImageService._();

  /// Gets or creates a preview image path for the given original image path.
  ///
  /// If a preview already exists and is up-to-date, returns its path immediately.
  /// Otherwise, generates a new downscaled preview, saves it to disk, and returns the path.
  ///
  /// The preview is generated in an isolate to avoid blocking the UI thread.
  ///
  /// Throws [Exception] if the original file doesn't exist or preview generation fails.
  Future<String> getOrCreatePreviewPath(String originalPath) async {
    try {
      final originalFile = File(originalPath);
      if (!await originalFile.exists()) {
        throw Exception('Original image does not exist: $originalPath');
      }

      // Get modification time to check if preview is stale
      final originalModified = await originalFile.lastModified();

      // Generate preview path in temporary directory
      final dir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(originalPath);
      final ext = p.extension(originalPath).toLowerCase();
      final previewPath = p.join(
        dir.path,
        'previews',
        '${baseName}_preview$ext',
      );

      // Create previews directory if it doesn't exist
      final previewDir = Directory(p.dirname(previewPath));
      if (!await previewDir.exists()) {
        await previewDir.create(recursive: true);
      }

      final previewFile = File(previewPath);

      // Check if preview exists and is up-to-date
      if (await previewFile.exists()) {
        try {
          final previewModified = await previewFile.lastModified();
          // If preview is newer than or equal to original, use it
          if (previewModified.isAfter(originalModified) ||
              previewModified.isAtSameMomentAs(originalModified)) {
            AppLogger.info(
              'Using existing preview',
              data: {'path': previewPath},
            );
            return previewPath;
          }
        } catch (e) {
          // If we can't check modification time, regenerate preview
          AppLogger.warning(
            error: null,
            'Could not check preview modification time, regenerating',
            data: {'error': e.toString()},
          );
        }
      }

      // Generate new preview
      AppLogger.info('Generating preview', data: {'original': originalPath});
      final bytes = await originalFile.readAsBytes();

      final resizedBytes = await compute<_ResizeParams, Uint8List>(
        _resizeImageIsolate,
        _ResizeParams(bytes, maxPreviewDimension),
      );

      await previewFile.writeAsBytes(resizedBytes, flush: true);

      // Set modification time to match original for future checks
      try {
        await previewFile.setLastModified(originalModified);
      } catch (_) {
        // Ignore errors setting modification time - not critical
      }

      AppLogger.info(
        'Preview generated successfully',
        data: {'path': previewPath, 'size': resizedBytes.length},
      );
      
      // Clean up old preview files periodically
      _cleanupOldPreviewFiles(previewDir);
      
      return previewPath;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to get or create preview',
        error: e,
        stack: stack,
        data: {'originalPath': originalPath},
      );
      rethrow;
    }
  }

  /// Cleans up old preview files
  /// Keeps the most recent N files and deletes files older than 24 hours
  static Future<void> _cleanupOldPreviewFiles(Directory previewDir) async {
    try {
      if (!await previewDir.exists()) return;

      final files = previewDir
          .listSync()
          .whereType<File>()
          .where((file) => p.basename(file.path).endsWith('_preview.jpg') ||
              p.basename(file.path).endsWith('_preview.png'))
          .toList();

      if (files.isEmpty) return;

      // Sort by modification time (newest first)
      files.sort((a, b) {
        try {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        } catch (_) {
          return 0;
        }
      });

      const keepCount = 50; // Keep more previews as they're smaller
      final now = DateTime.now();
      const maxAge = Duration(hours: 24);

      int deleted = 0;
      for (int i = keepCount; i < files.length; i++) {
        final file = files[i];
        try {
          final modified = await file.lastModified();
          if (now.difference(modified) > maxAge) {
            await file.delete();
            deleted++;
          }
        } catch (_) {
          // Ignore errors deleting individual files
        }
      }

      if (deleted > 0) {
        AppLogger.info(
          'Cleaned up old preview files',
          data: {'deleted': deleted},
        );
      }
    } catch (e) {
      AppLogger.warning('Failed to cleanup old preview files', error: e);
    }
  }

  /// Clears all cached preview images.
  ///
  /// Useful for freeing disk space or forcing regeneration of previews.
  Future<void> clearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      final previewDir = Directory(p.join(dir.path, 'previews'));
      if (await previewDir.exists()) {
        await previewDir.delete(recursive: true);
        AppLogger.info('Preview cache cleared');
      }
    } catch (e, stack) {
      AppLogger.error('Failed to clear preview cache', error: e, stack: stack);
    }
  }

  /// Gets the cached preview path without generating if it doesn't exist.
  ///
  /// Returns the preview path if it exists, null otherwise.
  Future<String?> getCachedPreviewPath(String originalPath) async {
    try {
      final dir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(originalPath);
      final ext = p.extension(originalPath).toLowerCase();
      final previewPath = p.join(
        dir.path,
        'previews',
        '${baseName}_preview$ext',
      );

      final previewFile = File(previewPath);
      if (await previewFile.exists()) {
        return previewPath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Parameters for the isolate function that resizes images.
class _ResizeParams {
  final Uint8List bytes;
  final int maxDim;

  _ResizeParams(this.bytes, this.maxDim);
}

/// Isolate entry point for resizing images.
///
/// This runs in a separate isolate to avoid blocking the UI thread.
Uint8List _resizeImageIsolate(_ResizeParams params) {
  try {
    // Decode the original image
    final original = img.decodeImage(params.bytes);
    if (original == null) {
      throw Exception('Failed to decode image for preview');
    }

    final w = original.width;
    final h = original.height;
    final maxDim = params.maxDim;

    // If image is already small enough, just re-encode with compression
    if (w <= maxDim && h <= maxDim) {
      // Re-encode as JPEG with good quality for smaller file size
      return Uint8List.fromList(img.encodeJpg(original, quality: 90));
    }

    // Calculate scale factor to fit within max dimension
    final scale = w > h ? maxDim / w : maxDim / h;
    final newWidth = (w * scale).round();
    final newHeight = (h * scale).round();

    // Resize the image
    final resized = img.copyResize(
      original,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );

    // Encode as JPEG with good quality
    return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
  } catch (e) {
    throw Exception('Failed to resize image: $e');
  }
}
