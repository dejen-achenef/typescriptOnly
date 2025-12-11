import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:thyscan/core/errors/pdf_exceptions.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';

class PdfGenerationProgress {
  const PdfGenerationProgress({
    required this.processedPages,
    required this.totalPages,
    required this.stage,
  });

  final int processedPages;
  final int totalPages;
  final String stage;

  double get percent =>
      totalPages == 0 ? 0 : processedPages / totalPages.clamp(1, totalPages);
}

class PdfGenerationResult {
  const PdfGenerationResult({
    required this.pdfPath,
    required this.optimizedImagePaths,
    required this.elapsed,
  });

  final String pdfPath;
  final List<String> optimizedImagePaths;
  final Duration elapsed;
}

class PdfGenerationService {
  PdfGenerationService._();
  static final PdfGenerationService instance = PdfGenerationService._();

  Future<PdfGenerationResult> generate({
    required List<String> imagePaths,
    required String outputPdfPath,
    required String optimizedDirPath,
    required String documentId,
    String batchId = '',
    PdfGenerationConfig config = const PdfGenerationConfig(),
    void Function(PdfGenerationProgress progress)? onProgress,
  }) async {
    if (imagePaths.isEmpty) {
      throw ArgumentError('imagePaths cannot be empty');
    }

    final outputFile = File(outputPdfPath);
    await outputFile.parent.create(recursive: true);

    final optimizedDir = Directory(optimizedDirPath);
    await optimizedDir.create(recursive: true);

    final receivePort = ReceivePort();
    final stopwatch = Stopwatch()..start();

    final payload = _PdfIsolatePayload(
      sendPort: receivePort.sendPort,
      imagePaths: imagePaths,
      outputPdfPath: outputPdfPath,
      optimizedDirPath: optimizedDir.path,
      documentId: documentId,
      batchId: batchId.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : batchId,
      maxPageSizeBytes: (config.maxPageSizeMb * 1024 * 1024).round(),
      addWhiteBackground: config.addWhiteBackground,
      pageWidth: config.pageWidth,
      pageHeight: config.pageHeight,
      margin: config.margin,
      metadata: config.metadata == null
          ? null
          : _PdfMetadataPayload(
              title: config.metadata!.title,
              author: config.metadata!.author,
              subject: config.metadata!.subject,
              keywords: config.metadata!.keywords,
              creator: config.metadata!.creator,
            ),
    );

    final isolate = await Isolate.spawn<_PdfIsolatePayload>(
      _pdfGenerationEntry,
      payload,
      debugName: 'pdf_generation_isolate',
    );

    final completer = Completer<PdfGenerationResult>();

    receivePort.listen((message) {
      if (message is _PdfProgressMessage) {
        onProgress?.call(
          PdfGenerationProgress(
            processedPages: message.processed,
            totalPages: message.total,
            stage: message.stage,
          ),
        );
      } else if (message is _PdfCompleteMessage) {
        if (!completer.isCompleted) {
          completer.complete(
            PdfGenerationResult(
              pdfPath: message.pdfPath,
              optimizedImagePaths: message.optimizedPaths,
              elapsed: stopwatch.elapsed,
            ),
          );
        }
        receivePort.close();
        isolate.kill(priority: Isolate.immediate);
      } else if (message is _PdfErrorMessage) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(message.message));
        }
        receivePort.close();
        isolate.kill(priority: Isolate.immediate);
      }
    });

    return completer.future;
  }
}

class _PdfIsolatePayload {
  const _PdfIsolatePayload({
    required this.sendPort,
    required this.imagePaths,
    required this.outputPdfPath,
    required this.optimizedDirPath,
    required this.documentId,
    required this.batchId,
    required this.maxPageSizeBytes,
    required this.addWhiteBackground,
    required this.pageWidth,
    required this.pageHeight,
    required this.margin,
    this.metadata,
  });

  final SendPort sendPort;
  final List<String> imagePaths;
  final String outputPdfPath;
  final String optimizedDirPath;
  final String documentId;
  final String batchId;
  final int maxPageSizeBytes;
  final bool addWhiteBackground;
  final double pageWidth;
  final double pageHeight;
  final double margin;
  final _PdfMetadataPayload? metadata;
}

class _PdfProgressMessage {
  const _PdfProgressMessage(this.processed, this.total, this.stage);

  final int processed;
  final int total;
  final String stage;
}

class _PdfCompleteMessage {
  const _PdfCompleteMessage(this.pdfPath, this.optimizedPaths);

  final String pdfPath;
  final List<String> optimizedPaths;
}

class _PdfErrorMessage {
  const _PdfErrorMessage(this.message);
  final String message;
}

class _PdfMetadataPayload {
  const _PdfMetadataPayload({
    this.title,
    this.author,
    this.subject,
    this.keywords = const [],
    this.creator,
  });

  final String? title;
  final String? author;
  final String? subject;
  final List<String> keywords;
  final String? creator;
}

Future<void> _pdfGenerationEntry(_PdfIsolatePayload payload) async {
  final sendPort = payload.sendPort;
  try {
    final optimizedPaths = <String>[];
    final metadata = payload.metadata;
    final document = pw.Document(
      title: metadata?.title,
      author: metadata?.author,
      subject: metadata?.subject,
      keywords: metadata?.keywords.join(','),
      creator: metadata?.creator,
    );
    final pageFormat = PdfPageFormat(payload.pageWidth, payload.pageHeight);

    for (int i = 0; i < payload.imagePaths.length; i++) {
      final optimizedPath = await _compressAndSave(
        sourcePath: payload.imagePaths[i],
        optimizedDirPath: payload.optimizedDirPath,
        documentId: payload.documentId,
        batchId: payload.batchId,
        pageIndex: i,
        maxBytes: payload.maxPageSizeBytes,
      );
      optimizedPaths.add(optimizedPath);

      final imageBytes = await File(optimizedPath).readAsBytes();
      final pageImage = pw.MemoryImage(imageBytes);

      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(payload.margin),
          build: (_) => pw.Container(
            color: payload.addWhiteBackground ? PdfColors.white : null,
            child: pw.FittedBox(
              fit: pw.BoxFit.contain,
              child: pw.Image(pageImage),
            ),
          ),
        ),
      );

      sendPort.send(
        _PdfProgressMessage(i + 1, payload.imagePaths.length, 'pages'),
      );
    }

    final file = File(payload.outputPdfPath);
    await file.writeAsBytes(await document.save(), flush: true);
    sendPort.send(
      _PdfProgressMessage(
        payload.imagePaths.length,
        payload.imagePaths.length,
        'finalizing',
      ),
    );
    sendPort.send(_PdfCompleteMessage(file.path, optimizedPaths));
  } catch (e) {
    sendPort.send(_PdfErrorMessage('PDF generation error: $e'));
  }
}

Future<String> _compressAndSave({
  required String sourcePath,
  required String optimizedDirPath,
  required String documentId,
  required String batchId,
  required int pageIndex,
  required int maxBytes,
}) async {
  final file = File(sourcePath);
  if (!await file.exists()) {
    throw Exception('Source image missing: $sourcePath');
  }
  final inputBytes = await file.readAsBytes();
  final decodedImage = img.decodeImage(inputBytes);
  if (decodedImage == null) {
    throw Exception('Unable to decode image: $sourcePath');
  }

  img.Image decoded = _normalizeOrientation(decodedImage);

  int quality = 95;
  double scale = 1.0;
  Uint8List encoded = _encodeWithQuality(decoded, quality);

  while (encoded.length > maxBytes && (quality > 55 || scale > 0.5)) {
    if (quality > 55) {
      quality -= 5;
    } else {
      scale = max(0.5, scale - 0.1);
      decoded = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }
    encoded = _encodeWithQuality(decoded, quality);
  }

  if (encoded.length > maxBytes) {
    throw PdfTooLargeException(
      'Unable to compress page $pageIndex below ${maxBytes ~/ 1024}KB.',
    );
  }

  final optimizedName = '${documentId}_${batchId}_page_$pageIndex.jpg';
  final optimizedPath = p.join(optimizedDirPath, optimizedName);
  final optimizedFile = File(optimizedPath);
  await optimizedFile.writeAsBytes(encoded, flush: true);
  return optimizedPath;
}

img.Image _normalizeOrientation(img.Image source) {
  {
    // This single line fixes ALL orientation issues on iOS & Android
    // It reads EXIF, rotates the image correctly, and removes the tag
    return img.bakeOrientation(source);
  }
}

Uint8List _encodeWithQuality(img.Image image, int quality) {
  return Uint8List.fromList(
    img.encodeJpg(image, quality: quality.clamp(40, 95)),
  );
}
