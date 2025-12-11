// features/home/controllers/documents_pagination_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/models/document_filter.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Page size for pagination (50 items per page = ~150 items for 3 pages)
const int _pageSize = 50;

/// Maximum documents to keep in memory (3 pages = 150 items)
const int _maxDocumentsInMemory = 150;

/// State for paginated documents with windowed loading
class PaginatedDocumentsState {
  final List<DocumentModel> documents;
  final int currentPage;
  final int totalItems;
  final bool isLoading;
  final bool hasMore;
  final Map<int, List<DocumentModel>> pageCache;
  final Set<int> loadedPages;

  PaginatedDocumentsState({
    required this.documents,
    required this.currentPage,
    required this.totalItems,
    required this.isLoading,
    required this.hasMore,
    Map<int, List<DocumentModel>>? pageCache,
    Set<int>? loadedPages,
  }) : pageCache = pageCache ?? {},
       loadedPages = loadedPages ?? {};

  PaginatedDocumentsState copyWith({
    List<DocumentModel>? documents,
    int? currentPage,
    int? totalItems,
    bool? isLoading,
    bool? hasMore,
    Map<int, List<DocumentModel>>? pageCache,
    Set<int>? loadedPages,
  }) {
    return PaginatedDocumentsState(
      documents: documents ?? this.documents,
      currentPage: currentPage ?? this.currentPage,
      totalItems: totalItems ?? this.totalItems,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      pageCache: pageCache ?? this.pageCache,
      loadedPages: loadedPages ?? this.loadedPages,
    );
  }

  /// Gets cached page data
  List<DocumentModel>? getCachedPage(int page) => pageCache[page];

  /// Checks if page is loaded
  bool isPageLoaded(int page) => loadedPages.contains(page);
}

/// Notifier for paginated documents with windowed loading
/// Implements CamScanner/Microsoft Lens style pagination:
/// - Loads only 3 pages at a time (current + 1 before + 1 after)
/// - Disposes pages when user scrolls far away
/// - Keeps max 150 documents in memory
class PaginatedDocumentsNotifier
    extends StateNotifier<PaginatedDocumentsState> {
  final String? scanMode;
  final SortCriteria sortBy;
  Timer? _disposeTimer;

  PaginatedDocumentsNotifier({required this.scanMode, required this.sortBy})
    : super(
        PaginatedDocumentsState(
          documents: const [],
          currentPage: 0,
          totalItems: 0,
          isLoading: true,
          hasMore: false,
        ),
      ) {
    _loadInitialPage();
  }

  /// Loads initial page (page 0)
  Future<void> _loadInitialPage() async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await DocumentService.instance.getDocumentsPaginated(
        page: 0,
        pageSize: _pageSize,
        sortBy: _sortByToString(sortBy),
        descending: true,
        forceRefresh: false,
      );

      // Filter by scan mode if specified
      final filteredDocs = _filterDocuments(result.items);

      final newCache = <int, List<DocumentModel>>{0: filteredDocs};
      final newLoadedPages = <int>{0};

      state = state.copyWith(
        documents: filteredDocs,
        currentPage: 0,
        totalItems: result.totalItems,
        isLoading: false,
        hasMore: result.hasMore,
        pageCache: newCache,
        loadedPages: newLoadedPages,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Loads a specific page
  Future<void> loadPage(int page) async {
    if (state.isPageLoaded(page)) {
      // Page already loaded, just update current page
      _updateCurrentPage(page);
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final result = await DocumentService.instance.getDocumentsPaginated(
        page: page,
        pageSize: _pageSize,
        sortBy: _sortByToString(sortBy),
        descending: true,
        forceRefresh: false,
      );

      // Filter by scan mode if specified
      final filteredDocs = _filterDocuments(result.items);

      // Update cache and loaded pages
      final newCache = Map<int, List<DocumentModel>>.from(state.pageCache);
      final newLoadedPages = Set<int>.from(state.loadedPages);

      newCache[page] = filteredDocs;
      newLoadedPages.add(page);

      // Windowed loading: keep only 3 pages (current + 1 before + 1 after)
      _cleanupDistantPages(page, newCache, newLoadedPages);

      // Merge documents from windowed pages (current + 1 before + 1 after)
      final windowedDocs = _mergeWindowedPages(page, newCache);

      state = state.copyWith(
        documents: windowedDocs,
        currentPage: page,
        totalItems: result.totalItems,
        isLoading: false,
        hasMore: result.hasMore,
        pageCache: newCache,
        loadedPages: newLoadedPages,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Updates current page without loading (for scrolling within loaded pages)
  void _updateCurrentPage(int page) {
    if (!state.isPageLoaded(page)) return;

    final windowedDocs = _mergeWindowedPages(page, state.pageCache);
    state = state.copyWith(documents: windowedDocs, currentPage: page);
  }

  /// Merges documents from windowed pages (current + 1 before + 1 after)
  List<DocumentModel> _mergeWindowedPages(
    int currentPage,
    Map<int, List<DocumentModel>> cache,
  ) {
    final pages = [currentPage - 1, currentPage, currentPage + 1];
    final merged = <DocumentModel>[];

    for (final page in pages) {
      if (page >= 0 && cache.containsKey(page)) {
        merged.addAll(cache[page]!);
      }
    }

    return merged;
  }

  /// Cleans up pages that are far from current page (beyond window)
  void _cleanupDistantPages(
    int currentPage,
    Map<int, List<DocumentModel>> cache,
    Set<int> loadedPages,
  ) {
    // Keep only pages within window (current ± 1) and ensure max 150 docs
    final pagesToKeep = <int>{};
    final pagesToRemove = <int>[];

    // Always keep current page and adjacent pages (window of 3 pages)
    for (int i = currentPage - 1; i <= currentPage + 1; i++) {
      if (i >= 0 && loadedPages.contains(i)) {
        pagesToKeep.add(i);
      }
    }

    // Count total documents in pages to keep
    int totalDocs = 0;
    for (final page in pagesToKeep) {
      totalDocs += cache[page]?.length ?? 0;
    }

    // If we're over the limit, remove oldest pages first
    if (totalDocs > _maxDocumentsInMemory) {
      final sortedPages = loadedPages.toList()..sort();
      for (final page in sortedPages) {
        if (!pagesToKeep.contains(page)) {
          pagesToRemove.add(page);
        } else if (totalDocs > _maxDocumentsInMemory) {
          // Remove from pages to keep if still over limit
          final pageDocs = cache[page]?.length ?? 0;
          if (totalDocs - pageDocs >= _maxDocumentsInMemory * 0.5) {
            pagesToRemove.add(page);
            totalDocs -= pageDocs;
          }
        }
      }
    } else {
      // Remove pages outside window
      for (final page in loadedPages) {
        if (!pagesToKeep.contains(page)) {
          pagesToRemove.add(page);
        }
      }
    }

    // Remove distant pages
    for (final page in pagesToRemove) {
      cache.remove(page);
      loadedPages.remove(page);
    }
  }

  /// Filters documents by scan mode
  List<DocumentModel> _filterDocuments(List<DocumentModel> documents) {
    if (scanMode == null) {
      // Return all non-deleted documents
      return documents.where((doc) => !doc.isDeleted).toList();
    }

    return documents
        .where((doc) => !doc.isDeleted && doc.scanMode == scanMode)
        .toList();
  }

  /// Loads next page (for infinite scroll)
  Future<void> loadNextPage() async {
    if (!state.hasMore || state.isLoading) return;

    final nextPage = state.currentPage + 1;
    await loadPage(nextPage);
  }

  /// Refreshes current page
  Future<void> refresh() async {
    // Clear cache for current page and reload
    final newCache = Map<int, List<DocumentModel>>.from(state.pageCache);
    final newLoadedPages = Set<int>.from(state.loadedPages);

    newCache.remove(state.currentPage);
    newLoadedPages.remove(state.currentPage);

    state = state.copyWith(pageCache: newCache, loadedPages: newLoadedPages);

    await loadPage(state.currentPage);
  }

  /// Converts SortCriteria to string for DocumentService
  String _sortByToString(SortCriteria criteria) {
    switch (criteria) {
      case SortCriteria.date:
        return 'createdAt';
      case SortCriteria.size:
        return 'pageCount';
      case SortCriteria.pages:
        return 'pageCount';
    }
  }

  @override
  void dispose() {
    _disposeTimer?.cancel();
    super.dispose();
  }
}

/// Provider for paginated documents with windowed loading
/// Automatically filters by active filter and sort criteria
final paginatedDocumentsProvider =
    StateNotifierProvider.family<
      PaginatedDocumentsNotifier,
      PaginatedDocumentsState,
      PaginatedDocumentsParams
    >((ref, params) {
      return PaginatedDocumentsNotifier(
        scanMode: params.scanMode,
        sortBy: params.sortBy,
      );
    });

/// Parameters for paginated documents provider
class PaginatedDocumentsParams {
  final String? scanMode;
  final SortCriteria sortBy;

  const PaginatedDocumentsParams({
    required this.scanMode,
    required this.sortBy,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedDocumentsParams &&
          runtimeType == other.runtimeType &&
          scanMode == other.scanMode &&
          sortBy == other.sortBy;

  @override
  int get hashCode => scanMode.hashCode ^ sortBy.hashCode;
}

/// Provider that returns the current paginated documents state
/// Automatically uses active filter and sort from home state
final currentPaginatedDocumentsProvider = Provider<PaginatedDocumentsState>((
  ref,
) {
  final homeState = ref.watch(homeProvider);
  final activeFilter = DocumentFilters.getById(homeState.activeFilterId);

  return ref.watch(
    paginatedDocumentsProvider(
      PaginatedDocumentsParams(
        scanMode: activeFilter.scanMode,
        sortBy: homeState.sortCriteria,
      ),
    ),
  );
});

/// Provider for document count (lightweight, doesn't load all documents)
final documentCountProvider = FutureProvider<int>((ref) async {
  final result = await DocumentService.instance.getDocumentsPaginated(
    page: 0,
    pageSize: 1,
    sortBy: 'createdAt',
    descending: true,
    forceRefresh: false,
  );
  return result.totalItems;
});
