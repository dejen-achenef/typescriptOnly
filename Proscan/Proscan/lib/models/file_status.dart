// models/file_status.dart

/// File validation status for documents
enum FileStatus {
  /// File exists and is valid
  valid,

  /// File is missing (deleted manually)
  missing,

  /// File exists but is corrupted or unreadable
  corrupted,
}

extension FileStatusExtension on FileStatus {
  String get label {
    switch (this) {
      case FileStatus.valid:
        return 'Valid';
      case FileStatus.missing:
        return 'Missing';
      case FileStatus.corrupted:
        return 'Corrupted';
    }
  }

  bool get isProblematic => this != FileStatus.valid;
}

