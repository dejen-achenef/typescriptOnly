// features/home/controllers/async_documents_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/models/document_filter.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Async provider for all documents (never blocks main thread)
/// Uses DocumentRepository with compute() isolates
final allDocumentsAsyncProvider = FutureProvider<List<DocumentModel>>((
  ref,
) async {
  return await DocumentRepository.instance.getAllDocuments(
    includeDeleted: false,
  );
});

/// Async provider for document count (never blocks main thread)
final documentCountAsyncProvider = FutureProvider<int>((ref) async {
  return await DocumentRepository.instance.getDocumentCount(
    includeDeleted: false,
  );
});

/// Async provider for filtered documents (never blocks main thread)
final filteredDocumentsAsyncProvider = FutureProvider<List<DocumentModel>>((
  ref,
) async {
  final homeState = ref.watch(homeProvider);
  final activeFilter = DocumentFilters.getById(homeState.activeFilterId);

  // Get all documents async
  final allDocuments = await ref.watch(allDocumentsAsyncProvider.future);

  // Apply filter
  final filteredDocs = allDocuments.where((doc) {
    if (doc.isDeleted) return false;
    return activeFilter.matches(doc.scanMode);
  }).toList();

  // Apply sorting
  switch (homeState.sortCriteria) {
    case SortCriteria.date:
      filteredDocs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case SortCriteria.size:
    case SortCriteria.pages:
      filteredDocs.sort((a, b) => b.pageCount.compareTo(a.pageCount));
      break;
  }

  return filteredDocs;
});

/// Async provider for document by ID (never blocks main thread)
final documentByIdProvider = FutureProvider.family<DocumentModel?, String>((
  ref,
  id,
) async {
  return await DocumentRepository.instance.getDocumentById(id);
});

/// Async provider for document count by filter (never blocks main thread)
final documentCountByFilterAsyncProvider = FutureProvider.family<int, String>((
  ref,
  filterId,
) async {
  final allDocuments = await ref.watch(allDocumentsAsyncProvider.future);
  final filter = DocumentFilters.getById(filterId);

  if (filter.scanMode == null) {
    return allDocuments.length; // 'All' filter
  }

  return allDocuments.where((doc) => filter.matches(doc.scanMode)).length;
});

/// Stream provider that watches Hive box changes (async, non-blocking)
/// Uses Hive box watch() which is already async-safe
final documentsStreamProvider = StreamProvider<List<DocumentModel>>((
  ref,
) async* {
  final box = await Hive.openBox<DocumentModel>(DocumentService.boxName);

  // Initial load (async)
  final initialDocs = await DocumentRepository.instance.getAllDocuments(
    includeDeleted: false,
  );
  yield initialDocs;

  // Watch for changes
  await for (final event in box.watch()) {
    // Reload documents async when box changes
    final updatedDocs = await DocumentRepository.instance.getAllDocuments(
      includeDeleted: false,
    );
    yield updatedDocs;
  }
});

/// StateNotifier that watches Hive box changes (async, non-blocking)
class AsyncDocumentsNotifier
    extends StateNotifier<AsyncValue<List<DocumentModel>>> {
  StreamSubscription? _subscription;
  final Box<DocumentModel> _box;

  AsyncDocumentsNotifier(this._box) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initial load (async, in isolate)
      final docs = await DocumentRepository.instance.getAllDocuments(
        includeDeleted: false,
      );
      state = AsyncValue.data(docs);

      // Watch for changes
      _subscription = _box.watch().listen((_) async {
        // Reload async when box changes
        try {
          final updatedDocs = await DocumentRepository.instance.getAllDocuments(
            includeDeleted: false,
          );
          state = AsyncValue.data(updatedDocs);
        } catch (e, stack) {
          AppLogger.error(
            'Error reloading documents in AsyncDocumentsNotifier',
            error: e,
            stack: stack,
          );
          state = AsyncValue.error(e, stack);
        }
      });
    } catch (e, stack) {
      AppLogger.error(
        'Error initializing AsyncDocumentsNotifier',
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

/// Provider that returns async documents notifier (never blocks main thread)
final asyncDocumentsNotifierProvider =
    StateNotifierProvider<
      AsyncDocumentsNotifier,
      AsyncValue<List<DocumentModel>>
    >((ref) {
      // Get box reference (this is safe, just getting reference)
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      return AsyncDocumentsNotifier(box);
    });
