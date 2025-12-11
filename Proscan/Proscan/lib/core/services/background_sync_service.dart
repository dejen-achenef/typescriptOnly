// core/services/background_sync_service.dart
import 'dart:async';

import 'package:workmanager/workmanager.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_backend_sync_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/services/document_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/models/document_model.dart';

/// Background sync service for pulling remote document changes.
///
/// Uses WorkManager to periodically sync documents from the backend
/// even when the app is in the background or closed.
///
/// **Features:**
/// - Periodic background sync (every 15 minutes when app is active)
/// - Delta sync (only fetches documents updated since last sync)
/// - Conflict resolution (last write wins)
/// - Automatic retry on failure
///
/// **Usage:**
/// ```dart
/// // Initialize in main.dart
/// await BackgroundSyncService.initialize();
///
/// // Register periodic task
/// BackgroundSyncService.registerPeriodicSync();
/// ```
class BackgroundSyncService {
  BackgroundSyncService._();
  static const String _taskName = 'pullRemoteDocuments';
  static const String _uniqueTaskName = 'pullRemoteDocumentsUnique';

  /// Initializes the background sync service
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // Set to true for debugging
    );
    AppLogger.info('BackgroundSyncService initialized');
  }

  /// Registers a periodic task to pull remote document changes
  ///
  /// **Frequency:**
  /// - Runs every 15 minutes when app is active
  /// - Minimum interval is 15 minutes (Android/iOS limitation)
  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      _uniqueTaskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    AppLogger.info('Periodic background sync registered (every 15 minutes)');
  }

  /// Cancels the periodic sync task
  static Future<void> cancelPeriodicSync() async {
    await Workmanager().cancelByUniqueName(_uniqueTaskName);
    AppLogger.info('Periodic background sync cancelled');
  }

  /// Manually triggers a background sync (one-time task)
  static Future<void> triggerSync() async {
    await Workmanager().registerOneOffTask(
      _taskName,
      _taskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    AppLogger.info('One-time background sync triggered');
  }

  /// Callback dispatcher for WorkManager
  ///
  /// This is called by WorkManager when the background task executes.
  /// It must be a top-level function (not a class method).
  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      if (task == _taskName) {
        try {
          AppLogger.info('Background sync task started');
          await _pullRemoteChanges();
          AppLogger.info('Background sync task completed successfully');
          return Future.value(true);
        } catch (e, stack) {
          AppLogger.error(
            'Background sync task failed',
            error: e,
            stack: stack,
          );
          return Future.value(false);
        }
      }
      return Future.value(false);
    });
  }

  /// Pulls remote document changes and updates local storage
  ///
  /// **Process:**
  /// 1. Gets last successful sync timestamp
  /// 2. Fetches documents updated since that timestamp
  /// 3. Updates local Hive storage with remote changes
  /// 4. Handles conflicts (last write wins)
  /// 5. Updates sync status for each document
  static Future<void> _pullRemoteChanges() async {
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
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
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
            AppLogger.info(
              'Created new document from cloud',
              data: {'documentId': remoteDoc.id, 'title': remoteDoc.title},
            );
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
              AppLogger.info(
                'Soft deleted document from cloud',
                data: {'documentId': remoteDoc.id},
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
            AppLogger.info(
              'Updated local document from cloud (remote was newer)',
              data: {
                'documentId': remoteDoc.id,
                'localUpdatedAt': localDoc.updatedAt.toIso8601String(),
                'remoteUpdatedAt': remoteDoc.updatedAt.toIso8601String(),
              },
            );
          } else if (localDoc.updatedAt.isAfter(remoteDoc.updatedAt)) {
            // Local is newer, mark as conflict (will be resolved on next upload)
            DocumentSyncStateService.instance.setSyncStatus(
              remoteDoc.id,
              DocumentSyncStatus.pendingConflictResolution,
              errorMessage: 'Local version is newer than remote',
            );
            conflicts++;
            AppLogger.warning(
              'Conflict detected: local version is newer',
              error: null,
              data: {
                'documentId': remoteDoc.id,
                'localUpdatedAt': localDoc.updatedAt.toIso8601String(),
                'remoteUpdatedAt': remoteDoc.updatedAt.toIso8601String(),
              },
            );
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

      AppLogger.info(
        'Background sync completed',
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
}

