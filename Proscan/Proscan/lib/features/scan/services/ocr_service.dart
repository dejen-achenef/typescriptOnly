import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service for extracting text from an [InputImage] using Google ML Kit
/// (offline text recognition) for Translate mode.
class TranslateOcrService {
  TranslateOcrService() : _textRecognizer = TextRecognizer();

  final TextRecognizer _textRecognizer;
  bool _isClosed = false;

  /// Extracts text from an [InputImage].
  ///
  /// Returns the extracted text, or `null` if no text is found.
  /// Throws [Exception] if ML Kit fails for any reason.
  Future<String?> extractText(InputImage inputImage) async {
    if (_isClosed) {
      throw StateError('TranslateOcrService has been disposed');
    }

    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final buffer = StringBuffer();
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
        buffer.writeln();
      }

      final text = buffer.toString().trim();
      if (text.isEmpty) {
        return null;
      }
      return text;
    } catch (e) {
      throw Exception('OCR processing failed: $e');
    }
  }

  /// Releases the underlying ML Kit resources.
  void dispose() {
    if (_isClosed) return;
    _isClosed = true;
    _textRecognizer.close();
  }
}
