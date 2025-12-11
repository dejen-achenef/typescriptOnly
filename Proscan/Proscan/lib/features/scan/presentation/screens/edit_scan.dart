// features/scan/presentation/screens/edit_scan_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/features/scan/model/scan_flow_models.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/features/scan/core/services/pdf_generation_service.dart';
import 'package:thyscan/features/scan/core/services/image_processing_service.dart';
import 'package:thyscan/features/scan/core/services/preview_image_service.dart';
import 'package:thyscan/services/document_service.dart';
import 'package:thyscan/core/utils/share_utils.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/core/services/app_logger.dart';

class EditScanScreen extends StatefulWidget {
  final String imagePath;
  final ScanMode initialMode;
  final String? documentId;
  final List<String>? imagePaths;
  final DocumentColorProfile initialColorProfile;
  final String? documentTitle;

  const EditScanScreen({
    super.key,
    required this.imagePath,
    required this.initialMode,
    this.initialColorProfile = DocumentColorProfile.color,
    this.documentId,
    this.imagePaths,
    this.documentTitle,
  });

  @override
  State<EditScanScreen> createState() => _EditScanScreenState();
}

enum ImageFilter {
  none,
  grayscale,
  sepia,
  invert,
  brightness,
  contrast,
  vintage,
  blackAndWhite,
}

class _EditScanScreenState extends State<EditScanScreen> {
  late String _currentPath;
  List<String> _pages = [];
  late final PageController _pageController;
  int _currentIndex = 0;
  late String _pdfFileName;
  late DocumentColorProfile _colorProfile;
  int? _draggingIndex;

  // Store filter and rotation for each page
  final Map<int, ImageFilter> _pageFilters = {};
  final Map<int, int> _pageRotations =
      {}; // Rotation in degrees (0, 90, 180, 270)

  // Filter preview thumbnails for the current page
  Map<ImageFilter, String> _filterPreviews = {};
  bool _isGeneratingPreviews = false;
  bool _isSaving = false;
  PdfGenerationProgress? _pdfProgress;
  bool _isGridView = false;

  // Preview image paths for UI display (downscaled to reduce memory pressure)
  // Key: original image path, Value: preview image path
  final Map<String, String> _previewPaths = {};
  bool _isLoadingPreviews = true;

  @override
  void initState() {
    super.initState();
    if (widget.imagePaths != null && widget.imagePaths!.isNotEmpty) {
      _pages = List.from(widget.imagePaths!);
      _currentPath = _pages[0];
    } else {
      _currentPath = widget.imagePath;
      _pages = [widget.imagePath];
    }
    _colorProfile = widget.initialColorProfile;
    _pageController = PageController(initialPage: 0);
    // Initialize PDF file name with document title if provided
    final resolvedTitle = widget.documentTitle?.isNotEmpty == true
        ? widget.documentTitle!
        : 'DocScan_${DateTime.now().millisecondsSinceEpoch}';
    _pdfFileName = resolvedTitle.replaceAll('.pdf', '');

    // Load preview images for all pages (for UI display)
    _loadPreviewImages();

    // Generate initial filter previews for the first page
    _generateFilterPreviewsForCurrentPage();
  }

  /// Load preview images for all pages to reduce memory pressure in UI.
  /// Preview images are downscaled versions used only for display.
  /// Original images remain untouched for OCR, export, and processing.
  Future<void> _loadPreviewImages() async {
    setState(() => _isLoadingPreviews = true);

    try {
      // Load previews for all pages
      final previewFutures = _pages.map((originalPath) async {
        try {
          final previewPath = await PreviewImageService.instance
              .getOrCreatePreviewPath(originalPath);
          return MapEntry(originalPath, previewPath);
        } catch (e) {
          AppLogger.warning(
            'Failed to generate preview, using original',
            data: {'path': originalPath, 'error': e.toString()},
            error: null,
          );
          // Fallback to original if preview generation fails
          return MapEntry(originalPath, originalPath);
        }
      });

      final previewEntries = await Future.wait(previewFutures);

      if (!mounted) return;

      setState(() {
        _previewPaths.addAll(Map.fromEntries(previewEntries));
        _isLoadingPreviews = false;
      });
    } catch (e, stack) {
      AppLogger.error('Failed to load preview images', error: e, stack: stack);
      if (!mounted) return;

      // Fallback: use original paths if preview loading fails
      setState(() {
        for (final path in _pages) {
          _previewPaths[path] = path;
        }
        _isLoadingPreviews = false;
      });
    }
  }

  /// Gets the preview path for a given original image path.
  /// Falls back to original path if preview is not available.
  String _getPreviewPath(String originalPath) {
    return _previewPaths[originalPath] ?? originalPath;
  }

  /// Loads preview for a single image path and updates the preview paths map.
  /// Used when new pages are added or existing pages are modified.
  Future<void> _loadPreviewForPath(String originalPath) async {
    if (_previewPaths.containsKey(originalPath)) {
      return; // Already loaded
    }

    try {
      final previewPath = await PreviewImageService.instance
          .getOrCreatePreviewPath(originalPath);
      if (mounted) {
        setState(() {
          _previewPaths[originalPath] = previewPath;
        });
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to generate preview, using original',
        data: {'path': originalPath, 'error': e.toString()},
        error: null,
      );
      if (mounted) {
        setState(() {
          _previewPaths[originalPath] = originalPath;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isOnAddSlot => _currentIndex == _pages.length;

  // ← NEW: Proper permission handling for ImageCropper
  Future<bool> _requestCropPermissions() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    // Android 13+ (API 33+) uses scoped storage + Photo Picker
    // ImageCropper handles it automatically if you have READ_MEDIA_IMAGES
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.photos.request();
        return status.isGranted;
      } else {
        // Android < 13: fallback to storage
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }

    return true;
  }

  Future<void> _cropImage() async {
    if (_isOnAddSlot) return;
    // ← CRITICAL: Request permission BEFORE cropping
    final hasPermission = await _requestCropPermissions();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo access required for cropping')),
      );
      return;
    }

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _currentPath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust Scan',
            toolbarColor: Theme.of(context).colorScheme.surface,
            statusBarColor: Theme.of(context).colorScheme.surface,
            toolbarWidgetColor: Theme.of(context).colorScheme.onSurface,
            activeControlsWidgetColor: Theme.of(context).colorScheme.primary,
            cropFrameColor: Colors.white,
            cropGridColor: Colors.white70,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Adjust Scan',
            cancelButtonTitle: 'Cancel',
            doneButtonTitle: 'Done',
          ),
        ],
      );

      if (cropped == null) {
        // User cancelled
        return;
      }

      if (!mounted) return;

      final oldPath = _currentPath;
      setState(() {
        final idx = _pages.indexOf(_currentPath);
        if (idx != -1) {
          _pages[idx] = cropped.path;
          _currentIndex = idx;
        } else {
          _pages.add(cropped.path);
          _currentIndex = _pages.length - 1;
          _pageController.jumpToPage(_currentIndex);
        }
        _currentPath = cropped.path;
        // Remove old preview mapping
        _previewPaths.remove(oldPath);
      });

      // Load preview for cropped image
      await _loadPreviewForPath(cropped.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cropping failed: $e')));
    }
  }

  Future<void> _captureAdditionalPage() async {
    try {
      final result = await context.push<CameraCaptureResult>(
        '/camerascreen',
        extra: CameraScreenConfig(
          initialMode: widget.initialMode,
          restrictToInitialMode: true,
          returnCapturePath: true,
          colorProfile: _colorProfile,
        ),
      );

      if (result == null || !mounted) return;

      setState(() {
        _pages.add(result.imagePath);
        _currentIndex = _pages.length - 1;
        _currentPath = result.imagePath;
        _colorProfile = result.colorProfile;
      });

      // Load preview for the newly added page
      await _loadPreviewForPath(result.imagePath);

      // Ensure PageView is updated before animating
      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add page: $e')));
    }
  }

  void _handlePageChanged(int index) {
    setState(() {
      _currentIndex = index;
      if (index < _pages.length) {
        _currentPath = _pages[index];
      } else {
        // On add slot, clear current path
        _currentPath = '';
      }
    });

    // Regenerate filter previews for the newly selected page
    _generateFilterPreviewsForCurrentPage();

    // If user swiped to add slot, automatically trigger capture if desired
    // But for now, just ensure the add slot is accessible
  }

  Future<void> _retakeCurrentPage() async {
    if (_isOnAddSlot) return;

    try {
      final result = await context.push<CameraCaptureResult>(
        '/camerascreen',
        extra: CameraScreenConfig(
          initialMode: widget.initialMode,
          restrictToInitialMode: true,
          returnCapturePath: true,
          colorProfile: _colorProfile,
        ),
      );

      if (result == null || !mounted) return;

      final oldPath = _pages[_currentIndex];
      setState(() {
        _pages[_currentIndex] = result.imagePath;
        _currentPath = result.imagePath;
        _colorProfile = result.colorProfile;
        // Reset filter and rotation for this page
        _pageFilters.remove(_currentIndex);
        _pageRotations.remove(_currentIndex);
        // Remove old preview mapping
        _previewPaths.remove(oldPath);
      });

      // Load preview for retaken image
      await _loadPreviewForPath(result.imagePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not retake: $e')));
    }
  }

  Future<void> _rotateCurrentPage() async {
    if (_isOnAddSlot) return;

    try {
      final currentRotation = _pageRotations[_currentIndex] ?? 0;
      final newRotation = (currentRotation + 90) % 360;

      final sourcePath = _pages[_currentIndex];
      final newPath = await ImageProcessingService.instance.rotate90(
        sourcePath,
      );

      final oldPath = _pages[_currentIndex];
      setState(() {
        _pages[_currentIndex] = newPath;
        _currentPath = newPath;
        // Remove old preview mapping
        _previewPaths.remove(oldPath);
        _pageRotations[_currentIndex] = newRotation;
      });

      // Load preview for rotated image
      await _loadPreviewForPath(newPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rotation failed: $e')));
    }
  }

  Future<void> _applyFilter(ImageFilter filter) async {
    if (_isOnAddSlot) return;

    try {
      if (filter != ImageFilter.none) {
        final sourcePath = _pages[_currentIndex];
        // Convert enum to string for isolate serialization
        final filterName = filter.toString().split('.').last;
        final newPath = await ImageProcessingService.instance.applyFilter(
          sourcePath,
          filterName,
        );

        final oldPath = _pages[_currentIndex];
        setState(() {
          _pages[_currentIndex] = newPath;
          _currentPath = newPath;
          _pageFilters[_currentIndex] = filter;
          // Remove old preview mapping
          _previewPaths.remove(oldPath);
          final mappedProfile = _profileFromFilter(filter);
          if (mappedProfile != null) {
            _colorProfile = mappedProfile;
          }
        });

        // Load preview for filtered image
        await _loadPreviewForPath(newPath);
        // Regenerate filter previews after applying filter
        _generateFilterPreviewsForCurrentPage();
      } else {
        // Reset to original - would need to store original paths
        setState(() {
          _pageFilters[_currentIndex] = filter;
        });
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      AppLogger.error('Filter application failed', error: e, stack: stackTrace);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Filter application failed: $e')));
    }
  }

  DocumentColorProfile? _profileFromFilter(ImageFilter filter) {
    return switch (filter) {
      ImageFilter.none => DocumentColorProfile.color,
      ImageFilter.grayscale => DocumentColorProfile.grayscale,
      ImageFilter.blackAndWhite => DocumentColorProfile.blackWhite,
      ImageFilter.vintage => DocumentColorProfile.magic,
      _ => null,
    };
  }

  /// Navigate to document preview/save screen
  void _navigateToSavePdf() {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to save')));
      return;
    }

    context.push(
      '/savepdfscreen',
      extra: {
        'imagePaths': _pages,
        'pdfFileName': _pdfFileName,
        'documentId': widget.documentId,
        'scanMode': widget.initialMode,
        'colorProfile': _colorProfile.key,
      },
    );
  }

  Future<void> _handleConfirm() async {
    if (widget.documentId == null) {
      _navigateToSavePdf();
    } else {
      await _fastSaveExistingDocument();
    }
  }

  Future<void> _fastSaveExistingDocument() async {
    if (widget.documentId == null) {
      _navigateToSavePdf();
      return;
    }

    setState(() {
      _isSaving = true;
      _pdfProgress = PdfGenerationProgress(
        processedPages: 0,
        totalPages: _pages.length,
        stage: 'Preparing',
      );
    });

    try {
      await DocumentService.instance.updateDocument(
        documentId: widget.documentId!,
        pageImagePaths: _pages,
        title: _pdfFileName,
        scanMode: _scanModeKey(widget.initialMode),
        colorProfile: _colorProfile,
        options: _buildSaveOptions(),
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _pdfProgress = progress);
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document updated'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      context.go('/appmainscreen');

      // Prompt for share after save
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      final doc = box.get(widget.documentId!);
      if (doc != null) {
        await _promptShareAfterSave(doc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _pdfProgress = null;
        });
      }
    }
  }

  String _scanModeKey(ScanMode mode) => mode.toString().split('.').last;

  DocumentSaveOptions _buildSaveOptions() {
    final tagSet = {_scanModeKey(widget.initialMode), _colorProfile.key}
      ..removeWhere((element) => element.isEmpty);
    return DocumentSaveOptions.enterpriseDefaults(
      title: _pdfFileName,
      tags: tagSet.toList(),
    );
  }

  void _goToPreviousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextPage() {
    if (_currentIndex < _pages.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildImagePage(String originalPath) {
    // Use preview path for UI display to reduce memory pressure
    // Original path is still stored for processing operations
    final previewPath = _getPreviewPath(originalPath);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Image.file(File(previewPath), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterListView() {
    final cs = Theme.of(context).colorScheme;
    final currentFilter = _pageFilters[_currentIndex] ?? ImageFilter.none;

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: ImageFilter.values.map((filter) {
          final isSelected = filter == currentFilter;
          final previewPath = _filterPreviews[filter];

          return GestureDetector(
            onTap: () => _applyFilter(filter),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? cs.primary : Colors.transparent,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: previewPath != null && !_isGeneratingPreviews
                          ? Image.file(
                              File(previewPath),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              color: cs.surfaceContainerHighest,
                              child: _isGeneratingPreviews
                                  ? const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getFilterName(filter),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? cs.primary : cs.onSurface,
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getFilterName(ImageFilter filter) {
    switch (filter) {
      case ImageFilter.none:
        return 'Original';
      case ImageFilter.grayscale:
        return 'Grayscale';
      case ImageFilter.sepia:
        return 'Sepia';
      case ImageFilter.invert:
        return 'Invert';
      case ImageFilter.brightness:
        return 'Bright';
      case ImageFilter.contrast:
        return 'Contrast';
      case ImageFilter.vintage:
        return 'Vintage';
      case ImageFilter.blackAndWhite:
        return 'B&W';
    }
  }

  Future<void> _generateFilterPreviewsForCurrentPage() async {
    if (_isOnAddSlot) return;

    try {
      setState(() {
        _isGeneratingPreviews = true;
        _filterPreviews = {};
      });

      final path = _currentPath;
      if (path.isEmpty) return;
      final file = File(path);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return;

      // Work on a downscaled copy for performance
      final baseThumb = img.copyResize(original, width: 220);
      final dir = await getTemporaryDirectory();

      for (final filter in ImageFilter.values) {
        img.Image previewImage;
        switch (filter) {
          case ImageFilter.grayscale:
            previewImage = img.grayscale(baseThumb.clone());
            break;
          case ImageFilter.sepia:
            previewImage = img.sepia(baseThumb.clone());
            break;
          case ImageFilter.invert:
            previewImage = img.invert(baseThumb.clone());
            break;
          case ImageFilter.brightness:
            previewImage = img.adjustColor(baseThumb.clone(), brightness: 1.2);
            break;
          case ImageFilter.contrast:
            previewImage = img.adjustColor(baseThumb.clone(), contrast: 1.3);
            break;
          case ImageFilter.vintage:
            previewImage = img.sepia(baseThumb.clone());
            previewImage = img.adjustColor(
              previewImage,
              brightness: 0.9,
              contrast: 1.1,
            );
            break;
          case ImageFilter.blackAndWhite:
            previewImage = img.grayscale(baseThumb.clone());
            previewImage = img.adjustColor(previewImage, contrast: 1.5);
            break;
          case ImageFilter.none:
            previewImage = baseThumb.clone();
            break;
        }

        final previewBytes = Uint8List.fromList(
          img.encodeJpg(previewImage, quality: 80),
        );
        final filterName = filter.toString().split('.').last;
        final previewPath =
            '${dir.path}/preview_${filterName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(previewPath).writeAsBytes(previewBytes, flush: true);

        _filterPreviews[filter] = previewPath;
      }
    } catch (_) {
      // Ignore preview generation errors; user can still use filters.
    } finally {
      if (!mounted) return;
      setState(() {
        _isGeneratingPreviews = false;
      });
    }
  }

  Widget _buildBottomIcons() {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomIcon(
            icon: Icons.camera_alt_rounded,
            label: 'Retake',
            onTap: _retakeCurrentPage,
            color: cs.onSurface,
          ),
          _buildBottomIcon(
            icon: Icons.rotate_right_rounded,
            label: 'Right',
            onTap: _rotateCurrentPage,
            color: cs.onSurface,
          ),
          _buildBottomIcon(
            icon: Icons.crop_rounded,
            label: 'Crop',
            onTap: _cropImage,
            color: cs.onSurface,
          ),
          _buildBottomIcon(
            icon: Icons.text_fields_rounded,
            label: 'Extract Text',
            onTap: () {
              // Placeholder for extract text functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Extract text feature coming soon'),
                ),
              );
            },
            color: cs.onSurface,
          ),
          _buildBottomIcon(
            icon: Icons.check_circle_rounded,
            label: 'Confirm',
            onTap: _isSaving ? null : _handleConfirm,
            color: cs.onPrimary,
            backgroundColor: cs.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomIcon({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              shape: BoxShape.circle,
              border: backgroundColor == null
                  ? Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    )
                  : null,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPageCard() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primaryContainer.withValues(alpha: 0.1),
              cs.surfaceContainerHighest.withValues(alpha: 0.2),
            ],
          ),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 25,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: cs.surface.withValues(alpha: 0.7),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Modern icon container
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary.withValues(alpha: 0.1),
                        cs.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: InkWell(
                    onTap: _captureAdditionalPage,
                    child: Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 42,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Add More Pages',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Capture additional pages to build your multi-page document',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                const SizedBox(height: 16),

                // Hint text
                Text(
                  'Swipe to navigate between pages',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailGrid() {
    final totalItems = _pages.length + 1;
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          // First item is always the add button
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildAddThumbnailTile(),
            );
          }
          // Remaining items are pages (index - 1 is the actual page index)
          final pageIndex = index - 1;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 80,
              child: _buildDraggableThumbnail(pageIndex),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddThumbnailTile() {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _captureAdditionalPage,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primaryContainer.withValues(alpha: 0.15),
                  cs.primary.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.1),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primary.withValues(alpha: 0.2),
                          cs.primary.withValues(alpha: 0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 24,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableThumbnail(int index) {
    final tile = _buildThumbnailContent(index);
    final isBeingDragged = _draggingIndex == index;
    final visibleTile = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isBeingDragged ? 0.5 : 1,
      child: tile,
    );
    return LongPressDraggable<int>(
      data: index,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => setState(() => _draggingIndex = index),
      onDraggableCanceled: (_, __) => setState(() => _draggingIndex = null),
      onDragEnd: (_) => setState(() => _draggingIndex = null),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 90, child: tile),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) => _handleReorder(details.data, index),
        builder: (context, candidateData, rejectedData) {
          final highlight = candidateData.isNotEmpty;
          return Dismissible(
            key: ValueKey(_pages[index]),
            direction: _pages.length <= 1
                ? DismissDirection.none
                : DismissDirection.up,
            background: Container(
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.delete, color: Colors.redAccent),
            ),
            onDismissed: (_) => _removePageAt(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: highlight
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: visibleTile,
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbnailContent(int index) {
    final cs = Theme.of(context).colorScheme;
    final isActive = index == _currentIndex;
    return GestureDetector(
      onTap: () => _jumpToPage(index),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.surface,
          border: Border.all(
            color: isActive ? cs.primary : cs.outlineVariant,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(
                    _getPreviewPath(_pages[index]),
                  ), // Use preview for thumbnail
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: cs.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Page ${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReorder(int from, int to) {
    if (from == to) return;
    setState(() {
      final page = _pages.removeAt(from);
      _pages.insert(to, page);

      if (_currentIndex == from) {
        _currentIndex = to;
      } else if (from < _currentIndex && to >= _currentIndex) {
        _currentIndex -= 1;
      } else if (from > _currentIndex && to <= _currentIndex) {
        _currentIndex += 1;
      }

      _currentIndex = _currentIndex.clamp(0, _pages.length - 1);
      _currentPath = _pages[_currentIndex];
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentIndex);
    }
  }

  void _removePageAt(int index) {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one page in the document')),
      );
      return;
    }
    setState(() {
      _pages.removeAt(index);
      if (_currentIndex >= _pages.length) {
        _currentIndex = _pages.length - 1;
      }
      _currentPath = _pages[_currentIndex];
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentIndex);
    }
  }

  Future<void> _jumpToPage(int index) async {
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    setState(() {
      _currentIndex = index;
      _currentPath = _pages[index];
    });
  }

  Widget _buildPageNavigation() {
    final cs = Theme.of(context).colorScheme;
    final isFirstPage = _currentIndex == 0;
    final isLastPage = _currentIndex == _pages.length - 1;
    final totalPages = _pages.length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: isFirstPage ? null : _goToPreviousPage,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: isFirstPage
                  ? cs.onSurface.withValues(alpha: 0.3)
                  : cs.primary,
              size: 32,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isFirstPage
                  ? null
                  : cs.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
            ),
          ),

          // Page counter - transparent background
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              '${_currentIndex + 1} / $totalPages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Next button
          IconButton(
            onPressed: isLastPage ? null : _goToNextPage,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: isLastPage
                  ? cs.onSurface.withValues(alpha: 0.3)
                  : cs.primary,
              size: 32,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isLastPage
                  ? null
                  : cs.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingOverlay(ColorScheme colorScheme) {
    final progress = _pdfProgress;
    final subtitle = progress == null
        ? 'Finalizing changes…'
        : '${progress.stage} • ${progress.processedPages}/${progress.totalPages} pages';
    final double? percent = progress == null
        ? null
        : (progress.processedPages / progress.totalPages).clamp(0.0, 1.0);

    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                'Saving to library…',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: percent,
                minHeight: 6,
                borderRadius: BorderRadius.circular(20),
                backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditFileNameDialog() {
    final controller = TextEditingController(
      text: _pdfFileName.replaceAll('.pdf', ''),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Document Name',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'Give your document a meaningful name',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),

              // Text field with clear button
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter document name',
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            onPressed: () {
                              controller.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      this.setState(() {
                        _pdfFileName = value.trim();
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),

              // File extension hint
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'File will be saved as: ${controller.text.trim().isEmpty ? 'document' : controller.text.trim()}.pdf',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final newName = controller.text.trim();
                        if (newName.isNotEmpty) {
                          setState(() {
                            _pdfFileName = newName;
                          });
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      resizeToAvoidBottomInset:
          false, // Prevent jank from GridView/PageView rebuilds during keyboard animation
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _pdfFileName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.edit_rounded, size: 20, color: cs.primary),
              tooltip: 'Edit file name',
              onPressed: () => _showEditFileNameDialog(),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isGridView
                  ? Icons.view_carousel_rounded
                  : Icons.grid_view_rounded,
              color: cs.onSurface,
            ),
            tooltip: _isGridView ? 'List View' : 'Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          _isGridView
              ? _buildGridView()
              : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: _handlePageChanged,
                        itemCount: _pages.length + 1,
                        allowImplicitScrolling: false,
                        itemBuilder: (context, index) {
                          if (index < _pages.length) {
                            return _buildImagePage(_pages[index]);
                          }
                          return _buildAddPageCard();
                        },
                      ),
                    ),
                    SizedBox(height: 220, child: _buildThumbnailGrid()),
                    const SizedBox(height: 8),
                  ],
                ),
          if (_isSaving) _buildSavingOverlay(cs),
        ],
      ),
      bottomNavigationBar: _isOnAddSlot
          ? null
          : Container(
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Professional-style page navigation: 1 / N with prev/next
                    _buildPageNavigation(),
                    // Filter list with live image previews
                    _buildFilterListView(),
                    // Bottom action icons (Retake, Rotate, Crop, Extract, Confirm)
                    _buildBottomIcons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGridView() {
    final totalItems = _pages.length + 1;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index == _pages.length) {
          return _buildAddPageGridCard();
        }
        return _buildDraggableGridItem(index);
      },
    );
  }

  Widget _buildAddPageGridCard() {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _captureAdditionalPage,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer.withValues(alpha: 0.15),
                cs.primary.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.3),
              width: 2,
              style: BorderStyle.solid,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary.withValues(alpha: 0.2),
                      cs.primary.withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 36,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Page',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableGridItem(int index) {
    final tile = _buildGridItemContent(index);
    return LongPressDraggable<int>(
      data: index,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => setState(() => _draggingIndex = index),
      onDraggableCanceled: (_, __) => setState(() => _draggingIndex = null),
      onDragEnd: (_) => setState(() => _draggingIndex = null),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 160, height: 220, child: tile),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) => _handleReorder(details.data, index),
        builder: (context, candidateData, rejectedData) {
          final highlight = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: highlight
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: tile,
          );
        },
      ),
    );
  }

  Widget _buildGridItemContent(int index) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(_getPreviewPath(_pages[index])),
              fit: BoxFit.cover,
            ), // Use preview for grid view
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _removePageAt(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptShareAfterSave(DocumentModel doc) async {
    if (!mounted) return;
    final shouldShare =
        await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.ios_share_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Share your PDF?',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Send ${doc.title} right away or skip for now.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Maybe later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Share now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (shouldShare) {
      await _shareFile(
        doc.filePath,
        subject: doc.title,
        text: 'Sent from ThyScan',
      );
    }
  }

  Future<void> _shareFile(String path, {String? subject, String? text}) async {
    final files = <XFile>[XFile(path)];
    await ShareUtils.shareFiles(files, subject: subject, text: text);
  }
}
