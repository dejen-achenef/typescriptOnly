// features/profile/domain/repositories/profile_repository.dart

import '../entities/profile.dart';

/// Repository interface for profile operations.
///
/// This defines the contract for profile data operations in the domain layer.
/// Implementations are provided in the data layer.
abstract class ProfileRepository {
  /// Gets the current user's profile.
  ///
  /// **Returns:**
  /// - [Profile] if found
  /// - Throws exception if not found or error occurs
  Future<Profile> getCurrentProfile();

  /// Updates the current user's profile.
  ///
  /// **Parameters:**
  /// - `fullName`: Optional new full name
  /// - `avatarUrl`: Optional new avatar URL
  ///
  /// **Returns:**
  /// - Updated [Profile]
  /// - Throws exception if update fails
  Future<Profile> updateProfile({
    String? fullName,
    String? avatarUrl,
  });

  /// Uploads an avatar image to Supabase Storage.
  ///
  /// **Parameters:**
  /// - `imagePath`: Local file path to the image
  ///
  /// **Returns:**
  /// - Public URL of the uploaded image
  /// - Throws exception if upload fails
  Future<String> uploadAvatar(String imagePath);
}

