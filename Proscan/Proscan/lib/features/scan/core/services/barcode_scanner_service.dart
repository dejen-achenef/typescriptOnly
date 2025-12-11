// features/scan/core/services/barcode_scanner_service.dart
import 'dart:async';
import 'dart:ui'; // [Fixed] Required for Size
import 'dart:io'; // Required for Platform check

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'; // [Fixed] Required for WriteBuffer
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
// ignore: depend_on_referenced_packages
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Service for scanning QR codes and barcodes from camera stream
class BarcodeScannerService {
  final BarcodeScanner _barcodeScanner;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isPaused = false;
  String? _lastDetectedCode;
  DateTime? _lastDetectionTime;

  // Throttling: Only process every N frames (e.g., every 10 frames = ~3-6 FPS)
  static const int _frameSkipCount = 10;
  int _frameCounter = 0;

  // Debouncing: Don't trigger same code within this duration
  static const Duration _debounceDuration = Duration(milliseconds: 2000);

  BarcodeScannerService()
    : _barcodeScanner = BarcodeScanner(
        formats: [
          BarcodeFormat.qrCode,
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.code93,
          BarcodeFormat.codabar,
          BarcodeFormat.itf,
          BarcodeFormat.upca,
          BarcodeFormat.upce,
          BarcodeFormat.pdf417,
          BarcodeFormat.aztec,
          BarcodeFormat.dataMatrix,
        ],
      );

  /// Initialize the barcode scanner
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  /// Process a camera image frame for barcodes
  Future<BarcodeData?> processImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    // Skip if paused (e.g., result modal is showing)
    if (_isPaused || _isProcessing) return null;

    // Throttling: Skip frames
    _frameCounter++;
    if (_frameCounter < _frameSkipCount) {
      return null;
    }
    _frameCounter = 0;

    // Check debouncing: Don't process same code too frequently
    final now = DateTime.now();
    if (_lastDetectedCode != null && _lastDetectionTime != null) {
      final timeSinceLastDetection = now.difference(_lastDetectionTime!);
      if (timeSinceLastDetection < _debounceDuration) {
        return null;
      }
    }

    _isProcessing = true;

    try {
      await initialize();

      // Convert CameraImage to InputImage
      final inputImage = _cameraImageToInputImage(image, camera);
      if (inputImage == null) {
        _isProcessing = false;
        return null;
      }

      // Process the image
      final barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        _isProcessing = false;
        return null;
      }

      // Take the first detected barcode
      final barcode = barcodes.first;
      final rawValue = barcode.rawValue ?? '';

      // Check if this is the same code we just detected
      if (_lastDetectedCode == rawValue && _lastDetectionTime != null) {
        final timeSinceLastDetection = now.difference(_lastDetectionTime!);
        if (timeSinceLastDetection < _debounceDuration) {
          _isProcessing = false;
          return null;
        }
      }

      // Update last detection info
      _lastDetectedCode = rawValue;
      _lastDetectionTime = now;

      // Parse barcode data
      final barcodeData = _parseBarcode(barcode);

      _isProcessing = false;
      return barcodeData;
    } catch (e) {
      _isProcessing = false;
      // Silently fail - don't spam errors for every frame
      return null;
    }
  }

  /// Parse barcode into structured data
  BarcodeData _parseBarcode(Barcode barcode) {
    final rawValue = barcode.rawValue ?? '';
    final type = barcode.type;

    // Determine data type
    BarcodeDataType dataType;
    if (_isUrl(rawValue)) {
      dataType = BarcodeDataType.url;
    } else if (_isEmail(rawValue)) {
      dataType = BarcodeDataType.email;
    } else if (_isPhoneNumber(rawValue)) {
      dataType = BarcodeDataType.phone;
    } else if (_isContact(rawValue)) {
      dataType = BarcodeDataType.contact;
    } else {
      dataType = BarcodeDataType.text;
    }

    return BarcodeData(
      rawValue: rawValue,
      type: type,
      dataType: dataType,
      displayValue: rawValue,
    );
  }

  bool _isUrl(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('www.');
  }

  bool _isEmail(String value) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(value);
  }

  bool _isPhoneNumber(String value) {
    return RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value) &&
        value.replaceAll(RegExp(r'[\s\-\(\)]'), '').length >= 7;
  }

  bool _isContact(String value) {
    // Check for vCard format
    return value.toUpperCase().startsWith('BEGIN:VCARD');
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage? _cameraImageToInputImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageRotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (imageRotation == null) return null;

    final inputImageFormat = InputImageFormatValue.fromRawValue(
      image.format.raw,
    );
    if (inputImageFormat == null) return null;

    // [FIXED] Updated logic for google_mlkit_commons 0.6.0+
    // InputImagePlaneMetadata was removed. We now pass bytesPerRow directly.
    // Note: On Android, we typically use the first plane's bytesPerRow.
    final plane = image.planes.first;

    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: plane.bytesPerRow, // Correct updated property
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  /// Pause processing (e.g., when result modal is showing)
  void pause() {
    _isPaused = true;
  }

  /// Resume processing
  void resume() {
    _isPaused = false;
    // Reset last detection to allow re-scanning the same code
    _lastDetectedCode = null;
    _lastDetectionTime = null;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _barcodeScanner.close();
    _isInitialized = false;
  }
}

/// Data structure for detected barcode information
class BarcodeData {
  final String rawValue;
  final BarcodeType type;
  final BarcodeDataType dataType;
  final String displayValue;

  BarcodeData({
    required this.rawValue,
    required this.type,
    required this.dataType,
    required this.displayValue,
  });
}

/// Enum for barcode data types
enum BarcodeDataType { url, email, phone, contact, text }
