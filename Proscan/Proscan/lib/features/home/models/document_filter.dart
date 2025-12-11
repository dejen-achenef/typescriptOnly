import 'package:flutter/material.dart';

/// Model representing a document filter option
class DocumentFilter {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String? scanMode; // null means 'all'

  const DocumentFilter({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.scanMode,
  });

  bool matches(String documentScanMode) {
    if (scanMode == null) return true; // 'All' filter
    return documentScanMode == scanMode;
  }
}

/// Predefined document filters based on actual scan modes
class DocumentFilters {
  static const allFilter = DocumentFilter(
    id: 'all',
    label: 'All',
    icon: Icons.folder_outlined,
    color: Color(0xFF3B82F6),
    scanMode: null,
  );

  static const document = DocumentFilter(
    id: 'document',
    label: 'Scan',
    icon: Icons.document_scanner_rounded,
    color: Color(0xFF3B82F6),
    scanMode: 'document',
  );

  static const idCard = DocumentFilter(
    id: 'idCard',
    label: 'ID Card',
    icon: Icons.credit_card_rounded,
    color: Color(0xFF8B5CF6),
    scanMode: 'idCard',
  );

  static const book = DocumentFilter(
    id: 'book',
    label: 'Book',
    icon: Icons.menu_book_rounded,
    color: Color(0xFFEC4899),
    scanMode: 'book',
  );

  static const slides = DocumentFilter(
    id: 'slides',
    label: 'Slides',
    icon: Icons.slideshow_rounded,
    color: Color(0xFFF59E0B),
    scanMode: 'slides',
  );

  static const excel = DocumentFilter(
    id: 'excel',
    label: 'Excel',
    icon: Icons.grid_on_rounded,
    color: Color(0xFF10B981),
    scanMode: 'excel',
  );

  static const word = DocumentFilter(
    id: 'word',
    label: 'Word',
    icon: Icons.text_fields_rounded,
    color: Color(0xFF6366F1),
    scanMode: 'word',
  );

  static const timestamp = DocumentFilter(
    id: 'timestamp',
    label: 'Timestamp',
    icon: Icons.schedule_rounded,
    color: Color(0xFF8B5CF6),
    scanMode: 'timestamp',
  );

  static const extractText = DocumentFilter(
    id: 'extractText',
    label: 'Extract Text',
    icon: Icons.text_snippet_rounded,
    color: Color(0xFF10B981),
    scanMode: 'extractText',
  );

  static const question = DocumentFilter(
    id: 'question',
    label: 'Question',
    icon: Icons.quiz_rounded,
    color: Color(0xFFE11D48),
    scanMode: 'question',
  );

  static const translate = DocumentFilter(
    id: 'translate',
    label: 'Translate',
    icon: Icons.translate_rounded,
    color: Color(0xFF06B6D4),
    scanMode: 'translate',
  );

  static const scanCode = DocumentFilter(
    id: 'scanCode',
    label: 'Scan Code',
    icon: Icons.qr_code_scanner_rounded,
    color: Color(0xFF14B8A6),
    scanMode: 'scanCode',
  );

  /// List of all available filters
  static const List<DocumentFilter> allFilters = [
    allFilter,
    document,
    idCard,
    book,
    slides,
    excel,
    word,
    timestamp,
    extractText,
    question,
    translate,
    scanCode,
  ];

  /// Get filter by ID
  static DocumentFilter getById(String filterId) {
    return allFilters.firstWhere(
      (filter) => filter.id == filterId,
      orElse: () => allFilter,
    );
  }

  /// Get filter by scan mode
  static DocumentFilter getByScanMode(String scanMode) {
    return allFilters.firstWhere(
      (filter) => filter.scanMode == scanMode,
      orElse: () => document,
    );
  }
}
