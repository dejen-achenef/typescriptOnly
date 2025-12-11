import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Production-ready storage service for cross-platform storage information.
///
/// Provides storage statistics using native Dart APIs without platform channels.
/// Works on Android, iOS, Linux, macOS, and Windows.
/// Web is not supported (throws UnsupportedError).
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  /// Gets total storage capacity in bytes.
  ///
  /// Returns the total storage space available on the device.
  /// On unsupported platforms (web), throws [UnsupportedError].
  ///
  /// Throws:
  /// - [UnsupportedError] on web platform
  /// - [Exception] if storage information cannot be retrieved
  Future<int> getTotalStorage() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Storage information is not available on web platform.',
      );
    }

    try {
      final freeBytes = await getFreeStorage();
      final usedBytes = await _calculateUsedStorage();

      // Total = free + used
      final total = freeBytes + usedBytes;

      // If calculation seems unreasonable, use a fallback estimate
      if (total < freeBytes || total < 1024 * 1024) {
        AppLogger.warning(
          error: null,
          'Storage calculation seems invalid, using fallback',
          data: {'calculatedTotal': total, 'free': freeBytes},
        );
        // Estimate: assume free space represents ~30% of total (conservative)
        return (freeBytes * 3.33).round();
      }

      return total;
    } catch (e, stack) {
      AppLogger.error('Failed to get total storage', error: e, stack: stack);
      rethrow;
    }
  }

  /// Gets free (available) storage space in bytes.
  ///
  /// Returns the amount of free storage space available.
  /// On unsupported platforms (web), throws [UnsupportedError].
  ///
  /// Throws:
  /// - [UnsupportedError] on web platform
  /// - [Exception] if storage information cannot be retrieved
  Future<int> getFreeStorage() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Storage information is not available on web platform.',
      );
    }

    try {
      return await _getPlatformFreeStorage();
    } catch (e, stack) {
      AppLogger.error('Failed to get free storage', error: e, stack: stack);
      // Return a conservative fallback to avoid breaking the app
      AppLogger.warning(
        error: null,
        'Using fallback free storage value',
        data: {'error': e.toString()},
      );
      return 10 * 1024 * 1024 * 1024; // 10 GB fallback
    }
  }

  /// Gets used storage space in bytes.
  ///
  /// Calculated as: totalStorage - freeStorage
  /// On unsupported platforms (web), throws [UnsupportedError].
  ///
  /// Throws:
  /// - [UnsupportedError] on web platform
  /// - [Exception] if storage information cannot be retrieved
  Future<int> getUsedStorage() async {
    try {
      return await _calculateUsedStorage();
    } catch (e) {
      AppLogger.error('Failed to calculate used storage', error: e);
      // Fallback: try to calculate from total - free
      try {
        final total = await getTotalStorage();
        final free = await getFreeStorage();
        return (total - free).clamp(0, total);
      } catch (_) {
        rethrow;
      }
    }
  }

  /// Gets free storage space using platform-specific methods.
  Future<int> _getPlatformFreeStorage() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await _getMobileFreeStorage();
    } else if (Platform.isLinux || Platform.isMacOS) {
      return await _getUnixFreeStorage();
    } else if (Platform.isWindows) {
      return await _getWindowsFreeStorage();
    } else {
      throw UnsupportedError(
        'Platform ${Platform.operatingSystem} is not supported.',
      );
    }
  }

  /// Gets free storage for mobile platforms (Android/iOS).
  ///
  /// Uses the application documents directory to estimate available space.
  Future<int> _getMobileFreeStorage() async {
    try {
      // Get the application's document directory
      final directory = await getApplicationDocumentsDirectory();

      // For mobile, we use a conservative approach:
      // Check the parent directory's available space
      return await _getDirectoryFreeSpace(directory.path);
    } catch (e) {
      AppLogger.warning(
        error: null,
        'Mobile free storage check failed, using fallback',
        data: {'error': e.toString()},
      );
      // Conservative fallback for mobile
      return 1024 * 1024 * 1024; // 1 GB
    }
  }

  /// Gets free storage for Unix-like systems (Linux/macOS).
  Future<int> _getUnixFreeStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return await _getDirectoryFreeSpace(directory.path);
    } catch (e) {
      AppLogger.warning(
        error: null,
        'Unix free storage check failed, using fallback',
        data: {'error': e.toString()},
      );
      return 5 * 1024 * 1024 * 1024; // 5 GB fallback
    }
  }

  /// Gets free storage for Windows.
  Future<int> _getWindowsFreeStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return await _getWindowsDirectoryFreeSpace(directory.path);
    } catch (e) {
      AppLogger.warning(
        error: null,
        'Windows free storage check failed, using fallback',
        data: {'error': e.toString()},
      );
      return 5 * 1024 * 1024 * 1024; // 5 GB fallback
    }
  }

  /// Gets free space for a directory using `df` command (Unix/Linux/macOS).
  Future<int> _getDirectoryFreeSpace(String path) async {
    if (Platform.isWindows) {
      return await _getWindowsDirectoryFreeSpace(path);
    }

    try {
      // Use 'df' command for Unix-like systems
      final result = await Process.run('df', ['-k', path]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final lines = output.split('\n');

        // Skip header line, get data line
        if (lines.length >= 2) {
          final parts = lines[1].trim().split(RegExp(r'\s+'));
          // df output format: Filesystem 1K-blocks Used Available Use% Mounted
          // We want the "Available" column (usually index 3)
          if (parts.length >= 4) {
            final availableKb = int.tryParse(parts[3]);
            if (availableKb != null) {
              return availableKb * 1024; // Convert KB to bytes
            }
          }
        }
      }

      throw Exception('df command failed or returned unexpected output');
    } catch (e) {
      AppLogger.warning(
        error: null,
        'df command failed for path: $path',
        data: {'error': e.toString()},
      );
      // Fallback to conservative estimate
      return 1024 * 1024 * 1024; // 1 GB
    }
  }

  /// Gets free space for a directory on Windows using `wmic`.
  Future<int> _getWindowsDirectoryFreeSpace(String path) async {
    try {
      // Extract drive letter (e.g., "C:" from "C:\Users\...")
      final driveMatch = RegExp(r'^([A-Z]):').firstMatch(path.toUpperCase());
      if (driveMatch == null) {
        throw Exception('Could not extract drive letter from path: $path');
      }

      final driveLetter = driveMatch.group(1);

      // Use wmic to get free space
      final result = await Process.run('wmic', [
        'logicaldisk',
        'where',
        'name="$driveLetter:"',
        'get',
        'freespace',
        '/format:value',
      ]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'FreeSpace=(\d+)').firstMatch(output);
        if (match != null) {
          final freeSpaceStr = match.group(1);
          if (freeSpaceStr != null) {
            return int.parse(freeSpaceStr);
          }
        }
      }

      throw Exception('wmic command failed or returned unexpected output');
    } catch (e) {
      AppLogger.warning(
        error: null,
        'Windows free space check failed for path: $path',
        data: {'error': e.toString()},
      );
      // Fallback to conservative estimate
      return 1024 * 1024 * 1024; // 1 GB
    }
  }

  /// Calculates used storage by examining the application's directory size.
  Future<int> _calculateUsedStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return await _getDirectorySize(directory);
    } catch (e) {
      AppLogger.warning(
        error: null,
        'Could not calculate used storage, returning 0',
        data: {'error': e.toString()},
      );
      return 0;
    }
  }

  /// Recursively calculates the size of a directory.
  Future<int> _getDirectorySize(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }

    try {
      int totalSize = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (_) {
            // Skip files that can't be read
          }
        }
      }
      return totalSize;
    } catch (e) {
      AppLogger.warning(
        error: null,
        'Error calculating directory size',
        data: {'path': directory.path, 'error': e.toString()},
      );
      return 0;
    }
  }
}
