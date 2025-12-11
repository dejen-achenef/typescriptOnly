import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:thyscan/core/errors/pdf_exceptions.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart' as settings;

/// Production-ready PDF builder service.
/// 
/// Accepts processed image bytes and builds a complete PDF with:
/// - Metadata enforcement
/// - DPI scaling
/// - White background layer
/// - Compression preset compliance
class PdfBuilder {
  PdfBuilder._();
  static final PdfBuilder instance = PdfBuilder._();

  /// Builds a PDF from processed image bytes.
  /// 
  /// [imageBytesList] - List of JPEG-encoded image bytes (already preprocessed)
  /// [options] - Document save options with metadata, paper size, etc.
  /// [documentTitle] - Fallback title if metadata.title is empty
  /// 
  /// Returns the final PDF as Uint8List bytes.
  Future<Uint8List> build({
    required List<Uint8List> imageBytesList,
    required settings.DocumentSaveOptions options,
    required String documentTitle,
  }) async {
    if (imageBytesList.isEmpty) {
      throw PdfBuildException('Cannot build PDF with no images');
    }

    // Validate options
    options.validate(pageCount: imageBytesList.length);

    // Enforce metadata with fallbacks
    final metadata = _enforceMetadata(options.metadata, documentTitle);

    // Get page format with dynamic margins
    final pageFormat = options.paperSize.format;
    final margin = options.paperSize.suggestedMargin;
    final addWhiteBg = options.addWhiteBackground;

    // Create document with enforced metadata
    final document = pw.Document(
      title: metadata.title,
      author: metadata.author,
      subject: metadata.subject,
      keywords: metadata.keywords.join(','),
      creator: metadata.creator,
    );

    try {
      // Add pages with white background
      for (final imageBytes in imageBytesList) {
        final pageImage = pw.MemoryImage(imageBytes);

        document.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.all(margin),
            build: (_) => pw.Container(
              color: addWhiteBg ? PdfColors.white : null,
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Image(pageImage),
              ),
            ),
          ),
        );
      }

      // Save and return bytes
      final pdfBytes = await document.save();
      
      // Validate final size
      _validatePdfSize(pdfBytes, options.compressionPreset, imageBytesList.length);

      return Uint8List.fromList(pdfBytes);
    } catch (e) {
      if (e is PdfTooLargeException) rethrow;
      throw PdfBuildException('Failed to build PDF', cause: e);
    }
  }

  /// Enforces metadata with fallbacks - title must never be empty.
  settings.PdfMetadata _enforceMetadata(settings.PdfMetadata? metadata, String fallbackTitle) {
    final base = metadata ?? const settings.PdfMetadata();
    
    return base.withFallbacks(
      title: fallbackTitle.isNotEmpty ? fallbackTitle : 'Untitled Document',
      fallbackKeywords: ['scanned', 'document'],
      defaultAuthor: 'ThyScan User',
      defaultSubject: 'Scanned Document',
      defaultCreator: 'ThyScan v1.0',
    );
  }

  /// Validates that the final PDF doesn't exceed size limits.
  void _validatePdfSize(List<int> pdfBytes, settings.PdfCompressionPreset preset, int pageCount) {
    // Max size scales with page count
    final maxBytes = (preset.maxPageSizeMb * 1024 * 1024 * pageCount).round();
    if (pdfBytes.length > maxBytes) {
      throw PdfTooLargeException(
        'PDF size ${(pdfBytes.length / 1024 / 1024).toStringAsFixed(2)}MB '
        'exceeds limit for $preset preset',
      );
    }
  }
}
