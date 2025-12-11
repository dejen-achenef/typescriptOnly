// core/services/document_sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/config/app_env.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/events/document_events.dart';
import 'package:thyscan/core/services/document_download_service.dart'
    show DocumentDownloadService, DownloadPriority, DownloadProgress;
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/core/services/rate_limiter_service.dart';
import 'package:thyscan/core/utils/url_validator.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Production-ready service to sync documents from backend PostgreSQL to local Hive storage.
///
/// **Features:**
/// - **Incremental Sync**: Only fetches documents updated since last sync
/// - **Full Sync**: Option to fetch all documents (first sync)
/// - **Conflict Resolution**: Backend wins if `updatedAt` is newer
/// - **Automatic Sync**: Syncs when connectivity is restored
/// - **Error Handling**: Comprehensive error handling with detailed logging
///
/// **Sync Strategy:**
/// 1. Fetches documents from backend API
/// 2. Merges with local Hive storage
/// 3. Resolves conflicts by `updatedAt` timestamp
/// 4. Updates local cache automatically
///
/// **Usage:**
/// ```dart
/// // Initialize service (typically in main.dart)
/// await DocumentSyncService.instance.initialize();
///
/// // Manual sync
/// final result = await DocumentSyncService.instance.syncDocuments();
/// print('Synced: ${result.documentsAdded} added, ${result.documentsUpdated} updated');
///
/// // Force full sync
/// final fullResult = await DocumentSyncService.instance.syncDocuments(forceFullSync: true);
/// ```
class DocumentSyncService {
  DocumentSyncService._();
  static final DocumentSyncService instance = DocumentSyncService._();

  final Connectivity _connectivity = Connectivity();
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Track active download subscriptions to prevent memory leaks
  final Map<String, StreamSubscription<DownloadProgress>> _downloadSubscriptions = {};
  
  // Sync queue to handle concurrent sync requests
  final _syncQueue = <_SyncRequest>[];
  static const Duration _syncRequestTimeout = Duration(minutes: 10);
  
  static const String _lastSyncTimeKey = 'last_sync_time';
  static const int _maxRetryAttempts = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryBackoff = Duration(minutes: 5);
  Box<dynamic>? _prefsBox;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Initializes the sync service and sets up connectivity listener
  Future<void> initialize() async {
    AppLogger.info('Initializing DocumentSyncService');

    // Load last sync time from persistent storage
    try {
      _prefsBox = await Hive.openBox('sync_preferences');
      final lastSyncTimeString = _prefsBox!.get(_lastSyncTimeKey) as String?;
      if (lastSyncTimeString != null) {
        _lastSyncTime = DateTime.parse(lastSyncTimeString);
        AppLogger.info(
          'Loaded last sync time from storage',
          data: {'lastSyncTime': _lastSyncTime!.toIso8601String()},
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to load last sync time, will perform full sync',
        error: e,
      );
    }

    // Listen to connectivity changes to sync when online
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
          'Network connectivity restored, triggering incremental sync',
        );
        // Use incremental sync by default (more efficient)
        syncDocuments(forceFullSync: false).catchError((error) {
          AppLogger.error(
            'Auto-sync failed after connectivity change',
            error: error,
          );
          return SyncResult(
            success: false,
            message: 'Auto-sync failed',
            documentsAdded: 0,
            documentsUpdated: 0,
            documentsSkipped: 0,
            documentsReplaced: 0,
          );
        });
      }
    });

    AppLogger.info('DocumentSyncService initialized');
  }

  /// Disposes the sync service
  void dispose() {
    _connectivitySubscription?.cancel();
    // Cancel all active download subscriptions
    for (final subscription in _downloadSubscriptions.values) {
      subscription.cancel();
    }
    _downloadSubscriptions.clear();
  }

  /// Clears all sync data and resets service state
  /// Called during logout to clear user data
  Future<void> clearAll() async {
    try {
      AppLogger.info('Clearing DocumentSyncService data');
      
      // Clear sync state
      _isSyncing = false;
      _lastSyncTime = null;
      
      // Cancel connectivity subscription
      _connectivitySubscription?.cancel();
      _connectivitySubscription = null;
      
      // Cancel all download subscriptions
      for (final subscription in _downloadSubscriptions.values) {
        subscription.cancel();
      }
      _downloadSubscriptions.clear();
      
      // Clear sync preferences box
      if (_prefsBox != null) {
        await _prefsBox!.clear();
        await _prefsBox!.close();
        _prefsBox = null;
      }
      
      AppLogger.info('DocumentSyncService data cleared');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to clear DocumentSyncService data',
        error: e,
        stack: stack,
      );
    }
  }

  /// Syncs documents from backend to local storage.
  ///
  /// **Process:**
  /// 1. Validates authentication and network connectivity
  /// 2. Fetches documents from backend (incremental or full)
  /// 3. Replaces local documents (if `replaceLocal: true`) OR merges with local Hive storage (if `replaceLocal: false`)
  /// 4. Resolves conflicts by `updatedAt` timestamp when merging
  /// 5. Retries with exponential backoff on failure
  ///
  /// **Sync Modes:**
  /// - **Replace Mode** (`replaceLocal: true`): Clears local storage and replaces with backend data
  ///   - ⚠️ NOT RECOMMENDED for production - use merge mode instead
  ///   - All local documents are replaced with backend versions
  /// - **Merge Mode** (`replaceLocal: false`): Merges backend documents with local storage
  ///   - Conflict resolution by `updatedAt` timestamp
  ///   - If backend `updatedAt` > local: Update local from backend
  ///   - If local `updatedAt` > backend: Keep local (will be uploaded)
  ///   - If equal: Keep local (assumed already synced)
  ///
  /// **Parameters:**
  /// - `forceFullSync`: If `true`, fetches all documents regardless of `_lastSyncTime`
  /// - `replaceLocal`: If `true`, replaces all local documents with backend data (default: `false`)
  ///
  /// **Returns:**
  /// - `SyncResult` with counts of added, updated, skipped, and replaced documents
  ///
  /// **Examples:**
  /// ```dart
  /// // Merge mode (default) - for background sync
  /// final result = await DocumentSyncService.instance.syncDocuments();
  ///
  /// // Full sync with merge (recommended for app startup)
  /// final result = await DocumentSyncService.instance.syncDocuments(
  ///   forceFullSync: true,
  ///   replaceLocal: false, // SAFE: Preserves local documents
  /// );
  /// ```
  Future<SyncResult> syncDocuments({
    bool forceFullSync = false,
    bool replaceLocal = false,
    int retryAttempt = 0,
  }) async {
    if (_isSyncing) {
      AppLogger.info('Sync already in progress, skipping');
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        documentsAdded: 0,
        documentsUpdated: 0,
        documentsSkipped: 0,
        documentsReplaced: 0,
      );
    }

    try {
      // Check rate limit (non-blocking for queued requests)
      if (!RateLimiterService.instance.tryAcquire('document_sync')) {
        AppLogger.warning(
          'Sync rate limited',
          error: null,
          data: {
            'forceFullSync': forceFullSync,
            'availableTokens': RateLimiterService.instance.getAvailableTokens('document_sync'),
          },
        );
        // For queued requests, wait for rate limit
        if (retryAttempt == 0) {
          await RateLimiterService.instance.acquire('document_sync');
        } else {
          // For retries, return error to trigger retry with backoff
          return SyncResult(
            success: false,
            message: 'Rate limited, will retry',
            documentsAdded: 0,
            documentsUpdated: 0,
            documentsSkipped: 0,
            documentsReplaced: 0,
          );
        }
      }

      _isSyncing = true;
      AppLogger.info(
        '🔄 Starting document sync',
        data: {
          'forceFullSync': forceFullSync,
          'replaceLocal': replaceLocal,
          'retryAttempt': retryAttempt,
        },
      );

      // Check authentication
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;
      if (user == null) {
        AppLogger.warning('Cannot sync: user not authenticated', error: null);
        return SyncResult(
          success: false,
          message: 'User not authenticated',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
          documentsReplaced: 0,
        );
      }

      // CRITICAL: Log userId to ensure we're syncing the correct user's documents
      AppLogger.info(
        '🔄 Starting sync for authenticated user',
        data: {
          'userId': user.id,
          'userEmail': user.email ?? 'N/A',
          'forceFullSync': forceFullSync,
          'replaceLocal': replaceLocal,
        },
      );

      // Check connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        AppLogger.info('No internet connection, cannot sync');
        return SyncResult(
          success: false,
          message: 'No internet connection',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
          documentsReplaced: 0,
        );
      }

      // Get backend URL and fix for Android emulator
      var backendUrl = AppEnv.backendApiUrl;

      // Fix for Android emulator: replace localhost with 10.0.2.2
      if (backendUrl != null && backendUrl.contains('localhost')) {
        AppLogger.info(
          'Detected localhost in backend URL, fixing for Android emulator',
          data: {'originalUrl': backendUrl},
        );
        backendUrl = backendUrl.replaceAll('localhost', '10.0.2.2');
        AppLogger.info(
          'Fixed URL for Android emulator',
          data: {'fixedUrl': backendUrl},
        );
      }

      if (backendUrl == null || backendUrl.isEmpty) {
        AppLogger.warning(
          'Backend API URL not configured, cannot sync',
          error: null,
        );
        return SyncResult(
          success: false,
          message: 'Backend API URL not configured',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
          documentsReplaced: 0,
        );
      }

      // Validate URL format
      if (!UrlValidator.isValidUrl(backendUrl)) {
        AppLogger.error(
          'Invalid backend API URL format',
          data: {'url': backendUrl},
        );
        return SyncResult(
          success: false,
          message: 'Invalid backend API URL format',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
          documentsReplaced: 0,
        );
      }

      // Get session token
      final session = AuthService.instance.supabase.auth.currentSession;
      if (session == null) {
        AppLogger.warning('No active session, cannot sync', error: null);
        return SyncResult(
          success: false,
          message: 'No active session',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
          documentsReplaced: 0,
        );
      }

      // Build sync URL - use sync endpoint for incremental, documents endpoint for full sync
      // CRITICAL: Backend automatically filters by userId from JWT token
      // The @CurrentUser() decorator extracts userId from the authenticated session
      // No need to pass userId in query params - backend handles it automatically
      final syncPath = forceFullSync || _lastSyncTime == null
          ? 'api/documents'
          : 'api/documents/sync';

      final baseApiUrl = UrlValidator.buildApiUrl(backendUrl, syncPath);
      if (baseApiUrl == null) {
        return SyncResult(
          success: false,
          message: 'Failed to build API URL',
          documentsAdded: 0,
          documentsUpdated: 0,
          documentsSkipped: 0,
          documentsReplaced: 0,
        );
      }

      AppLogger.info(
        '📡 Backend API endpoint configured',
        data: {
          'userId': user.id,
          'endpoint': syncPath,
          'fullUrl': baseApiUrl,
          'note': 'Backend will filter documents by userId from JWT token',
        },
      );

      // Fetch all documents from backend (handle pagination for full sync)
      final List<dynamic> allDocumentsJson = [];

      if (forceFullSync || _lastSyncTime == null) {
        // Full sync: fetch all pages
        int page = 0;
        const int pageSize = 100; // Large page size to minimize requests
        bool hasMore = true;

        AppLogger.info(
          'Starting full sync - fetching all documents from backend',
          data: {'pageSize': pageSize},
        );

        while (hasMore) {
          final syncUrl = Uri.parse(baseApiUrl).replace(
            queryParameters: {
              'page': page.toString(),
              'pageSize': pageSize.toString(),
            },
          );

          AppLogger.info(
            'Fetching documents page $page',
            data: {'url': syncUrl.toString()},
          );

          final response = await http
              .get(
                syncUrl,
                headers: {
                  'Authorization': 'Bearer ${session.accessToken}',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  throw TimeoutException('Backend API request timed out');
                },
              );

          if (response.statusCode != 200) {
            AppLogger.error(
              'Backend API error during sync',
              data: {
                'statusCode': response.statusCode,
                'responseBody': response.body,
                'url': syncUrl.toString(),
              },
            );
            throw Exception(
              'Backend API error: ${response.statusCode} - ${response.body}',
            );
          }

          final responseBody = jsonDecode(response.body);

          if (responseBody is Map<String, dynamic> &&
              responseBody.containsKey('documents')) {
            // Paginated response
            final documentsJson = responseBody['documents'] as List<dynamic>;
            allDocumentsJson.addAll(documentsJson);

            final pagination =
                responseBody['pagination'] as Map<String, dynamic>?;
            hasMore = pagination?['hasMore'] as bool? ?? false;

            AppLogger.info(
              'Fetched page $page: ${documentsJson.length} documents',
              data: {'totalSoFar': allDocumentsJson.length, 'hasMore': hasMore},
            );
          } else {
            throw Exception('Unexpected response format from backend');
          }

          page++;
        }
      } else {
        // INCREMENTAL SYNC: Only fetch documents updated since last sync
        // This is much more efficient than full sync
        final syncUrl = Uri.parse(
          baseApiUrl,
        ).replace(queryParameters: {'since': _lastSyncTime!.toIso8601String()});

        AppLogger.info(
          '🔄 Incremental sync: Fetching documents updated since ${_lastSyncTime!.toIso8601String()}',
          data: {
            'url': syncUrl.toString(),
            'lastSyncTime': _lastSyncTime!.toIso8601String(),
            'timeSinceLastSync': DateTime.now()
                .difference(_lastSyncTime!)
                .inMinutes,
          },
        );

        final response = await http
            .get(
              syncUrl,
              headers: {
                'Authorization': 'Bearer ${session.accessToken}',
                'Content-Type': 'application/json',
              },
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('Backend API request timed out');
              },
            );

        if (response.statusCode != 200) {
          AppLogger.error(
            'Backend API error during sync',
            data: {
              'statusCode': response.statusCode,
              'responseBody': response.body,
              'url': syncUrl.toString(),
            },
          );
          throw Exception(
            'Backend API error: ${response.statusCode} - ${response.body}',
          );
        }

        final responseBody = jsonDecode(response.body);

        if (responseBody is List) {
          // Array response (from sync endpoint)
          allDocumentsJson.addAll(responseBody);
        } else {
          throw Exception('Unexpected response format from backend');
        }
      }

      AppLogger.info(
        'Received ${allDocumentsJson.length} documents from backend for user ${user.id}',
        data: {
          'userId': user.id,
          'forceFullSync': forceFullSync,
          'replaceLocal': replaceLocal,
          'documentCount': allDocumentsJson.length,
        },
      );

      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      int added = 0;
      int updated = 0;
      int skipped = 0;
      int replaced = 0;
      int conflicts = 0;

      // Track which documents exist in backend (for detecting local-only documents)
      final backendDocumentIds = <String>{};

      // SAFE MERGE STRATEGY: Never clear local storage unless explicitly requested
      // Even then, we should preserve documents with local files that aren't in backend
      if (replaceLocal) {
        // Only use replace mode if explicitly requested (not recommended for production)
        // This is kept for backward compatibility but should be avoided
        final localCountBeforeClear = box.length;
        AppLogger.warning(
          error: null,
          '⚠️ REPLACE MODE: This will clear local documents. Use merge mode for production.',
          data: {
            'localCount': localCountBeforeClear,
            'backendCount': allDocumentsJson.length,
          },
        );
        await box.clear();
        replaced = localCountBeforeClear;
      }

      // Process backend documents with enhanced merge strategy
      for (final docJson in allDocumentsJson) {
        try {
          final remoteDoc = _parseBackendDocument(docJson);
          backendDocumentIds.add(remoteDoc.id);
          final localDoc = box.get(remoteDoc.id);

          // Check if document files need to be downloaded (if filePath is a URL)
          final needsDownload =
              remoteDoc.filePath.startsWith('http://') ||
              remoteDoc.filePath.startsWith('https://');

          // Check if local document has local files (not just URLs)
          final hasLocalFiles =
              localDoc != null &&
              !localDoc.filePath.startsWith('http://') &&
              !localDoc.filePath.startsWith('https://');

          // ENHANCED MERGE STRATEGY
          if (localDoc == null) {
            // Case 1: New document from backend - add it
            DocumentModel finalDoc = remoteDoc;

            // If it needs download, start download in background but add metadata now
            if (needsDownload) {
              _startBackgroundDownload(remoteDoc, box);
              // Mark as pending download - status will be updated when download completes
              DocumentSyncStateService.instance.setSyncStatus(
                remoteDoc.id,
                DocumentSyncStatus.pendingDownload,
              );
            } else {
              // No download needed - document is already synced
              DocumentSyncStateService.instance.setSyncStatus(
                remoteDoc.id,
                DocumentSyncStatus.synced,
                lastSyncTime: DateTime.now(),
              );
            }

            await box.put(remoteDoc.id, finalDoc);
            added++;
            
            // Emit document created event
            DocumentEventBus.instance.emitCreated(finalDoc);
            
            AppLogger.info(
              '✅ Added new document from backend',
              data: {
                'id': remoteDoc.id,
                'title': remoteDoc.title,
                'needsDownload': needsDownload,
                'status': needsDownload ? 'pendingDownload' : 'synced',
              },
            );
          } else {
            // Case 2: Document exists locally - apply conflict resolution
            if (replaceLocal) {
              // Replace mode: always use backend version (not recommended)
              DocumentModel finalDoc = remoteDoc;

              // Preserve local files if they exist and backend only has URL
              if (hasLocalFiles && needsDownload) {
                AppLogger.info(
                  '📱 Preserving local files, downloading backend version in background',
                  data: {'id': remoteDoc.id, 'title': remoteDoc.title},
                );
                // Keep local file paths temporarily, download in background
                finalDoc = localDoc;
                _startBackgroundDownload(remoteDoc, box);
              } else if (needsDownload) {
                _startBackgroundDownload(remoteDoc, box);
              }

              await box.put(remoteDoc.id, finalDoc);
              updated++;
            } else {
              // MERGE MODE: Smart conflict resolution
              final localUpdatedAt = localDoc.updatedAt;
              final remoteUpdatedAt = remoteDoc.updatedAt;
              final timeDifference = remoteUpdatedAt.difference(localUpdatedAt);

              // Enhanced conflict detection: consider both timestamp and file state
              if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
                // Backend version is newer - update from backend
                DocumentModel finalDoc = remoteDoc;

                // If local has files and backend has URL, preserve local files during download
                if (hasLocalFiles && needsDownload) {
                  AppLogger.info(
                    '📱 Backend newer: Keeping local files visible, downloading in background',
                    data: {
                      'id': remoteDoc.id,
                      'title': remoteDoc.title,
                      'localUpdated': localUpdatedAt.toIso8601String(),
                      'remoteUpdated': remoteUpdatedAt.toIso8601String(),
                    },
                  );
                  // Keep local version visible until download completes
                  finalDoc = localDoc;
                  _startBackgroundDownload(remoteDoc, box);
                } else if (needsDownload) {
                  _startBackgroundDownload(remoteDoc, box);
                }

                // Update sync status
                DocumentSyncStateService.instance.setSyncStatus(
                  remoteDoc.id,
                  needsDownload
                      ? DocumentSyncStatus.pendingDownload
                      : DocumentSyncStatus.synced,
                );

              await box.put(remoteDoc.id, finalDoc);
              updated++;
              
              // Emit document updated event
              DocumentEventBus.instance.emitUpdated(finalDoc, previousDocument: localDoc);
              
              AppLogger.info(
                '✅ Updated local document with newer backend version',
                data: {
                  'id': remoteDoc.id,
                  'title': remoteDoc.title,
                  'timeDiff': '${timeDifference.inSeconds}s',
                },
              );
              } else if (remoteUpdatedAt.isBefore(localUpdatedAt)) {
                // Local version is newer - keep local (will be uploaded by upload service)
                // Update sync status to pending upload
                DocumentSyncStateService.instance.setSyncStatus(
                  remoteDoc.id,
                  DocumentSyncStatus.pendingUpload,
                );
                skipped++;
                AppLogger.info(
                  '⏭️ Skipped backend document (local is newer, will upload)',
                  data: {
                    'id': remoteDoc.id,
                    'title': remoteDoc.title,
                    'timeDiff': '${timeDifference.inSeconds}s',
                  },
                );
              } else {
                // Same timestamp - check if content differs
                final contentDiffers = _documentsDiffer(localDoc, remoteDoc);
                if (contentDiffers) {
                  // Same timestamp but different content - potential conflict
                  conflicts++;
                  // Mark as conflict in sync state
                  DocumentSyncStateService.instance.setSyncStatus(
                    remoteDoc.id,
                    DocumentSyncStatus.conflict,
                  );
                  AppLogger.warning(
                    '⚠️ Conflict detected: Same timestamp but different content',
                    error: null,
                    data: {
                      'id': remoteDoc.id,
                      'title': remoteDoc.title,
                      'action': 'Keeping local version (will be uploaded)',
                    },
                  );
                  // Keep local version - it will be uploaded and overwrite backend
                  skipped++;
                } else {
                  // Identical - already synced
                  // Mark as synced since local and backend are identical
                  DocumentSyncStateService.instance.setSyncStatus(
                    remoteDoc.id,
                    DocumentSyncStatus.synced,
                    lastSyncTime: DateTime.now(),
                  );
                  skipped++;
                  AppLogger.info(
                    '✅ Document already synced (identical)',
                    data: {
                      'id': remoteDoc.id,
                      'title': remoteDoc.title,
                    },
                  );
                }
              }
            }
          }
        } catch (e, stack) {
          AppLogger.error(
            'Failed to process document from backend',
            error: e,
            stack: stack,
            data: {'documentJson': docJson},
          );
        }
      }

      // PROTECT LOCAL-ONLY DOCUMENTS: Documents that exist locally but not in backend
      // These are likely pending uploads or documents created offline
      if (!replaceLocal) {
        final allLocalDocs = box.values.toList();
        for (final localDoc in allLocalDocs) {
          if (!backendDocumentIds.contains(localDoc.id)) {
            // This document exists locally but not in backend
            final hasLocalFiles =
                !localDoc.filePath.startsWith('http://') &&
                !localDoc.filePath.startsWith('https://');

            if (hasLocalFiles) {
              // Preserve local-only documents (pending upload)
              // Update sync status to pending upload
              DocumentSyncStateService.instance.setSyncStatus(
                localDoc.id,
                DocumentSyncStatus.pendingUpload,
              );
              AppLogger.info(
                '📱 Preserving local-only document (pending upload)',
                data: {
                  'id': localDoc.id,
                  'title': localDoc.title,
                  'createdAt': localDoc.createdAt.toIso8601String(),
                },
              );
              // Document is already in box, no action needed
              // Upload service will handle uploading it
            } else {
              // Local document with URL but not in backend - might be orphaned
              AppLogger.warning(
                '⚠️ Local document with URL not found in backend (may be orphaned)',
                error: null,
                data: {'id': localDoc.id, 'title': localDoc.title},
              );
            }
          }
        }
      }

      // Save last sync time to persistent storage
      _lastSyncTime = DateTime.now();
      try {
        if (_prefsBox != null) {
          await _prefsBox!.put(
            _lastSyncTimeKey,
            _lastSyncTime!.toIso8601String(),
          );
        }
      } catch (e) {
        AppLogger.warning('Failed to save last sync time', error: e);
      }

      // Update sync status for all processed documents
      // Mark remaining local documents as pending upload if they weren't in backend
      if (!replaceLocal) {
        final allLocalDocs = box.values.toList();
        for (final localDoc in allLocalDocs) {
          if (!backendDocumentIds.contains(localDoc.id)) {
            final hasLocalFiles = !localDoc.filePath.startsWith('http://') &&
                !localDoc.filePath.startsWith('https://');
            if (hasLocalFiles) {
              // This is a local-only document, mark as pending upload
              DocumentSyncStateService.instance.setSyncStatus(
                localDoc.id,
                DocumentSyncStatus.pendingUpload,
              );
            }
          }
        }
      }

      final syncType = forceFullSync || _lastSyncTime == null
          ? 'full'
          : 'incremental';
      final syncEfficiency = forceFullSync || _lastSyncTime == null
          ? 'N/A'
          : '${allDocumentsJson.length} documents fetched (incremental)';

      AppLogger.info(
        'Document sync completed',
        data: {
          'syncType': syncType,
          'added': added,
          'updated': updated,
          'skipped': skipped,
          'replaced': replaced,
          'conflicts': conflicts,
          'total': allDocumentsJson.length,
          'replaceLocal': replaceLocal,
          'efficiency': syncEfficiency,
          'lastSyncTime': _lastSyncTime!.toIso8601String(),
        },
      );

      return SyncResult(
        success: true,
        message: replaceLocal
            ? 'Local documents replaced with backend data'
            : 'Sync completed successfully',
        documentsAdded: added,
        documentsUpdated: updated,
        documentsSkipped: skipped,
        documentsReplaced: replaced,
      );
    } catch (e, stack) {
      AppLogger.error(
        'Document sync failed (attempt ${retryAttempt + 1}/$_maxRetryAttempts)',
        error: e,
        stack: stack,
      );

      // Retry with exponential backoff
      if (retryAttempt < _maxRetryAttempts - 1) {
        final delay = _calculateRetryDelay(retryAttempt);
        AppLogger.info(
          'Retrying sync in ${delay.inSeconds}s (attempt ${retryAttempt + 2}/$_maxRetryAttempts)',
          data: {'error': e.toString(), 'delaySeconds': delay.inSeconds},
        );

        await Future.delayed(delay);
        return syncDocuments(
          forceFullSync: forceFullSync,
          replaceLocal: replaceLocal,
          retryAttempt: retryAttempt + 1,
        );
      }

      // Max attempts reached
      return SyncResult(
        success: false,
        message:
            'Sync failed after $_maxRetryAttempts attempts: ${e.toString()}',
        documentsAdded: 0,
        documentsUpdated: 0,
        documentsSkipped: 0,
        documentsReplaced: 0,
      );
    } finally {
      _isSyncing = false;
      // Process next queued sync request
      _processSyncQueue();
    }
  }

  /// Processes the sync queue after a sync completes
  void _processSyncQueue() {
    if (_syncQueue.isEmpty || _isSyncing) {
      return;
    }

    // Remove expired requests
    final now = DateTime.now();
    _syncQueue.removeWhere((req) {
      if (now.difference(req.createdAt) > _syncRequestTimeout) {
        if (!req.completer.isCompleted) {
          req.completer.completeError(
            TimeoutException('Sync request expired'),
          );
        }
        return true;
      }
      return false;
    });

    if (_syncQueue.isEmpty) {
      return;
    }

    // Process next request in queue
    final nextRequest = _syncQueue.removeAt(0);
    AppLogger.info(
      'Processing queued sync request',
      data: {
        'forceFullSync': nextRequest.forceFullSync,
        'replaceLocal': nextRequest.replaceLocal,
        'queueRemaining': _syncQueue.length,
      },
    );

    syncDocuments(
      forceFullSync: nextRequest.forceFullSync,
      replaceLocal: nextRequest.replaceLocal,
      retryAttempt: nextRequest.retryAttempt,
    ).then((result) {
      if (!nextRequest.completer.isCompleted) {
        nextRequest.completer.complete(result);
      }
    }).catchError((error) {
      if (!nextRequest.completer.isCompleted) {
        nextRequest.completer.completeError(error);
      }
    });
  }

  /// Calculates retry delay with exponential backoff
  Duration _calculateRetryDelay(int attempt) {
    final baseDelay = _baseRetryDelay.inSeconds;
    final delaySeconds =
        baseDelay * (1 << attempt); // Exponential: 5s, 10s, 20s
    final delay = Duration(seconds: delaySeconds);
    return delay > _maxRetryBackoff ? _maxRetryBackoff : delay;
  }

  /// Starts background download for a document with URL filePath.
  /// Uses the download queue for better management and progress tracking.
  /// Implements retry logic with exponential backoff (max 3 retries).
  void _startBackgroundDownload(
    DocumentModel remoteDoc,
    Box<DocumentModel> box,
  ) {
    // Check retry count before queuing
    final retryCount = DocumentSyncStateService.instance.getRetryCount(remoteDoc.id);
    const maxRetries = 3;

    if (retryCount >= maxRetries) {
      // Max retries reached - mark as failed
      AppLogger.warning(
        'Download failed after $maxRetries retries, marking as failed',
        error: null,
        data: {
          'id': remoteDoc.id,
          'title': remoteDoc.title,
          'retryCount': retryCount,
        },
      );
      DocumentSyncStateService.instance.setSyncStatus(
        remoteDoc.id,
        DocumentSyncStatus.failed,
        errorMessage: 'Download failed after $maxRetries attempts',
      );
      return;
    }

    AppLogger.info(
      '📥 Queuing document for download',
      data: {
        'id': remoteDoc.id,
        'title': remoteDoc.title,
        'retryCount': retryCount,
        'fileUrl':
            remoteDoc.filePath.substring(
              0,
              remoteDoc.filePath.length > 100 ? 100 : remoteDoc.filePath.length,
            ) +
            '...',
      },
    );

    // Queue the download (will be processed by download service)
    DocumentDownloadService.instance.queueDownload(
      documentId: remoteDoc.id,
      fileUrl: remoteDoc.filePath,
      thumbnailUrl: remoteDoc.thumbnailPath.isNotEmpty
          ? remoteDoc.thumbnailPath
          : null,
      format: remoteDoc.format,
      priority: DownloadPriority.normal,
    );

    // Cancel any existing subscription for this document
    _downloadSubscriptions[remoteDoc.id]?.cancel();
    _downloadSubscriptions.remove(remoteDoc.id);

    // Listen to download progress and update document when complete
    final subscription = DocumentDownloadService.instance.progressStream.listen(
      (progress) {
        if (progress.documentId == remoteDoc.id && progress.isComplete) {
          // Download completed successfully - reset retry count
          DocumentSyncStateService.instance.resetRetryCount(remoteDoc.id);
          // Update document with local paths
          _updateDocumentAfterDownload(remoteDoc, box);
          _cleanupSubscription(remoteDoc.id);
        } else if (progress.documentId == remoteDoc.id &&
            progress.error != null) {
          // Download failed - increment retry count and retry with exponential backoff
          DocumentSyncStateService.instance.incrementRetryCount(remoteDoc.id);
          final newRetryCount = DocumentSyncStateService.instance.getRetryCount(remoteDoc.id);
          
          AppLogger.error(
            'Download failed for document (retry $newRetryCount/$maxRetries)',
            error: Exception(progress.error),
            data: {'id': remoteDoc.id, 'retryCount': newRetryCount},
          );

          // Emit sync failed event
          DocumentEventBus.instance.emitSyncFailed(
            remoteDoc.id,
            error: progress.error ?? 'Unknown error',
            isUpload: false,
            retryCount: newRetryCount,
          );
          
          if (newRetryCount < maxRetries) {
            // Calculate exponential backoff delay: 5min, 15min, 30min
            final delayMinutes = [5, 15, 30][newRetryCount - 1];
            AppLogger.info(
              'Retrying download after ${delayMinutes} minutes',
              data: {'id': remoteDoc.id, 'retryCount': newRetryCount},
            );
            
            // Schedule retry
            Future.delayed(Duration(minutes: delayMinutes), () {
              _startBackgroundDownload(remoteDoc, box);
            });
          } else {
            // Max retries reached - mark as failed
            DocumentSyncStateService.instance.setSyncStatus(
              remoteDoc.id,
              DocumentSyncStatus.failed,
              errorMessage: progress.error ?? 'Download failed after $maxRetries attempts',
            );
          }
          
          _cleanupSubscription(remoteDoc.id);
        }
      },
      onError: (error) {
        // Increment retry count on stream error
        DocumentSyncStateService.instance.incrementRetryCount(remoteDoc.id);
        final newRetryCount = DocumentSyncStateService.instance.getRetryCount(remoteDoc.id);
        
        AppLogger.error(
          'Error listening to download progress (retry $newRetryCount/$maxRetries)',
          error: error,
          data: {'id': remoteDoc.id, 'retryCount': newRetryCount},
        );

        if (newRetryCount < maxRetries) {
          // Calculate exponential backoff delay
          final delayMinutes = [5, 15, 30][newRetryCount - 1];
          Future.delayed(Duration(minutes: delayMinutes), () {
            _startBackgroundDownload(remoteDoc, box);
          });
        } else {
          // Max retries reached - mark as failed
          DocumentSyncStateService.instance.setSyncStatus(
            remoteDoc.id,
            DocumentSyncStatus.failed,
            errorMessage: 'Download failed after $maxRetries attempts: ${error.toString()}',
          );
        }
        
        _cleanupSubscription(remoteDoc.id);
      },
    );

    // Store subscription for cleanup
    _downloadSubscriptions[remoteDoc.id] = subscription;
  }

  /// Cleans up subscription for a document
  void _cleanupSubscription(String documentId) {
    final subscription = _downloadSubscriptions.remove(documentId);
    subscription?.cancel();
  }

  /// Updates document in Hive after download completes
  Future<void> _updateDocumentAfterDownload(
    DocumentModel remoteDoc,
    Box<DocumentModel> box,
  ) async {
    try {
      // Get local file paths
      final appDocsDir = await getApplicationDocumentsDirectory();
      if (appDocsDir == null) {
        AppLogger.warning(
          'Failed to get application documents directory',
          error: null,
          data: {'id': remoteDoc.id},
        );
        return;
      }

      final documentsDir = Directory('${appDocsDir.path}/scanned_documents');
      final thumbsDir = Directory('${appDocsDir.path}/thumbnails');

      final localFilePath =
          '${documentsDir.path}/${remoteDoc.id}/${remoteDoc.id}.${remoteDoc.format}';
      final localThumbPath = '${thumbsDir.path}/${remoteDoc.id}_thumb.jpg';

      // Check if files exist
      final fileExists = await File(localFilePath).exists();
      final thumbExists = await File(localThumbPath).exists();

      if (fileExists) {
        final currentDoc = box.get(remoteDoc.id);
        if (currentDoc != null) {
          final updatedDoc = DocumentModel(
            id: remoteDoc.id,
            title: remoteDoc.title,
            filePath: localFilePath,
            thumbnailPath: thumbExists ? localThumbPath : '',
            format: remoteDoc.format,
            pageCount: remoteDoc.pageCount,
            createdAt: remoteDoc.createdAt,
            updatedAt: remoteDoc.updatedAt,
            pageImagePaths: remoteDoc.pageImagePaths,
            scanMode: remoteDoc.scanMode,
            textContent: remoteDoc.textContent,
            colorProfile: remoteDoc.colorProfile,
            tags: remoteDoc.tags,
            metadata: remoteDoc.metadata,
          );

          await box.put(remoteDoc.id, updatedDoc);
          
          // Update sync status to synced since download completed
          DocumentSyncStateService.instance.setSyncStatus(
            remoteDoc.id,
            DocumentSyncStatus.synced,
            lastSyncTime: DateTime.now(),
          );
          
          // Emit sync success event
          DocumentEventBus.instance.emitSynced(
            remoteDoc.id,
            isUpload: false,
            success: true,
          );
          
          AppLogger.info(
            '✅ Document updated with local file paths after download and marked as synced',
            data: {
              'id': remoteDoc.id,
              'filePath': localFilePath,
              'thumbnailPath': thumbExists ? localThumbPath : 'none',
            },
          );
        } else {
          AppLogger.warning(
            'Document not found in box after download',
            error: null,
            data: {'id': remoteDoc.id},
          );
        }
      } else {
        AppLogger.warning(
          'Downloaded file not found at expected path',
          error: null,
          data: {
            'id': remoteDoc.id,
            'expectedPath': localFilePath,
          },
        );
      }
    } catch (e, stack) {
      AppLogger.error(
        'Failed to update document after download',
        error: e,
        stack: stack,
        data: {'id': remoteDoc.id},
      );
    }
  }

  /// Checks if two documents differ in content (beyond just timestamps).
  /// Used for conflict detection when timestamps are equal.
  bool _documentsDiffer(DocumentModel local, DocumentModel remote) {
    // Compare key fields that indicate content changes
    if (local.title != remote.title) return true;
    if (local.pageCount != remote.pageCount) return true;
    if (local.format != remote.format) return true;
    if (local.scanMode != remote.scanMode) return true;
    if (local.colorProfile != remote.colorProfile) return true;

    // Compare tags (order-independent)
    final localTags = Set.from(local.tags);
    final remoteTags = Set.from(remote.tags);
    if (localTags.length != remoteTags.length ||
        !localTags.containsAll(remoteTags)) {
      return true;
    }

    // Compare metadata keys (not values, as they may be formatted differently)
    final localMetadataKeys = Set.from(local.metadata.keys);
    final remoteMetadataKeys = Set.from(remote.metadata.keys);
    if (localMetadataKeys.length != remoteMetadataKeys.length ||
        !localMetadataKeys.containsAll(remoteMetadataKeys)) {
      return true;
    }

    return false;
  }

  /// Parses a backend document JSON into a DocumentModel.
  ///
  /// **Backend Response Format:**
  /// ```json
  /// {
  ///   "id": "uuid",
  ///   "userId": "uuid",
  ///   "title": "Document Title",
  ///   "fileUrl": "https://supabase.co/storage/...",
  ///   "thumbnailUrl": "https://supabase.co/storage/...",
  ///   "format": "pdf",
  ///   "pageCount": 5,
  ///   "scanMode": "document",
  ///   "colorProfile": "color",
  ///   "textContent": null,
  ///   "tags": ["tag1", "tag2"],
  ///   "metadata": {"key": "value"},
  ///   "createdAt": "2024-01-01T00:00:00Z",
  ///   "updatedAt": "2024-01-01T00:00:00Z"
  /// }
  /// ```
  ///
  /// **Note:** Backend returns `fileUrl` (Supabase Storage URL) which is stored
  /// in `filePath` field. For synced documents, the file is not downloaded locally
  /// but accessed via the URL when needed.
  ///
  /// **Parameters:**
  /// - `json`: JSON object from backend API
  ///
  /// **Returns:**
  /// - `DocumentModel` instance with all fields populated
  ///
  /// **Throws:**
  /// - `FormatException` if JSON structure is invalid
  DocumentModel _parseBackendDocument(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      title: json['title'] as String,
      filePath: json['fileUrl'] as String, // Store Supabase URL here
      thumbnailPath: json['thumbnailUrl'] as String? ?? '',
      format: json['format'] as String,
      pageCount: json['pageCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      pageImagePaths: const [], // Backend doesn't store page images
      scanMode: json['scanMode'] as String,
      textContent: json['textContent'] as String? ?? '',
      colorProfile: json['colorProfile'] as String? ?? 'color',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      metadata:
          (json['metadata'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
    );
  }
}

/// Result of a document sync operation.
///
/// Contains information about the sync operation including success status,
/// counts of documents added/updated/skipped, and any error messages.
///
/// **Example:**
/// ```dart
/// final result = await DocumentSyncService.instance.syncDocuments();
/// if (result.success) {
///   print('Added: ${result.documentsAdded}');
///   print('Updated: ${result.documentsUpdated}');
///   print('Skipped: ${result.documentsSkipped}');
/// } else {
///   print('Error: ${result.message}');
/// }
/// ```
/// Result of a document sync operation.
///
/// Contains information about the sync operation including success status,
/// counts of documents added/updated/skipped/replaced, and any error messages.
///
/// **Example:**
/// ```dart
/// final result = await DocumentSyncService.instance.syncDocuments();
/// if (result.success) {
///   print('Added: ${result.documentsAdded}');
///   print('Updated: ${result.documentsUpdated}');
///   print('Skipped: ${result.documentsSkipped}');
///   print('Replaced: ${result.documentsReplaced}');
/// } else {
///   print('Error: ${result.message}');
/// }
/// ```
class SyncResult {
  /// Whether the sync operation completed successfully
  final bool success;

  /// Human-readable message describing the sync result
  final String message;

  /// Number of new documents added from backend
  final int documentsAdded;

  /// Number of existing documents updated from backend
  final int documentsUpdated;

  /// Number of documents skipped (local version was newer or same)
  final int documentsSkipped;

  /// Number of documents replaced (when replaceLocal is true)
  final int documentsReplaced;

  /// Creates a new [SyncResult] instance.
  ///
  /// **Parameters:**
  /// - `success`: Whether the sync operation completed successfully
  /// - `message`: Human-readable message describing the result
  /// - `documentsAdded`: Number of new documents added
  /// - `documentsUpdated`: Number of documents updated
  /// - `documentsSkipped`: Number of documents skipped
  /// - `documentsReplaced`: Number of documents replaced (default: 0)
  SyncResult({
    required this.success,
    required this.message,
    required this.documentsAdded,
    required this.documentsUpdated,
    required this.documentsSkipped,
    this.documentsReplaced = 0,
  });

  /// Total number of documents processed (added + updated + skipped + replaced)
  int get totalProcessed =>
      documentsAdded + documentsUpdated + documentsSkipped + documentsReplaced;

  @override
  String toString() {
    return 'SyncResult('
        'success: $success, '
        'message: $message, '
        'added: $documentsAdded, '
        'updated: $documentsUpdated, '
        'skipped: $documentsSkipped, '
        'replaced: $documentsReplaced, '
        'total: $totalProcessed'
        ')';
  }
}

/// Internal class to represent a queued sync request
class _SyncRequest {
  final Completer<SyncResult> completer;
  final bool forceFullSync;
  final bool replaceLocal;
  final int retryAttempt;
  final DateTime createdAt;

  _SyncRequest({
    required this.completer,
    required this.forceFullSync,
    required this.replaceLocal,
    required this.retryAttempt,
    required this.createdAt,
  });
}
