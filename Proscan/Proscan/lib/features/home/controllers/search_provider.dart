// features/home/controllers/search_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:thyscan/core/services/document_backend_sync_service.dart';
import 'package:thyscan/core/services/document_search_service.dart';
import 'package:thyscan/core/services/recent_searches_service.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/models/document_filter.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Provider for search query state
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for search page state
final searchPageProvider = StateProvider<int>((ref) => 0);

/// Provider for search results (debounced and paginated)
final searchResultsProvider =
    FutureProvider.family<PaginatedDocuments, SearchParams>((
      ref,
      params,
    ) async {
      final query = params.query;
      final scanMode = params.scanMode;
      final sortBy = params.sortBy;
      final descending = params.descending;
      final page = params.page;
      final pageSize = params.pageSize;

      // Watch search query to trigger rebuild when it changes
      final currentQuery = ref.watch(searchQueryProvider);

      // Add delay for debouncing (only if query is not empty)
      if (query.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 300));
        // Check if query has changed during delay
        final latestQuery = ref.read(searchQueryProvider);
        if (latestQuery != query) {
          // Query changed, cancel this search by throwing a specific error
          // This will be caught and the provider will rebuild with new params
          throw _QueryChangedException();
        }
      }

      // Perform search
      return DocumentSearchService.instance.search(
        query: query.isEmpty ? null : query,
        scanMode: scanMode,
        sortBy: sortBy,
        descending: descending,
        page: page,
        pageSize: pageSize,
      );
    });

/// Exception thrown when search query changes during debounce delay
class _QueryChangedException implements Exception {
  @override
  String toString() => 'Query changed during debounce';
}

/// Provider for current search results (uses current search state)
final currentSearchResultsProvider = FutureProvider<PaginatedDocuments>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider);
  final page = ref.watch(searchPageProvider);
  final homeState = ref.watch(homeProvider);

  // Get scan mode from active filter
  final activeFilter = DocumentFilters.getById(homeState.activeFilterId);
  final scanMode = activeFilter.scanMode;

  final searchParams = SearchParams(
    query: query,
    scanMode: scanMode,
    sortBy: homeState.sortCriteria,
    descending: true, // Default to descending
    page: page,
    pageSize: 20,
  );

  final asyncValue = ref.watch(searchResultsProvider(searchParams));

  return asyncValue.when(
    data: (data) => data,
    loading: () async {
      // If still loading, directly call the search method
      return await DocumentSearchService.instance.search(
        query: query.isEmpty ? null : query,
        scanMode: scanMode,
        sortBy: searchParams.sortBy,
        descending: searchParams.descending,
        page: searchParams.page,
        pageSize: searchParams.pageSize,
      );
    },
    error: (error, stack) {
      if (error is _QueryChangedException) {
        throw error;
      }
      throw error;
    },
  );
});

/// Provider for search loading state
final isSearchingProvider = Provider<bool>((ref) {
  final resultsAsync = ref.watch(currentSearchResultsProvider);
  return resultsAsync.isLoading;
});

/// Provider for search error state
final searchErrorProvider = Provider<String?>((ref) {
  final resultsAsync = ref.watch(currentSearchResultsProvider);
  return resultsAsync.hasError ? resultsAsync.error.toString() : null;
});

/// Provider for search suggestions/autocomplete
final searchSuggestionsProvider = FutureProvider.family<List<String>, String>((
  ref,
  query,
) async {
  if (query.trim().isEmpty || query.trim().length < 1) {
    return [];
  }

  try {
    return await DocumentBackendSyncService.instance.getSearchSuggestions(
      query: query.trim(),
      limit: 10,
    );
  } catch (e) {
    return [];
  }
});

/// Provider for recent searches
final recentSearchesProvider = Provider<List<String>>((ref) {
  return RecentSearchesService.instance.getRecentSearches(limit: 10);
});

/// Search parameters model
class SearchParams {
  final String query;
  final String? scanMode;
  final SortCriteria sortBy;
  final bool descending;
  final int page;
  final int pageSize;

  const SearchParams({
    required this.query,
    this.scanMode,
    required this.sortBy,
    required this.descending,
    required this.page,
    required this.pageSize,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchParams &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          scanMode == other.scanMode &&
          sortBy == other.sortBy &&
          descending == other.descending &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode =>
      query.hashCode ^
      scanMode.hashCode ^
      sortBy.hashCode ^
      descending.hashCode ^
      page.hashCode ^
      pageSize.hashCode;
}

/// Debouncer utility class for delaying function calls
class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer({required this.duration});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() {
    _timer?.cancel();
  }
}
