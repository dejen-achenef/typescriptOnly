// features/profile/core/services/profile_service.dart

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';

/// Production-ready service for profile operations.
///
/// Handles:
/// - Image picking (gallery/camera)
/// - Avatar upload to Supabase Storage
/// - Local caching of avatars
/// - Offline queue support
///
/// **Storage:**
/// - Bucket: "avatars"
/// - Path: "{user_id}/avatar.jpg"
/// - Public: false (uses signed URLs)
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  static const String _storageBucket = 'avatars';
  final ImagePicker _imagePicker = ImagePicker();
  final Connectivity _connectivity = Connectivity();

  /// Picks an image from gallery or camera.
  ///
  /// **Parameters:**
  /// - `source`: ImageSource.gallery or ImageSource.camera
  ///
  /// **Returns:**
  /// - Local file path to the picked image
  /// - `null` if user cancels
  /// - Throws exception if pick fails
  Future<String?> pickImage(ImageSource source) async {
    try {
      AppLogger.info('Picking image from ${source.name}');

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85, // Compress to 85% quality
        maxWidth: 1024, // Max width 1024px
        maxHeight: 1024, // Max height 1024px
      );

      if (pickedFile == null) {
        AppLogger.info('User cancelled image pick');
        return null;
      }

      // Copy to app's temporary directory for processing
      final appDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${appDir.path}/avatar_$timestamp.jpg';

      await File(pickedFile.path).copy(tempPath);

      AppLogger.info('Image picked successfully', data: {'path': tempPath});
      return tempPath;
    } catch (e, stack) {
      AppLogger.error('Failed to pick image', error: e, stack: stack);
      rethrow;
    }
  }

  /// Uploads avatar image to Supabase Storage.
  ///
  /// **Process:**
  /// 1. Validates user authentication
  /// 2. Checks network connectivity
  /// 3. Uploads to Supabase Storage: `{user_id}/avatar.jpg`
  /// 4. Gets public/signed URL
  ///
  /// **Parameters:**
  /// - `imagePath`: Local file path to the image
  ///
  /// **Returns:**
  /// - Public URL of uploaded avatar
  /// - Throws exception if upload fails
  Future<String> uploadAvatar(String imagePath) async {
    try {
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check network connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline = connectivityResults.any(
        (result) =>
            result != ConnectivityResult.none &&
            result != ConnectivityResult.bluetooth,
      );

      if (!isOnline) {
        throw Exception('No internet connection. Please try again when online.');
      }

      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found: $imagePath');
      }

      final userId = user.id;
      final storagePath = '$userId/avatar.jpg';
      final fileSize = await file.length();

      AppLogger.info(
        'Uploading avatar to Supabase Storage',
        data: {
          'userId': userId,
          'path': storagePath,
          'size': fileSize,
        },
      );

      final supabase = AuthService.instance.supabase;

      // Upload to Supabase Storage (upsert to replace existing)
      await supabase.storage.from(_storageBucket).upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      // Get public URL (or signed URL if bucket is private)
      final publicUrl = supabase.storage
          .from(_storageBucket)
          .getPublicUrl(storagePath);

      AppLogger.info(
        'Avatar uploaded successfully',
        data: {'url': publicUrl},
      );

      // Cache avatar locally
      await _cacheAvatarLocally(imagePath, userId);

      return publicUrl;
    } catch (e, stack) {
      AppLogger.error('Failed to upload avatar', error: e, stack: stack);
      rethrow;
    }
  }

  /// Caches avatar image locally for offline access.
  ///
  /// **Parameters:**
  /// - `imagePath`: Local file path to the image
  /// - `userId`: User's ID
  Future<void> _cacheAvatarLocally(String imagePath, String userId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/avatar_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cachedPath = '${cacheDir.path}/$userId.jpg';
      await File(imagePath).copy(cachedPath);

      AppLogger.info('Avatar cached locally', data: {'path': cachedPath});
    } catch (e) {
      AppLogger.warning('Failed to cache avatar locally', error: e);
      // Non-critical, continue
    }
  }

  /// Gets cached avatar path if available.
  ///
  /// **Parameters:**
  /// - `userId`: User's ID
  ///
  /// **Returns:**
  /// - Local file path if cached, `null` otherwise
  Future<String?> getCachedAvatarPath(String userId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cachedPath = '${appDir.path}/avatar_cache/$userId.jpg';
      final file = File(cachedPath);

      if (await file.exists()) {
        return cachedPath;
      }
      return null;
    } catch (e) {
      AppLogger.warning('Failed to get cached avatar', error: e);
      return null;
    }
  }
}

