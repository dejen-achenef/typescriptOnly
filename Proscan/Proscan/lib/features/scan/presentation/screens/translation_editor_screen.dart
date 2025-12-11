import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/utils/share_utils.dart';
import 'package:thyscan/core/services/docx_generator_service.dart';
import 'package:thyscan/features/scan/presentation/widgets/loading_overlay.dart';
import 'package:thyscan/features/scan/providers/translation_provider.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

class TranslationEditorScreen extends ConsumerStatefulWidget {
  final String? documentId;

  const TranslationEditorScreen({super.key, this.documentId});

  @override
  ConsumerState<TranslationEditorScreen> createState() =>
      _TranslationEditorScreenState();
}

class _TranslationEditorScreenState
    extends ConsumerState<TranslationEditorScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  DocumentModel? _document;
  bool _isModified = false;
  bool _isSaving = false;
  bool _isExporting = false;
  Timer? _debounceTimer;
  String? _originalText;

  int get _characterCount => _controller.text.length;
  int get _wordCount {
    final text = _controller.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    if (widget.documentId != null) {
      _loadDocument();
    } else {
      // Initialize with current provider state if new translation
      // Use addPostFrameCallback to safely access ref after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final state = ref.read(translationProvider);
          _controller.text = state.translatedText;
          _originalText = state.translatedText;
        }
      });
    }

    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() => setState(() {}));
  }

  void _onTextChanged() {
    final isNowModified = _controller.text != _originalText;
    if (isNowModified != _isModified) {
      setState(() => _isModified = isNowModified);
    }

    // Debounce provider updates to improve performance
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref
          .read(translationProvider.notifier)
          .updateTranslatedText(_controller.text);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      final doc = box.get(widget.documentId);

      if (doc != null && mounted) {
        setState(() {
          _document = doc;
          _controller.text = doc.textContent ?? '';
          _originalText = doc.textContent ?? '';
          _isModified = false;
          // Update provider with loaded text
          ref
              .read(translationProvider.notifier)
              .updateTranslatedText(doc.textContent ?? '');
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load document', error: e, stack: stackTrace);
      if (mounted) {
        _showSnackBar('Failed to load document: $e', isError: true);
      }
    }
  }

  Future<void> _saveDocument() async {
    if (!_isModified && _document != null) return;

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      final text = _controller.text;
      DocumentModel? savedDoc;

      if (_document != null) {
        // Update existing document
        savedDoc = _document!.copyWith(
          textContent: text,
          updatedAt: DateTime.now(),
        );

        final box = Hive.box<DocumentModel>(DocumentService.boxName);
        await box.put(_document!.id, savedDoc);

        // Update text file
        final file = File(_document!.filePath);
        await file.writeAsString(text);
      } else {
        // Save new document
        savedDoc = await DocumentService.instance.saveTextDocument(
          text: text,
          title: 'Translation ${DateTime.now().toString()}',
          scanMode: 'translate',
        );
      }

      if (mounted) {
        setState(() {
          _document = savedDoc;
          _originalText = text;
          _isModified = false;
        });

        _showSnackBar('Document saved successfully!');

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
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _onCopyPressed() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Nothing to copy', isError: true);
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    _showSnackBar('Copied to clipboard');
  }

  Future<void> _onExportDocxPressed() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showSnackBar('No text to export', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();

    try {
      // Save document first if modified (but don't navigate)
      if (_isModified && _document != null) {
        try {
          final updatedDoc = _document!.copyWith(
            textContent: text,
            updatedAt: DateTime.now(),
          );

          final box = Hive.box<DocumentModel>(DocumentService.boxName);
          await box.put(_document!.id, updatedDoc);

          final file = File(_document!.filePath);
          await file.writeAsString(text);

          if (mounted) {
            setState(() {
              _document = updatedDoc;
              _originalText = text;
              _isModified = false;
            });
          }
        } catch (e) {
          AppLogger.warning(
            'Failed to save before export',
            data: {'error': e},
            error: null,
          );
        }
      } else if (_document == null && _isModified) {
        // Save new document
        try {
          final savedDoc = await DocumentService.instance.saveTextDocument(
            text: text,
            title: 'Translation ${DateTime.now().toString()}',
            scanMode: 'translate',
          );

          if (mounted) {
            setState(() {
              _document = savedDoc;
              _originalText = text;
              _isModified = false;
            });
          }
        } catch (e) {
          AppLogger.warning(
            'Failed to save before export',
            data: {'error': e},
            error: null,
          );
        }
      }

      // Now export to Word
      final docxPath = await DocxGeneratorService.instance.generateDocxFromText(
        text: text,
        title: _document?.title ?? 'Translation',
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
          'Export failed: ${e.toString().split(':').last.trim()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _onSharePressed() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showSnackBar('No text to share', isError: true);
      return;
    }

    try {
      await ShareUtils.shareText(
        text,
        subject: _document?.title ?? 'Translation',
      );
    } catch (e) {
      AppLogger.error('Share failed', error: e);
      if (mounted) {
        _showSnackBar(
          'Share failed: ${e.toString().split(':').last.trim()}',
          isError: true,
        );
      }
    }
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    Duration? duration,
    SnackBarAction? action,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: GoogleFonts.inter(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: action,
      ),
    );
  }

  Future<void> _onChangeLanguagePressed() async {
    final state = ref.read(translationProvider);
    final current = state.targetLanguage;
    final languages = SupportedLanguage.values;

    final selected = await showModalBottomSheet<SupportedLanguage>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Translate to',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    return RadioListTile<SupportedLanguage>(
                      value: lang,
                      groupValue: current,
                      title: Text(lang.label),
                      onChanged: (value) {
                        Navigator.of(ctx).pop(value);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null || selected == current) return;

    final controller = ref.read(translationProvider.notifier);

    await LoadingOverlay.runWithDelay<void>(
      context: context,
      message: 'Translating…',
      action: () => controller.changeTargetLanguage(selected),
    );

    // Update controller with new translation
    if (mounted) {
      _controller.text = ref.read(translationProvider).translatedText;
    }
  }

  Future<void> _showRenameDialog() async {
    if (_document == null) return;

    final controller = TextEditingController(text: _document!.title);
    final formKey = GlobalKey<FormState>();

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Document Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle != _document!.title && mounted) {
      try {
        await DocumentService.instance.renameDocument(
          widget.documentId!,
          newTitle,
        );
        setState(() {
          _document = _document!.copyWith(title: newTitle);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document renamed successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Rename failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(translationProvider);

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (_isModified) {
          final shouldSave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Unsaved Changes',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Do you want to save your changes before leaving?',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Discard',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );

          if (shouldSave == true) {
            await _saveDocument();
          } else if (mounted) {
            Navigator.of(context).pop();
          }
        } else if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset:
            false, // Prevent jank from GridView/PageView rebuilds during keyboard animation
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _document?.title ?? 'Translation',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_document != null)
                IconButton(
                  icon: Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: _showRenameDialog,
                  tooltip: 'Rename',
                ),
            ],
          ),
          actions: [
            // Modified indicator
            if (_isModified && !_isSaving)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.orange),
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
            IconButton(
              tooltip: 'Change language',
              icon: Icon(
                Icons.translate_rounded,
                color: theme.colorScheme.primary,
              ),
              onPressed: _onChangeLanguagePressed,
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: theme.colorScheme.onSurface,
              ),
              onSelected: (value) {
                if (value == 'export') {
                  _onExportDocxPressed();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download, size: 20),
                      const SizedBox(width: 12),
                      Text('Export to Word'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Stats bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.translate_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    state.targetLanguage.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildStatChip(
                    theme.colorScheme,
                    Icons.text_fields,
                    '$_wordCount words',
                  ),
                  const SizedBox(width: 12),
                  _buildStatChip(
                    theme.colorScheme,
                    Icons.format_size,
                    '$_characterCount chars',
                  ),
                ],
              ),
            ),

            // Text editor
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : theme.dividerColor.withValues(alpha: 0.1),
                    width: _focusNode.hasFocus ? 2 : 1,
                  ),
                  boxShadow: _focusNode.hasFocus
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      height: 1.6,
                      letterSpacing: 0.2,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: state.isLoading
                          ? 'Translating...'
                          : 'Translation will appear here...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 16,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.5,
                        ),
                        height: 1.6,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom action bar
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveDocument,
                          icon: _isSaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(Icons.save_rounded, size: 20),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _onSharePressed,
                          icon: Icon(Icons.share, size: 20),
                          label: Text(
                            'Share',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(ColorScheme cs, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
