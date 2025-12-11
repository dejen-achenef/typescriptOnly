enum StorageErrorType {
  diskFull,
  permissionDenied,
  fileCorrupted,
  notFound,
  insufficientMemory,
  unknown,
}

class DocumentStorageException implements Exception {
  const DocumentStorageException({
    required this.message,
    this.documentId,
    this.type = StorageErrorType.unknown,
    this.cause,
  });

  final String message;
  final String? documentId;
  final StorageErrorType type;
  final Object? cause;

  @override
  String toString() =>
      'DocumentStorageException(type: $type, documentId: $documentId, message: $message)';
}

class DiskSpaceException extends DocumentStorageException {
  const DiskSpaceException({required super.message, super.documentId})
    : super(type: StorageErrorType.diskFull);
}
