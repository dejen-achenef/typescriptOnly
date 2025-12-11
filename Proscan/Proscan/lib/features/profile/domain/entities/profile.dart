// features/profile/domain/entities/profile.dart

/// Profile entity representing a user's profile information.
///
/// This is the core domain entity that represents the user's profile
/// in the business logic layer. It's independent of data sources.
class Profile {
  const Profile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// User's unique identifier (UUID)
  final String id;

  /// User's email address
  final String email;

  /// User's full name
  final String? fullName;

  /// URL to user's avatar image (Supabase Storage URL)
  final String? avatarUrl;

  /// Profile creation timestamp
  final DateTime? createdAt;

  /// Profile last update timestamp
  final DateTime? updatedAt;

  /// Creates a copy of this [Profile] with the given fields replaced.
  Profile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile &&
        other.id == id &&
        other.email == email &&
        other.fullName == fullName &&
        other.avatarUrl == avatarUrl;
  }

  @override
  int get hashCode => Object.hash(id, email, fullName, avatarUrl);

  @override
  String toString() {
    return 'Profile(id: $id, email: $email, fullName: $fullName, avatarUrl: $avatarUrl)';
  }
}

