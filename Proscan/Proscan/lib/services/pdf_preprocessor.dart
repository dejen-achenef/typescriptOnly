import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/errors/pdf_exceptions.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/resource_guard.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';

class PdfPreprocessor {
  PdfPreprocessor._();

  static final PdfPreprocessor instance = PdfPreprocessor._();

  Future<List<String>> preprocess({
    required List<String> imagePaths,
    PdfDpi dpi = PdfDpi.dpi300,
  }) async {
    if (imagePaths.isEmpty) return const [];

    final memorySafe = !ResourceGuard.instance.hasSufficientMemory(
      minFreeMb: dpi == PdfDpi.dpi300 ? 400 : 250,
    );
    final maxDimension = memorySafe ? 2000 : 2500;
    final dpiCap = dpi == PdfDpi.dpi150 ? 2000 : maxDimension;
    final quality = memorySafe ? 82 : 90;

    final tempDir = await getTemporaryDirectory();
    final results = <String>[];

    for (final path in imagePaths) {
      try {
        final processedPath = await compute<_PreprocessPayload, String>(
          _preprocessImage,
          _PreprocessPayload(
            sourcePath: path,
            outputDir: tempDir.path,
            maxDimension: dpiCap,
            jpegQuality: quality,
          ),
        );
        results.add(processedPath);
      } on ImageProcessingException catch (e) {
        throw PreprocessingException('Failed to preprocess $path', cause: e);
      } catch (e) {
        throw PreprocessingException(
          'Unknown preprocessing error for $path',
          cause: e,
        );
      }
    }

    // Clean up old preprocessed files after operation
    _cleanupOldPreprocessedFiles(tempDir);

    return results;
  }

  /// Cleans up old preprocessed image files
  /// Keeps the most recent N files and deletes files older than 24 hours
  static Future<void> _cleanupOldPreprocessedFiles(
    Directory tempDir,
  ) async {
    try {
      if (!await tempDir.exists()) return;

      final files = tempDir
          .listSync()
          .whereType<File>()
          .where((file) => p.basename(file.path).startsWith('pre_'))
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

      const keepCount = 20; // Keep more preprocessed files
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
          'Cleaned up old preprocessed files',
          data: {'deleted': deleted},
        );
      }
    } catch (e) {
      AppLogger.warning('Failed to cleanup old preprocessed files', error: e);
    }
  }
}

class _PreprocessPayload {
  const _PreprocessPayload({
    required this.sourcePath,
    required this.outputDir,
    required this.maxDimension,
    required this.jpegQuality,
  });

  final String sourcePath;
  final String outputDir;
  final int maxDimension;
  final int jpegQuality;
}

String _preprocessImage(_PreprocessPayload payload) {
  final file = File(payload.sourcePath);
  if (!file.existsSync()) {
    throw ImageProcessingException(
      'Source image not found: ${payload.sourcePath}',
    );
  }

  final bytes = file.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw ImageProcessingException(
      'Unable to decode image: ${payload.sourcePath}',
    );
  }

  img.Image image = img.bakeOrientation(decoded);

  final longest = image.width > image.height ? image.width : image.height;
  if (longest > payload.maxDimension) {
    final scale = payload.maxDimension / longest;
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  final clampedQuality = payload.jpegQuality.clamp(70, 95);
  Uint8List encoded;
  try {
    encoded = Uint8List.fromList(img.encodeJpg(image, quality: clampedQuality));
  } catch (e) {
    throw ImageProcessingException('Failed to encode image', cause: e);
  }

  final fileName =
      'pre_${DateTime.now().microsecondsSinceEpoch}_${p.basename(payload.sourcePath)}';
  final outputPath = p.join(payload.outputDir, fileName);
  File(outputPath).writeAsBytesSync(encoded, flush: true);
  return outputPath;
}
