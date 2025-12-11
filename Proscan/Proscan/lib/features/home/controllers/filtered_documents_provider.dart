import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_search_service.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/models/document_filter.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Provider that watches Hive box for real-time document updates (async, non-blocking)
final hiveBoxProvider = Provider<Box<DocumentModel>>((ref) {
  return Hive.box<DocumentModel>(DocumentService.boxName);
});

/// StateNotifier that watches Hive box and emits document list updates (async, non-blocking)
class DocumentsNotifier extends StateNotifier<AsyncValue<List<DocumentModel>>> {
  final Box<DocumentModel> _box;
  StreamSubscription? _subscription;

  DocumentsNotifier(this._box) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initial load (async, in isolate - never blocks main thread)
      final docs = await DocumentRepository.instance.getAllDocuments(
        includeDeleted: false,
      );
      state = AsyncValue.data(docs);

      // Listen to box changes - watch() returns Stream<BoxEvent>
      _subscription = _box.watch().listen((_) async {
        // Reload async when box changes (never blocks main thread)
        try {
          final updatedDocs = await DocumentRepository.instance.getAllDocuments(
            includeDeleted: false,
          );
          state = AsyncValue.data(updatedDocs);
        } catch (e, stack) {
          AppLogger.error(
            'Error reloading documents in DocumentsNotifier',
            error: e,
            stack: stack,
          );
          state = AsyncValue.error(e, stack);
        }
      });
    } catch (e, stack) {
      AppLogger.error(
        'Error initializing DocumentsNotifier',
        error: e,
        stack: stack,
      );
      state = AsyncValue.error(e, stack);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider that returns all documents (reactive to Hive changes, async, non-blocking)
/// Excludes soft-deleted documents from the main view
final allDocumentsProvider =
    StateNotifierProvider<DocumentsNotifier, AsyncValue<List<DocumentModel>>>((
      ref,
    ) {
      final box = ref.watch(hiveBoxProvider);
      return DocumentsNotifier(box);
    });

/// Provider that returns filtered and sorted documents based on current home state
/// Uses local filtering by default for performance, but can use backend when online
/// Now reactive to Hive box changes for immediate updates (async, non-blocking)
final filteredDocumentsProvider = Provider<AsyncValue<List<DocumentModel>>>((
  ref,
) {
  final homeState = ref.watch(homeProvider);

  // Watch all documents (reactive to Hive changes, async)
  final allDocumentsAsync = ref.watch(allDocumentsProvider);

  return allDocumentsAsync.when(
    data: (allDocuments) {
      // Apply filter based on scan mode and exclude soft-deleted documents
      final activeFilter = DocumentFilters.getById(homeState.activeFilterId);
      final filteredDocs = allDocuments.where((doc) {
        // Exclude soft-deleted documents from main view
        if (doc.isDeleted) {
          return false;
        }
        return activeFilter.matches(doc.scanMode);
      }).toList();

      // Apply sorting
      switch (homeState.sortCriteria) {
        case SortCriteria.date:
          filteredDocs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case SortCriteria.size:
          // Sort by file size (approximate based on page count)
          filteredDocs.sort((a, b) => b.pageCount.compareTo(a.pageCount));
          break;
        case SortCriteria.pages:
          filteredDocs.sort((a, b) => b.pageCount.compareTo(a.pageCount));
          break;
      }

      return AsyncValue.data(filteredDocs);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider that uses backend search when online (for consistent cross-device results)
/// Falls back to local filtering when offline
final filteredDocumentsWithBackendProvider = FutureProvider<List<DocumentModel>>((
  ref,
) async {
  final homeState = ref.watch(homeProvider);
  final activeFilter = DocumentFilters.getById(homeState.activeFilterId);

  // Check connectivity
  final connectivity = Connectivity();
  final connectivityResults = await connectivity.checkConnectivity();
  final isOnline = connectivityResults.any(
    (result) =>
        result != ConnectivityResult.none &&
        result != ConnectivityResult.bluetooth,
  );

  // For "All" filter with default sort, use local (fast and documents are synced)
  // For specific filters or when online, prefer backend for consistency
  if (isOnline && activeFilter.scanMode != null) {
    try {
      // Use backend search for filtered views when online
      final results = await DocumentSearchService.instance.search(
        query: null, // No text query, just filtering
        scanMode: activeFilter.scanMode,
        sortBy: homeState.sortCriteria,
        descending: true,
        page: 0,
        pageSize: 1000, // Get all results for main view
      );
      return results.items;
    } catch (e) {
      // Fallback to local on error
    }
  }

  // Use local filtering (offline or "All" filter or backend failed)
  final allDocumentsAsync = ref.watch(allDocumentsProvider);
  final allDocuments = await allDocumentsAsync.value ?? [];
  return DocumentSearchService.instance.filterAndSort(
    documents: allDocuments,
    scanMode: activeFilter.scanMode,
    sortBy: homeState.sortCriteria,
    descending: true,
  );
});

/// Provider for document count by filter (reactive to Hive changes, async, non-blocking)
final documentCountByFilterProvider = Provider.family<AsyncValue<int>, String>((
  ref,
  filterId,
) {
  // Watch all documents (reactive to Hive changes, async)
  final allDocumentsAsync = ref.watch(allDocumentsProvider);

  return allDocumentsAsync.when(
    data: (allDocuments) {
      final filter = DocumentFilters.getById(filterId);

      if (filter.scanMode == null) {
        return AsyncValue.data(allDocuments.length); // 'All' filter
      }

      final count = allDocuments
          .where((doc) => filter.matches(doc.scanMode))
          .length;
      return AsyncValue.data(count);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});
