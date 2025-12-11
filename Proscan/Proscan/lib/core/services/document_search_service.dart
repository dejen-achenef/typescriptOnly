// core/services/document_search_service.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/repositories/document_repository.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/document_backend_sync_service.dart';
import 'package:thyscan/core/services/full_text_search_index_service.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Hybrid search service that uses backend API when online and local Hive storage when offline.
///
/// **Features:**
/// - Backend search with query, filter, sort, and pagination
/// - Local search fallback for offline scenarios
/// - Automatic connectivity detection
/// - Result caching for performance
/// - Error handling with graceful fallback
///
/// **Usage:**
/// ```dart
/// final results = await DocumentSearchService.instance.search(
///   query: 'invoice',
///   scanMode: 'document',
///   sortBy: SortCriteria.date,
///   descending: true,
///   page: 0,
///   pageSize: 20,
/// );
/// ```
class DocumentSearchService {
  DocumentSearchService._();
  static final DocumentSearchService instance = DocumentSearchService._();

  final Connectivity _connectivity = Connectivity();
  final Map<String, PaginatedDocuments> _cache = {};
  static const Duration _cacheTTL = Duration(minutes: 5);
  final Map<String, DateTime> _cacheTimestamps = {};
  static const int _maxCacheSize = 50;

  /// Searches documents using backend API.
  ///
  /// **Parameters:**
  /// - `query`: Search query string (searches title, textContent, tags)
  /// - `scanMode`: Filter by scan mode (optional)
  /// - `sortBy`: Sort field (date, size, pages, title)
  /// - `descending`: Sort order (default: true)
  /// - `page`: Page number (default: 0)
  /// - `pageSize`: Items per page (default: 20)
  ///
  /// **Returns:**
  /// - PaginatedDocuments with search results
  ///
  /// **Throws:**
  /// - Exception if backend search fails
  Future<PaginatedDocuments> searchBackend({
    String? query,
    String? scanMode,
    SortCriteria sortBy = SortCriteria.date,
    bool descending = true,
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      return await DocumentBackendSyncService.instance.searchDocuments(
        query: query,
        scanMode: scanMode,
        sortBy: _sortCriteriaToString(sortBy),
        order: descending ? 'desc' : 'asc',
        page: page,
        pageSize: pageSize,
      );
    } catch (e, stack) {
      AppLogger.error(
        'Backend search failed',
        error: e,
        stack: stack,
        data: {
          'query': query,
          'scanMode': scanMode,
          'sortBy': sortBy.name,
        },
      );
      rethrow;
    }
  }

  /// Searches documents in local Hive storage using full-text search index.
  /// 
  /// Uses inverted index for instant search (<100ms) like Microsoft Lens.
  ///
  /// **Parameters:**
  /// - `query`: Search query string (searches title, tags, OCR textContent)
  /// - `scanMode`: Filter by scan mode (optional)
  /// - `sortBy`: Sort field (date, size, pages)
  /// - `descending`: Sort order (default: true)
  ///
  /// **Returns:**
  /// - List of matching documents (all results, no pagination)
  Future<List<DocumentModel>> searchLocal({
    String? query,
    String? scanMode,
    SortCriteria sortBy = SortCriteria.date,
    bool descending = true,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      List<DocumentModel> documents;
      
      // Use full-text search index if query is provided
      if (query != null && query.trim().isNotEmpty) {
        // Search using inverted index (instant <100ms)
        final matchingDocIds = await FullTextSearchIndexService.instance.search(query);
        
        if (matchingDocIds.isEmpty) {
          // No results from index
          stopwatch.stop();
          AppLogger.info(
            'Local search completed (no results)',
            data: {
              'query': query,
              'scanMode': scanMode,
              'resultsCount': 0,
              'durationMs': stopwatch.elapsedMilliseconds,
            },
          );
          return [];
        }
        
        // Get documents by IDs from repository
        documents = await DocumentRepository.instance.getDocumentsByIds(matchingDocIds);
        
        // Filter out deleted documents
        documents = documents.where((doc) => !doc.isDeleted).toList();
      } else {
        // No query - get all documents
        documents = await DocumentRepository.instance.getAllDocuments();
        documents = documents.where((doc) => !doc.isDeleted).toList();
      }

      // Apply scanMode filter
      if (scanMode != null && scanMode.isNotEmpty) {
        documents = documents.where((doc) => doc.scanMode == scanMode).toList();
      }

      // Apply sorting
      switch (sortBy) {
        case SortCriteria.date:
          documents.sort((a, b) => descending
              ? b.createdAt.compareTo(a.createdAt)
              : a.createdAt.compareTo(b.createdAt));
          break;
        case SortCriteria.size:
        case SortCriteria.pages:
          documents.sort((a, b) => descending
              ? b.pageCount.compareTo(a.pageCount)
              : a.pageCount.compareTo(b.pageCount));
          break;
      }

      stopwatch.stop();
      
      AppLogger.info(
        'Local search completed',
        data: {
          'query': query,
          'scanMode': scanMode,
          'resultsCount': documents.length,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );

      return documents;
    } catch (e, stack) {
      AppLogger.error(
        'Local search failed',
        error: e,
        stack: stack,
      );
      return [];
    }
  }

  /// Hybrid search: tries backend when online, falls back to local when offline.
  ///
  /// **Parameters:**
  /// - `query`: Search query string (optional)
  /// - `scanMode`: Filter by scan mode (optional)
  /// - `sortBy`: Sort field (default: date)
  /// - `descending`: Sort order (default: true)
  /// - `page`: Page number (default: 0)
  /// - `pageSize`: Items per page (default: 20)
  ///
  /// **Returns:**
  /// - PaginatedDocuments with search results
  Future<PaginatedDocuments> search({
    String? query,
    String? scanMode,
    SortCriteria sortBy = SortCriteria.date,
    bool descending = true,
    int page = 0,
    int pageSize = 20,
  }) async {
    // Check cache first
    final cacheKey = _buildCacheKey(query, scanMode, sortBy, descending, page, pageSize);
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheTTL) {
        AppLogger.info('Returning cached search results', data: {'cacheKey': cacheKey});
        return cached;
      } else {
        // Cache expired, remove it
        _cache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
      }
    }

    // Check connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final isOnline = connectivityResults.any(
      (result) =>
          result != ConnectivityResult.none &&
          result != ConnectivityResult.bluetooth,
    );

    if (isOnline) {
      try {
        // Try backend search
        final results = await searchBackend(
          query: query,
          scanMode: scanMode,
          sortBy: sortBy,
          descending: descending,
          page: page,
          pageSize: pageSize,
        );

        // Cache results
        _cacheResult(cacheKey, results);

        return results;
      } catch (e) {
        AppLogger.warning(
          'Backend search failed, falling back to local search',
          error: e,
        );
        // Fall through to local search
      }
    }

    // Use local search (offline or backend failed)
    final localResults = await searchLocal(
      query: query,
      scanMode: scanMode,
      sortBy: sortBy,
      descending: descending,
    );

    // Convert local results to paginated format
    final start = page * pageSize;
    final end = (start + pageSize).clamp(0, localResults.length);
    final paginatedItems = start < localResults.length
        ? localResults.sublist(start, end)
        : <DocumentModel>[];

    final paginatedResults = PaginatedDocuments(
      page: page,
      pageSize: pageSize,
      totalItems: localResults.length,
      items: paginatedItems,
      hasMore: end < localResults.length,
    );

    return paginatedResults;
  }

  /// Filters and sorts documents locally (helper method).
  ///
  /// **Parameters:**
  /// - `documents`: List of documents to filter/sort
  /// - `scanMode`: Filter by scan mode (optional)
  /// - `sortBy`: Sort field (default: date)
  /// - `descending`: Sort order (default: true)
  ///
  /// **Returns:**
  /// - Filtered and sorted list of documents
  List<DocumentModel> filterAndSort({
    required List<DocumentModel> documents,
    String? scanMode,
    SortCriteria sortBy = SortCriteria.date,
    bool descending = true,
  }) {
    var filtered = documents.where((doc) => !doc.isDeleted).toList();

    // Apply scanMode filter
    if (scanMode != null && scanMode.isNotEmpty) {
      filtered = filtered.where((doc) => doc.scanMode == scanMode).toList();
    }

    // Apply sorting
    switch (sortBy) {
      case SortCriteria.date:
        filtered.sort((a, b) => descending
            ? b.createdAt.compareTo(a.createdAt)
            : a.createdAt.compareTo(b.createdAt));
        break;
      case SortCriteria.size:
      case SortCriteria.pages:
        filtered.sort((a, b) => descending
            ? b.pageCount.compareTo(a.pageCount)
            : a.pageCount.compareTo(b.pageCount));
        break;
    }

    return filtered;
  }

  /// Invalidates cache for a specific document (call when document is created/updated/deleted).
  void invalidateCacheForDocument(String documentId) {
    // Clear all cache entries since any document change could affect search results
    clearCache();
    
    // Update full-text search index
    // Note: This is async but we don't await it to avoid blocking
    DocumentRepository.instance.getDocumentById(documentId).then((doc) {
      if (doc != null) {
        FullTextSearchIndexService.instance.updateDocumentIndex(doc);
      } else {
        // Document deleted - remove from index
        FullTextSearchIndexService.instance.removeDocumentFromIndex(documentId);
      }
    }).catchError((error) {
      AppLogger.warning(
        'Failed to update search index for document',
        error: error,
        data: {'documentId': documentId},
      );
    });
    
    AppLogger.info('Search cache invalidated due to document change', data: {'documentId': documentId});
  }

  /// Builds cache key from search parameters.
  String _buildCacheKey(
    String? query,
    String? scanMode,
    SortCriteria sortBy,
    bool descending,
    int page,
    int pageSize,
  ) {
    return '${query ?? ''}|${scanMode ?? ''}|${sortBy.name}|$descending|$page|$pageSize';
  }

  /// Caches search results with LRU eviction.
  void _cacheResult(String key, PaginatedDocuments results) {
    // Evict oldest entries if cache is full
    if (_cache.length >= _maxCacheSize) {
      final oldestKey = _cacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _cache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }

    _cache[key] = results;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Converts SortCriteria enum to backend string format.
  String _sortCriteriaToString(SortCriteria sortBy) {
    switch (sortBy) {
      case SortCriteria.date:
        return 'date';
      case SortCriteria.size:
        return 'size';
      case SortCriteria.pages:
        return 'pages';
    }
  }

  /// Clears all search cache
  /// Called during logout to clear user data
  void clearCache() {
    try {
      AppLogger.info('Clearing DocumentSearchService cache');
      _cache.clear();
      _cacheTimestamps.clear();
      AppLogger.info('DocumentSearchService cache cleared');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to clear DocumentSearchService cache',
        error: e,
        stack: stack,
      );
    }
  }
}

