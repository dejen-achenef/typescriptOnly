// models/document_model.dart
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/file_status.dart';

part 'document_model.g.dart';

/// Document model representing a scanned or created document.
///
/// This model is used for both local storage (Hive) and cloud synchronization.
/// It supports PDF and DOCX formats with metadata, tags, and thumbnails.
///
/// **Fields:**
/// - `id`: Unique document identifier (UUID)
/// - `title`: Document title/name
/// - `filePath`: Local file path or Supabase Storage URL
/// - `format`: Document format ('pdf' or 'docx')
/// - `pageCount`: Number of pages in the document
/// - `scanMode`: Type of scan ('document', 'idCard', 'book', etc.)
/// - `colorProfile`: Color processing mode ('color', 'grayscale', 'blackwhite')
/// - `tags`: List of tags for categorization
/// - `metadata`: Additional metadata as key-value pairs
@HiveType(typeId: 0)
class DocumentModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String filePath;

  @HiveField(3)
  final String format;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final int pageCount;

  @HiveField(6)
  final String thumbnailPath;

  @HiveField(7, defaultValue: <String>[])
  final List<String>? _pageImagePaths; // Internal nullable field

  @HiveField(8, defaultValue: 'document')
  final String scanMode;

  @HiveField(9, defaultValue: '')
  final String? textContent; // For text/docx documents

  @HiveField(10)
  final DateTime updatedAt;

  @HiveField(11, defaultValue: 'color')
  final String colorProfile;

  @HiveField(12, defaultValue: <String>[])
  final List<String>? _tags;

  @HiveField(13, defaultValue: <String, String>{})
  final Map<String, String>? _metadata;

  @HiveField(14, defaultValue: false)
  final bool isDeleted;

  @HiveField(15, defaultValue: null)
  final DateTime? deletedAt;

  /// Public getter that guarantees non-null list of page image paths.
  /// Returns empty list if null.
  List<String> get pageImagePaths => _pageImagePaths ?? [];

  /// Gets the color profile as an enum for type-safe operations.
  DocumentColorProfile get colorProfileEnum =>
      DocumentColorProfile.fromKey(colorProfile);

  /// Gets tags list, returns empty list if null.
  List<String> get tags => _tags ?? const [];

  /// Gets metadata map, returns empty map if null.
  Map<String, String> get metadata => _metadata ?? const {};

  DocumentModel({
    required this.id,
    required this.title,
    required this.filePath,
    required this.format,
    required this.createdAt,
    required this.pageCount,
    required this.thumbnailPath,
    this.scanMode = 'document',
    this.textContent,
    required this.updatedAt,
    this.colorProfile = 'color',
    List<String>? pageImagePaths,
    List<String>? tags,
    Map<String, String>? metadata,
    this.isDeleted = false,
    this.deletedAt,
  }) : _pageImagePaths = pageImagePaths,
       _tags = tags,
       _metadata = metadata;
  /// Creates a copy of this document with the given fields replaced with new values.
  ///
  /// All fields are optional. If a field is not provided, the original value is used.
  ///
  /// **Example:**
  /// ```dart
  /// final updated = document.copyWith(
  ///   title: 'New Title',
  ///   updatedAt: DateTime.now(),
  /// );
  /// ```
  DocumentModel copyWith({
    String? id,
    String? title,
    String? filePath,
    String? format,
    DateTime? createdAt,
    int? pageCount,
    String? thumbnailPath,
    String? scanMode,
    String? textContent,
    List<String>? pageImagePaths,
    DateTime? updatedAt,
    String? colorProfile,
    List<String>? tags,
    Map<String, String>? metadata,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      createdAt: createdAt ?? this.createdAt,
      pageCount: pageCount ?? this.pageCount,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      scanMode: scanMode ?? this.scanMode,
      textContent: textContent ?? this.textContent,
      updatedAt: updatedAt ?? this.updatedAt,
      colorProfile: colorProfile ?? this.colorProfile,
      pageImagePaths: pageImagePaths ?? this.pageImagePaths,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Checks if this document has a valid file path.
  bool get hasValidFilePath => filePath.isNotEmpty;

  /// Checks if this document has a thumbnail.
  bool get hasThumbnail => thumbnailPath.isNotEmpty;

  /// Gets a display-friendly file size (if available from metadata).
  String? get displayFileSize => metadata['fileSize'];

  /// Gets the document author (if available from metadata).
  String? get author => metadata['author'];

  /// Gets the document subject (if available from metadata).
  String? get subject => metadata['subject'];

  /// Checks if the main file exists and is valid (bulletproof validation)
  /// Returns true only if file exists and is readable
  bool get hasValidFile {
    if (filePath.isEmpty) return false;
    
    // If it's a URL (cloud document), consider it valid (can be re-downloaded)
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return true;
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;
      
      // Check if file is readable (not corrupted)
      final stat = file.statSync();
      return stat.size > 0;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the thumbnail exists and is valid (bulletproof validation)
  /// Returns true only if thumbnail exists and is readable
  bool get hasValidThumbnail {
    if (thumbnailPath.isEmpty) return false;
    
    // If it's a URL (cloud thumbnail), consider it valid (can be re-downloaded)
    if (thumbnailPath.startsWith('http://') || 
        thumbnailPath.startsWith('https://')) {
      return true;
    }

    try {
      final file = File(thumbnailPath);
      if (!file.existsSync()) return false;
      
      // Check if file is readable (not corrupted)
      final stat = file.statSync();
      return stat.size > 0;
    } catch (_) {
      return false;
    }
  }

  /// Gets the file status (valid/missing/corrupted)
  /// Performs actual file system check
  FileStatus get fileStatus {
    if (filePath.isEmpty) return FileStatus.missing;
    
    // Cloud documents are always considered valid (can be re-downloaded)
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return FileStatus.valid;
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) return FileStatus.missing;
      
      // Check if file is readable
      try {
        final stat = file.statSync();
        if (stat.size == 0) return FileStatus.corrupted;
        
        // Try to read first byte to verify file is not corrupted
        final raf = file.openSync();
        raf.readByteSync();
        raf.closeSync();
        
        return FileStatus.valid;
      } catch (_) {
        return FileStatus.corrupted;
      }
    } catch (_) {
      return FileStatus.missing;
    }
  }

  /// Gets the thumbnail status (valid/missing/corrupted)
  FileStatus get thumbnailStatus {
    if (thumbnailPath.isEmpty) return FileStatus.missing;
    
    // Cloud thumbnails are always considered valid (can be re-downloaded)
    if (thumbnailPath.startsWith('http://') || 
        thumbnailPath.startsWith('https://')) {
      return FileStatus.valid;
    }

    try {
      final file = File(thumbnailPath);
      if (!file.existsSync()) return FileStatus.missing;
      
      // Check if file is readable
      try {
        final stat = file.statSync();
        if (stat.size == 0) return FileStatus.corrupted;
        return FileStatus.valid;
      } catch (_) {
        return FileStatus.corrupted;
      }
    } catch (_) {
      return FileStatus.missing;
    }
  }

  /// Checks if this is a cloud document (URL-based)
  bool get isCloudDocument =>
      filePath.startsWith('http://') || filePath.startsWith('https://');

  /// Checks if file needs re-download (cloud document with missing local file)
  bool get needsRedownload =>
      isCloudDocument && !hasValidFile;
}
