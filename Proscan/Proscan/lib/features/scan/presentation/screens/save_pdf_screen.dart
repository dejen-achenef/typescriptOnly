// features/scan/presentation/screens/save_pdf_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/core/services/document_download_service.dart';
import 'package:thyscan/core/services/docx_generator_service.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/features/scan/core/services/preview_image_service.dart';
import 'package:thyscan/features/scan/core/services/pdf_generation_service.dart';
import 'package:thyscan/features/scan/model/scan_flow_models.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/features/scan/presentation/screens/delete_pages_screen.dart';
import 'package:thyscan/services/document_service.dart';
import 'package:thyscan/core/utils/share_utils.dart';

extension _ColorAlphaX on Color {
  Color alpha(double opacity) => withValues(alpha: opacity);
}

class SavePdfScreen extends StatefulWidget {
  final List<String> imagePaths;
  final String pdfFileName;
  final String? documentId; // Optional: for opening existing documents
  final ScanMode? scanMode; // Track the original scan mode
  final DocumentColorProfile? initialColorProfile;

  const SavePdfScreen({
    super.key,
    required this.imagePaths,
    required this.pdfFileName,
    this.documentId,
    this.scanMode,
    this.initialColorProfile,
  });

  @override
  State<SavePdfScreen> createState() => _SavePdfScreenState();
}

class _SavePdfScreenState extends State<SavePdfScreen> {
  bool _isSaving = false;
  String? _savedPdfPath;
  List<String> _pages = [];
  int _selectedBottomNavIndex = 0;
  String? _documentId; // Store the document ID after auto-save
  bool _hasUnsavedChanges = false;
  DocumentColorProfile _colorProfile = DocumentColorProfile.color;
  late final ScanMode _activeScanMode;
  PdfGenerationProgress? _pdfProgress;
  
  // Preview paths for UI display (downscaled to reduce memory pressure)
  final Map<String, String> _previewPaths = {};
  bool _isLoadingPreviews = false;

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.imagePaths);
    _documentId = widget.documentId;
    _activeScanMode = widget.scanMode ?? ScanMode.document;
    _colorProfile = widget.initialColorProfile ?? DocumentColorProfile.color;

    // Download URLs if needed, then load preview images
    _downloadAndPreparePages().then((_) {
      if (mounted) {
        _loadPreviewImages();
      }
    });

    // Only auto-save if this is a new document (no documentId provided)
    if (widget.documentId == null) {
      _autoSaveDocument();
    } else {
      // Load existing document data
      _loadExistingDocument();
    }
  }

  /// Downloads any URLs in imagePaths to local files
  Future<void> _downloadAndPreparePages() async {
    if (_pages.isEmpty) return;

    final downloadedPages = <String>[];
    for (final path in _pages) {
      // Check if path is a URL
      if (path.startsWith('http://') || path.startsWith('https://')) {
        // Download the file
        final documentId = widget.documentId ?? 'temp_${path.hashCode}';
        final downloadedPath = await DocumentDownloadService.instance
            .downloadFile(
          url: path,
          documentId: documentId,
          fileName: path.split('/').last.split('?').first,
        );

        if (downloadedPath != null) {
          downloadedPages.add(downloadedPath);
        } else {
          // Download failed, keep original URL (will show error later)
          downloadedPages.add(path);
        }
      } else {
        // Local path, use as-is
        downloadedPages.add(path);
      }
    }

    if (mounted) {
      setState(() {
        _pages = downloadedPages;
      });
    }
  }

  /// Load preview images for all pages to reduce memory pressure in UI.
  /// Preview images are downscaled versions used only for display.
  /// Original images remain untouched for PDF export and processing.
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
    } catch (e) {
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

  /// Load existing document data from Hive
  Future<void> _loadExistingDocument() async {
    if (widget.documentId == null) return;

    try {
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      final doc = box.get(widget.documentId);

      if (doc != null && mounted) {
        String filePath = doc.filePath;

        // If filePath is a URL, download it first
        if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
          final downloadedPath = await DocumentDownloadService.instance
              .downloadFile(
            url: filePath,
            documentId: doc.id,
            fileName: '${doc.id}.${doc.format}',
          );

          if (downloadedPath != null) {
            filePath = downloadedPath;
          }
        }

        setState(() {
          _savedPdfPath = filePath;
          _colorProfile = DocumentColorProfile.fromKey(doc.colorProfile);
          _documentId = doc.id;
        });
      }
    } catch (e) {
      debugPrint('Failed to load existing document: $e');
    }
  }

  /// Automatically save document to internal storage and Hive on screen load
  Future<void> _autoSaveDocument() async {
    // Wait 800ms to let camera finish before auto-saving
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      await _persistDocument(force: true);
    }
  }

  /// Update existing document when pages are modified
  Future<void> _updateExistingDocument() async {
    await _persistDocument(force: true);
  }

  Future<DocumentModel?> _persistDocument({bool force = false}) async {
    if (_pages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No pages to save')));
      }
      return null;
    }

    if (_isSaving) return null;

    if (!force && !_hasUnsavedChanges && _documentId != null) {
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      return box.get(_documentId!);
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
      final title = widget.pdfFileName.replaceAll('.pdf', '');
      final scanModeKey = _scanModeKey(_activeScanMode);
      final options = _buildSaveOptions();
      void progressHandler(PdfGenerationProgress progress) {
        if (!mounted) return;
        setState(() => _pdfProgress = progress);
      }

      late DocumentModel doc;
      if (_documentId == null) {
        doc = await DocumentService.instance.saveDocument(
          pageImagePaths: _pages,
          title: title,
          scanMode: scanModeKey,
          colorProfile: _colorProfile,
          onProgress: progressHandler,
          options: options,
        );
      } else {
        doc = await DocumentService.instance.updateDocument(
          documentId: _documentId!,
          pageImagePaths: _pages,
          title: title,
          scanMode: scanModeKey,
          colorProfile: _colorProfile,
          onProgress: progressHandler,
          options: options,
        );
      }

      if (!mounted) return doc;

      setState(() {
        _documentId = doc.id;
        _savedPdfPath = doc.filePath;
        if (doc.pageImagePaths.isNotEmpty) {
          _pages = List.from(doc.pageImagePaths);
        }
        _hasUnsavedChanges = false;
      });

      return doc;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _pdfProgress = null;
        });
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to share')));
      return;
    }

    try {
      // Ensure we synchronously persist before sharing, so we always
      // have a concrete PDF path to share. This uses the existing
      // direct persistence path rather than the queue.
      final doc = await _persistDocument(force: true);
      final pdfPath = doc?.filePath ?? _savedPdfPath;

      if (pdfPath != null && File(pdfPath).existsSync() && mounted) {
        await _shareFile(
          pdfPath,
          subject: 'Document Scan - ${widget.pdfFileName}',
          text: 'Check out this document I scanned!',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sharing failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addPage() async {
    try {
      final result = await context.push<CameraCaptureResult>(
        '/camerascreen',
        extra: CameraScreenConfig(
          initialMode: _activeScanMode,
          restrictToInitialMode: true,
          returnCapturePath: true,
          colorProfile: _colorProfile,
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _pages.add(result.imagePath);
          _colorProfile = result.colorProfile;
          _hasUnsavedChanges = true;
        });
        
        // Load preview for newly added page
        try {
          final previewPath = await PreviewImageService.instance
              .getOrCreatePreviewPath(result.imagePath);
          if (mounted) {
            setState(() {
              _previewPaths[result.imagePath] = previewPath;
            });
          }
        } catch (e) {
          // Fallback to original if preview generation fails
          if (mounted) {
            setState(() {
              _previewPaths[result.imagePath] = result.imagePath;
            });
          }
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Page added successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add page: $e')));
    }
  }

  Future<void> _shareFile(String path, {String? subject, String? text}) async {
    final files = <XFile>[XFile(path)];
    await ShareUtils.shareFiles(files, subject: subject, text: text);
  }

  void _handleBottomNavTap(int index) {
    setState(() {
      _selectedBottomNavIndex = index;
    });

    switch (index) {
      case 0: // Add
        _addPage().then((_) {
          if (mounted) {
            setState(() {
              _selectedBottomNavIndex = -1; // Reset selection
            });
          }
        });
        break;
      case 1: // Edit
        _showEditOptions();
        break;
      case 2: // Share
        _sharePdf().then((_) {
          if (mounted) {
            setState(() {
              _selectedBottomNavIndex = -1; // Reset selection
            });
          }
        });
        break;
      case 3: // Save
        _handleSaveAndHome();
        break;
    }
  }

  void _showEditOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit Document',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Pages'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to edit screen
                context.push(
                  '/editscanscreen',
                  extra: EditScanArgs(
                    imagePath: _pages.isNotEmpty ? _pages[0] : '',
                    initialMode: _activeScanMode,
                    documentId: _documentId,
                    imagePaths: _pages,
                    colorProfile: _colorProfile,
                    documentTitle: widget.pdfFileName,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded),
              title: const Text('Delete Pages'),
              onTap: () {
                Navigator.pop(context);
                // Show delete options
                _handleDeletePages();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeletePages() async {
    final deletedIndices = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(builder: (context) => DeletePagesScreen(pages: _pages)),
    );

    if (deletedIndices != null && deletedIndices.isNotEmpty && mounted) {
      setState(() {
        // Remove pages in reverse order to avoid index shifting issues
        for (final index in deletedIndices.reversed) {
          _pages.removeAt(index);
        }
        _hasUnsavedChanges = true;
      });

      // Update the document
      await _updateExistingDocument();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted ${deletedIndices.length} page${deletedIndices.length == 1 ? '' : 's'}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Saves document and redirects to Home Screen
  Future<void> _handleSaveAndHome() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to save')));
      return;
    }

    final doc = await _persistDocument(force: true);
    if (!mounted || doc == null) return;

    await _promptShareAfterSave(doc);

    // Navigate to Home Screen
    context.go('/appmainscreen');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document saved successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
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

  /// Exports document as Word (.docx) file
  Future<void> _convertToWord() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pages to export')));
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.description_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Export as Word'),
          ],
        ),
        content: const Text(
          'Export this document as a Word (.docx) file?\n\nThe file will open in Microsoft Word, Google Docs, and other compatible apps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      // Generate DOCX file
      final fileName = widget.pdfFileName.replaceAll('.pdf', '');
      final docxPath = await DocxGeneratorService.instance
          .generateDocxFromImages(imagePaths: _pages, fileName: fileName);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      // Show success with Open and Share options
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Word document saved!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () async {
              await OpenFilex.open(docxPath);
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      // Show share option after delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Want to share this document?',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => _shareFile(
                docxPath,
                subject: fileName,
                text: 'Check out this Word document!',
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export Word document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _scanModeKey(ScanMode mode) => mode.toString().split('.').last;

  DocumentSaveOptions _buildSaveOptions() {
    final resolvedTitle = widget.pdfFileName.replaceAll('.pdf', '');
    final tagSet = {_scanModeKey(_activeScanMode), _colorProfile.key}
      ..removeWhere((element) => element.isEmpty);
    return DocumentSaveOptions.enterpriseDefaults(
      title: resolvedTitle,
      tags: tagSet.toList(),
    );
  }

  void _showAppBarMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Export as PDF'),
              subtitle: const Text('Save to library'),
              onTap: () {
                Navigator.pop(context);
                _handleSaveAndHome();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_rounded),
              title: const Text('Export as Word'),
              subtitle: const Text('Save as .docx file'),
              onTap: () {
                Navigator.pop(context);
                _convertToWord();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share PDF'),
              onTap: () {
                Navigator.pop(context);
                _sharePdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded),
              title: const Text('Delete Document'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDocumentDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteDocumentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBanner(ColorScheme colorScheme) {
    final progress = _pdfProgress;
    if (progress == null) return const SizedBox.shrink();

    final double? percent = progress.totalPages == 0
        ? null
        : (progress.processedPages / progress.totalPages).clamp(0.0, 1.0);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Optimizing PDF…',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: percent,
                minHeight: 6,
                borderRadius: BorderRadius.circular(20),
                backgroundColor: colorScheme.outlineVariant.withValues(
                  alpha: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${progress.stage} • ${progress.processedPages}/${progress.totalPages} pages',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageGridItem(int index) {
    final cs = Theme.of(context).colorScheme;

    if (index < _pages.length) {
      return GestureDetector(
        onTap: () {
          // Show full page preview or edit
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_getPreviewPath(_pages[index])), // Use preview for grid view
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else {
      // Add page button
      return GestureDetector(
        onTap: _addPage,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.3),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_rounded,
                size: 48,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 8),
              Text(
                'Add Pages',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      // CRITICAL: Prevent keyboard animation jank (IME_INSETS_SHOW/HIDE_ANIMATION)
      // Without this, heavy GridView rebuilds during keyboard animation cause 10+ dropped frames
      // This prevents the scaffold from resizing when keyboard opens/closes, avoiding expensive rebuilds
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/appmainscreen'),
        ),
        title: Text(
          widget.pdfFileName.replaceAll('.pdf', ''),
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: _showAppBarMenu,
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemCount: _pages.length + 1,
                itemBuilder: (context, index) {
                  return _buildPageGridItem(index);
                },
              ),
            ),
          ),
          if (_pdfProgress != null) _buildProgressBanner(cs),
        ],
      ),
      bottomNavigationBar: Container(
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
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(
                  icon: Icons.camera_alt_rounded,
                  label: 'Add',
                  index: 0,
                ),
                _buildBottomNavItem(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  index: 1,
                ),
                _buildBottomNavItem(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  index: 2,
                ),
                _buildBottomNavItem(
                  icon: Icons.save_rounded,
                  label: 'Save',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedBottomNavIndex == index;

    return GestureDetector(
      onTap: () => _handleBottomNavTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.6),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
