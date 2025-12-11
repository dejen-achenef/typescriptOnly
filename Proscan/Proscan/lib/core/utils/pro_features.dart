// core/utils/pro_features.dart
import 'package:thyscan/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Utility class for Pro feature gating (like CamScanner/Genius Scan).
/// Pro features are available when user is authenticated.
class ProFeatures {
  ProFeatures._();

  /// Checks if Pro features are available (user is authenticated).
  static bool isProAvailable(WidgetRef ref) {
    final authState = ref.read(authControllerProvider);
    return authState.isAuthenticated;
  }

  /// Gets the Pro unlock message to show in banners.
  static String getProUnlockMessage() {
    return 'Sign in to unlock Pro';
  }
}

/// Provider that indicates if Pro features are available.
final isProAvailableProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.isAuthenticated;
});

