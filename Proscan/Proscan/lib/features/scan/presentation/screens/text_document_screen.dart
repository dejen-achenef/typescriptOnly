import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/utils/share_utils.dart';
import 'package:thyscan/core/services/docx_generator_service.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

class TextDocumentScreen extends StatefulWidget {
  final String documentId;

  const TextDocumentScreen({
    super.key,
    required this.documentId,
  });

  @override
  State<TextDocumentScreen> createState() => _TextDocumentScreenState();
}

class _TextDocumentScreenState extends State<TextDocumentScreen> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  DocumentModel? _document;
  bool _isModified = false;
  bool _isSaving = false;
  bool _isExporting = false;
  Timer? _autoSaveTimer;
  String? _originalText;

  int get _characterCount => _textController.text.length;
  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _loadDocument();
    
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(() {
      setState(() {}); // Update UI on focus change
    });
  }

  void _onTextChanged() {
    final isNowModified = _textController.text != _originalText;
    if (isNowModified != _isModified) {
      setState(() => _isModified = isNowModified);
    }
    
    // Auto-save after 2 seconds of inactivity
    _autoSaveTimer?.cancel();
    if (_isModified && _document != null) {
      _autoSaveTimer = Timer(const Duration(seconds: 2), () {
        if (_isModified && mounted) {
          _saveDocument(silent: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
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
          _textController.text = doc.textContent ?? '';
          _originalText = doc.textContent ?? '';
          _isModified = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load document', error: e, stack: stackTrace);
      if (mounted) {
        _showSnackBar('Failed to load document: $e', isError: true);
      }
    }
  }

  Future<void> _saveDocument({bool silent = false}) async {
    if (_document == null || (!_isModified && !silent)) return;

    setState(() => _isSaving = true);
    _autoSaveTimer?.cancel();

    try {
      final updatedDoc = _document!.copyWith(
        textContent: _textController.text,
        updatedAt: DateTime.now(),
      );

      // Save to Hive
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      await box.put(widget.documentId, updatedDoc);

      // Update the text file
      final file = File(_document!.filePath);
      await file.writeAsString(_textController.text);

      if (mounted) {
        setState(() {
          _document = updatedDoc;
          _originalText = _textController.text;
          _isModified = false;
        });

        if (!silent) {
          HapticFeedback.lightImpact();
          _showSnackBar('Document saved successfully!');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Save failed', error: e, stack: stackTrace);
      if (mounted && !silent) {
        _showSnackBar('Failed to save: ${e.toString().split(':').last.trim()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _exportToWord() async {
    if (_document == null) return;

    // Save first if modified
    if (_isModified) {
      await _saveDocument(silent: true);
    }

    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();

    try {
      final docxPath = await DocxGeneratorService.instance.generateDocxFromText(
        text: _textController.text,
        title: _document!.title,
      );

      if (mounted) {
        _showSnackBar(
          'Exported to: ${docxPath.split('/').last}',
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () => _shareFile(docxPath),
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Export failed', error: e, stack: stackTrace);
      if (mounted) {
        _showSnackBar('Export failed: ${e.toString().split(':').last.trim()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _shareDocument() async {
    if (_document == null) return;

    try {
      await ShareUtils.shareFiles(
        [XFile(_document!.filePath)],
        subject: _document!.title,
      );
    } catch (e) {
      AppLogger.error('Share failed', error: e);
      if (mounted) {
        _showSnackBar('Share failed: ${e.toString().split(':').last.trim()}', isError: true);
      }
    }
  }

  Future<void> _shareFile(String filePath) async {
    try {
      await ShareUtils.shareFiles([XFile(filePath)]);
    } catch (e) {
      AppLogger.error('Share failed', error: e);
    }
  }

  Future<void> _deleteDocument() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Document',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${_document?.title}"? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DocumentService.instance.deleteDocument(widget.documentId);
        if (mounted) {
          context.go('/appmainscreen');
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Delete failed: $e', isError: true);
        }
      }
    }
  }

  Future<void> _showRenameDialog() async {
    if (_document == null) return;

    final controller = TextEditingController(text: _document!.title);
    final formKey = GlobalKey<FormState>();

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Document', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Document Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text('Rename', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle != _document!.title && mounted) {
      try {
        await DocumentService.instance.renameDocument(widget.documentId, newTitle);
        setState(() {
          _document = _document!.copyWith(title: newTitle);
        });
        if (mounted) {
          _showSnackBar('Document renamed successfully!');
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Rename failed: $e', isError: true);
        }
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false, Duration? duration, SnackBarAction? action}) {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_document == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        resizeToAvoidBottomInset: false, // Prevent jank from GridView/PageView rebuilds during keyboard animation
        body: Center(
          child: CircularProgressIndicator(color: cs.primary),
        ),
      );
    }

    return PopScope(
      canPop: !_isModified,
      onPopInvoked: (didPop) async {
        if (didPop || !_isModified) return;

        final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
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
                child: Text('Discard', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );

        if (shouldSave == true) {
          await _saveDocument();
        }
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        resizeToAvoidBottomInset: false, // Prevent jank from GridView/PageView rebuilds during keyboard animation
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _document!.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_rounded, size: 18, color: cs.primary),
                onPressed: _showRenameDialog,
                tooltip: 'Rename',
              ),
            ],
          ),
          actions: [
            // Auto-save indicator
            if (_isSaving)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Saving...',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              )
            else if (_isModified)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            if (_isModified)
              IconButton(
                icon: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      )
                    : Icon(Icons.save_rounded, color: cs.primary),
                onPressed: _isSaving ? null : () => _saveDocument(),
                tooltip: 'Save',
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: cs.onSurface),
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    _exportToWord();
                    break;
                  case 'share':
                    _shareDocument();
                    break;
                  case 'delete':
                    _deleteDocument();
                    break;
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
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 20),
                      const SizedBox(width: 12),
                      Text('Share'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Colors.red)),
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
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                border: Border(
                  bottom: BorderSide(
                    color: cs.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _document!.format == 'txt' ? Icons.text_snippet : Icons.description,
                    color: cs.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _document!.format.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildStatChip(cs, Icons.text_fields, '$_wordCount words'),
                  const SizedBox(width: 12),
                  _buildStatChip(cs, Icons.format_size, '$_characterCount chars'),
                  const Spacer(),
                  if (_isSaving)
                    Text(
                      'Auto-saving...',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            // Text editor
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? cs.primary.withValues(alpha: 0.3)
                        : cs.outline.withValues(alpha: 0.1),
                    width: _focusNode.hasFocus ? 2 : 1,
                  ),
                  boxShadow: _focusNode.hasFocus
                      ? [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.1),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      height: 1.6,
                      letterSpacing: 0.2,
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Start typing or paste your text here...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 16,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isExporting ? null : _exportToWord,
                        icon: _isExporting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.file_download, size: 20),
                        label: Text(
                          'Export',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _shareDocument,
                        icon: Icon(Icons.share, size: 20),
                        label: Text(
                          'Share',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
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
