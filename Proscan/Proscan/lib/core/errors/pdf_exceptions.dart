class PdfTooLargeException implements Exception {
  const PdfTooLargeException(this.message);
  final String message;

  @override
  String toString() => 'PdfTooLargeException($message)';
}

class InvalidMetadataException implements Exception {
  const InvalidMetadataException(this.message);
  final String message;

  @override
  String toString() => 'InvalidMetadataException($message)';
}

class UnsupportedPageSizeException implements Exception {
  const UnsupportedPageSizeException(this.message);
  final String message;

  @override
  String toString() => 'UnsupportedPageSizeException($message)';
}

class ImageProcessingException implements Exception {
  const ImageProcessingException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'ImageProcessingException($message, cause: $cause)';
}

class PreprocessingException implements Exception {
  const PreprocessingException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'PreprocessingException($message, cause: $cause)';
}

class PdfBuildException implements Exception {
  const PdfBuildException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'PdfBuildException($message, cause: $cause)';
}

