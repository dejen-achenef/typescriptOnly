// core/models/app_user.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Immutable data class representing an authenticated user in the app.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String? name;
  final String? photoUrl;

  /// Factory constructor to create an [AppUser] from Supabase's [User] object.
  /// Safely extracts name and photo URL from user metadata.
  factory AppUser.fromSupabase(User user) {
    // Extract name from user_metadata or raw_user_meta_data
    String? name;
    if (user.userMetadata != null) {
      name = user.userMetadata!['name'] as String?;
      if (name == null || name.isEmpty) {
        name = user.userMetadata!['full_name'] as String?;
      }
    }
    if (name == null || name.isEmpty) {
      // Fallback to app_metadata if available
      final appMeta = user.appMetadata;
      if (appMeta.isNotEmpty) {
        name = appMeta['name'] as String?;
        if (name == null || name.isEmpty) {
          name = appMeta['full_name'] as String?;
        }
      }
    }

    // Extract photo URL from user_metadata or raw_user_meta_data
    String? photoUrl;
    if (user.userMetadata != null) {
      photoUrl = user.userMetadata!['avatar_url'] as String?;
      if (photoUrl == null || photoUrl.isEmpty) {
        photoUrl = user.userMetadata!['picture'] as String?;
      }
    }
    if (photoUrl == null || photoUrl.isEmpty) {
      final appMeta = user.appMetadata;
      if (appMeta.isNotEmpty) {
        photoUrl = appMeta['avatar_url'] as String?;
        if (photoUrl == null || photoUrl.isEmpty) {
          photoUrl = appMeta['picture'] as String?;
        }
      }
    }

    return AppUser(
      id: user.id,
      email: user.email ?? '',
      name: name?.isNotEmpty == true ? name : null,
      photoUrl: photoUrl?.isNotEmpty == true ? photoUrl : null,
    );
  }

  /// Creates a copy of this [AppUser] with the given fields replaced.
  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser &&
        other.id == id &&
        other.email == email &&
        other.name == name &&
        other.photoUrl == photoUrl;
  }

  @override
  int get hashCode => Object.hash(id, email, name, photoUrl);

  @override
  String toString() {
    return 'AppUser(id: $id, email: $email, name: $name, photoUrl: $photoUrl)';
  }
}

