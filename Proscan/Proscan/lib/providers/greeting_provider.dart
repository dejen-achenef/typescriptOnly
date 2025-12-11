// providers/greeting_provider.dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:thyscan/core/utils/greeting_utils.dart';
import 'package:thyscan/providers/auth_provider.dart';

part 'greeting_provider.g.dart';

/// Provider that provides the current greeting text with user's name (if logged in).
/// Updates automatically when:
/// - Time crosses greeting boundaries (5:00, 12:00, 17:00, 21:00)
/// - User logs in/out (via auth state changes)
@riverpod
Stream<String> greeting(Ref ref) async* {
  // Watch auth state to get current user (reactive to login/logout)
  // This ensures greeting updates immediately when user logs in/out
  final authState = ref.watch(authControllerProvider);
  final userName = authState.user?.name;
  
  // Yield initial greeting immediately
  String lastGreeting = GreetingUtils.getFullGreeting(userName: userName);
  yield lastGreeting;
  
  // Then emit periodic updates every minute to catch time boundary crossings
  await for (final _ in Stream.periodic(const Duration(minutes: 1))) {
    // Re-read auth state on each emission to catch login/logout
    final currentAuthState = ref.read(authControllerProvider);
    final currentUserName = currentAuthState.user?.name;
    final newGreeting = GreetingUtils.getFullGreeting(userName: currentUserName);
    
    // Only yield if greeting changed (distinct)
    if (newGreeting != lastGreeting) {
      lastGreeting = newGreeting;
      yield newGreeting;
    }
  }
}

/// Provider that provides the current greeting synchronously (for immediate display).
/// Use this for initial display, then switch to greetingProvider for updates.
@riverpod
String currentGreeting(Ref ref) {
  final authState = ref.watch(authControllerProvider);
  final userName = authState.user?.name;
  return GreetingUtils.getFullGreeting(userName: userName);
}

