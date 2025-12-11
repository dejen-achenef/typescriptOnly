// core/services/image_cache_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Image cache service with LRU eviction and size limits.
/// 
/// Manages cached images with automatic eviction when size limit is reached.
/// Uses LRU (Least Recently Used) algorithm to evict oldest images first.
class ImageCacheService {
  ImageCacheService._();
  static final ImageCacheService instance = ImageCacheService._();

  // Maximum cache size in bytes (100MB default)
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  
  // Current cache size in bytes
  int _currentCacheSize = 0;
  
  // Map of image path -> cache entry (for LRU tracking)
  final Map<String, _CacheEntry> _cacheEntries = {};
  
  // Cache directory
  Directory? _cacheDir;
  bool _isInitialized = false;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Current cache size in bytes
  int get currentCacheSize => _currentCacheSize;
  
  /// Maximum cache size in bytes
  int get maxCacheSizeBytes => maxCacheSize;
  
  /// Cache size as percentage of max
  double get cacheSizePercentage => (currentCacheSize / maxCacheSize) * 100;

  /// Initializes the image cache service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/image_cache');
      
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }

      // Calculate current cache size
      await _calculateCacheSize();
      
      // Clean up if over limit
      if (_currentCacheSize > maxCacheSize) {
        await _evictToLimit();
      }

      _isInitialized = true;
      AppLogger.info(
        'ImageCacheService initialized',
        data: {
          'cacheSizeMB': (_currentCacheSize / 1024 / 1024).toStringAsFixed(2),
          'maxSizeMB': (maxCacheSize / 1024 / 1024).toStringAsFixed(2),
        },
      );
    } catch (e, stack) {
      AppLogger.error(
        'Failed to initialize ImageCacheService',
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }

  /// Gets a cached image file, or returns null if not cached
  Future<File?> getCachedImage(String imagePath) async {
    if (!_isInitialized || _cacheDir == null) {
      await initialize();
    }

    final cacheKey = _getCacheKey(imagePath);
    final cachedFile = File('${_cacheDir!.path}/$cacheKey');

    if (await cachedFile.exists()) {
      // Update access time for LRU
      _updateAccessTime(imagePath);
      return cachedFile;
    }

    return null;
  }

  /// Caches an image file
  /// 
  /// Returns the cached file path, or null if caching failed
  Future<String?> cacheImage(String sourcePath, String? cacheKey) async {
    if (!_isInitialized || _cacheDir == null) {
      await initialize();
    }

    try {
      final key = cacheKey ?? _getCacheKey(sourcePath);
      final cachedFile = File('${_cacheDir!.path}/$key');

      // Check if already cached
      if (await cachedFile.exists()) {
        _updateAccessTime(sourcePath);
        return cachedFile.path;
      }

      // Check cache size and evict if needed
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        AppLogger.warning('Source image not found for caching', error: null, data: {'path': sourcePath});
        return null;
      }

      final fileSize = await sourceFile.length();
      
      // Evict if adding this file would exceed limit
      while (_currentCacheSize + fileSize > maxCacheSize && _cacheEntries.isNotEmpty) {
        await _evictOldest();
      }

      // Copy file to cache
      await sourceFile.copy(cachedFile.path);

      // Update cache tracking
      _cacheEntries[sourcePath] = _CacheEntry(
        cachePath: cachedFile.path,
        size: fileSize,
        lastAccessed: DateTime.now(),
      );
      _currentCacheSize += fileSize;

      AppLogger.info(
        'Image cached',
        data: {
          'sourcePath': sourcePath,
          'cachePath': cachedFile.path,
          'sizeMB': (fileSize / 1024 / 1024).toStringAsFixed(2),
          'totalCacheMB': (_currentCacheSize / 1024 / 1024).toStringAsFixed(2),
        },
      );

      return cachedFile.path;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to cache image',
        error: e,
        stack: stack,
        data: {'sourcePath': sourcePath},
      );
      return null;
    }
  }

  /// Clears the entire image cache
  Future<void> clearCache() async {
    if (!_isInitialized || _cacheDir == null) return;

    try {
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }

      _cacheEntries.clear();
      _currentCacheSize = 0;

      AppLogger.info('Image cache cleared');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to clear image cache',
        error: e,
        stack: stack,
      );
    }
  }

  /// Clears cache when memory pressure is detected
  Future<void> clearOnMemoryPressure() async {
    AppLogger.warning(
      'Memory pressure detected, clearing image cache',
      error: null,
    );
    
    // Clear 50% of cache (oldest entries)
    final targetSize = _currentCacheSize ~/ 2;
    while (_currentCacheSize > targetSize && _cacheEntries.isNotEmpty) {
      await _evictOldest();
    }
  }

  /// Gets cache statistics
  Map<String, dynamic> getStatistics() {
    return {
      'currentSizeMB': (_currentCacheSize / 1024 / 1024).toStringAsFixed(2),
      'maxSizeMB': (maxCacheSize / 1024 / 1024).toStringAsFixed(2),
      'usagePercentage': cacheSizePercentage.toStringAsFixed(1),
      'entryCount': _cacheEntries.length,
      'isInitialized': _isInitialized,
    };
  }

  /// Calculates current cache size by scanning cache directory
  Future<void> _calculateCacheSize() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) {
      _currentCacheSize = 0;
      return;
    }

    int totalSize = 0;
    final entries = <String, _CacheEntry>{};

    try {
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          final size = await entity.length();
          totalSize += size;
          
          // Try to extract original path from filename or use cache path
          final originalPath = entity.path; // Simplified - could be enhanced
          entries[originalPath] = _CacheEntry(
            cachePath: entity.path,
            size: size,
            lastAccessed: await entity.lastModified(),
          );
        }
      }

      _currentCacheSize = totalSize;
      _cacheEntries.clear();
      _cacheEntries.addAll(entries);
    } catch (e) {
      AppLogger.warning('Failed to calculate cache size', error: e);
      _currentCacheSize = 0;
    }
  }

  /// Evicts oldest cache entries until under limit
  Future<void> _evictToLimit() async {
    while (_currentCacheSize > maxCacheSize && _cacheEntries.isNotEmpty) {
      await _evictOldest();
    }
  }

  /// Evicts the oldest (least recently used) cache entry
  Future<void> _evictOldest() async {
    if (_cacheEntries.isEmpty) return;

    // Find oldest entry
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cacheEntries.entries) {
      if (oldestTime == null || entry.value.lastAccessed.isBefore(oldestTime)) {
        oldestTime = entry.value.lastAccessed;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      final entry = _cacheEntries[oldestKey]!;
      try {
        final file = File(entry.cachePath);
        if (await file.exists()) {
          await file.delete();
        }
        _currentCacheSize -= entry.size;
        _cacheEntries.remove(oldestKey);

        AppLogger.info(
          'Evicted cache entry',
          data: {
            'path': oldestKey,
            'sizeMB': (entry.size / 1024 / 1024).toStringAsFixed(2),
            'remainingMB': (_currentCacheSize / 1024 / 1024).toStringAsFixed(2),
          },
        );
      } catch (e) {
        AppLogger.warning('Failed to evict cache entry', error: e);
        // Remove from tracking even if deletion failed
        _cacheEntries.remove(oldestKey);
      }
    }
  }

  /// Updates access time for LRU tracking
  void _updateAccessTime(String imagePath) {
    final entry = _cacheEntries[imagePath];
    if (entry != null) {
      _cacheEntries[imagePath] = entry.copyWith(lastAccessed: DateTime.now());
    }
  }

  /// Generates a cache key from image path
  String _getCacheKey(String imagePath) {
    // Use a hash of the path as the cache key
    return imagePath.hashCode.toString();
  }
}

/// Cache entry tracking
class _CacheEntry {
  final String cachePath;
  final int size;
  final DateTime lastAccessed;

  _CacheEntry({
    required this.cachePath,
    required this.size,
    required this.lastAccessed,
  });

  _CacheEntry copyWith({
    String? cachePath,
    int? size,
    DateTime? lastAccessed,
  }) {
    return _CacheEntry(
      cachePath: cachePath ?? this.cachePath,
      size: size ?? this.size,
      lastAccessed: lastAccessed ?? this.lastAccessed,
    );
  }
}

