// main.dart — FINAL, BULLETPROOF VERSION
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/config/router/router.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/services/document_download_service.dart';
import 'package:thyscan/core/services/document_sync_service.dart';
import 'package:thyscan/core/services/document_health_check_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/core/services/full_text_search_index_service.dart';
import 'package:thyscan/core/services/image_cache_service.dart';
import 'package:thyscan/core/services/memory_monitor_service.dart';
import 'package:thyscan/core/services/recent_searches_service.dart';
import 'package:thyscan/core/services/background_sync_service.dart';
import 'package:thyscan/core/theme/constants/theme.dart';
import 'package:thyscan/core/theme/controllers/theme.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        AppLogger.error(
          'Flutter error',
          error: details.exception,
          stack: details.stack,
        );
      };

      // Set global error widget builder (catches rendering errors)
      // This prevents one corrupted widget from crashing the entire app
      ErrorWidget.builder = (details) {
        AppLogger.error(
          'ErrorWidget caught error',
          error: details.exception,
          stack: details.stack,
        );
        
        // Return a safe error widget instead of crashing
        return Material(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This widget failed to render',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      };

      try {
        // OFFLINE-FIRST: Start AuthService.init() in background (non-blocking)
        // App opens instantly, auth initializes silently in background
        final authInitFuture = AuthService.instance.init().catchError((error) {
          AppLogger.error(
            'AuthService initialization failed (continuing in guest mode)',
            error: error,
          );
        });

        // Initialize Hive (required for app to work)
        // CRITICAL: Documents from internal storage are available immediately
        // The UI will show these documents right away, even before sync completes
        await Hive.initFlutter();
        Hive.registerAdapter(DocumentModelAdapter());
        await Hive.openBox<DocumentModel>(DocumentService.boxName);
        
        AppLogger.info(
          '📱 Hive initialized - Documents from internal storage are now available',
          data: {
            'documentCount': Hive.box<DocumentModel>(DocumentService.boxName).length,
          },
        );

        // Initialize document upload service
        DocumentUploadService.instance.initialize().catchError((error) {
          AppLogger.error(
            'DocumentUploadService initialization failed',
            error: error,
          );
        });

        // Initialize document download service
        DocumentDownloadService.instance.initialize().catchError((error) {
          AppLogger.error(
            'DocumentDownloadService initialization failed',
            error: error,
          );
        });

        // Initialize document sync service
        DocumentSyncService.instance.initialize().catchError((error) {
          AppLogger.error(
            'DocumentSyncService initialization failed',
            error: error,
          );
        });

        // Initialize document sync state service
        DocumentSyncStateService.instance.initialize().catchError((error) {
          AppLogger.error(
            'DocumentSyncStateService initialization failed',
            error: error,
          );
        });

        // Initialize background sync service
        BackgroundSyncService.initialize().catchError((error) {
          AppLogger.error(
            'BackgroundSyncService initialization failed',
            error: error,
          );
        });

        RecentSearchesService.instance.initialize().catchError((error) {
          AppLogger.error(
            'RecentSearchesService initialization failed',
            error: error,
          );
        });

        // Initialize full-text search index service (instant search like Microsoft Lens)
        FullTextSearchIndexService.instance.initialize().catchError((error) {
          AppLogger.error(
            'FullTextSearchIndexService initialization failed',
            error: error,
          );
        });

        // Initialize image cache service
        ImageCacheService.instance.initialize().catchError((error) {
          AppLogger.error(
            'ImageCacheService initialization failed',
            error: error,
          );
        });

        // Initialize and start memory monitoring
        MemoryMonitorService.instance.startMonitoring();
        // Register memory pressure callbacks
        MemoryMonitorService.instance.registerMemoryPressureCallback(() {
          ImageCacheService.instance.clearOnMemoryPressure();
        });

        // Run document health check in background (non-blocking)
        // Prevents crashes from manually deleted files
        DocumentHealthCheckService.instance.runHealthCheck().catchError((error) {
          AppLogger.error(
            'Document health check failed (non-critical)',
            error: error,
          );
        });

        // Trigger initial sync after auth is ready (non-blocking)
        // SAFE MERGE MODE: Merges backend documents with local storage
        // Never clears local documents - preserves offline work
        authInitFuture.then((_) async {
          // Wait a bit for auth to fully initialize
          await Future.delayed(const Duration(seconds: 2));
          final user = AuthService.instance.currentUser;
          if (user != null) {
            AppLogger.info(
              '✅ User authenticated - userId: ${user.id}',
              data: {
                'userId': user.id,
                'email': user.email ?? 'N/A',
              },
            );
            
            // Register periodic background sync
            BackgroundSyncService.registerPeriodicSync().catchError((error) {
              AppLogger.error(
                'Failed to register periodic background sync',
                error: error,
              );
            });
            
            AppLogger.info(
              '🔄 Triggering initial document sync for authenticated user (merging with local documents)',
              data: {
                'userId': user.id,
                'localDocumentCount': Hive.box<DocumentModel>(DocumentService.boxName).length,
              },
            );
            // SAFE: Merge backend documents with local storage
            // Local documents are preserved and only updated if backend version is newer
            // CRITICAL: Backend will only return documents with this user's userId
            DocumentSyncService.instance
                .syncDocuments(
                  forceFullSync: true,
                  replaceLocal: false, // SAFE: Merge mode - preserves local documents
                )
                .then((result) {
              AppLogger.info(
                '✅ Initial sync completed for user ${user.id}',
                data: {
                  'userId': user.id,
                  'success': result.success,
                  'added': result.documentsAdded,
                  'updated': result.documentsUpdated,
                  'skipped': result.documentsSkipped,
                },
              );
            }).catchError((error) {
              AppLogger.warning(
                '⚠️ Initial sync failed for user ${user.id} (app will use local documents)',
                error: error,
                data: {'userId': user.id},
              );
            });
          } else {
            AppLogger.info(
              'ℹ️ No authenticated user - app will show only local documents',
            );
          }
        }).catchError((error) {
          AppLogger.warning(
            'Auth initialization failed, skipping initial sync',
            error: error,
          );
        });

        AppLogger.info('Core services initialized successfully (auth initializing in background)');
      } catch (e, s) {
        AppLogger.error('FATAL: Core initialization failed', error: e, stack: s);
        // Optional: Show crash screen
      }

      runApp( ProviderScope(child: MyApp()));
    },
    (error, stack) {
      AppLogger.error('Uncaught error', error: error, stack: stack);
    },
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: 'ThyScan',
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode.value ?? ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}
