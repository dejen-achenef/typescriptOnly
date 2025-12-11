import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:thyscan/core/errors/failures.dart';
import 'package:thyscan/core/errors/pdf_exceptions.dart';
import 'package:thyscan/core/errors/storage_exceptions.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/app_storage_service.dart';
import 'package:thyscan/core/services/document_backend_sync_service.dart';
import 'package:thyscan/core/services/document_operation_queue.dart';
import 'package:thyscan/core/services/document_search_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/core/services/performance_tracker.dart';
import 'package:thyscan/core/services/resource_guard.dart';
import 'package:thyscan/features/scan/core/config/pdf_settings.dart';
import 'package:thyscan/features/scan/core/services/file_export_service.dart';
import 'package:thyscan/features/scan/core/services/pdf_generation_service.dart';
import 'package:thyscan/models/document_color_profile.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/pdf_preprocessor.dart';

typedef PdfProgressCallback = void Function(PdfGenerationProgress progress);

class DocumentService {
  static const String boxName = 'documents';
  static final DocumentService instance = DocumentService._();
  DocumentService._();

  final _uuid = const Uuid();
  final _documentsCache = <String, DocumentModel>{};
  final _sortedCache = <String, List<String>>{};
  bool _cacheDirty = true;
  DateTime? _lastCacheUpdate;

  Future<DocumentModel> saveDocument({
    required List<String> pageImagePaths,
    String? title,
    String scanMode = 'document',
    String? textContent,
    DocumentColorProfile colorProfile = DocumentColorProfile.color,
    PdfProgressCallback? onProgress,
    DocumentSaveOptions options = const DocumentSaveOptions(),
  }) {
    return DocumentOperationQueue.instance.enqueue(
      () => PerformanceTracker.track(
        'saveDocument',
        () => _saveDocumentInternal(
          pageImagePaths: pageImagePaths,
          title: title,
          scanMode: scanMode,
          textContent: textContent,
          colorProfile: colorProfile,
          onProgress: onProgress,
          options: options,
        ),
      ),
    );
  }

  Future<DocumentModel> _saveDocumentInternal({
    required List<String> pageImagePaths,
    String? title,
    required String scanMode,
    String? textContent,
    required DocumentColorProfile colorProfile,
    PdfProgressCallback? onProgress,
    required DocumentSaveOptions options,
  }) async {
    if (pageImagePaths.isEmpty) {
      throw ArgumentError('pageImagePaths cannot be empty');
    }

    final pageCount = pageImagePaths.length;
    options.validate(pageCount: pageCount);

    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(
      p.join(appDocsDir.path, 'scanned_documents'),
    );
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));
    final pagesDir = Directory(p.join(appDocsDir.path, 'page_images'));

    await _ensureDir(documentsDir);
    await _ensureDir(thumbsDir);
    await _ensureDir(pagesDir);

    final hasDisk = await _ensureDiskSpace(pageImagePaths: pageImagePaths);
    if (!hasDisk) {
      throw DiskSpaceException(message: 'Insufficient disk space for save');
    }

    final id = _uuid.v4();
    final createdAt = DateTime.now();
    final timestamp = createdAt.millisecondsSinceEpoch;

    final docTitle = title?.isNotEmpty == true
        ? title!
        : 'Scan ${DateFormat('MMM dd, yyyy').format(createdAt)}';

    // Temp file path for PDF generation (in scanned_documents folder)
    final tempFilePath = p.join(
      documentsDir.path,
      'doc_${id}_$timestamp.tmp.pdf',
    );
    final tempThumbnailPath = _buildThumbnailPath(
      thumbsDir.path,
      id,
      timestamp,
    );

    final resolvedTags = options.tags ?? [scanMode];
    final resolvedMetadata = (options.metadata ?? const PdfMetadata())
        .withFallbacks(title: docTitle, fallbackKeywords: resolvedTags);

    final baseConfig = PdfGenerationConfig(
      maxPageSizeMb: options.compressionPreset.maxPageSizeMb,
      pageWidth: options.paperSize.format.width,
      pageHeight: options.paperSize.format.height,
      margin: options.paperSize.suggestedMargin,
      addWhiteBackground: options.addWhiteBackground,
      metadata: resolvedMetadata.toPdfDocumentMetadata(),
    );

    final appliedConfig =
        ResourceGuard.instance.hasSufficientMemory(minFreeMb: 250)
        ? baseConfig
        : baseConfig.copyWith(
            maxPageSizeMb: max(0.8, baseConfig.maxPageSizeMb * 0.75),
          );

    PdfGenerationResult? pdfResult;
    String? committedFilePath;
    String? committedThumbPath;
    List<String> preprocessedPaths = const [];

    try {
      preprocessedPaths = await PdfPreprocessor.instance.preprocess(
        imagePaths: pageImagePaths,
        dpi: options.dpi,
      );

      final generationInputs = preprocessedPaths.isNotEmpty
          ? preprocessedPaths
          : pageImagePaths;

      pdfResult = await PdfGenerationService.instance.generate(
        imagePaths: generationInputs,
        outputPdfPath: tempFilePath,
        optimizedDirPath: pagesDir.path,
        documentId: id,
        batchId: timestamp.toString(),
        config: appliedConfig,
        onProgress: onProgress,
      );

      final tempFile = File(tempFilePath);
      if (!await tempFile.exists()) {
        throw StorageFailure('Temporary PDF file missing after generation');
      }

      // Move PDF from temp location to organized folder structure
      final savedPdfPath = await AppStorageService.instance.moveToAppFolder(
        tempFilePath: tempFilePath,
        documentId: id,
        scanMode: scanMode,
        format: 'pdf',
      );
      committedFilePath = savedPdfPath;

      if (pdfResult.optimizedImagePaths.isNotEmpty) {
        final firstPageFile = File(pdfResult.optimizedImagePaths.first);
        if (await firstPageFile.exists()) {
          await firstPageFile.copy(tempThumbnailPath);
          committedThumbPath = tempThumbnailPath;
        }
      }

      final doc = DocumentModel(
        id: id,
        title: docTitle,
        filePath: savedPdfPath,
        thumbnailPath: committedThumbPath ?? '',
        format: 'pdf',
        pageCount: pageCount,
        createdAt: createdAt,
        updatedAt: createdAt,
        pageImagePaths: pdfResult.optimizedImagePaths,
        scanMode: scanMode,
        textContent: textContent,
        colorProfile: colorProfile.key,
        tags: resolvedTags,
        metadata: resolvedMetadata.toDocumentMap(),
      );

      // Use repository for async write (never blocks main thread)
      await DocumentRepository.instance.saveDocument(doc);
      _markCacheDirty();
      
      // Invalidate search cache
      DocumentSearchService.instance.invalidateCacheForDocument(id);

      // Upload to cloud in background (non-blocking)
      print('═══════════════════════════════════════════════════════════');
      print('🚀 [DOCUMENT SERVICE] Starting background upload');
      print('   Document ID: ${doc.id}');
      print('   Title: ${doc.title}');
      print('   Format: ${doc.format}');
      print('   Page Count: ${doc.pageCount}');
      print('   File Path: ${doc.filePath}');
      print('═══════════════════════════════════════════════════════════');
      
      AppLogger.info(
        '🚀 Starting background upload for document ${doc.id}',
        data: {
          'documentId': doc.id,
          'title': doc.title,
          'format': doc.format,
          'pageCount': doc.pageCount,
        },
      );
      
      DocumentUploadService.instance.uploadDocument(doc).then((url) {
        print('═══════════════════════════════════════════════════════════');
        print('✅ [DOCUMENT SERVICE] Upload completed');
        print('   Document ID: ${doc.id}');
        print('   URL: ${url != null ? url.substring(0, url.length > 60 ? 60 : url.length) + "..." : "NULL (queued)"}');
        print('═══════════════════════════════════════════════════════════');
        if (url != null) {
          AppLogger.info(
            '✅ Document uploaded successfully: ${doc.id}',
            data: {'url': url.substring(0, 50) + '...'},
          );
        } else {
          AppLogger.warning(
            '⚠️ Document upload queued for later: ${doc.id}',
            error: null,
          );
        }
      }).catchError((error, stack) {
        print('═══════════════════════════════════════════════════════════');
        print('❌ [DOCUMENT SERVICE] Upload FAILED');
        print('   Document ID: ${doc.id}');
        print('   Error: $error');
        print('   Stack: ${stack.toString().substring(0, stack.toString().length > 200 ? 200 : stack.toString().length)}');
        print('═══════════════════════════════════════════════════════════');
        AppLogger.error(
          '❌ Background upload failed for document ${doc.id}',
          error: error,
          stack: stack,
        );
        // Upload will be retried automatically via queue
      });

      return doc;
    } catch (e) {
      await _deleteIfExists(tempFilePath);
      if (committedFilePath != null) {
        await _deleteIfExists(committedFilePath);
      }
      if (committedThumbPath != null) {
        await _deleteIfExists(committedThumbPath);
      }
      rethrow;
    } finally {
      await _cleanupTempFiles(preprocessedPaths);
    }
  }

  /// Retrieves all documents safely, filtering out corrupted entries or missing files.
  /// Returns a list of valid [DocumentModel]s.
  Future<List<DocumentModel>> getAllDocumentsSafe() async {
    await _refreshCache(forceRefresh: true);
    final docs = _documentsCache.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  @Deprecated('Use getDocumentsPaginated or getAllDocumentsSafe instead.')
  List<DocumentModel> getAllDocuments() {
    if (_documentsCache.isNotEmpty && !_cacheDirty) {
      final docs = _documentsCache.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    }

    final box = Hive.box<DocumentModel>(boxName);
    final docs = box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  Future<DocumentModel> updateDocument({
    required String documentId,
    required List<String> pageImagePaths,
    String? title,
    String? scanMode,
    DocumentColorProfile? colorProfile,
    PdfProgressCallback? onProgress,
    DocumentSaveOptions options = const DocumentSaveOptions(),
  }) {
    return DocumentOperationQueue.instance.enqueue(
      () => PerformanceTracker.track(
        'updateDocument',
        () => _updateDocumentInternal(
          documentId: documentId,
          pageImagePaths: pageImagePaths,
          title: title,
          scanMode: scanMode,
          colorProfile: colorProfile,
          onProgress: onProgress,
          options: options,
        ),
      ),
    );
  }

  Future<DocumentModel> _updateDocumentInternal({
    required String documentId,
    required List<String> pageImagePaths,
    String? title,
    String? scanMode,
    DocumentColorProfile? colorProfile,
    PdfProgressCallback? onProgress,
    required DocumentSaveOptions options,
  }) async {
    if (pageImagePaths.isEmpty) {
      throw ArgumentError('pageImagePaths cannot be empty');
    }

    // Use repository for async read (never blocks main thread)
    final existingDoc = await DocumentRepository.instance.getDocumentById(documentId);

    if (existingDoc == null) {
      throw DocumentStorageException(
        message: 'Document not found',
        documentId: documentId,
        type: StorageErrorType.notFound,
      );
    }

    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(
      p.join(appDocsDir.path, 'scanned_documents'),
    );
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));
    final pagesDir = Directory(p.join(appDocsDir.path, 'page_images'));

    await _ensureDir(documentsDir);
    await _ensureDir(thumbsDir);
    await _ensureDir(pagesDir);

    final hasDisk = await _ensureDiskSpace(pageImagePaths: pageImagePaths);
    if (!hasDisk) {
      throw DiskSpaceException(
        message: 'Insufficient disk space for update',
        documentId: documentId,
      );
    }

    final pageCount = pageImagePaths.length;
    options.validate(pageCount: pageCount);
    final docTitle = title?.isNotEmpty == true ? title! : existingDoc.title;
    final newScanMode = scanMode ?? existingDoc.scanMode;
    final newColorProfile =
        colorProfile ?? DocumentColorProfile.fromKey(existingDoc.colorProfile);
    final resolvedTags = options.tags ?? existingDoc.tags;
    final baseMetadata = options.metadata ?? _metadataFromDocument(existingDoc);
    final resolvedMetadata = baseMetadata.withFallbacks(
      title: docTitle,
      fallbackKeywords: resolvedTags,
    );
    final baseConfig = PdfGenerationConfig(
      maxPageSizeMb: options.compressionPreset.maxPageSizeMb,
      pageWidth: options.paperSize.format.width,
      pageHeight: options.paperSize.format.height,
      margin: options.paperSize.suggestedMargin,
      addWhiteBackground: options.addWhiteBackground,
      metadata: resolvedMetadata.toPdfDocumentMetadata(),
    );
    final appliedConfig =
        ResourceGuard.instance.hasSufficientMemory(minFreeMb: 250)
        ? baseConfig
        : baseConfig.copyWith(
            maxPageSizeMb: max(0.8, baseConfig.maxPageSizeMb * 0.75),
          );

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final tempFilePath = p.join(
      documentsDir.path,
      'doc_${documentId}_$timestamp.tmp.pdf',
    );
    final tempThumbPath = _buildThumbnailPath(
      thumbsDir.path,
      documentId,
      timestamp,
    );

    PdfGenerationResult? pdfResult;
    String? committedFilePath;
    String? committedThumbPath;
    List<String> preprocessedPaths = const [];

    try {
      preprocessedPaths = await PdfPreprocessor.instance.preprocess(
        imagePaths: pageImagePaths,
        dpi: options.dpi,
      );

      final generationInputs = preprocessedPaths.isNotEmpty
          ? preprocessedPaths
          : pageImagePaths;

      pdfResult = await PdfGenerationService.instance.generate(
        imagePaths: generationInputs,
        outputPdfPath: tempFilePath,
        optimizedDirPath: pagesDir.path,
        documentId: documentId,
        batchId: timestamp.toString(),
        config: appliedConfig,
        onProgress: onProgress,
      );

      final tempFile = File(tempFilePath);
      if (!await tempFile.exists()) {
        throw StorageFailure('Temporary PDF file missing after generation');
      }

      // Delete old file if it exists in a different location or if scan mode changed
      final oldFilePath = existingDoc.filePath;
      if (oldFilePath.isNotEmpty) {
        try {
          final oldFile = File(oldFilePath);
          if (await oldFile.exists()) {
            // Only delete if scan mode changed or file is in old location
            final isOldLocation = oldFilePath.contains('scanned_documents');
            if (newScanMode != existingDoc.scanMode || isOldLocation) {
              await oldFile.delete();
              AppLogger.info(
                'Deleted old document file',
                data: {'oldPath': oldFilePath, 'documentId': documentId},
              );
            }
          }
        } catch (e) {
          AppLogger.warning(
            'Failed to delete old document file',
            data: {'oldPath': oldFilePath, 'error': e.toString()},
            error: null,
          );
          // Continue even if deletion fails
        }
      }

      // Move PDF from temp location to organized folder structure
      final savedPdfPath = await AppStorageService.instance.moveToAppFolder(
        tempFilePath: tempFilePath,
        documentId: documentId,
        scanMode: newScanMode,
        format: 'pdf',
      );
      committedFilePath = savedPdfPath;

      if (pdfResult.optimizedImagePaths.isNotEmpty) {
        final firstPageFile = File(pdfResult.optimizedImagePaths.first);
        if (await firstPageFile.exists()) {
          await firstPageFile.copy(tempThumbPath);
          committedThumbPath = tempThumbPath;
        }
      }

      if (existingDoc.thumbnailPath.isNotEmpty &&
          existingDoc.thumbnailPath != committedThumbPath) {
        await _deleteIfExists(existingDoc.thumbnailPath);
      }

      for (final oldPagePath in existingDoc.pageImagePaths) {
        try {
          if (!pdfResult.optimizedImagePaths.contains(oldPagePath)) {
            final pageFile = File(oldPagePath);
            if (await pageFile.exists()) await pageFile.delete();
          }
        } catch (_) {}
      }

      final updatedDoc = DocumentModel(
        id: documentId,
        title: docTitle,
        filePath: savedPdfPath,
        thumbnailPath: committedThumbPath ?? existingDoc.thumbnailPath,
        format: 'pdf',
        pageCount: pageCount,
        createdAt: existingDoc.createdAt,
        updatedAt: DateTime.now(),
        pageImagePaths: pdfResult.optimizedImagePaths,
        scanMode: newScanMode,
        colorProfile: newColorProfile.key,
        textContent: existingDoc.textContent,
        tags: resolvedTags,
        metadata: resolvedMetadata.toDocumentMap(),
      );

      // Use repository for async write (never blocks main thread)
      await DocumentRepository.instance.updateDocument(updatedDoc);
      _markCacheDirty();
      
      // Invalidate search cache
      DocumentSearchService.instance.invalidateCacheForDocument(documentId);

      // Upload updated file to Supabase Storage and sync metadata to backend
      // This will replace the old file in storage and update the backend with new metadata
      AppLogger.info(
        '🔄 Document updated, uploading new version to Supabase Storage',
        data: {
          'documentId': updatedDoc.id,
          'title': updatedDoc.title,
          'pageCount': updatedDoc.pageCount,
          'filePath': updatedDoc.filePath,
          'format': updatedDoc.format,
        },
      );

      DocumentUploadService.instance.uploadDocument(updatedDoc).then((url) {
        if (url != null) {
          AppLogger.info(
            '✅ Updated document uploaded successfully',
            data: {
              'documentId': updatedDoc.id,
              'url': url.substring(0, url.length > 100 ? 100 : url.length) + '...',
            },
          );
        } else {
          AppLogger.warning(
            '⚠️ Updated document upload queued for later',
            error: null,
            data: {'documentId': updatedDoc.id},
          );
        }
      }).catchError((error, stack) {
        AppLogger.error(
          '❌ Failed to upload updated document',
          error: error,
          stack: stack,
          data: {'documentId': updatedDoc.id},
        );
        // Upload will be retried automatically via queue
      });

      return updatedDoc;
    } catch (e) {
      await _deleteIfExists(tempFilePath);
      if (committedFilePath != null) {
        await _deleteIfExists(committedFilePath);
      }
      if (committedThumbPath != null) {
        await _deleteIfExists(committedThumbPath);
      }
      rethrow;
    } finally {
      await _cleanupTempFiles(preprocessedPaths);
    }
  }

  Future<DocumentModel> saveTextDocument({
    required String text,
    String? title,
    String scanMode = 'text',
  }) {
    return DocumentOperationQueue.instance.enqueue(
      () => PerformanceTracker.track(
        'saveTextDocument',
        () => _saveTextDocumentInternal(
          text: text,
          title: title,
          scanMode: scanMode,
        ),
      ),
    );
  }

  Future<DocumentModel> _saveTextDocumentInternal({
    required String text,
    String? title,
    required String scanMode,
  }) async {
    if (text.isEmpty) {
      throw ArgumentError('text cannot be empty');
    }

    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(
      p.join(appDocsDir.path, 'scanned_documents'),
    );
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));

    await _ensureDir(documentsDir);
    await _ensureDir(thumbsDir);

    final id = _uuid.v4();
    final createdAt = DateTime.now();

    final docTitle = title?.isNotEmpty == true
        ? title!
        : 'Text ${DateFormat('MMM dd, yyyy').format(createdAt)}';

    final thumbnailPath = p.join(thumbsDir.path, 'thumb_$id.png');

    // Generate DOCX file using FileExportService (creates temp file)
    final fileExportService = FileExportService();
    final tempPath = await fileExportService.exportToWord(
      text: text,
      fileName: 'doc_$id',
    );

    // Move DOCX from temp location to organized folder structure
    final filePath = await AppStorageService.instance.moveToAppFolder(
      tempFilePath: tempPath,
      documentId: id,
      scanMode: scanMode,
      format: 'docx',
    );

    // Create a text thumbnail (icon-based)
    // For now, we'll use a placeholder path
    // You can generate an actual thumbnail image if needed
    final thumbFile = File(thumbnailPath);
    await thumbFile.writeAsBytes([]); // Empty file as placeholder

    // Save to Hive
    final doc = DocumentModel(
      id: id,
      title: docTitle,
      filePath: filePath,
      thumbnailPath: thumbnailPath,
      format: 'docx',
      pageCount: 1,
      createdAt: createdAt,
      updatedAt: createdAt,
      pageImagePaths: [], // No page images for text documents
      scanMode: scanMode,
      textContent: text, // Store the text content
      colorProfile: DocumentColorProfile.color.key,
      tags: const ['text'],
      metadata: const {
        'title': 'Text Document',
        'creator': 'ThyScan Text Suite',
      },
    );

    // Use repository for async write (never blocks main thread)
    await DocumentRepository.instance.saveDocument(doc);
    _markCacheDirty();
    
    // Invalidate search cache
    DocumentSearchService.instance.invalidateCacheForDocument(id);

    // Upload to cloud in background (non-blocking)
    DocumentUploadService.instance.uploadDocument(doc).catchError((error) {
      AppLogger.warning(
        'Background upload failed for document ${doc.id}',
        error: error,
      );
      // Upload will be retried automatically via queue
      return null; // Return null to satisfy catchError signature
    });

    return doc;
  }

  Future<void> deleteDocument(String id, {bool hardDelete = false}) {
    return DocumentOperationQueue.instance.enqueue(
      () => PerformanceTracker.track(
        'deleteDocument',
        () => _deleteDocumentInternal(id, hardDelete: hardDelete),
      ),
    );
  }

  Future<void> _deleteDocumentInternal(String id, {bool hardDelete = false}) async {
    // Use repository for async read (never blocks main thread)
    final doc = await DocumentRepository.instance.getDocumentById(id);

    if (doc == null) {
      AppLogger.warning(
        'Document not found for deletion',
        error: null,
        data: {'documentId': id},
      );
      return;
    }

    AppLogger.info(
      '🗑️ Starting document deletion',
      data: {
        'documentId': id,
        'title': doc.title,
        'filePath': doc.filePath,
        'hardDelete': hardDelete,
      },
    );

    // Check if document is uploaded to Supabase Storage
    // If filePath is a URL (starts with http/https), it's in Supabase Storage
    final isUploaded = doc.filePath.startsWith('http://') ||
        doc.filePath.startsWith('https://');

    // If hard delete is requested or document is local-only, perform immediate deletion
    if (hardDelete || !isUploaded) {
      // Perform hard delete (immediate permanent deletion)
      await _performHardDelete(id, doc, isUploaded);
    } else {
      // Perform soft delete (mark as deleted, keep for retention period)
      await _performSoftDelete(id, doc);
    }
  }

  /// Performs soft delete: marks document as deleted but keeps it for retention period
  Future<void> _performSoftDelete(String id, DocumentModel doc) async {
    AppLogger.info(
      '🗑️ Performing soft delete',
      data: {'documentId': id, 'title': doc.title},
    );

    // Mark document as deleted in Hive
    final softDeletedDoc = doc.copyWith(
      isDeleted: true,
      deletedAt: DateTime.now(),
    );
    // Use repository for async write
    await DocumentRepository.instance.updateDocument(softDeletedDoc);
    _markCacheDirty();

    // Request soft delete from backend
    final isUploaded = doc.filePath.startsWith('http://') ||
        doc.filePath.startsWith('https://');
    
    if (isUploaded) {
      try {
        final fileUrl = doc.filePath;
        final thumbnailUrl = doc.thumbnailPath.isNotEmpty &&
                (doc.thumbnailPath.startsWith('http://') ||
                    doc.thumbnailPath.startsWith('https://'))
            ? doc.thumbnailPath
            : null;

        await DocumentBackendSyncService.instance.deleteDocument(
          documentId: id,
          fileUrl: fileUrl,
          thumbnailUrl: thumbnailUrl,
          hardDelete: false, // Request soft delete from backend
        );

        AppLogger.info(
          '✅ Document soft deleted on backend',
          data: {'documentId': id},
        );
      } catch (e, stack) {
        AppLogger.error(
          '⚠️ Failed to soft delete document on backend (keeping local soft delete)',
          error: e,
          stack: stack,
          data: {'documentId': id},
        );
        // Revert local soft delete on backend failure
        final revertedDoc = softDeletedDoc.copyWith(
          isDeleted: false,
          deletedAt: null,
        );
        // Use repository for async write
        await DocumentRepository.instance.updateDocument(revertedDoc);
        _markCacheDirty();
        DocumentSyncStateService.instance.setSyncStatus(
          id,
          DocumentSyncStatus.error,
          errorMessage: 'Failed to soft delete on backend: ${e.toString()}',
        );
      }
    }
  }

  /// Performs hard delete: permanently removes document from storage and database
  Future<void> _performHardDelete(String id, DocumentModel doc, bool isUploaded) async {
    AppLogger.info(
      '🗑️ Performing hard delete',
      data: {'documentId': id, 'title': doc.title},
    );

    // 1. Delete from Supabase Storage and PostgreSQL (if uploaded)
    if (isUploaded) {
      try {
        AppLogger.info(
          '📤 Document is uploaded, deleting from Supabase Storage and PostgreSQL',
          data: {'documentId': id},
        );

        // Extract fileUrl and thumbnailUrl from filePath and thumbnailPath
        final fileUrl = doc.filePath;
        final thumbnailUrl = doc.thumbnailPath.isNotEmpty &&
                (doc.thumbnailPath.startsWith('http://') ||
                    doc.thumbnailPath.startsWith('https://'))
            ? doc.thumbnailPath
            : null;

        await DocumentBackendSyncService.instance.deleteDocument(
          documentId: id,
          fileUrl: fileUrl,
          thumbnailUrl: thumbnailUrl,
          hardDelete: true, // Request hard delete from backend
        );

        AppLogger.info(
          '✅ Document deleted from Supabase Storage and PostgreSQL',
          data: {'documentId': id},
        );
      } catch (e, stack) {
        // Log error but continue with local deletion
        // This ensures local cleanup happens even if backend deletion fails
        AppLogger.error(
          '⚠️ Failed to delete document from backend (continuing with local deletion)',
          error: e,
          stack: stack,
          data: {'documentId': id},
        );
      }
    } else {
      AppLogger.info(
        '📱 Document is local only, skipping backend deletion',
        data: {'documentId': id},
      );
    }

    // 2. Delete local files (if they exist)
    await _deleteLocalFiles(doc, isUploaded);

    // 3. Clear sync status for this document
    try {
      DocumentSyncStateService.instance.clearSyncStatus(id);
      AppLogger.info(
        'Cleared sync status for deleted document',
        data: {'documentId': id},
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to clear sync status (non-critical)',
        error: e,
        data: {'documentId': id},
      );
    }

    // 4. Delete from local storage using repository
    // Use repository for async delete (never blocks main thread)
    await DocumentRepository.instance.deleteDocument(id);
    _markCacheDirty();
    
    // Invalidate search cache
    DocumentSearchService.instance.invalidateCacheForDocument(id);

    AppLogger.info(
      '✅ Document hard deletion completed',
      data: {
        'documentId': id,
        'wasUploaded': isUploaded,
      },
    );
  }

  /// Restores a soft-deleted document
  Future<void> restoreDocument(String id) async {
    // Use repository for async read (never blocks main thread)
    final doc = await DocumentRepository.instance.getDocumentById(id);

    if (doc == null || !doc.isDeleted) {
      AppLogger.warning(
        'Document not found or not deleted',
        error: null,
        data: {'documentId': id},
      );
      return;
    }

    final restoredDoc = doc.copyWith(
      isDeleted: false,
      deletedAt: null,
    );
    // Use repository for async write (never blocks main thread)
    await DocumentRepository.instance.updateDocument(restoredDoc);
    _markCacheDirty();

    // If document was uploaded, restore it on backend
    final isUploaded = doc.filePath.startsWith('http://') ||
        doc.filePath.startsWith('https://');
    
    if (isUploaded) {
      try {
        // Update document metadata on backend to clear deleted flag
        await DocumentBackendSyncService.instance.updateDocumentMetadata(restoredDoc);
        DocumentSyncStateService.instance.setSyncStatus(
          id,
          DocumentSyncStatus.synced,
          lastSyncTime: DateTime.now(),
        );
        AppLogger.info(
          '✅ Document restored on backend',
          data: {'documentId': id},
        );
      } catch (e, stack) {
        AppLogger.error(
          '⚠️ Failed to restore document on backend',
          error: e,
          stack: stack,
          data: {'documentId': id},
        );
        DocumentSyncStateService.instance.setSyncStatus(
          id,
          DocumentSyncStatus.error,
          errorMessage: 'Failed to restore on backend: ${e.toString()}',
        );
      }
    }
  }

  /// Deletes local files associated with a document
  Future<void> _deleteLocalFiles(DocumentModel doc, bool isUploaded) async {
    try {
      // Only try to delete if it's a local file path (not a URL)
      if (!isUploaded) {
        final file = File(doc.filePath);
        if (await file.exists()) {
          await file.delete();
          AppLogger.info(
            '🗑️ Deleted local document file',
            data: {'path': doc.filePath},
          );
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to delete local document file (may not exist)',
        error: e,
        data: {'path': doc.filePath},
      );
    }

    try {
      // Delete thumbnail if it's a local file
      if (doc.thumbnailPath.isNotEmpty &&
          !doc.thumbnailPath.startsWith('http://') &&
          !doc.thumbnailPath.startsWith('https://')) {
        final thumb = File(doc.thumbnailPath);
        if (await thumb.exists()) {
          await thumb.delete();
          AppLogger.info(
            '🗑️ Deleted local thumbnail file',
            data: {'path': doc.thumbnailPath},
          );
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to delete local thumbnail file (may not exist)',
        error: e,
        data: {'path': doc.thumbnailPath},
      );
    }

    // Delete all page images (always local files)
    for (final pagePath in doc.pageImagePaths) {
      try {
        final pageFile = File(pagePath);
        if (await pageFile.exists()) {
          await pageFile.delete();
        }
      } catch (e) {
        AppLogger.warning(
          'Failed to delete page image (may not exist)',
          error: e,
          data: {'path': pagePath},
        );
      }
    }
  }

  Future<void> renameDocument(String id, String newTitle) {
    return DocumentOperationQueue.instance.enqueue(
      () => PerformanceTracker.track(
        'renameDocument',
        () => _renameDocumentInternal(id, newTitle),
      ),
    );
  }

  Future<void> _renameDocumentInternal(String id, String newTitle) async {
    final box = Hive.box<DocumentModel>(boxName);
    final doc = box.get(id);

    if (doc != null) {
      final updatedDoc = DocumentModel(
        id: doc.id,
        title: newTitle,
        filePath: doc.filePath,
        thumbnailPath: doc.thumbnailPath,
        format: doc.format,
        pageCount: doc.pageCount,
        createdAt: doc.createdAt,
        pageImagePaths: doc.pageImagePaths,
        scanMode: doc.scanMode,
        textContent: doc.textContent,
        updatedAt: DateTime.now(),
        colorProfile: doc.colorProfile,
        tags: doc.tags,
        metadata: doc.metadata,
      );
      // Use repository for async write (never blocks main thread)
      await DocumentRepository.instance.updateDocument(updatedDoc);
      _markCacheDirty();
      
      // Invalidate search cache
      DocumentSearchService.instance.invalidateCacheForDocument(id);
    }
  }

  Future<PaginatedDocuments> getDocumentsPaginated({
    int page = 0,
    int pageSize = 20,
    String sortBy = 'createdAt',
    bool descending = true,
    bool forceRefresh = false,
  }) async {
    await _refreshCache(forceRefresh: forceRefresh);
    final sortedIds = await _getSortedIds(sortBy, descending);

    final start = page * pageSize;
    if (start >= sortedIds.length) {
      return PaginatedDocuments(
        page: page,
        pageSize: pageSize,
        totalItems: sortedIds.length,
        items: const [],
        hasMore: false,
      );
    }

    final end = min(start + pageSize, sortedIds.length);
    final items = sortedIds
        .sublist(start, end)
        .map((id) => _documentsCache[id])
        .whereType<DocumentModel>()
        .toList();

    return PaginatedDocuments(
      page: page,
      pageSize: pageSize,
      totalItems: sortedIds.length,
      items: items,
      hasMore: end < sortedIds.length,
    );
  }

  Future<void> _refreshCache({bool forceRefresh = false}) async {
    if (!forceRefresh && !_cacheDirty && _documentsCache.isNotEmpty) {
      return;
    }

    // Use repository for async Hive access (never blocks main thread)
    final docs = await DocumentRepository.instance.getAllDocuments(includeDeleted: false);
    _documentsCache
      ..clear()
      ..addEntries(docs.map((doc) => MapEntry(doc.id, doc)));
    _sortedCache.clear();
    _cacheDirty = false;
    _lastCacheUpdate = DateTime.now();
    AppLogger.info(
      'Document cache refreshed',
      data: {
        'count': _documentsCache.length,
        'timestamp': _lastCacheUpdate!.toIso8601String(),
      },
    );
  }

  Future<List<String>> _getSortedIds(String sortBy, bool descending) async {
    final sortKey = '$sortBy|${descending ? 'desc' : 'asc'}';
    if (_sortedCache.containsKey(sortKey)) {
      return _sortedCache[sortKey]!;
    }

    final payload = {
      'docs': _documentsCache.values
          .map(
            (doc) => {
              'id': doc.id,
              'title': doc.title,
              'createdAt': doc.createdAt.millisecondsSinceEpoch,
              'updatedAt': doc.updatedAt.millisecondsSinceEpoch,
              'pageCount': doc.pageCount,
            },
          )
          .toList(),
      'sortBy': sortBy,
      'descending': descending,
    };

    final sortedIds = await compute<Map<String, dynamic>, List<String>>(
      _sortDocumentIdsIsolate,
      payload,
    );
    _sortedCache[sortKey] = sortedIds;
    return sortedIds;
  }

  void _markCacheDirty() {
    _cacheDirty = true;
  }

  String _buildThumbnailPath(String baseDir, String documentId, int timestamp) {
    return p.join(baseDir, 'thumb_${documentId}_$timestamp.jpg');
  }

  Future<void> _ensureDir(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Calculates total size of page images
  Future<int> calculateTotalSize(List<String> pageImagePaths) async {
    var totalBytes = 0;
    for (final path in pageImagePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          totalBytes += await file.length();
        }
      } catch (_) {}
    }
    return totalBytes;
  }

  /// Validates file size and provides user feedback
  /// Returns a validation result with warnings if size is large
  Future<FileSizeValidationResult> validateFileSize(
    List<String> pageImagePaths,
  ) async {
    final totalBytes = await calculateTotalSize(pageImagePaths);
    final totalSizeMB = totalBytes / (1024 * 1024);
    const maxRecommendedSizeMB = 50.0;

    if (totalSizeMB > maxRecommendedSizeMB) {
      return FileSizeValidationResult(
        isValid: true,
        totalSizeMB: totalSizeMB,
        warning: 'Large file detected (${totalSizeMB.toStringAsFixed(1)}MB). '
            'Processing may take longer. Consider using compression.',
        requiresCompression: true,
      );
    }

    return FileSizeValidationResult(
      isValid: true,
      totalSizeMB: totalSizeMB,
      warning: null,
      requiresCompression: false,
    );
  }

  Future<bool> _ensureDiskSpace({required List<String> pageImagePaths}) async {
    final requiredBytes = await calculateTotalSize(pageImagePaths);
    // Add 10MB buffer for processing overhead
    final requiredBytesWithBuffer = max(requiredBytes, 10 * 1024 * 1024);

    return ResourceGuard.instance.hasSufficientDiskSpace(
      requiredBytes: requiredBytesWithBuffer,
    );
  }

  PdfMetadata _metadataFromDocument(DocumentModel doc) {
    final data = doc.metadata;
    return PdfMetadata(
      title: data['title'],
      author: data['author'],
      subject: data['subject'],
      keywords: (data['keywords']?.split(',') ?? doc.tags)
          .where((s) => s.isNotEmpty)
          .toList(),
      creator: data['creator'],
    );
  }

  Future<void> _cleanupTempFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  Future<DatabaseHealthReport> runHealthCheck() async {
    final missingDocuments = <String>[];
    final missingThumbnails = <String>[];
    final orphanedFiles = <String>[];

    final appDocsDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory(
      p.join(appDocsDir.path, 'scanned_documents'),
    );
    final thumbsDir = Directory(p.join(appDocsDir.path, 'thumbnails'));

    await _ensureDir(documentsDir);
    await _ensureDir(thumbsDir);

    final box = Hive.box<DocumentModel>(boxName);
    final referencedDocuments = <String>{};
    final referencedThumbnails = <String>{};

    for (final doc in box.values) {
      referencedDocuments.add(doc.filePath);
      referencedThumbnails.add(doc.thumbnailPath);

      if (!await File(doc.filePath).exists()) {
        missingDocuments.add(doc.id);
      }
      if (doc.thumbnailPath.isNotEmpty &&
          !await File(doc.thumbnailPath).exists()) {
        missingThumbnails.add(doc.id);
      }
    }

    for (final file in documentsDir.listSync().whereType<File>().map(
      (f) => f.path,
    )) {
      if (!referencedDocuments.contains(file)) {
        orphanedFiles.add(file);
      }
    }
    for (final file in thumbsDir.listSync().whereType<File>().map(
      (f) => f.path,
    )) {
      if (!referencedThumbnails.contains(file)) {
        orphanedFiles.add(file);
      }
    }

    return DatabaseHealthReport(
      missingDocumentIds: missingDocuments,
      missingThumbnails: missingThumbnails,
      orphanedFiles: orphanedFiles,
    );
  }

  /// Pulls remote document changes from backend and updates local storage.
  ///
  /// This method is called by BackgroundSyncService but can also be called manually.
  ///
  /// **Process:**
  /// 1. Fetches documents updated since last successful sync
  /// 2. Updates local Hive storage
  /// 3. Handles conflicts (last write wins)
  /// 4. Updates sync status for each document
  Future<void> pullRemoteChanges() async {
    try {
      // Ensure sync state service is initialized
      if (!DocumentSyncStateService.instance.isInitialized) {
        await DocumentSyncStateService.instance.initialize();
      }

      // Get last successful pull sync time
      final lastSyncTime = DocumentSyncStateService.instance.lastSuccessfulPullSyncTime;
      final since = lastSyncTime ?? DateTime.now().subtract(const Duration(days: 30));

      AppLogger.info(
        'Pulling remote changes since ${since.toIso8601String()}',
        data: {'since': since.toIso8601String()},
      );

      // Fetch remote documents
      final remoteDocuments = await DocumentBackendSyncService.instance.getDocumentsSince(since);

      if (remoteDocuments.isEmpty) {
        AppLogger.info('No remote changes found');
        DocumentSyncStateService.instance.setLastSuccessfulPullSyncTime(DateTime.now());
        return;
      }

      AppLogger.info(
        'Fetched ${remoteDocuments.length} remote documents',
        data: {'count': remoteDocuments.length},
      );

      // Process each remote document
      final box = Hive.box<DocumentModel>(boxName);
      int updated = 0;
      int created = 0;
      int conflicts = 0;

      for (final remoteDoc in remoteDocuments) {
        try {
          final localDoc = box.get(remoteDoc.id);

          if (localDoc == null) {
            // New document from cloud
            await box.put(remoteDoc.id, remoteDoc);
            DocumentSyncStateService.instance.setSyncStatus(
              remoteDoc.id,
              DocumentSyncStatus.synced,
              lastSyncTime: DateTime.now(),
            );
            created++;
          } else if (remoteDoc.isDeleted) {
            // Document deleted on cloud
            if (!localDoc.isDeleted) {
              // Soft delete locally
              final softDeletedDoc = localDoc.copyWith(
                isDeleted: true,
                deletedAt: DateTime.now(),
              );
              await box.put(remoteDoc.id, softDeletedDoc);
              DocumentSyncStateService.instance.setSyncStatus(
                remoteDoc.id,
                DocumentSyncStatus.synced,
                lastSyncTime: DateTime.now(),
              );
            }
          } else if (remoteDoc.updatedAt.isAfter(localDoc.updatedAt)) {
            // Remote is newer, update local (last write wins)
            await box.put(remoteDoc.id, remoteDoc);
            DocumentSyncStateService.instance.setSyncStatus(
              remoteDoc.id,
              DocumentSyncStatus.synced,
              lastSyncTime: DateTime.now(),
            );
            updated++;
          } else if (localDoc.updatedAt.isAfter(remoteDoc.updatedAt)) {
            // Local is newer, mark as conflict
            DocumentSyncStateService.instance.setSyncStatus(
              remoteDoc.id,
              DocumentSyncStatus.pendingConflictResolution,
              errorMessage: 'Local version is newer than remote',
            );
            conflicts++;
          } else {
            // Same timestamp, already synced
            DocumentSyncStateService.instance.setSyncStatus(
              remoteDoc.id,
              DocumentSyncStatus.synced,
              lastSyncTime: DateTime.now(),
            );
          }
        } catch (e, stack) {
          AppLogger.error(
            'Failed to process remote document',
            error: e,
            stack: stack,
            data: {'documentId': remoteDoc.id},
          );
        }
      }

      // Update last successful pull sync time
      DocumentSyncStateService.instance.setLastSuccessfulPullSyncTime(DateTime.now());
      _markCacheDirty();

      AppLogger.info(
        'Remote changes pulled successfully',
        data: {
          'total': remoteDocuments.length,
          'created': created,
          'updated': updated,
          'conflicts': conflicts,
        },
      );
    } catch (e, stack) {
      AppLogger.error(
        'Failed to pull remote changes',
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }

  Future<void> initializeWithHealthCheck({bool autoRepair = true}) async {
    final report = await runHealthCheck();
    if (autoRepair) {
      final box = Hive.box<DocumentModel>(boxName);
      for (final id in report.missingDocumentIds) {
        await box.delete(id);
      }
      for (final path in report.orphanedFiles) {
        await _deleteIfExists(path);
      }
    }

    if (report.hasIssues) {
      AppLogger.warning(
        'Database health issues detected',
        data: {
          'missingDocuments': report.missingDocumentIds.length,
          'missingThumbnails': report.missingThumbnails.length,
          'orphanedFiles': report.orphanedFiles.length,
        },
        error: null,
      );
    }

    await _refreshCache(forceRefresh: true);
  }
}

class PaginatedDocuments {
  const PaginatedDocuments({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.items,
    required this.hasMore,
  });

  final int page;
  final int pageSize;
  final int totalItems;
  final List<DocumentModel> items;
  final bool hasMore;
}

class DatabaseHealthReport {
  DatabaseHealthReport({
    this.missingDocumentIds = const [],
    this.missingThumbnails = const [],
    this.orphanedFiles = const [],
  });

  final List<String> missingDocumentIds;
  final List<String> missingThumbnails;
  final List<String> orphanedFiles;

  bool get hasIssues =>
      missingDocumentIds.isNotEmpty ||
      missingThumbnails.isNotEmpty ||
      orphanedFiles.isNotEmpty;
}

/// File size validation result
class FileSizeValidationResult {
  final bool isValid;
  final double totalSizeMB;
  final String? warning;
  final bool requiresCompression;

  FileSizeValidationResult({
    required this.isValid,
    required this.totalSizeMB,
    this.warning,
    required this.requiresCompression,
  });
}

List<String> _sortDocumentIdsIsolate(Map<String, dynamic> payload) {
  final docs = (payload['docs'] as List)
      .cast<Map>()
      .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
      .toList();
  final sortBy = payload['sortBy'] as String;
  final descending = payload['descending'] as bool;

  int comparator(Map<String, dynamic> a, Map<String, dynamic> b) {
    int result;
    switch (sortBy) {
      case 'title':
        result = (a['title'] as String).toLowerCase().compareTo(
          (b['title'] as String).toLowerCase(),
        );
        break;
      case 'updatedAt':
        result = (a['updatedAt'] as int).compareTo(b['updatedAt'] as int);
        break;
      case 'createdAt':
      default:
        result = (a['createdAt'] as int).compareTo(b['createdAt'] as int);
        break;
    }
    return descending ? -result : result;
  }

  docs.sort(comparator);
  return docs.map((e) => e['id'] as String).toList();
}
