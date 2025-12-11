import 'package:flutter/material.dart';
import 'package:thyscan/models/document_color_profile.dart';

enum ScanMode {
  slides,
  excel,
  timestamp,
  extractText,
  word,
  document,
  idCard,
  question,
  translate,
  book,
  scanCode;

  String get name => switch (this) {
    slides => 'Slides',
    excel => 'Excel',
    timestamp => 'Timestamp',
    extractText => 'Extract Text',
    word => 'Word',
    document => 'Scan',
    idCard => 'ID Card',
    question => 'Question',
    translate => 'Translate',
    book => 'Book',
    scanCode => 'Scan Code',
  };

  IconData get icon => switch (this) {
    slides => Icons.slideshow_rounded,
    excel => Icons.grid_on_rounded,
    timestamp => Icons.schedule_rounded,
    extractText => Icons.text_snippet_rounded,
    word => Icons.text_fields_rounded,
    document => Icons.document_scanner_rounded,
    idCard => Icons.credit_card_rounded,
    question => Icons.quiz_rounded,
    translate => Icons.translate_rounded,
    book => Icons.menu_book_rounded,
    scanCode => Icons.qr_code_scanner_rounded,
  };

  String get hint => switch (this) {
    slides => 'Capture slide fully',
    excel => 'Align table with grid',
    timestamp => 'Include date/time',
    extractText => 'Capture any text',
    word => 'Place page flat',
    document => 'Align document within frame',
    idCard => 'Center ID card perfectly',
    question => 'Capture question clearly',
    translate => 'Point at text to translate',
    book => 'Open book flat, avoid shadows',
    scanCode => 'Point camera at QR code or barcode',
  };

  bool get showGrid => this == ScanMode.excel || this == ScanMode.slides;
  bool get showIdFrame => this == ScanMode.idCard;
  bool get autoDewarpHint => this == ScanMode.book || this == ScanMode.document;
}

// Add this inside scan_flow_models.dart or a new file
extension ScanModeX on ScanMode {
  IconData get icon => switch (this) {
    ScanMode.document => Icons.document_scanner_rounded,
    ScanMode.idCard => Icons.credit_card_rounded,
    ScanMode.book => Icons.menu_book_rounded,
    ScanMode.excel => Icons.grid_on_rounded,
    ScanMode.slides => Icons.slideshow_rounded,
    ScanMode.word => Icons.description_rounded,
    ScanMode.question => Icons.quiz_rounded,
    ScanMode.translate => Icons.translate_rounded,
    ScanMode.timestamp => Icons.schedule_rounded,
    ScanMode.extractText => Icons.text_snippet_rounded,
    // TODO: Handle this case.
    ScanMode.scanCode => throw UnimplementedError(),
  };

  Color get color => switch (this) {
    ScanMode.document => const Color(0xFF3B82F6),
    ScanMode.idCard => const Color(0xFF8B5CF6),
    ScanMode.book => const Color(0xFFEC4899),
    ScanMode.excel => const Color(0xFF10B981),
    ScanMode.slides => const Color(0xFFF59E0B),
    ScanMode.word => const Color(0xFF6366F1),
    ScanMode.question => const Color(0xFFE11D48),
    ScanMode.translate => const Color(0xFF06B6D4),
    ScanMode.timestamp => const Color(0xFF8B5CF6),
    ScanMode.extractText => const Color(0xFF10B981),
    // TODO: Handle this case.
    ScanMode.scanCode => throw UnimplementedError(),
  };
}

class EditScanArgs {
  final String imagePath;
  final ScanMode initialMode;
  final String? documentId;
  final List<String>? imagePaths;
  final DocumentColorProfile colorProfile;
  final String? documentTitle;

  const EditScanArgs({
    required this.imagePath,
    required this.initialMode,
    this.colorProfile = DocumentColorProfile.color,
    this.documentId,
    this.imagePaths,
    this.documentTitle,
  });
}

class CameraScreenConfig {
  final ScanMode initialMode;
  final bool restrictToInitialMode;
  final bool returnCapturePath;
  final DocumentColorProfile colorProfile;

  const CameraScreenConfig({
    this.initialMode = ScanMode.document,
    this.restrictToInitialMode = false,
    this.returnCapturePath = false,
    this.colorProfile = DocumentColorProfile.color,
  });
}

class CameraCaptureResult {
  CameraCaptureResult({required this.imagePath, required this.colorProfile});

  final String imagePath;
  final DocumentColorProfile colorProfile;
}
