// features/profile/data/repositories/profile_repository_impl.dart

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thyscan/core/config/app_env.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/utils/url_validator.dart';
import 'package:thyscan/features/profile/core/services/profile_service.dart';
import 'package:thyscan/features/profile/domain/entities/profile.dart';
import 'package:thyscan/features/profile/domain/repositories/profile_repository.dart';

/// Implementation of [ProfileRepository] using Supabase and NestJS backend.
///
/// Handles:
/// - Fetching profile from backend
/// - Updating profile via backend API
/// - Uploading avatars to Supabase Storage
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    ProfileService? profileService,
  }) : _profileService = profileService ?? ProfileService.instance;

  final ProfileService _profileService;

  @override
  Future<Profile> getCurrentProfile() async {
    try {
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final session = AuthService.instance.supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      final backendUrl = AppEnv.backendApiUrl;
      if (backendUrl == null || backendUrl.isEmpty) {
        // Fallback to Supabase auth user data if backend not configured
        AppLogger.warning(
          'Backend API URL not configured, using Supabase auth data',
          error: null,
        );
        return Profile(
          id: user.id,
          email: user.email,
          fullName: user.name,
          avatarUrl: user.photoUrl,
        );
      }

      // Validate and normalize URL
      if (!UrlValidator.isValidUrl(backendUrl)) {
        throw Exception('Invalid backend API URL format: $backendUrl');
      }

      final apiUrl = UrlValidator.buildApiUrl(backendUrl, 'api/profiles/me');
      if (apiUrl == null) {
        throw Exception('Failed to build API URL from: $backendUrl');
      }

      final url = Uri.parse(apiUrl);
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Backend API request timed out');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseProfile(json);
      } else if (response.statusCode == 404) {
        // Profile doesn't exist yet, return from auth data
        AppLogger.info('Profile not found in backend, using auth data');
        return Profile(
          id: user.id,
          email: user.email,
          fullName: user.name,
          avatarUrl: user.photoUrl,
        );
      } else {
        throw Exception(
          'Failed to fetch profile: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stack) {
      AppLogger.error('Failed to get current profile', error: e, stack: stack);
      rethrow;
    }
  }

  @override
  Future<Profile> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      await AuthService.instance.ensureInitialized();
      final user = AuthService.instance.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final session = AuthService.instance.supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      final backendUrl = AppEnv.backendApiUrl;
      if (backendUrl == null || backendUrl.isEmpty) {
        AppLogger.warning(
          'Backend API URL not configured, skipping profile update',
          error: null,
        );
        // Return updated profile from local data
        return Profile(
          id: user.id,
          email: user.email,
          fullName: fullName ?? user.name,
          avatarUrl: avatarUrl ?? user.photoUrl,
        );
      }

      // Validate and normalize URL
      if (!UrlValidator.isValidUrl(backendUrl)) {
        throw Exception('Invalid backend API URL format: $backendUrl');
      }

      final apiUrl = UrlValidator.buildApiUrl(backendUrl, 'api/profiles/me');
      if (apiUrl == null) {
        throw Exception('Failed to build API URL from: $backendUrl');
      }

      final url = Uri.parse(apiUrl);
      final body = <String, dynamic>{};
      if (fullName != null) body['fullName'] = fullName;
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

      final response = await http
          .patch(
            url,
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Backend API request timed out');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseProfile(json);
      } else {
        throw Exception(
          'Failed to update profile: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stack) {
      AppLogger.error('Failed to update profile', error: e, stack: stack);
      rethrow;
    }
  }

  @override
  Future<String> uploadAvatar(String imagePath) async {
    return _profileService.uploadAvatar(imagePath);
  }

  /// Parses profile JSON from backend into [Profile] entity.
  Profile _parseProfile(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

