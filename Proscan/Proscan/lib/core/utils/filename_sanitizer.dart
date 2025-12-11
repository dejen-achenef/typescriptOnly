// core/utils/filename_sanitizer.dart

/// Utility class for sanitizing filenames for safe storage in cloud storage systems.
///
/// Provides methods to sanitize document titles and create safe filenames
/// that are compatible with Supabase Storage and other cloud storage providers.
///
/// **Features:**
/// - Removes invalid characters for file systems
/// - Handles special characters and Unicode
/// - Ensures filename length limits
/// - Preserves readability while ensuring safety
class FilenameSanitizer {
  const FilenameSanitizer._();

  /// Maximum filename length (excluding extension)
  /// Most file systems support 255 characters, but we use 200 for safety
  static const int _maxFilenameLength = 200;

  /// Characters that are invalid in filenames across most file systems
  static const String _invalidChars = r'<>:"/\|?*';

  /// Sanitizes a document title to create a safe filename.
  ///
  /// **Process:**
  /// 1. Removes invalid characters (`<>:"/\|?*`)
  /// 2. Replaces spaces with underscores (or keeps them based on preference)
  /// 3. Truncates to maximum length
  /// 4. Removes leading/trailing dots and spaces
  /// 5. Ensures filename is not empty
  ///
  /// **Parameters:**
  /// - `title`: The document title to sanitize
  /// - `replaceSpaces`: If `true`, replaces spaces with underscores (default: `false`)
  ///
  /// **Returns:**
  /// - A sanitized filename safe for cloud storage
  ///
  /// **Examples:**
  /// ```dart
  /// FilenameSanitizer.sanitize('My Document.pdf') // 'My Document.pdf'
  /// FilenameSanitizer.sanitize('File<>Name?') // 'FileName'
  /// FilenameSanitizer.sanitize('Very Long Title...') // Truncated to 200 chars
  /// ```
  static String sanitize(String title, {bool replaceSpaces = false}) {
    if (title.isEmpty) {
      return 'document';
    }

    // Remove invalid characters
    String sanitized = title;
    for (final char in _invalidChars.split('')) {
      sanitized = sanitized.replaceAll(char, '');
    }

    // Replace or keep spaces based on preference
    if (replaceSpaces) {
      sanitized = sanitized.replaceAll(' ', '_');
    }

    // Remove control characters (0x00-0x1F, 0x7F)
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Remove leading/trailing dots, spaces, and underscores
    sanitized = sanitized.trim().replaceAll(RegExp(r'^[._]+|[._]+$'), '');

    // Truncate to maximum length
    if (sanitized.length > _maxFilenameLength) {
      sanitized = sanitized.substring(0, _maxFilenameLength).trim();
    }

    // Ensure not empty
    if (sanitized.isEmpty) {
      return 'document';
    }

    return sanitized;
  }

  /// Creates a safe filename from a document title with extension.
  ///
  /// **Parameters:**
  /// - `title`: The document title
  /// - `extension`: File extension (e.g., 'pdf', 'docx') - without the dot
  /// - `replaceSpaces`: If `true`, replaces spaces with underscores (default: `false`)
  ///
  /// **Returns:**
  /// - A complete filename: `{sanitized_title}.{extension}`
  ///
  /// **Example:**
  /// ```dart
  /// FilenameSanitizer.createFilename('My Document', 'pdf')
  /// // Returns: 'My Document.pdf'
  /// ```
  static String createFilename(
    String title,
    String extension, {
    bool replaceSpaces = false,
  }) {
    final sanitized = sanitize(title, replaceSpaces: replaceSpaces);
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    return '$sanitized.$ext';
  }

  /// Creates a storage path for Supabase Storage.
  ///
  /// **Format:** `{userId}/{sanitized_filename}`
  ///
  /// **Parameters:**
  /// - `userId`: The user's UUID
  /// - `title`: The document title
  /// - `extension`: File extension (e.g., 'pdf', 'docx')
  /// - `replaceSpaces`: If `true`, replaces spaces with underscores (default: `false`)
  ///
  /// **Returns:**
  /// - Storage path: `{userId}/{sanitized_title}.{extension}`
  ///
  /// **Example:**
  /// ```dart
  /// FilenameSanitizer.createStoragePath('user-123', 'My Document', 'pdf')
  /// // Returns: 'user-123/My Document.pdf'
  /// ```
  static String createStoragePath(
    String userId,
    String title,
    String extension, {
    bool replaceSpaces = false,
  }) {
    final filename = createFilename(title, extension, replaceSpaces: replaceSpaces);
    return '$userId/$filename';
  }

  /// Creates a thumbnail storage path for Supabase Storage.
  ///
  /// **Format:** `{userId}/{sanitized_filename}_thumb.jpg`
  ///
  /// **Parameters:**
  /// - `userId`: The user's UUID
  /// - `title`: The document title
  /// - `replaceSpaces`: If `true`, replaces spaces with underscores (default: `false`)
  ///
  /// **Returns:**
  /// - Storage path: `{userId}/{sanitized_title}_thumb.jpg`
  static String createThumbnailStoragePath(
    String userId,
    String title, {
    bool replaceSpaces = false,
  }) {
    final sanitized = sanitize(title, replaceSpaces: replaceSpaces);
    return '$userId/${sanitized}_thumb.jpg';
  }
}

