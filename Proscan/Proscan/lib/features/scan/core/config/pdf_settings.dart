// features/scan/core/config/pdf_settings.dart
//
// Shared configuration objects for PDF generation and document persistence.

import 'package:pdf/pdf.dart';
import 'package:thyscan/core/errors/pdf_exceptions.dart';

enum PdfCompressionPreset { economy, balanced, archival }

extension PdfCompressionPresetX on PdfCompressionPreset {
  double get maxPageSizeMb => switch (this) {
    PdfCompressionPreset.economy => 0.9,
    PdfCompressionPreset.balanced => 1.9,
    PdfCompressionPreset.archival => 3.0,
  };
}

enum PdfPaperSize { a4, letter, legal }

extension PdfPaperSizeX on PdfPaperSize {
  PdfPageFormat get format => switch (this) {
    PdfPaperSize.a4 => PdfPageFormat.a4,
    PdfPaperSize.letter => PdfPageFormat.letter,
    PdfPaperSize.legal => PdfPageFormat(
      8.5 * PdfPageFormat.inch,
      14 * PdfPageFormat.inch,
    ),
  };

  double get suggestedMargin => switch (this) {
    PdfPaperSize.a4 => 24,
    PdfPaperSize.letter => 28,
    PdfPaperSize.legal => 32,
  };
}

class PdfMetadata {
  const PdfMetadata({
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

  PdfMetadata withFallbacks({
    required String title,
    List<String>? fallbackKeywords,
    String defaultAuthor = 'ThyScan Platform',
    String defaultSubject = 'Digitized Document',
    String defaultCreator = 'ThyScan Scanner',
  }) {
    return PdfMetadata(
      title: this.title ?? title,
      author: author ?? defaultAuthor,
      subject: subject ?? defaultSubject,
      keywords: keywords.isNotEmpty ? keywords : (fallbackKeywords ?? const []),
      creator: creator ?? defaultCreator,
    );
  }

  Map<String, String> toDocumentMap() {
    final map = <String, String>{};
    if ((title ?? '').isNotEmpty) map['title'] = title!;
    if ((author ?? '').isNotEmpty) map['author'] = author!;
    if ((subject ?? '').isNotEmpty) map['subject'] = subject!;
    if ((creator ?? '').isNotEmpty) map['creator'] = creator!;
    if (keywords.isNotEmpty) map['keywords'] = keywords.join(',');
    return map;
  }

  PdfDocumentMetadata toPdfDocumentMetadata() => PdfDocumentMetadata(
    title: title,
    author: author,
    subject: subject,
    keywords: keywords,
    creator: creator,
  );
}

class PdfDocumentMetadata {
  const PdfDocumentMetadata({
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

class PdfGenerationConfig {
  const PdfGenerationConfig({
    this.maxPageSizeMb = 1.9,
    this.pageWidth = 595.28,
    this.pageHeight = 841.89,
    this.margin = 24,
    this.addWhiteBackground = true,
    this.metadata,
  });

  final double maxPageSizeMb;
  final double pageWidth;
  final double pageHeight;
  final double margin;
  final bool addWhiteBackground;
  final PdfDocumentMetadata? metadata;

  PdfGenerationConfig copyWith({
    double? maxPageSizeMb,
    double? pageWidth,
    double? pageHeight,
    double? margin,
    bool? addWhiteBackground,
    PdfDocumentMetadata? metadata,
  }) {
    return PdfGenerationConfig(
      maxPageSizeMb: maxPageSizeMb ?? this.maxPageSizeMb,
      pageWidth: pageWidth ?? this.pageWidth,
      pageHeight: pageHeight ?? this.pageHeight,
      margin: margin ?? this.margin,
      addWhiteBackground: addWhiteBackground ?? this.addWhiteBackground,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum PdfDpi {
  dpi150(150),
  dpi300(300);

  const PdfDpi(this.value);
  final int value;

  double get scaleFactor => value / 72.0;
}

class DocumentSaveOptions {
  const DocumentSaveOptions({
    this.compressionPreset = PdfCompressionPreset.balanced,
    this.paperSize = PdfPaperSize.a4,
    this.metadata,
    this.tags,
    this.addWhiteBackground = true,
    this.dpi = PdfDpi.dpi300,
  });

  final PdfCompressionPreset compressionPreset;
  final PdfPaperSize paperSize;
  final PdfMetadata? metadata;
  final List<String>? tags;
  final bool addWhiteBackground;
  final PdfDpi dpi;

  DocumentSaveOptions copyWith({
    PdfCompressionPreset? compressionPreset,
    PdfPaperSize? paperSize,
    PdfMetadata? metadata,
    List<String>? tags,
    bool? addWhiteBackground,
    PdfDpi? dpi,
  }) {
    return DocumentSaveOptions(
      compressionPreset: compressionPreset ?? this.compressionPreset,
      paperSize: paperSize ?? this.paperSize,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
      addWhiteBackground: addWhiteBackground ?? this.addWhiteBackground,
      dpi: dpi ?? this.dpi,
    );
  }

  static DocumentSaveOptions enterpriseDefaults({
    String? title,
    List<String>? tags,
    PdfCompressionPreset compressionPreset = PdfCompressionPreset.balanced,
    PdfPaperSize paperSize = PdfPaperSize.a4,
    PdfDpi dpi = PdfDpi.dpi300,
  }) {
    return DocumentSaveOptions(
      compressionPreset: compressionPreset,
      paperSize: paperSize,
      metadata: PdfMetadata(
        title: title,
        subject: 'Digitized Document',
        author: 'ThyScan Platform',
        keywords: tags ?? const [],
        creator: 'ThyScan Scanner',
      ),
      tags: tags,
      dpi: dpi,
    );
  }

  void validate({required int pageCount}) {
    final meta = metadata ?? const PdfMetadata();
    if ((meta.title ?? '').length > 120) {
      throw InvalidMetadataException('Document title exceeds 120 characters.');
    }
    if ((meta.author ?? '').length > 80) {
      throw InvalidMetadataException('Author metadata is too long.');
    }

    if (!PdfPaperSize.values.contains(paperSize)) {
      throw UnsupportedPageSizeException(
        'Paper size $paperSize is not supported.',
      );
    }

    if (compressionPreset == PdfCompressionPreset.archival && pageCount > 150) {
      throw PdfTooLargeException(
        'Archival preset is not recommended for more than 150 pages.',
      );
    }

    if (compressionPreset == PdfCompressionPreset.economy && pageCount < 2) {
      throw PdfTooLargeException(
        'Economy preset is ineffective for single-page documents.',
      );
    }
  }
}
