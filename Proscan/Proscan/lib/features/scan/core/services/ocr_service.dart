// features/scan/core/services/ocr_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Unified singleton service for extracting text from images using Google ML Kit Text Recognition.
/// 
/// IMPORTANT: This service ONLY processes captured image files, NOT live camera streams.
/// Heavy ML processing should never run on preview frames - only on still images after capture.
class OcrService {
  static OcrService? _instance;
  static OcrService get instance {
    _instance ??= OcrService._();
    return _instance!;
  }

  OcrService._();

  TextRecognizer? _textRecognizer;
  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Initialize the text recognizer (lazy initialization)
  Future<void> _ensureInitialized() async {
    if (_isInitialized || _isDisposed) return;
    
    try {
      _textRecognizer = TextRecognizer();
      _isInitialized = true;
      AppLogger.info('OcrService initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize OcrService', error: e);
      rethrow;
    }
  }

  /// Extract text from an image file path (captured image, not camera stream)
  /// 
  /// Returns the extracted text, or null if no text is found or an error occurs.
  /// 
  /// This method ONLY works with file paths - never call with camera stream frames.
  Future<String?> extractTextFromFile(String imagePath) async {
    if (_isDisposed) {
      throw StateError('OcrService has been disposed');
    }

    try {
      await _ensureInitialized();

      // Verify file exists
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist: $imagePath');
      }

      AppLogger.info('Starting OCR extraction from file', data: {'path': imagePath});

      // Create InputImage from file path (NOT from camera stream)
      final inputImage = InputImage.fromFilePath(imagePath);

      // Process the image - ML Kit handles its own threading
      final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);

      // Extract all text blocks efficiently using StringBuffer
      final buffer = StringBuffer();
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
        buffer.writeln(); // Extra line between blocks
      }

      // Clean up the text (remove extra newlines)
      String extractedText = buffer.toString().trim();
      
      // Normalize multiple newlines to double newline
      extractedText = extractedText.replaceAll(RegExp(r'\n{3,}'), '\n\n');

      // Return null if no text was found
      if (extractedText.isEmpty) {
        AppLogger.info('No text found in image', data: {'path': imagePath});
        return null;
      }

      AppLogger.info('OCR extraction completed', data: {
        'path': imagePath,
        'textLength': extractedText.length,
      });

      return extractedText;
    } catch (e, stack) {
      AppLogger.error('OCR processing failed', error: e, stack: stack, data: {'path': imagePath});
      throw Exception('OCR processing failed: $e');
    }
  }

  /// Extract text from an image file with detailed information
  /// 
  /// Returns a map with 'text' and 'blocks' information, or null if no text found.
  Future<Map<String, dynamic>?> extractTextWithDetails(String imagePath) async {
    if (_isDisposed) {
      throw StateError('OcrService has been disposed');
    }

    try {
      await _ensureInitialized();

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist: $imagePath');
      }

      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);

      String extractedText = '';
      List<Map<String, dynamic>> blocks = [];

      for (TextBlock block in recognizedText.blocks) {
        String blockText = '';
        List<Map<String, dynamic>> lines = [];

        for (TextLine line in block.lines) {
          blockText += line.text + '\n';
          lines.add({
            'text': line.text,
            'boundingBox': {
              'left': line.boundingBox.left,
              'top': line.boundingBox.top,
              'right': line.boundingBox.right,
              'bottom': line.boundingBox.bottom,
            },
          });
        }

        extractedText += blockText + '\n';
        blocks.add({
          'text': blockText.trim(),
          'lines': lines,
          'boundingBox': {
            'left': block.boundingBox.left,
            'top': block.boundingBox.top,
            'right': block.boundingBox.right,
            'bottom': block.boundingBox.bottom,
          },
        });
      }

      extractedText = extractedText.trim();

      if (extractedText.isEmpty) {
        return null;
      }

      return {
        'text': extractedText,
        'blocks': blocks,
      };
    } catch (e, stack) {
      AppLogger.error('OCR extraction with details failed', error: e, stack: stack, data: {'path': imagePath});
      throw Exception('OCR processing failed: $e');
    }
  }

  /// Dispose resources - call this when the service is no longer needed
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _textRecognizer?.close();
    _textRecognizer = null;
    _isInitialized = false;
    
    AppLogger.info('OcrService disposed');
  }
}
