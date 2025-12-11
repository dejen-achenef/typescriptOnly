// core/services/recent_searches_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Service for managing recent searches
/// Stores recent searches in Hive for quick access
class RecentSearchesService {
  RecentSearchesService._();
  static final RecentSearchesService instance = RecentSearchesService._();

  static const String _boxName = 'recent_searches';
  static const int _maxRecentSearches = 20;
  Box<String>? _box;
  bool _isInitialized = false;

  /// Initializes the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _box = await Hive.openBox<String>(_boxName);
      _isInitialized = true;
      AppLogger.info(
        'RecentSearchesService initialized',
        data: {'count': _box!.length},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Failed to initialize RecentSearchesService',
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }

  /// Adds a search query to recent searches
  void addSearch(String query) {
    if (!_isInitialized || _box == null) {
      AppLogger.warning('RecentSearchesService not initialized');
      return;
    }

    if (query.trim().isEmpty) {
      return;
    }

    try {
      final trimmedQuery = query.trim();

      // Remove if already exists (to move to top)
      if (_box!.containsKey(trimmedQuery)) {
        _box!.delete(trimmedQuery);
      }

      // Add to beginning
      _box!.put(trimmedQuery, DateTime.now().toIso8601String());

      // Limit to max recent searches
      if (_box!.length > _maxRecentSearches) {
        final keys = _box!.keys.toList();
        // Remove oldest (last in list)
        for (int i = keys.length - 1; i >= _maxRecentSearches; i--) {
          _box!.delete(keys[i]);
        }
      }

      AppLogger.warning('Recent search added', data: {'query': trimmedQuery});
    } catch (e) {
      AppLogger.warning('Failed to add recent search', error: e);
    }
  }

  /// Gets recent searches (most recent first)
  List<String> getRecentSearches({int limit = 10}) {
    if (!_isInitialized || _box == null) {
      return [];
    }

    try {
      // Get all searches with timestamps
      final searches = _box!.toMap().entries.toList();

      // Sort by timestamp (most recent first)
      searches.sort((a, b) {
        try {
          final aTime = DateTime.parse(a.value);
          final bTime = DateTime.parse(b.value);
          return bTime.compareTo(aTime);
        } catch (_) {
          return 0;
        }
      });

      // Return limited results
      return searches.take(limit).map((e) => e.key as String).toList();
    } catch (e) {
      AppLogger.warning('Failed to get recent searches', error: e);
      return [];
    }
  }

  /// Clears all recent searches
  void clearRecentSearches() {
    if (!_isInitialized || _box == null) {
      return;
    }

    try {
      _box!.clear();
      AppLogger.info('Recent searches cleared');
    } catch (e) {
      AppLogger.warning('Failed to clear recent searches', error: e);
    }
  }

  /// Removes a specific search from recent searches
  void removeSearch(String query) {
    if (!_isInitialized || _box == null) {
      return;
    }

    try {
      _box!.delete(query.trim());
      AppLogger.warning('Recent search removed', data: {'query': query});
    } catch (e) {
      AppLogger.warning('Failed to remove recent search', error: e);
    }
  }
}
