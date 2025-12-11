// features/scan/presentation/screens/smart_camera_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/features/scan/core/edge_detector.dart';
import 'package:thyscan/features/scan/core/services/barcode_scanner_service.dart';
import 'package:thyscan/features/scan/presentation/widgets/barcode_result_sheet.dart';
import 'package:thyscan/features/scan/presentation/widgets/loading_overlay.dart';
import 'package:thyscan/features/scan/providers/translation_provider.dart';
import 'package:flutter/services.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/providers/timestamp_provider.dart';

import '../../model/scan_flow_models.dart';
import 'edge_overlay.dart';

// Helper function to call async functions without awaiting
void unawaited(Future<void> future) {
  // Intentionally not awaiting - fire and forget
}

class CameraSettings {
  bool autoCapture;
  bool orientation;
  bool grid;
  bool sound;
  bool autoCrop;

  CameraSettings({
    this.autoCapture = false,
    this.orientation = true,
    this.grid = true,
    this.sound = true,
    this.autoCrop = true,
  });

  CameraSettings copyWith({
    bool? autoCapture,
    bool? orientation,
    bool? grid,
    bool? sound,
    bool? autoCrop,
  }) {
    return CameraSettings(
      autoCapture: autoCapture ?? this.autoCapture,
      orientation: orientation ?? this.orientation,
      grid: grid ?? this.grid,
      sound: sound ?? this.sound,
      autoCrop: autoCrop ?? this.autoCrop,
    );
  }
}

enum EdgeGuidanceState { scanning, holding, ready }

class SmartCameraScreen extends ConsumerStatefulWidget {
  final ScanMode initialMode;
  final bool restrictToInitialMode;
  final bool returnCapturePath;
  final DocumentColorProfile initialColorProfile;

  const SmartCameraScreen({
    super.key,
    this.initialMode = ScanMode.document,
    this.restrictToInitialMode = false,
    this.returnCapturePath = false,
    this.initialColorProfile = DocumentColorProfile.color,
  });

  @override
  ConsumerState<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends ConsumerState<SmartCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _isBusy = false;
  FlashMode _flashMode = FlashMode.auto;
  late ScanMode _currentMode;
  late final List<ScanMode> _availableModes;
  CameraSettings _settings = CameraSettings();
  late DocumentColorProfile _colorProfile;

  // Camera switching
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  final EdgeDetector _edgeDetector = EdgeDetector();
  List<ui.Offset>? _detectedEdges;
  EdgeGuidanceState _edgeGuidanceState = EdgeGuidanceState.scanning;
  Timer? _edgeGuidanceDebounce;

  // Barcode scanning
  final BarcodeScannerService _barcodeScannerService = BarcodeScannerService();
  bool _isBarcodeResultShowing = false;

  // Live analysis throttling - ensures only one frame is processed at a time
  bool _isAnalyzing = false;
  DateTime? _lastAnalysisTime;
  static const Duration _minAnalysisInterval = Duration(milliseconds: 750); // Increased to reduce buffer pressure
  
  // Frame skipping to reduce buffer accumulation - process every 5th frame
  int _frameSkipCounter = 0;
  static const int _framesToSkip = 4; // Process every 5th frame (skip 4, process 1)

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _colorProfile = widget.initialColorProfile;
    _availableModes = widget.restrictToInitialMode
        ? [widget.initialMode]
        : ScanMode.values;
    WidgetsBinding.instance.addObserver(this);

    // CRITICAL: Initialize edge detector as soon as possible
    unawaited(_edgeDetector.ensureInitialized());

    _initFuture = _initCamera(preserveIndex: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopImageStreamIfNeeded());
    _controller?.dispose();
    _edgeDetector.dispose();
    unawaited(_barcodeScannerService.dispose());
    _edgeGuidanceDebounce?.cancel();
    // Reset analysis state on dispose
    _isAnalyzing = false;
    _lastAnalysisTime = null;
    _frameSkipCounter = 0;
    super.dispose();
  }

  /// CRITICAL: Override didUpdateWidget to prevent memory leaks when scan mode changes
  /// This is the ONLY safe place to handle widget updates - setState/initState won't catch mode changes
  /// When initialMode changes, we MUST stop the old ImageAnalysis analyzer immediately
  /// before starting a new one, otherwise the old analyzer keeps running → memory leak → crash
  @override
  void didUpdateWidget(SmartCameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // CRITICAL: Check if initialMode changed - this is the root cause of memory leaks
    if (oldWidget.initialMode != widget.initialMode) {
      // Immediately stop the old image stream to prevent memory leak
      // This MUST happen synchronously before any other operations
      // We can't await in didUpdateWidget, but we trigger the stop immediately
      // and the stream will be stopped before we start a new one
      _stopImageStreamIfNeeded().then((_) {
        // Only proceed if widget is still mounted after stopping stream
        if (!mounted) return;
        
        // Update current mode to match new initialMode
        setState(() {
          _currentMode = widget.initialMode;
          _detectedEdges = null;
        });
        
        // Handle barcode scanning mode changes
        if (oldWidget.initialMode == ScanMode.scanCode && 
            widget.initialMode != ScanMode.scanCode) {
          // Switching away from barcode mode
          _barcodeScannerService.resume();
          _isBarcodeResultShowing = false;
        } else if (widget.initialMode == ScanMode.scanCode && 
                   oldWidget.initialMode != ScanMode.scanCode) {
          // Switching to barcode mode - ensure it's ready
          _barcodeScannerService.initialize().then((_) {
            if (mounted) {
              _barcodeScannerService.resume();
              _isBarcodeResultShowing = false;
            }
          });
        }
        
        // Apply mode-specific camera settings
        if (_controller != null && _controller!.value.isInitialized) {
          _applyModeSettings();
        }
        
        // Start new image stream if new mode needs live analysis
        // This MUST happen after stopping the old stream (which we just did above)
        if (_controller != null && 
            _controller!.value.isInitialized &&
            !_controller!.value.isStreamingImages &&
            _modeNeedsLiveAnalysis(widget.initialMode)) {
          _startImageStream();
        }
      });
    }
    
    // Update color profile if it changed
    if (oldWidget.initialColorProfile != widget.initialColorProfile && mounted) {
      setState(() {
        _colorProfile = widget.initialColorProfile;
      });
    }
  }

  /// Starts the image stream for live analysis
  /// 
  /// This method is idempotent - it will return early if:
  /// - Controller is null or not initialized
  /// - Stream is already running
  /// - Mode doesn't need live analysis
  /// - Widget is not mounted
  Future<void> _startImageStream() async {
    // Early exit checks - must be first
    if (_controller == null || 
        !_controller!.value.isInitialized || 
        _controller!.value.isStreamingImages ||
        !mounted) {
      return;
    }

    // Only start stream if current mode needs live analysis
    if (!_modeNeedsLiveAnalysis(_currentMode)) {
      return;
    }

    await _controller!.startImageStream((image) async {
      // CRITICAL: Return immediately for early exits to allow buffer cleanup
      // The camera plugin manages image lifecycle automatically when callback completes quickly
      
      // Early exit checks - must be first to prevent unnecessary processing
      if (!mounted || 
          _controller == null || 
          !_controller!.value.isInitialized || 
          _isBusy) {
        return; // Return immediately - plugin will release buffer
      }

      // Handle barcode scanning mode (has its own internal throttling)
      if (_currentMode == ScanMode.scanCode && !_isBarcodeResultShowing) {
        final barcodeData = await _barcodeScannerService.processImage(
          image,
          _controller!.description,
        );

        if (barcodeData != null && mounted && !_isBarcodeResultShowing) {
          // Trigger haptic feedback
          HapticFeedback.heavyImpact();

          // Show result sheet
          _showBarcodeResult(barcodeData);
        }
        return; // Return immediately - plugin will release buffer
      }

      // Frame skipping: Process every Nth frame to reduce buffer pressure
      _frameSkipCounter++;
      if (_frameSkipCounter <= _framesToSkip) {
        return; // Skip this frame immediately - plugin will release buffer
      }
      _frameSkipCounter = 0; // Reset counter

      // Throttle edge detection - ensure only one analysis runs at a time
      // Check if analysis is already in progress
      if (_isAnalyzing) {
        return; // Skip this frame immediately - plugin will release buffer
      }

      // Check if minimum interval has passed since last analysis
      final now = DateTime.now();
      if (_lastAnalysisTime != null) {
        final timeSinceLastAnalysis = now.difference(_lastAnalysisTime!);
        if (timeSinceLastAnalysis < _minAnalysisInterval) {
          return; // Skip this frame immediately - plugin will release buffer
        }
      }

      // Double-check mounted and controller state before starting analysis
      if (!mounted || 
          _controller == null || 
          !_controller!.value.isInitialized) {
        return;
      }

      // Start analysis - mark as analyzing
      _isAnalyzing = true;

      try {
        // Perform edge detection on this frame
        final edges = await _edgeDetector.detect(
          image,
          _currentMode,
          _controller!.description,
        );

        // Final safety check before updating UI
        if (!mounted || 
            _controller == null || 
            !_controller!.value.isInitialized) {
          return;
        }

        // Update UI state with detected edges
        setState(() {
          _detectedEdges = edges;
        });

        _updateEdgeGuidance(edges != null && edges.length == 4);

        // Auto-capture when edges are detected and auto-capture is enabled
        if (_settings.autoCapture &&
            edges != null &&
            edges.length == 4 &&
            !_isBusy) {
          // Add a small delay to ensure edges are stable
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted &&
              !_isBusy &&
              _controller != null &&
              _controller!.value.isInitialized &&
              _detectedEdges != null &&
              _detectedEdges!.length == 4) {
            unawaited(_capture());
          }
        }
      } catch (e) {
        // Silently handle errors - don't spam logs for expected exceptions
        // The EdgeDetector already handles errors internally
      } finally {
        // Always reset the analyzing flag and update timestamp
        // This ensures we can process the next frame even if an error occurred
        _isAnalyzing = false;
        _lastAnalysisTime = DateTime.now();
      }
    });
  }

  /// Stops the image stream and resets analysis state
  /// This should be called when:
  /// - Mode doesn't need live analysis
  /// - App goes to background
  /// - Screen is disposed
  /// - Navigating away from camera screen
  Future<void> _stopImageStreamIfNeeded() async {
    if (_controller == null) return;
    
    // Stop the image stream if it's running
    if (_controller!.value.isStreamingImages) {
      try {
        await _controller!.stopImageStream();
      } catch (_) {
        // Silently handle errors - stream may already be stopped
      }
    }
    
    // Reset analysis state when stream stops
    _isAnalyzing = false;
    _lastAnalysisTime = null;
    _frameSkipCounter = 0;
  }

  /// Determines if a scan mode requires live image stream analysis
  /// 
  /// Returns true for modes that need continuous edge detection or barcode scanning:
  /// - document, idCard, book, excel, slides: Need edge detection for alignment
  /// - scanCode: Needs live barcode scanning
  /// - timestamp, question: Need edge detection for document alignment
  /// 
  /// Returns false for modes that only process captured images:
  /// - extractText, word, translate: Only run OCR after capture
  bool _modeNeedsLiveAnalysis(ScanMode mode) {
    switch (mode) {
      case ScanMode.document:
      case ScanMode.idCard:
      case ScanMode.book:
      case ScanMode.excel:
      case ScanMode.slides:
      case ScanMode.scanCode:
      case ScanMode.timestamp:
      case ScanMode.question:
        return true;
      case ScanMode.extractText:
      case ScanMode.word:
      case ScanMode.translate:
        return false;
    }
  }

  void _updateEdgeGuidance(bool hasStableEdges) {
    if (hasStableEdges) {
      if (_edgeGuidanceState != EdgeGuidanceState.ready) {
        setState(() => _edgeGuidanceState = EdgeGuidanceState.holding);
      }
      _edgeGuidanceDebounce ??= Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _edgeGuidanceState = EdgeGuidanceState.ready;
          _edgeGuidanceDebounce = null;
        });
      });
    } else {
      _edgeGuidanceDebounce?.cancel();
      _edgeGuidanceDebounce = null;
      if (_edgeGuidanceState != EdgeGuidanceState.scanning && mounted) {
        setState(() => _edgeGuidanceState = EdgeGuidanceState.scanning);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    
    // Stop image stream and ML analysis when app goes to background/inactive
    if (state == AppLifecycleState.inactive || 
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_stopImageStreamIfNeeded());
      
      // Dispose controller if app is going away completely
      if (state == AppLifecycleState.inactive && c != null && c.value.isInitialized) {
        unawaited(c.dispose());
      }
    } 
    // Only restart camera when app resumes AND we're still mounted
    else if (state == AppLifecycleState.resumed && mounted) {
      // Reinitialize camera only if it was disposed
      if (c == null || !c.value.isInitialized) {
        _initFuture = _initCamera(preserveIndex: true);
      }
    }
  }

  Future<void> _initCamera({required bool preserveIndex}) async {
    _cameras = await availableCameras();

    if (!preserveIndex || _cameraIndex >= _cameras.length) {
      final backIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _cameraIndex = backIdx != -1 ? backIdx : 0;
    }

    // Use high instead of max to reduce frame size and improve
    // live analysis (edge detection / barcode) performance.
    _controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.jpeg
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();

    // Initialize edge detector (lightweight, doesn't start processing yet)
    await _edgeDetector.ensureInitialized();

    // Only start image stream if the current mode needs live analysis
    // This prevents unnecessary ML processing for modes like translate/extractText
    if (_modeNeedsLiveAnalysis(_currentMode) && mounted) {
      await _startImageStream();
    }

    final isFront =
        _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;
    _flashMode = isFront ? FlashMode.off : _flashMode;

    try {
      await _controller!.setFlashMode(_flashMode);
    } catch (_) {
      _flashMode = FlashMode.off;
    }

    await _applyModeSettings();
    if (mounted) setState(() {});
  }

  Future<void> _applyModeSettings() async {
    if (_controller == null) return;

    if (_currentMode == ScanMode.idCard || _currentMode == ScanMode.book) {
      await _controller!.setFocusMode(FocusMode.locked);
      await _controller!.setExposureMode(ExposureMode.locked);
    } else {
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
    }
  }

  Future<void> _changeMode(ScanMode mode) async {
    if (!_availableModes.contains(mode) || !mounted) return;

    final previousMode = _currentMode;
    final previousModeNeededLiveAnalysis = _modeNeedsLiveAnalysis(previousMode);
    final newModeNeedsLiveAnalysis = _modeNeedsLiveAnalysis(mode);

    // Handle mode switching for barcode scanning
    if (previousMode == ScanMode.scanCode && mode != ScanMode.scanCode) {
      // Switching away from barcode mode
      _barcodeScannerService.resume();
      _isBarcodeResultShowing = false;
    } else if (mode == ScanMode.scanCode && previousMode != ScanMode.scanCode) {
      // Switching to barcode mode - ensure it's ready
      await _barcodeScannerService.initialize();
      _barcodeScannerService.resume();
      _isBarcodeResultShowing = false;
    }

    // Update mode
    setState(() {
      _currentMode = mode;
      _detectedEdges = null;
    });

    // Stop or start image stream based on mode requirements
    if (previousModeNeededLiveAnalysis && !newModeNeedsLiveAnalysis) {
      // Switching FROM a mode that needs live analysis TO one that doesn't
      // Stop the image stream to save resources
      await _stopImageStreamIfNeeded();
    } else if (!previousModeNeededLiveAnalysis && newModeNeedsLiveAnalysis) {
      // Switching FROM a mode that doesn't need live analysis TO one that does
      // Start the image stream if controller is ready
      if (_controller != null && 
          _controller!.value.isInitialized && 
          !_controller!.value.isStreamingImages &&
          mounted) {
        await _startImageStream();
      }
    }
    // If both modes need live analysis or both don't, stream state stays the same

    await _applyModeSettings();
  }

  void _showBarcodeResult(BarcodeData barcodeData) {
    if (_isBarcodeResultShowing || !mounted) return;

    setState(() {
      _isBarcodeResultShowing = true;
    });

    // Pause barcode scanning while showing result
    _barcodeScannerService.pause();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BarcodeResultSheet(
        barcodeData: barcodeData,
        onDismiss: () {
          Navigator.of(context).pop();
          // Resume scanning after dismissing
          setState(() {
            _isBarcodeResultShowing = false;
          });
          _barcodeScannerService.resume();
        },
      ),
    ).then((_) {
      // Ensure we resume even if dismissed by other means
      if (mounted) {
        setState(() {
          _isBarcodeResultShowing = false;
        });
        _barcodeScannerService.resume();
      }
    });
  }

  Future<void> _toggleFlash() async {
    final modes = [FlashMode.auto, FlashMode.off, FlashMode.always];
    final next = modes[(modes.indexOf(_flashMode) + 1) % modes.length];
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (_) {
      _flashMode = FlashMode.off;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Flash not supported')));
      }
    }
  }

  Future<void> _capture() async {
    if (_isBusy || _controller == null) return;
    setState(() => _isBusy = true);

    try {
      final xFile = await _controller!.takePicture();
      final dir = await getTemporaryDirectory();
      final filename =
          '${_currentMode.name.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${dir.path}/$filename';
      await File(xFile.path).copy(path);

      if (!mounted) return;

      // Apply timestamp overlay only in Timestamp mode
      await _applyTimestampIfNeeded(path);
      await _applyColorProfileIfNeeded(path);
      if (!mounted) return;

      final captureResult = CameraCaptureResult(
        imagePath: path,
        colorProfile: _colorProfile,
      );

      // Stop image stream before navigating away to prevent ML from running in background
      // This is critical for performance and resource management
      await _stopImageStreamIfNeeded();

      // Translate mode flow – OCR -> Translate -> Navigate
      // IMPORTANT: OCR only runs on captured image file, never on preview stream
      if (_currentMode == ScanMode.translate) {
        await LoadingOverlay.runWithDelay<void>(
          context: context,
          message: 'Scanning & translating…',
          action: () => ref
              .read(translationProvider.notifier)
              .processImageFile(path),
        );

        if (!mounted) return;

        // Navigate to translation editor screen which consumes translationProvider
        context.push('/translationeditorscreen');
        return;
      }

      // Handle Extract Text mode differently
      if (_currentMode == ScanMode.extractText) {
        // Navigate to text editor screen with OCR processing
        context.push('/texteditorscreen', extra: {'imagePath': path});
      } else if (widget.returnCapturePath) {
        context.pop(captureResult);
      } else {
        context.push(
          '/editscanscreen',
          extra: EditScanArgs(
            imagePath: path,
            initialMode: _currentMode,
            colorProfile: _colorProfile,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      final dir = await getTemporaryDirectory();
      final filename = 'gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${dir.path}/$filename';
      await File(file.path).copy(path);

      if (!mounted) return;

      // Apply timestamp overlay only in Timestamp mode
      await _applyTimestampIfNeeded(path);
      await _applyColorProfileIfNeeded(path);
      if (!mounted) return;

      final captureResult = CameraCaptureResult(
        imagePath: path,
        colorProfile: _colorProfile,
      );

      // Stop image stream before navigating away to prevent ML from running in background
      await _stopImageStreamIfNeeded();

      // Translate mode flow for gallery images – OCR -> Translate -> Navigate
      // IMPORTANT: OCR only runs on captured image file, never on preview stream
      if (_currentMode == ScanMode.translate) {
        await LoadingOverlay.runWithDelay<void>(
          context: context,
          message: 'Scanning & translating…',
          action: () => ref
              .read(translationProvider.notifier)
              .processImageFile(path),
        );

        if (!mounted) return;

        context.push('/translationeditorscreen');
        return;
      }

      // Handle Extract Text mode differently
      if (_currentMode == ScanMode.extractText) {
        // Navigate to text editor screen with OCR processing
        context.push('/texteditorscreen', extra: {'imagePath': path});
      } else if (widget.returnCapturePath) {
        context.pop(captureResult);
      } else {
        context.push(
          '/editscanscreen',
          extra: EditScanArgs(
            imagePath: path,
            initialMode: _currentMode,
            colorProfile: _colorProfile,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gallery error: $e')));
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.isEmpty) return;

    try {
      final currentLens = _cameras[_cameraIndex].lensDirection;
      final desired = currentLens == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final idx = _cameras.indexWhere((c) => c.lensDirection == desired);
      final newIndex = idx != -1 ? idx : (_cameraIndex + 1) % _cameras.length;

      await _stopImageStreamIfNeeded();
      await _controller?.dispose();

      // Use high instead of max to reduce frame size and improve
      // live analysis (edge detection / barcode) performance.
      _controller = CameraController(
        _cameras[newIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );
      _cameraIndex = newIndex;
      await _controller!.initialize();
      await _startImageStream();

      final isFront =
          _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;
      _flashMode = isFront ? FlashMode.off : FlashMode.auto;
      try {
        await _controller!.setFlashMode(_flashMode);
      } catch (_) {
        _flashMode = FlashMode.off;
      }

      await _applyModeSettings();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Switch failed: $e')));
      }
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      builder: (_) => CameraSettingsSheet(
        settings: _settings,
        onSettingsChanged: (s) => setState(() => _settings = s),
      ),
    );
  }

  /// Applies a timestamp overlay to the image at [path] when the current
  /// scan mode is [ScanMode.timestamp]. Processing happens in memory and,
  /// if it exceeds 600ms, a non‑dismissible loading dialog is shown.
  Future<void> _applyTimestampIfNeeded(String path) async {
    if (_currentMode != ScanMode.timestamp) return;

    final controller = ref.read(timestampControllerProvider.notifier);

    bool dialogShown = false;
    var completed = false;

    // After 600ms, show a blocking loading dialog if processing is still running.
    final timer = Timer(const Duration(milliseconds: 600), () {
      if (!completed && mounted) {
        dialogShown = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.5),
          builder: (ctx) => const _TimestampLoadingDialog(),
        );
      }
    });

    try {
      final bytes = await File(path).readAsBytes();
      final stampedBytes = await controller.addTimestamp(bytes);
      completed = true;
      timer.cancel();

      // Close the dialog if it was shown.
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Overwrite the file with the stamped image.
      await File(path).writeAsBytes(stampedBytes, flush: true);
    } catch (_) {
      completed = true;
      timer.cancel();

      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      // Fail silently here; the caller will still navigate with the
      // original image if processing fails.
    }
  }

  Future<void> _applyColorProfileIfNeeded(String path) async {
    if (_colorProfile == DocumentColorProfile.color) return;
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      final filtered = _applyProfileFilter(decoded, _colorProfile);
      final encoded = img.encodeJpg(filtered, quality: 95);
      await File(path).writeAsBytes(encoded, flush: true);
    } catch (_) {
      // Silently ignore filter failures to avoid interrupting the flow.
    }
  }

  Widget _buildFilteredPreview() {
    if (_controller == null) {
      return const SizedBox.shrink();
    }
    final preview = CameraPreview(_controller!);
    final filter = _previewFilterForProfile(_colorProfile);
    if (filter == null) return preview;
    return ColorFiltered(colorFilter: filter, child: preview);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _currentMode.name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _flashMode == FlashMode.off
                      ? Icons.flash_off_rounded
                      : _flashMode == FlashMode.auto
                      ? Icons.flash_auto_rounded
                      : Icons.flash_on_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              onPressed: _toggleFlash,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              onPressed: _showSettings,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          FutureBuilder(
            future: _initFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done ||
                  _controller == null ||
                  !_controller!.value.isInitialized) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              return SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.previewSize!.height,
                    height: _controller!.value.previewSize!.width,
                    child: _buildFilteredPreview(),
                  ),
                ),
              );
            },
          ),

          // GLOWING EDGES — NOW WORKING 100%
          if (_detectedEdges != null && _detectedEdges!.length == 4)
            Positioned.fill(
              child: IgnorePointer(
                child: EdgeOverlay(
                  points: _detectedEdges!,
                  size: MediaQuery.of(context).size,
                ),
              ),
            ),

          // Mode overlays
          if (_currentMode.showGrid && _settings.grid) const _GridOverlay(),
          if (_currentMode.showIdFrame) const _IDCardOverlay(),
          if (_currentMode.autoDewarpHint) const _DewarpHint(),

          // Hint
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 80),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Text(
                _currentMode.hint,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 150),
              child: _EdgeGuidanceChip(state: _edgeGuidanceState),
            ),
          ),

          // Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: const BoxDecoration(
                color: Colors.black,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black, Colors.black],
                  stops: [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          // Mode selector
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 140),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ColorProfileSelector(
                    selected: _colorProfile,
                    onChanged: (profile) {
                      setState(() => _colorProfile = profile);
                    },
                  ),
                  const SizedBox(height: 8),
                  _ModeSelector(
                    currentMode: _currentMode,
                    onModeChanged: _changeMode,
                    colorScheme: colorScheme,
                    modes: _availableModes,
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundIconButton(
                  icon: Icons.photo_library_rounded,
                  tooltip: 'Gallery',
                  onTap: _pickFromGallery,
                ),
                const SizedBox(width: 16),
                _ShutterButton(
                  onTap: _capture,
                  isBusy: _isBusy,
                  colorScheme: colorScheme,
                ),
                const SizedBox(width: 16),
                _RoundIconButton(
                  icon: Icons.cameraswitch_rounded,
                  tooltip: 'Switch camera',
                  onTap: _switchCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorProfileSelector extends StatelessWidget {
  const _ColorProfileSelector({
    required this.selected,
    required this.onChanged,
  });

  final DocumentColorProfile selected;
  final ValueChanged<DocumentColorProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profiles = DocumentColorProfile.values;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: profiles.map((profile) {
          final isSelected = profile == selected;
          return ChoiceChip(
            label: Text(profile.label),
            selected: isSelected,
            selectedColor: colorScheme.primary.withValues(alpha: 0.2),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.6)
                  : Colors.white24,
            ),
            onSelected: (_) => onChanged(profile),
          );
        }).toList(),
      ),
    );
  }
}

// Settings Sheet
class CameraSettingsSheet extends StatefulWidget {
  final CameraSettings settings;
  final ValueChanged<CameraSettings> onSettingsChanged;

  const CameraSettingsSheet({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<CameraSettingsSheet> createState() => _CameraSettingsSheetState();
}

class _CameraSettingsSheetState extends State<CameraSettingsSheet> {
  late CameraSettings _currentSettings;

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.settings;
  }

  void _updateSetting(bool value, String field) {
    setState(() {
      _currentSettings = _currentSettings.copyWith(
        autoCapture: field == 'autoCapture'
            ? value
            : _currentSettings.autoCapture,
        orientation: field == 'orientation'
            ? value
            : _currentSettings.orientation,
        grid: field == 'grid' ? value : _currentSettings.grid,
        sound: field == 'sound' ? value : _currentSettings.sound,
        autoCrop: field == 'autoCrop' ? value : _currentSettings.autoCrop,
      );
    });
    widget.onSettingsChanged(_currentSettings);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Camera Settings',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure your camera preferences',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _SettingsItem(
                title: 'Auto Capture',
                subtitle: 'Automatically capture when document is detected',
                value: _currentSettings.autoCapture,
                onChanged: (value) => _updateSetting(value, 'autoCapture'),
              ),
              _SettingsItem(
                title: 'Orientation',
                subtitle: 'Adjust orientation automatically',
                value: _currentSettings.orientation,
                onChanged: (value) => _updateSetting(value, 'orientation'),
              ),
              _SettingsItem(
                title: 'Grid Overlay',
                subtitle: 'Show grid lines for better alignment',
                value: _currentSettings.grid,
                onChanged: (value) => _updateSetting(value, 'grid'),
              ),
              _SettingsItem(
                title: 'Sound',
                subtitle: 'Play shutter sound when capturing',
                value: _currentSettings.sound,
                onChanged: (value) => _updateSetting(value, 'sound'),
              ),
              _SettingsItem(
                title: 'Auto Crop',
                subtitle: 'Automatically crop scanned documents',
                value: _currentSettings.autoCrop,
                onChanged: (value) => _updateSetting(value, 'autoCrop'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Settings Item Widget
class _SettingsItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsItem({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

// Text-only Mode Selector with Horizontal Scrolling
class _ModeSelector extends StatelessWidget {
  final ScanMode currentMode;
  final Function(ScanMode) onModeChanged;
  final ColorScheme colorScheme;
  final List<ScanMode> modes;

  const _ModeSelector({
    required this.currentMode,
    required this.onModeChanged,
    required this.colorScheme,
    required this.modes,
  });

  @override
  Widget build(BuildContext context) {
    if (modes.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: modes.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final mode = modes[index];
          final isSelected = currentMode == mode;

          return GestureDetector(
            onTap: () => onModeChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: Colors.white.withValues(alpha: 0.5))
                    : null,
              ),
              child: Center(
                child: Text(
                  mode.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Overlays
class _GridOverlay extends StatelessWidget {
  const _GridOverlay();
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.cyanAccent.withValues(alpha: 0.8),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CustomPaint(painter: _GridPainter(), size: const Size(300, 400)),
      ),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    for (double i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _IDCardOverlay extends StatelessWidget {
  const _IDCardOverlay();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 320,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.8),
          width: 3,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.credit_card_rounded,
        size: 50,
        color: Colors.orange.withValues(alpha: 0.7),
      ),
    ),
  );
}

class _DewarpHint extends StatelessWidget {
  const _DewarpHint();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Container(
      margin: const EdgeInsets.only(top: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            "Auto Dewarp Enabled",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

// Shutter Button
class _ShutterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isBusy;
  final ColorScheme colorScheme;

  const _ShutterButton({
    required this.onTap,
    required this.isBusy,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: isBusy ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isBusy ? 70 : 80,
      height: isBusy ? 70 : 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isBusy ? Colors.white38 : Colors.white,
          width: isBusy ? 3 : 4,
        ),
        color: isBusy ? Colors.white24 : Colors.transparent,
        boxShadow: isBusy
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isBusy ? Colors.transparent : Colors.white,
          boxShadow: isBusy
              ? null
              : [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: isBusy
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              )
            : null,
      ),
    ),
  );
}

// Small round icon buttons (Gallery, Switch camera)
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

/// Non‑dismissible modal dialog shown while timestamp processing takes longer
/// than 600ms. Back button is disabled until processing completes.
class _TimestampLoadingDialog extends StatelessWidget {
  const _TimestampLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  'Embedding timestamp…',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EdgeGuidanceChip extends StatelessWidget {
  const _EdgeGuidanceChip({required this.state});

  final EdgeGuidanceState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ready = state == EdgeGuidanceState.ready;
    final holding = state == EdgeGuidanceState.holding;

    Color bg;
    IconData icon;
    String label;
    Color fg;

    if (ready) {
      bg = cs.primaryContainer.withValues(alpha: 0.9);
      icon = Icons.check_circle_rounded;
      label = 'Edges locked';
      fg = cs.onPrimary;
    } else if (holding) {
      bg = Colors.amber.withValues(alpha: 0.9);
      icon = Icons.hourglass_top_rounded;
      label = 'Hold steady...';
      fg = Colors.black;
    } else {
      bg = cs.surfaceContainerHighest.withValues(alpha: 0.8);
      icon = Icons.center_focus_strong;
      label = 'Align document';
      fg = cs.onSurface;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

ColorFilter? _previewFilterForProfile(DocumentColorProfile profile) {
  switch (profile) {
    case DocumentColorProfile.color:
      return null;
    case DocumentColorProfile.grayscale:
      return const ColorFilter.matrix(_grayscaleMatrix);
    case DocumentColorProfile.blackWhite:
      return const ColorFilter.matrix(_blackWhiteMatrix);
    case DocumentColorProfile.magic:
      return const ColorFilter.matrix(_magicMatrix);
  }
}

img.Image _applyProfileFilter(img.Image image, DocumentColorProfile profile) {
  switch (profile) {
    case DocumentColorProfile.color:
      return image;
    case DocumentColorProfile.grayscale:
      return img.grayscale(image);
    case DocumentColorProfile.blackWhite:
      final gray = img.grayscale(image);
      return img.adjustColor(gray, contrast: 1.35, brightness: 1.05);
    case DocumentColorProfile.magic:
      return img.adjustColor(
        image,
        contrast: 1.15,
        saturation: 1.1,
        brightness: 1.02,
      );
  }
}

const List<double> _grayscaleMatrix = <double>[
  0.33,
  0.33,
  0.33,
  0,
  0,
  0.33,
  0.33,
  0.33,
  0,
  0,
  0.33,
  0.33,
  0.33,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

const List<double> _blackWhiteMatrix = <double>[
  0.6,
  0.6,
  0.6,
  0,
  -128,
  0.6,
  0.6,
  0.6,
  0,
  -128,
  0.6,
  0.6,
  0.6,
  0,
  -128,
  0,
  0,
  0,
  1,
  0,
];

const List<double> _magicMatrix = <double>[
  1.2,
  0.05,
  0.05,
  0,
  0,
  0.05,
  1.15,
  0.05,
  0,
  0,
  0.05,
  0.05,
  1.1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];
