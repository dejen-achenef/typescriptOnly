// core/services/app_storage_service.dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/constants/app_directories.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/features/scan/model/scan_flow_models.dart';

/// Service for managing organized document storage in ThyScan folder structure.
///
/// Handles:
/// - Creating organized folder structure (ThyScan/Document/, ThyScan/ID Card/, etc.)
/// - Moving final PDF/DOCX files from temp locations to organized folders
/// - Getting correct folder paths for scan modes
/// - Opening folders in file manager
///
/// This service ensures all final documents are saved in a clean, organized structure
/// that users can easily navigate to find their files.
class AppStorageService {
  AppStorageService._();

  static final AppStorageService instance = AppStorageService._();

  /// Gets the base ThyScan directory path in Documents folder.
  ///
  /// Creates the directory if it doesn't exist.
  Future<String> getAppDirectory() async {
    try {
      final appDocsDir = await getApplicationDocumentsDirectory();
      final appDir = Directory(p.join(appDocsDir.path, appMainFolder));

      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
        AppLogger.info(
          'Created ThyScan main directory',
          data: {'path': appDir.path},
        );
      }

      return appDir.path;
    } catch (e, stack) {
      AppLogger.error('Failed to get app directory', error: e, stack: stack);
      rethrow;
    }
  }

  /// Gets the folder path for a specific scan mode.
  ///
  /// Creates the folder if it doesn't exist.
  ///
  /// Example: Returns path to "ThyScan/Document/" for ScanMode.document
  Future<String> getScanModeFolderPath(ScanMode scanMode) async {
    try {
      final appDir = await getAppDirectory();
      final folderName = getFolderName(scanMode);
      final folderPath = Directory(p.join(appDir, folderName));

      if (!await folderPath.exists()) {
        await folderPath.create(recursive: true);
        AppLogger.info(
          'Created scan mode folder',
          data: {'mode': scanMode.name, 'path': folderPath.path},
        );
      }

      return folderPath.path;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to get scan mode folder path',
        error: e,
        stack: stack,
        data: {'scanMode': scanMode.name},
      );
      rethrow;
    }
  }

  /// Gets the folder path for a scan mode string (for backward compatibility).
  ///
  /// Used when we have a string scanMode from DocumentModel instead of ScanMode enum.
  Future<String> getScanModeFolderPathFromString(String scanMode) async {
    try {
      final appDir = await getAppDirectory();
      final folderName = getFolderNameForScanMode(scanMode);
      final folderPath = Directory(p.join(appDir, folderName));

      if (!await folderPath.exists()) {
        await folderPath.create(recursive: true);
        AppLogger.info(
          'Created scan mode folder from string',
          data: {'scanMode': scanMode, 'path': folderPath.path},
        );
      }

      return folderPath.path;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to get scan mode folder path from string',
        error: e,
        stack: stack,
        data: {'scanMode': scanMode},
      );
      rethrow;
    }
  }

  /// Creates all ThyScan subfolders at once (for initialization).
  ///
  /// This ensures all folders exist even before any documents are saved.
  Future<void> initializeFolders() async {
    try {
      await getAppDirectory(); // Ensure main folder exists

      // Create all scan mode folders
      for (final scanMode in ScanMode.values) {
        await getScanModeFolderPath(scanMode);
      }

      AppLogger.info('Initialized all ThyScan folders');
    } catch (e, stack) {
      AppLogger.error('Failed to initialize folders', error: e, stack: stack);
      // Don't rethrow - folder creation is best-effort
    }
  }

  /// Moves a final document file from temp location to organized folder.
  ///
  /// This is used after PDF/DOCX generation is complete.
  /// The file is moved (not copied) to preserve disk space.
  ///
  /// [tempFilePath] - Path to the temporary file (e.g., in scanned_documents/)
  /// [documentId] - Document ID used for filename (doc_$id.pdf)
  /// [scanMode] - Scan mode to determine target folder
  /// [format] - File format ('pdf' or 'docx')
  ///
  /// Returns the final path where the file was moved to.
  Future<String> moveToAppFolder({
    required String tempFilePath,
    required String documentId,
    required String scanMode,
    required String format, // 'pdf' or 'docx'
  }) async {
    try {
      final tempFile = File(tempFilePath);

      if (!await tempFile.exists()) {
        throw Exception('Temporary file does not exist: $tempFilePath');
      }

      // Get the target folder path for this scan mode
      final targetFolderPath = await getScanModeFolderPathFromString(scanMode);

      // Build final filename: doc_$id.pdf or doc_$id.docx
      final extension = format.toLowerCase();
      final finalFileName = 'doc_$documentId.$extension';
      final finalPath = p.join(targetFolderPath, finalFileName);

      // Check if target file already exists (shouldn't happen, but be safe)
      final finalFile = File(finalPath);
      if (await finalFile.exists()) {
        AppLogger.warning(
          'Target file already exists, deleting old version',
          data: {'path': finalPath},
          error: null,
        );
        await finalFile.delete();
      }

      // Move the file (preserves disk space vs. copy)
      await tempFile.rename(finalPath);

      AppLogger.info(
        'Moved document to organized folder',
        data: {
          'documentId': documentId,
          'scanMode': scanMode,
          'from': tempFilePath,
          'to': finalPath,
        },
      );

      return finalPath;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to move document to app folder',
        error: e,
        stack: stack,
        data: {
          'tempFilePath': tempFilePath,
          'documentId': documentId,
          'scanMode': scanMode,
          'format': format,
        },
      );
      rethrow;
    }
  }

  /// Gets the final document path without moving the file.
  ///
  /// Useful for determining where a file should be saved before generation.
  Future<String> getFinalDocumentPath({
    required String documentId,
    required String scanMode,
    required String format,
  }) async {
    try {
      final targetFolderPath = await getScanModeFolderPathFromString(scanMode);
      final extension = format.toLowerCase();
      final finalFileName = 'doc_$documentId.$extension';
      return p.join(targetFolderPath, finalFileName);
    } catch (e, stack) {
      AppLogger.error(
        'Failed to get final document path',
        error: e,
        stack: stack,
        data: {
          'documentId': documentId,
          'scanMode': scanMode,
          'format': format,
        },
      );
      rethrow;
    }
  }

  /// Opens the ThyScan folder in the system file manager (optional feature).
  ///
  /// Works on Android and iOS. On platforms where this isn't supported,
  /// this method will do nothing.
  Future<void> openAppFolder() async {
    try {
      final appDirPath = await getAppDirectory();

      // Use url_launcher or platform-specific method
      // For now, we'll log it - actual implementation would use url_launcher
      // or a platform channel
      AppLogger.info('Open folder requested', data: {'path': appDirPath});

      // TODO: Implement actual file manager opening using url_launcher
      // For Android: Use Intent.ACTION_VIEW with DocumentsContract
      // For iOS: Use UIApplication.shared.open() with file:// URL
    } catch (e, stack) {
      AppLogger.error('Failed to open app folder', error: e, stack: stack);
      // Don't rethrow - opening folder is non-critical
    }
  }

  /// Opens a specific scan mode folder in the system file manager.
  Future<void> openScanModeFolder(ScanMode scanMode) async {
    try {
      final folderPath = await getScanModeFolderPath(scanMode);
      AppLogger.info(
        'Open scan mode folder requested',
        data: {'mode': scanMode.name, 'path': folderPath},
      );

      // TODO: Implement actual file manager opening
    } catch (e, stack) {
      AppLogger.error(
        'Failed to open scan mode folder',
        error: e,
        stack: stack,
        data: {'scanMode': scanMode.name},
      );
    }
  }
}
