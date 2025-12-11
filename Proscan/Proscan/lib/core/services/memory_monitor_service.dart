// core/services/memory_monitor_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:system_info2/system_info2.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/image_cache_service.dart';
import 'package:thyscan/core/services/resource_guard.dart';

/// Memory monitoring service to track memory usage and handle memory pressure.
/// 
/// Monitors heap size, image cache size, and document cache size.
/// Provides callbacks for memory pressure events.
class MemoryMonitorService {
  MemoryMonitorService._();
  static final MemoryMonitorService instance = MemoryMonitorService._();

  // Memory thresholds
  static const double warningThreshold = 0.80; // 80%
  static const double criticalThreshold = 0.90; // 90%

  // Monitoring state
  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  final List<Function()> _memoryPressureCallbacks = [];

  /// Whether monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Starts memory monitoring
  /// 
  /// Checks memory usage every 30 seconds and triggers callbacks if thresholds are exceeded.
  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(interval, (_) => _checkMemoryUsage());

    AppLogger.info('Memory monitoring started', data: {'intervalSeconds': interval.inSeconds});
  }

  /// Stops memory monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    AppLogger.info('Memory monitoring stopped');
  }

  /// Registers a callback to be called when memory pressure is detected
  void registerMemoryPressureCallback(Function() callback) {
    _memoryPressureCallbacks.add(callback);
  }

  /// Unregisters a memory pressure callback
  void unregisterMemoryPressureCallback(Function() callback) {
    _memoryPressureCallbacks.remove(callback);
  }

  /// Gets current memory statistics
  Future<Map<String, dynamic>> getMemoryStats() async {
    try {
      final totalMemory = SysInfo.getTotalPhysicalMemory();
      final freeMemory = SysInfo.getFreePhysicalMemory();
      final usedMemory = totalMemory - freeMemory;
      final usagePercentage = (usedMemory / totalMemory) * 100;

      // Get image cache size
      final imageCacheSize = ImageCacheService.instance.currentCacheSize;
      final imageCachePercentage = ImageCacheService.instance.cacheSizePercentage;

      return {
        'totalMemoryMB': (totalMemory / 1024 / 1024).toStringAsFixed(2),
        'freeMemoryMB': (freeMemory / 1024 / 1024).toStringAsFixed(2),
        'usedMemoryMB': (usedMemory / 1024 / 1024).toStringAsFixed(2),
        'usagePercentage': usagePercentage.toStringAsFixed(1),
        'imageCacheSizeMB': (imageCacheSize / 1024 / 1024).toStringAsFixed(2),
        'imageCachePercentage': imageCachePercentage.toStringAsFixed(1),
        'isWarning': usagePercentage > (warningThreshold * 100),
        'isCritical': usagePercentage > (criticalThreshold * 100),
      };
    } catch (e) {
      AppLogger.warning('Failed to get memory stats', error: e);
      return {
        'error': 'Unable to retrieve memory statistics',
      };
    }
  }

  /// Checks current memory usage and triggers callbacks if needed
  Future<void> _checkMemoryUsage() async {
    try {
      final stats = await getMemoryStats();
      final usagePercentage = double.tryParse(stats['usagePercentage'] as String? ?? '0') ?? 0;

      if (usagePercentage > (criticalThreshold * 100)) {
        AppLogger.warning(
          'Critical memory usage detected',
          error: null,
          data: {'usagePercentage': usagePercentage.toStringAsFixed(1)},
        );
        _handleMemoryPressure(critical: true);
      } else if (usagePercentage > (warningThreshold * 100)) {
        AppLogger.warning(
          'High memory usage detected',
          error: null,
          data: {'usagePercentage': usagePercentage.toStringAsFixed(1)},
        );
        _handleMemoryPressure(critical: false);
      }
    } catch (e) {
      AppLogger.warning('Failed to check memory usage', error: e);
    }
  }

  /// Handles memory pressure by calling registered callbacks
  void _handleMemoryPressure({required bool critical}) {
    AppLogger.info(
      'Handling memory pressure',
      data: {'critical': critical, 'callbackCount': _memoryPressureCallbacks.length},
    );

    // Call all registered callbacks
    for (final callback in _memoryPressureCallbacks) {
      try {
        callback();
      } catch (e) {
        AppLogger.warning('Memory pressure callback failed', error: e);
      }
    }

    // Clear image cache on memory pressure
    ImageCacheService.instance.clearOnMemoryPressure().catchError((e) {
      AppLogger.warning('Failed to clear image cache on memory pressure', error: e);
    });

    // On critical memory pressure, take more aggressive actions
    if (critical) {
      // Reduce concurrent operations
      try {
        // Clear some queues to reduce memory pressure
        ResourceGuard.instance.clearAllQueues();
        AppLogger.info('Cleared operation queues due to critical memory pressure');
      } catch (e) {
        AppLogger.warning('Failed to clear operation queues', error: e);
      }

      // Force garbage collection hint (Dart VM will handle this)
      // Note: Dart doesn't have explicit GC control, but we can hint by creating
      // temporary objects and letting them be collected
      _hintGarbageCollection();
    }
  }

  /// Hints to the garbage collector that collection might be beneficial
  void _hintGarbageCollection() {
    // Create temporary objects and let them be collected
    // This is a hint to the VM that memory is under pressure
    try {
      final temp = List.generate(100, (i) => List.generate(100, (j) => i * j));
      // Let temp go out of scope immediately
    } catch (e) {
      // Ignore errors
    }
  }

  /// Forces a memory check immediately
  Future<void> checkMemoryNow() async {
    await _checkMemoryUsage();
  }

  /// Disposes the service
  void dispose() {
    stopMonitoring();
    _memoryPressureCallbacks.clear();
  }
}

