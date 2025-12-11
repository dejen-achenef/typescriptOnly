// core/services/document_upload_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/events/document_events.dart';
import 'package:thyscan/core/services/document_backend_sync_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/core/services/rate_limiter_service.dart';
import 'package:thyscan/core/services/resource_guard.dart';
import 'package:thyscan/core/utils/filename_sanitizer.dart';
import 'package:thyscan/models/document_model.dart';

/// Upload status for a document
enum UploadStatus {
  pending,
  uploading,
  uploadingFile,
  uploadingThumbnail,
  syncingMetadata,
  completed,
  failed,
  failedRetry,
}

/// Upload progress information
class UploadProgress {
  final String documentId;
  final UploadStatus status;
  final double progress; // 0.0 to 1.0
  final String? error;
  final DateTime? lastAttempt;

  const UploadProgress({
    required this.documentId,
    required this.status,
    this.progress = 0.0,
    this.error,
    this.lastAttempt,
  });

  UploadProgress copyWith({
    UploadStatus? status,
    double? progress,
    String? error,
    DateTime? lastAttempt,
  }) {
    return UploadProgress(
      documentId: documentId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      lastAttempt: lastAttempt ?? this.lastAttempt,
    );
  }
}

/// Pending upload job
class PendingUpload {
  final String documentId;
  final DocumentModel document;
  final int attempts;
  final DateTime createdAt;
  final DateTime? lastAttempt;

  PendingUpload({
    required this.documentId,
    required this.document,
    this.attempts = 0,
    DateTime? createdAt,
    this.lastAttempt,
  }) : createdAt = createdAt ?? DateTime.now();

  PendingUpload copyWith({int? attempts, DateTime? lastAttempt}) {
    return PendingUpload(
      documentId: documentId,
      document: document,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt,
      lastAttempt: lastAttempt ?? this.lastAttempt,
    );
  }
}

/// Production-ready document upload service.
///
/// Handles uploading documents to Supabase Storage and synchronizing metadata
/// with the backend API. Features include:
///
/// - **Supabase Storage Integration**: Uploads PDF/DOCX files and thumbnails
/// - **Backend API Sync**: Synchronizes document metadata to PostgreSQL
/// - **Offline Queue**: Queues uploads when offline, processes when online
/// - **Retry Logic**: Exponential backoff retry mechanism (max 3 attempts)
/// - **Progress Tracking**: Real-time upload progress via stream
/// - **Error Handling**: Comprehensive error handling with detailed logging
///
/// **Usage:**
/// ```dart
/// // Initialize service (typically in main.dart)
/// await DocumentUploadService.instance.initialize();
///
/// // Upload a document
/// final url = await DocumentUploadService.instance.uploadDocument(document);
///
/// // Listen to progress
/// DocumentUploadService.instance.progressStream.listen((progress) {
///   print('Upload ${progress.status}: ${progress.progress * 100}%');
/// });
/// ```
class DocumentUploadService {
  DocumentUploadService._();
  static final DocumentUploadService instance = DocumentUploadService._();

  static const String _storageBucket = 'documents';
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  static const Duration _maxRetryBackoff = Duration(minutes: 5);

  final _uploadQueue = <PendingUpload>[];
  final _progressController = StreamController<UploadProgress>.broadcast();
  final _isProcessing = <String, bool>{};
  final Connectivity _connectivity = Connectivity();

  bool _isInitialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Stream of upload progress events
  Stream<UploadProgress> get progressStream => _progressController.stream;

  /// Initializes the upload service
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.info('Initializing DocumentUploadService');

    // Listen to connectivity changes to process queue when online
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final isOnline = results.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (isOnline) {
        AppLogger.info(
          'Network connectivity restored, processing upload queue',
        );
        _processQueue();
      }
    });

    _isInitialized = true;
    AppLogger.info('DocumentUploadService initialized');

    // Process any pending uploads
    _processQueue();
  }

  /// Disposes the upload service
  void dispose() {
    _connectivitySubscription?.cancel();
    _progressController.close();
    _isInitialized = false;
  }

  /// Clears all upload queues and resets service state
  /// Called during logout to clear user data
  Future<void> clearAll() async {
    try {
      AppLogger.info('Clearing DocumentUploadService data');
      
      // Clear upload queue
      _uploadQueue.clear();
      
      // Clear processing flags
      _isProcessing.clear();
      
      // Cancel connectivity subscription
      _connectivitySubscription?.cancel();
      _connectivitySubscription = null;
      
      AppLogger.info('DocumentUploadService data cleared');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to clear DocumentUploadService data',
        error: e,
        stack: stack,
      );
    }
  }

  /// Uploads a document to Supabase Storage and syncs metadata to backend.
  ///
  /// **Process:**
  /// 1. Validates user authentication and network connectivity
  /// 2. Uploads document file to Supabase Storage
  /// 3. Uploads thumbnail (if available)
  /// 4. Syncs metadata to backend API
  ///
  /// **Returns:**
  /// - Public URL of uploaded file on success
  /// - `null` if queued for later (offline/unauthenticated) or failed
  ///
  /// **Throws:**
  /// - Exception if critical error occurs (logged automatically)
  ///
  /// **Example:**
  /// ```dart
  /// final url = await DocumentUploadService.instance.uploadDocument(document);
  /// if (url != null) {
  ///   print('Uploaded to: $url');
  /// } else {
  ///   print('Queued for later upload');
  /// }
  /// ```
  Future<String?> uploadDocument(DocumentModel document) async {
    print('═══════════════════════════════════════════════════════════');
    print('📤 [UPLOAD SERVICE] uploadDocument() CALLED');
    print('   Document ID: ${document.id}');
    print('   Title: ${document.title}');
    print('   Format: ${document.format}');
    print('═══════════════════════════════════════════════════════════');
    
    AppLogger.info(
      '📤 DocumentUploadService.uploadDocument() called',
      data: {
        'documentId': document.id,
        'title': document.title,
        'format': document.format,
      },
    );
    
    // Check rate limit
    if (!RateLimiterService.instance.tryAcquire('document_upload')) {
      AppLogger.warning(
        'Upload rate limited, queuing document',
        error: null,
        data: {
          'documentId': document.id,
          'availableTokens': RateLimiterService.instance.getAvailableTokens('document_upload'),
        },
      );
      _addToQueue(document);
      return null;
    }
    
    try {
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;
      
      print('🔐 [UPLOAD SERVICE] Auth check: ${user != null ? "AUTHENTICATED (${user.id})" : "NOT AUTHENTICATED"}');

      if (user == null) {
        print('❌ [UPLOAD SERVICE] User NOT authenticated - QUEUING');
        AppLogger.warning(
          '❌ Cannot upload document: user not authenticated',
          error: null,
          data: {'documentId': document.id},
        );
        // Queue for later when user logs in
        _addToQueue(document);
        return null;
      }

      print('✅ [UPLOAD SERVICE] User authenticated: ${user.id}');
      AppLogger.info(
        '✅ User authenticated: ${user.id}',
        data: {'documentId': document.id},
      );

      // Check network connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      print('🌐 [UPLOAD SERVICE] Network check: ${isOnline ? "ONLINE" : "OFFLINE"}');
      print('   Connectivity results: $connectivityResults');

      if (!isOnline) {
        print('⚠️ [UPLOAD SERVICE] No internet - QUEUING');
        AppLogger.warning(
          '⚠️ No internet connection, queuing document for later upload',
          error: null,
          data: {'documentId': document.id},
        );
        _addToQueue(document);
        return null;
      }

      print('🌐 [UPLOAD SERVICE] Network OK - Proceeding with upload');
      AppLogger.info(
        '🌐 Network connectivity OK, proceeding with upload',
        data: {'documentId': document.id},
      );

      return await _uploadDocumentInternal(document);
    } catch (e, stack) {
      AppLogger.error(
        'Failed to upload document ${document.id}',
        error: e,
        stack: stack,
      );
      _addToQueue(document);
      return null;
    }
  }

  /// Internal upload implementation with retry logic and exponential backoff.
  ///
  /// **Retry Strategy:**
  /// - Attempt 1: Immediate
  /// - Attempt 2: 5 seconds delay
  /// - Attempt 3: 10 seconds delay
  /// - Attempt 4: 20 seconds delay (max)
  ///
  /// After max attempts, document is queued for manual retry.
  ///
  /// **Parameters:**
  /// - `document`: Document to upload
  /// - `attempt`: Current retry attempt (0-indexed)
  ///
  /// **Returns:**
  /// - Public URL on success
  /// - `null` if max attempts reached (queued for later)
  Future<String?> _uploadDocumentInternal(
    DocumentModel document, {
    int attempt = 0,
  }) async {
    final documentId = document.id;
    final userId = AuthService.instance.currentUser!.id;

    AppLogger.info(
      '📤 Starting document upload (attempt ${attempt + 1})',
      data: {
        'documentId': documentId,
        'userId': userId,
        'title': document.title,
        'format': document.format,
        'filePath': document.filePath,
      },
    );

    try {
      // Update sync status to uploading file
      DocumentSyncStateService.instance.setSyncStatus(
        documentId,
        DocumentSyncStatus.uploadingFile,
      );
      _emitProgress(documentId, UploadStatus.uploadingFile, progress: 0.0);

      // 1. Upload PDF/DOCX to Supabase Storage
      final file = File(document.filePath);
      if (!await file.exists()) {
        throw Exception('Document file not found: ${document.filePath}');
      }

      // Use document ID as filename to ensure consistency across updates
      // This ensures that when a document is updated, it replaces the same file
      // Format: {userId}/{documentId}.{format}
      final fileName = '$userId/${document.id}.${document.format}';
      final fileSize = await file.length();

      AppLogger.info(
        'Uploading document to Supabase Storage',
        data: {
          'documentId': documentId,
          'fileName': fileName,
          'size': fileSize,
        },
      );

      final supabase = AuthService.instance.supabase;
      await supabase.storage
          .from(_storageBucket)
          .upload(
            fileName,
            file,
            fileOptions: FileOptions(
              upsert: true,
              contentType: document.format == 'pdf'
                  ? 'application/pdf'
                  : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            ),
          );

      // Get public URL
      final publicUrl = supabase.storage
          .from(_storageBucket)
          .getPublicUrl(fileName);

      // Update sync status to uploading thumbnail
      DocumentSyncStateService.instance.setSyncStatus(
        documentId,
        DocumentSyncStatus.uploadingThumbnail,
      );
      _emitProgress(documentId, UploadStatus.uploadingThumbnail, progress: 0.5);

      // 2. Upload thumbnail if exists
      String? thumbnailUrl;
      if (document.thumbnailPath.isNotEmpty) {
        try {
          final thumbFile = File(document.thumbnailPath);
          if (await thumbFile.exists()) {
            // Use document ID for thumbnail filename to ensure consistency
            // Format: {userId}/{documentId}_thumb.jpg
            final thumbFileName = '$userId/${document.id}_thumb.jpg';
            await supabase.storage
                .from(_storageBucket)
                .upload(
                  thumbFileName,
                  thumbFile,
                  fileOptions: const FileOptions(
                    upsert: true,
                    contentType: 'image/jpeg',
                  ),
                );
            thumbnailUrl = supabase.storage
                .from(_storageBucket)
                .getPublicUrl(thumbFileName);
          }
        } catch (e) {
          AppLogger.warning(
            'Failed to upload thumbnail, continuing without it',
            error: e,
          );
        }
      }

      // Update sync status to syncing metadata
      DocumentSyncStateService.instance.setSyncStatus(
        documentId,
        DocumentSyncStatus.syncingMetadata,
      );
      _emitProgress(documentId, UploadStatus.syncingMetadata, progress: 0.75);

      // 3. Sync metadata to backend API (create or update)
      print('═══════════════════════════════════════════════════════════');
      print('🔄 [UPLOAD SERVICE] Starting metadata sync to backend');
      print('   Document ID: $documentId');
      print('   File URL: ${publicUrl.substring(0, publicUrl.length > 60 ? 60 : publicUrl.length)}...');
      print('   Has Thumbnail: ${thumbnailUrl != null}');
      print('═══════════════════════════════════════════════════════════');
      
      AppLogger.info(
        '🔄 Starting metadata sync to backend',
        data: {
          'documentId': documentId,
          'fileUrl': publicUrl.substring(0, 50) + '...',
          'hasThumbnail': thumbnailUrl != null,
        },
      );
      try {
        await DocumentBackendSyncService.instance.syncDocumentMetadata(
          document: document,
          fileUrl: publicUrl,
          thumbnailUrl: thumbnailUrl,
        );
        print('✅ [UPLOAD SERVICE] Metadata sync SUCCESS');
        AppLogger.info(
          '✅ Metadata sync completed successfully',
          data: {'documentId': documentId},
        );
      } catch (syncError, syncStack) {
        // Handle conflict exception
        if (syncError is ConflictException) {
          print('═══════════════════════════════════════════════════════════');
          print('⚠️ [UPLOAD SERVICE] Conflict detected');
          print('   Document ID: $documentId');
          print('   Message: ${syncError.message}');
          print('═══════════════════════════════════════════════════════════');
          
          // Mark document as having a conflict
          DocumentSyncStateService.instance.setSyncStatus(
            documentId,
            DocumentSyncStatus.pendingConflictResolution,
            errorMessage: syncError.message,
          );
          
          AppLogger.warning(
            '⚠️ Document conflict detected',
            error: syncError,
            data: {
              'documentId': documentId,
              'hasRemoteDocument': syncError.remoteDocument != null,
            },
          );
          
          // For now, we'll use "last write wins" - keep local version
          // In the future, this could trigger a UI dialog for user resolution
          // Emit sync failed event
          DocumentEventBus.instance.emitSyncFailed(
            documentId,
            error: syncError.message,
            isUpload: true,
            retryCount: attempt,
          );
          
          // Re-throw to prevent marking as synced
          rethrow;
        }
        
        print('═══════════════════════════════════════════════════════════');
        print('❌ [UPLOAD SERVICE] Metadata sync FAILED');
        print('   Error: $syncError');
        print('═══════════════════════════════════════════════════════════');
        AppLogger.error(
          '❌ Metadata sync failed',
          error: syncError,
          stack: syncStack,
          data: {'documentId': documentId},
        );
        // Re-throw to trigger retry logic
        rethrow;
      }

      _emitProgress(documentId, UploadStatus.completed, progress: 1.0);

      // Update sync status to synced
      DocumentSyncStateService.instance.setSyncStatus(
        documentId,
        DocumentSyncStatus.synced,
        lastSyncTime: DateTime.now(),
      );

      AppLogger.info(
        'Document uploaded successfully',
        data: {'documentId': documentId},
      );
      return publicUrl;
    } catch (e, stack) {
      AppLogger.error(
        'Upload attempt ${attempt + 1} failed for document $documentId',
        error: e,
        stack: stack,
      );

      // Retry logic
      if (attempt < _maxRetryAttempts) {
        final delay = _calculateRetryDelay(attempt);
        AppLogger.info(
          'Retrying upload in ${delay.inSeconds} seconds',
          data: {'documentId': documentId, 'attempt': attempt + 1},
        );

        await Future.delayed(delay);
        return _uploadDocumentInternal(document, attempt: attempt + 1);
      }

      // Max attempts reached, queue for later
      _emitProgress(
        documentId,
        UploadStatus.failedRetry,
        error: e.toString(),
        lastAttempt: DateTime.now(),
      );

      // Update sync status to failed retry
      DocumentSyncStateService.instance.setSyncStatus(
        documentId,
        DocumentSyncStatus.failedRetry,
        errorMessage: e.toString(),
      );

      _addToQueue(document);
      return null;
    }
  }

  /// Adds document to upload queue
  void _addToQueue(DocumentModel document) {
    final existing = _uploadQueue.indexWhere(
      (u) => u.documentId == document.id,
    );
    if (existing >= 0) {
      // Update existing entry
      _uploadQueue[existing] = _uploadQueue[existing].copyWith(
        lastAttempt: DateTime.now(),
      );
    } else {
      _uploadQueue.add(
        PendingUpload(documentId: document.id, document: document),
      );
    }

    AppLogger.info(
      'Document added to upload queue',
      data: {'documentId': document.id, 'queueSize': _uploadQueue.length},
    );
  }

  /// Processes the upload queue
  Future<void> _processQueue() async {
    if (_uploadQueue.isEmpty) return;

    // Check if user is authenticated
    try {
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;
      if (user == null) {
        AppLogger.info('User not authenticated, skipping queue processing');
        return;
      }

      // Check concurrent upload limit using ResourceGuard
      while (_uploadQueue.isNotEmpty &&
          _isProcessing.length < ResourceGuard.maxConcurrentUploads) {
        final upload = _uploadQueue.removeAt(0);
        
        if (_isProcessing.containsKey(upload.documentId)) {
          continue; // Already processing
        }

        // Acquire upload slot
        await ResourceGuard.instance.acquireUploadSlot(
          operationId: upload.documentId,
          priority: OperationPriority.background,
        );

        _isProcessing[upload.documentId] = true;
      }
    } catch (e) {
      AppLogger.warning(
        error: null,
        'AuthService not ready, skipping queue processing',
      );
      return;
    }

    // Check connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final isOnline = connectivityResults.any(
      (result) =>
          result != ConnectivityResult.none &&
          result != ConnectivityResult.bluetooth,
    );

    if (!isOnline) {
      AppLogger.info('No internet connection, cannot process queue');
      return;
    }

    // Process queue (one at a time to avoid overwhelming the system)
    while (_uploadQueue.isNotEmpty) {
      final upload = _uploadQueue.removeAt(0);

      // Skip if already processing
      if (_isProcessing[upload.documentId] == true) {
        continue;
      }

      // Skip if max attempts reached
      if (upload.attempts >= _maxRetryAttempts) {
        AppLogger.warning(
          error: null,
          'Max retry attempts reached for document ${upload.documentId}',
        );
        continue;
      }

      _isProcessing[upload.documentId] = true;

      try {
        await _uploadDocumentInternal(upload.document);
        _isProcessing.remove(upload.documentId);
      } catch (e) {
        _isProcessing.remove(upload.documentId);
        // Re-add to queue with incremented attempts
        _uploadQueue.add(
          upload.copyWith(
            attempts: upload.attempts + 1,
            lastAttempt: DateTime.now(),
          ),
        );
      }

      // Small delay between uploads
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// Calculates retry delay with exponential backoff
  Duration _calculateRetryDelay(int attempt) {
    final baseDelay = _retryDelay.inSeconds;
    final delaySeconds =
        baseDelay * (1 << attempt); // Exponential: 5s, 10s, 20s
    final delay = Duration(seconds: delaySeconds);
    return delay > _maxRetryBackoff ? _maxRetryBackoff : delay;
  }

  /// Emits progress event
  void _emitProgress(
    String documentId,
    UploadStatus status, {
    double progress = 0.0,
    String? error,
    DateTime? lastAttempt,
  }) {
    _progressController.add(
      UploadProgress(
        documentId: documentId,
        status: status,
        progress: progress,
        error: error,
        lastAttempt: lastAttempt ?? DateTime.now(),
      ),
    );
  }

  /// Gets pending uploads count
  int get pendingCount => _uploadQueue.length;
  
  /// Gets list of pending uploads (for UI display)
  List<PendingUpload> get pendingUploads => List.unmodifiable(_uploadQueue);
  
  /// Gets current upload progress for a document
  UploadProgress? getProgress(String documentId) {
    // Check if currently uploading
    if (_isProcessing.containsKey(documentId) && _isProcessing[documentId] == true) {
      // Return latest progress from stream (would need to track this)
      // For now, return a pending status
      return UploadProgress(
        documentId: documentId,
        status: UploadStatus.uploading,
        progress: 0.5, // Approximate
      );
    }
    
    // Check if in queue
    final inQueue = _uploadQueue.any((u) => u.documentId == documentId);
    if (inQueue) {
      return UploadProgress(
        documentId: documentId,
        status: UploadStatus.pending,
        progress: 0.0,
      );
    }
    
    return null;
  }
  
  /// Cancels a pending upload
  Future<void> cancelUpload(String documentId) async {
    _uploadQueue.removeWhere((u) => u.documentId == documentId);
    _isProcessing[documentId] = false;
    
    AppLogger.info(
      'Upload cancelled',
      data: {'documentId': documentId, 'queueSize': _uploadQueue.length},
    );
  }
  
  /// Retries a failed upload
  Future<void> retryUpload(String documentId) async {
    // Find the upload in queue
    final uploadIndex = _uploadQueue.indexWhere((u) => u.documentId == documentId);
    if (uploadIndex == -1) {
      AppLogger.warning(
        'Cannot retry: upload not in queue',
        error: null,
        data: {'documentId': documentId},
      );
      return;
    }
    
    // Reset attempts and move to front of queue
    final upload = _uploadQueue.removeAt(uploadIndex);
    _uploadQueue.insert(0, upload.copyWith(attempts: 0));
    
    AppLogger.info(
      'Upload retry queued',
      data: {'documentId': documentId},
    );
    
    // Process queue if online
    _processQueue();
  }
  
  /// Forces immediate sync of all pending uploads
  Future<void> syncNow() async {
    AppLogger.info(
      'Force sync requested',
      data: {'queueSize': _uploadQueue.length},
    );
    await _processQueue();
  }

  /// Clears failed uploads from queue
  void clearFailedUploads() {
    _uploadQueue.removeWhere((u) => u.attempts >= _maxRetryAttempts);
  }
}
