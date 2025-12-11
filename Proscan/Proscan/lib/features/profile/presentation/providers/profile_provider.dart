// features/profile/presentation/providers/profile_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:thyscan/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:thyscan/features/profile/domain/entities/profile.dart';
import 'package:thyscan/features/profile/domain/repositories/profile_repository.dart';

part 'profile_provider.g.dart';

/// Provider for [ProfileRepository] implementation.
@riverpod
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepositoryImpl();
}

/// Provider for current user's profile.
///
/// Automatically fetches profile when accessed.
/// Use [profileNotifierProvider] for state management with loading/error states.
@riverpod
Future<Profile> currentProfile(Ref ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getCurrentProfile();
}

/// State for profile operations (loading, error, success).
class ProfileState {
  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.isUploadingAvatar = false,
  });

  final Profile? profile;
  final bool isLoading;
  final String? error;
  final bool isUploadingAvatar;

  bool get hasError => error != null;
  bool get isSuccess => profile != null && !isLoading && error == null;

  ProfileState copyWith({
    Profile? profile,
    bool? isLoading,
    String? error,
    bool? isUploadingAvatar,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
    );
  }
}

/// Notifier for managing profile state and operations.
@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  @override
  ProfileState build() {
    // Load profile on initialization
    _loadProfile();
    return const ProfileState();
  }

  /// Loads the current user's profile.
  Future<void> _loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repository = ref.read(profileRepositoryProvider);
      final profile = await repository.getCurrentProfile();
      state = state.copyWith(
        profile: profile,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Updates the profile with new full name and/or avatar.
  ///
  /// **Parameters:**
  /// - `fullName`: Optional new full name
  /// - `avatarUrl`: Optional new avatar URL (usually from upload)
  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repository = ref.read(profileRepositoryProvider);
      final updatedProfile = await repository.updateProfile(
        fullName: fullName,
        avatarUrl: avatarUrl,
      );

      state = state.copyWith(
        profile: updatedProfile,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Uploads avatar image and updates profile.
  ///
  /// **Parameters:**
  /// - `imagePath`: Local file path to the image
  Future<void> uploadAndUpdateAvatar(String imagePath) async {
    state = state.copyWith(isUploadingAvatar: true, error: null);

    try {
      final repository = ref.read(profileRepositoryProvider);
      final avatarUrl = await repository.uploadAvatar(imagePath);

      // Update profile with new avatar URL
      await updateProfile(avatarUrl: avatarUrl);
    } catch (e) {
      state = state.copyWith(
        isUploadingAvatar: false,
        error: e.toString(),
      );
      rethrow;
    } finally {
      state = state.copyWith(isUploadingAvatar: false);
    }
  }

  /// Refreshes the profile from backend.
  Future<void> refresh() async {
    await _loadProfile();
  }
}

