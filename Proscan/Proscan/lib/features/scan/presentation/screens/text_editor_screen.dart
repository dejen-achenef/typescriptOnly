// features/scan/presentation/screens/text_editor_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/docx_generator_service.dart';
import 'package:thyscan/features/scan/core/services/file_export_service.dart';
import 'package:thyscan/features/scan/core/services/ocr_service.dart';
import 'package:thyscan/services/document_service.dart';

class TextEditorScreen extends StatefulWidget {
  final String extractedText;
  final String? imagePath;

  const TextEditorScreen({
    super.key,
    required this.extractedText,
    this.imagePath,
  });

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  final FileExportService _fileExportService = FileExportService();

  bool _isExporting = false;
  bool _isProcessing = false;
  bool _hasUnsavedChanges = false;
  Timer? _debounceTimer;
  String? _lastSavedText;

  int get _characterCount => _textController.text.length;
  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.extractedText);
    _focusNode = FocusNode();
    _lastSavedText = widget.extractedText;

    _textController.addListener(_onTextChanged);

    // If imagePath is provided but no extractedText, process OCR
    if (widget.imagePath != null && widget.extractedText.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _processOcr());
    } else {
      // Auto-focus the text field for better UX
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  void _onTextChanged() {
    setState(() {
      _hasUnsavedChanges = _textController.text != _lastSavedText;
    });
  }

  Future<void> _processOcr() async {
    if (widget.imagePath == null) return;

    setState(() => _isProcessing = true);

    try {
      AppLogger.info(
        'Starting OCR extraction',
        data: {'path': widget.imagePath},
      );
      // Use singleton OcrService - only processes file paths, never camera streams
      final extractedText = await OcrService.instance.extractTextFromFile(
        widget.imagePath!,
      );

      if (mounted) {
        if (extractedText == null || extractedText.isEmpty) {
          _showSnackBar(
            'No text found in the image. You can type manually.',
            isError: true,
          );
          _textController.clear();
        } else {
          _textController.text = extractedText;
          _lastSavedText = extractedText;
          _hasUnsavedChanges = false;
          _showSnackBar('Text extracted successfully!');
        }

        // Auto-focus after processing
        _focusNode.requestFocus();
      }
    } catch (e, stackTrace) {
      AppLogger.error('OCR processing failed', error: e, stack: stackTrace);
      if (mounted) {
        _showSnackBar(
          'Failed to extract text: ${e.toString().split(':').last.trim()}',
          isError: true,
        );
        _textController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard() async {
    try {
      final text = _textController.text.trim();
      if (text.isEmpty) {
        _showSnackBar('No text to copy', isError: true);
        return;
      }

      await FlutterClipboard.copy(text);
      HapticFeedback.lightImpact();
      _showSnackBar('Text copied to clipboard');
    } catch (e) {
      AppLogger.error('Failed to copy text', error: e);
      _showSnackBar('Failed to copy text', isError: true);
    }
  }

  Future<void> _saveDocument() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('No text to save', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();

    try {
      final doc = await DocumentService.instance.saveTextDocument(
        text: text,
        title:
            'Extracted Text ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
      );

      if (mounted) {
        _showSnackBar(
          'Document saved successfully!',
          duration: const Duration(seconds: 2),
        );

        // Update saved state
        setState(() {
          _lastSavedText = text;
          _hasUnsavedChanges = false;
        });

        // Navigate to home screen after short delay
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          context.go('/appmainscreen');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Save failed', error: e, stack: stackTrace);
      if (mounted) {
        _showSnackBar(
          'Failed to save: ${e.toString().split(':').last.trim()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportToWord() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('No text to export', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();

    try {
      // Save document first
      await DocumentService.instance.saveTextDocument(
        text: text,
        title:
            'Extracted Text ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
      );

      // Export to Word document
      final docxPath = await DocxGeneratorService.instance.generateDocxFromText(
        text: text,
        title:
            'Extracted Text ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
      );

      if (mounted) {
        _showSnackBar(
          'Exported to Word successfully!',
          duration: const Duration(seconds: 2),
        );

        // Navigate to home screen after short delay
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          context.go('/appmainscreen');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Export failed', error: e, stack: stackTrace);
      if (mounted) {
        _showSnackBar(
          'Failed to export: ${e.toString().split(':').last.trim()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    Duration? duration,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Iconsax.close_circle : Iconsax.tick_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop || !_hasUnsavedChanges) return;

        final shouldDiscard =
            await showDialog<bool>(
              context: context,
              builder: (context) => _buildUnsavedChangesDialog(cs),
            ) ??
            false;

        if (shouldDiscard && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: cs.background,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: cs.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Iconsax.arrow_left, color: cs.onSurface),
            onPressed: () =>
                _showExitConfirmation(context, Theme.of(context).colorScheme),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Text Editor',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              if (_isProcessing)
                Text(
                  'Extracting text...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          actions: [
            if (!_isProcessing) ...[
              // Stats indicator
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outline.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.text_block, size: 14, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      '$_wordCount',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'words',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Iconsax.copy, color: cs.primary, size: 22),
                tooltip: 'Copy to clipboard',
                onPressed: _copyToClipboard,
              ),
              PopupMenuButton<String>(
                icon: Icon(Iconsax.more, color: cs.onSurface),
                surfaceTintColor: cs.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.document_download,
                          color: cs.onSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Export to Word',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'export') {
                    _exportToWord();
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        body: _isProcessing
            ? _buildProcessingView(cs)
            : _buildEditorView(cs, isDark),
      ),
    );
  }

  Widget _buildProcessingView(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withOpacity(0.1),
                  cs.primaryContainer.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
                Icon(Iconsax.scan_barcode, size: 32, color: cs.primary),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Extracting text from image',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Processing image with OCR...',
            style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Please wait a moment',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: cs.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorView(ColorScheme cs, bool isDark) {
    return Column(
      children: [
        // Stats header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              bottom: BorderSide(color: cs.outline.withOpacity(0.08), width: 1),
            ),
          ),
          child: Row(
            children: [
              _buildStatItem(cs, Iconsax.text_block, 'Words', '$_wordCount'),
              const SizedBox(width: 16),
              _buildStatItem(
                cs,
                Iconsax.chart_square,
                'Characters',
                '$_characterCount',
              ),
              const Spacer(),
              if (_hasUnsavedChanges)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.info_circle, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'Unsaved',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Text editor
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? cs.primary.withOpacity(0.3)
                    : cs.outline.withOpacity(0.1),
                width: _focusNode.hasFocus ? 1.5 : 1,
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.7,
                  letterSpacing: 0.2,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w400,
                ),
                cursorColor: cs.primary,
                decoration: InputDecoration(
                  hintText: _textController.text.isEmpty
                      ? 'Edit your extracted text here...\n\nYou can paste, type, or modify the text as needed.'
                      : null,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 16,
                    color: cs.onSurfaceVariant.withOpacity(0.5),
                    height: 1.7,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: () {
                  setState(() {});
                },
              ),
            ),
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(color: cs.outline.withOpacity(0.08), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Copy button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: Icon(Iconsax.copy, size: 20),
                    label: Text(
                      'Copy',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: cs.outline.withOpacity(0.3)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Save button
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [cs.primary, cs.primaryContainer],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _isExporting ? null : _saveDocument,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isExporting)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      cs.onPrimary,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Iconsax.save_2,
                                  size: 20,
                                  color: cs.onPrimary,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                _isExporting ? 'Saving...' : 'Save Document',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: cs.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    ColorScheme cs,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnsavedChangesDialog(ColorScheme cs) {
    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.warning_2, size: 28, color: Colors.orange),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'Unsaved Changes',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            // Message
            Text(
              'You have unsaved changes in your text. Are you sure you want to leave?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: cs.outline.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Continue Editing',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Discard',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation(
    BuildContext context,
    ColorScheme cs,
  ) async {
    if (!_hasUnsavedChanges) {
      if (mounted) context.pop();
      return;
    }

    final shouldDiscard =
        await showDialog<bool>(
          context: context,
          builder: (context) => _buildUnsavedChangesDialog(cs),
        ) ??
        false;

    if (shouldDiscard && mounted) {
      context.pop();
    }
  }
}
