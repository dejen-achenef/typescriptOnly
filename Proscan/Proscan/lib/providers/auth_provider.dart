// providers/auth_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:thyscan/core/errors/failures.dart';
import 'package:thyscan/core/models/app_user.dart';
import 'package:thyscan/core/services/auth_service.dart';

part 'auth_provider.g.dart';

/// Auth state that includes the current user and loading/error states
class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  final AppUser? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Riverpod provider that watches the current user from AuthService
@riverpod
Stream<AppUser?> authUserStream(Ref ref) {
  return AuthService.instance.userStream;
}

/// Riverpod controller for managing authentication state and operations
@riverpod
class AuthController extends _$AuthController {
  @override
  AuthState build() {
    // Watch the user stream via provider - this handles all state updates
    ref.listen<AsyncValue<AppUser?>>(
      authUserStreamProvider,
      (previous, next) {
        next.whenData((user) {
          state = state.copyWith(
            user: user,
            isLoading: false,
            error: null,
          );
        });
        next.whenOrNull(
          error: (error, stack) {
            state = state.copyWith(
              isLoading: false,
              error: error.toString(),
            );
          },
        );
      },
    );

    // Get initial user synchronously (safe - returns null if not initialized)
    final initialUser = AuthService.instance.currentUser;
    return AuthState(user: initialUser);
  }

  /// Sign in with email and password
  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await AuthService.instance.signInWithEmail(email, password);
      // State will be updated via the stream listener
    } catch (e) {
      final errorMessage = _extractErrorMessage(e);
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      rethrow;
    }
  }

  /// Sign up with email and password
  /// Returns true if email confirmation is required
  Future<bool> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final requiresEmailConfirmation = await AuthService.instance.signUpWithEmail(
        email,
        password,
        fullName: fullName,
      );

      if (requiresEmailConfirmation) {
        // Email confirmation is required - don't auto sign in
        state = state.copyWith(
          isLoading: false,
          error: null,
        );
        // Throw a specific error that can be caught and handled by UI
        throw AuthFailure(
          'Please check your email to confirm your account before signing in.',
        );
      } else {
        // User is immediately signed in (email confirmation disabled)
        // Auto sign in after signup
        await AuthService.instance.signInWithEmail(email, password);
        // State will be updated via the stream listener
        return false;
      }
    } catch (e) {
      final errorMessage = _extractErrorMessage(e);
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      rethrow;
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await AuthService.instance.signInWithGoogle();
      // State will be updated via the stream listener
    } catch (e) {
      final errorMessage = _extractErrorMessage(e);
      // Don't set error if user cancelled
      if (errorMessage.toLowerCase().contains('cancelled')) {
        state = state.copyWith(isLoading: false);
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await AuthService.instance.signOut();
      // State will be updated via the stream listener
    } catch (e) {
      final errorMessage = _extractErrorMessage(e);
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      rethrow;
    }
  }

  /// Extracts a user-friendly error message from an exception
  String _extractErrorMessage(dynamic error) {
    // Check if it's an AuthFailure (or any Failure) and extract the message
    if (error is AuthFailure) {
      return error.message;
    }
    
    // Check if it's a generic Failure
    if (error is Failure) {
      return error.message;
    }
    
    // For other exceptions, try to extract meaningful message
    final errorString = error.toString();
    
    // Remove common prefixes
    if (errorString.startsWith('AuthFailure: ')) {
      return errorString.substring('AuthFailure: '.length);
    }
    
    // If it's "Instance of 'AuthFailure'", return a generic message
    if (errorString.contains("Instance of 'AuthFailure'")) {
      return 'Authentication failed. Please try again.';
    }
    
    // Return the error string as-is, or a fallback
    return errorString.isNotEmpty ? errorString : 'An unexpected error occurred';
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

}

