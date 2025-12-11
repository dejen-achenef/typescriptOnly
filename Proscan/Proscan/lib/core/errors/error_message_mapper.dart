// core/errors/error_message_mapper.dart
import 'package:thyscan/core/errors/failures.dart';

/// Maps technical errors to user-friendly messages.
/// 
/// Provides context-aware error messages that are actionable for users.
class ErrorMessageMapper {
  ErrorMessageMapper._();

  /// Maps an error to a user-friendly message
  static String getUserFriendlyMessage(dynamic error, {String? context}) {
    if (error == null) {
      return 'An unexpected error occurred. Please try again.';
    }

    // Handle specific error types
    if (error is AuthFailure) {
      return _mapAuthError(error);
    }

    if (error is NetworkFailure) {
      return 'Please check your internet connection and try again.';
    }

    if (error is StorageFailure) {
      return 'Storage error: ${error.message}. Please free up space and try again.';
    }

    if (error is PdfGenerationFailure) {
      return 'Failed to create document. Please try again or contact support.';
    }

    // Handle string errors
    if (error is String) {
      return _mapStringError(error, context: context);
    }

    // Handle Exception
    if (error is Exception) {
      return _mapException(error, context: context);
    }

    // Default fallback
    return 'Something went wrong. Please try again.';
  }

  /// Maps authentication errors
  static String _mapAuthError(AuthFailure error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid') || message.contains('incorrect')) {
      return 'Invalid email or password. Please check your credentials.';
    }

    if (message.contains('network') || message.contains('connection')) {
      return 'Unable to connect. Please check your internet connection.';
    }

    if (message.contains('email') && message.contains('already')) {
      return 'This email is already registered. Please sign in instead.';
    }

    if (message.contains('weak') || message.contains('password')) {
      return 'Password is too weak. Please use a stronger password.';
    }

    return 'Authentication failed. Please try again.';
  }

  /// Maps string errors
  static String _mapStringError(String error, {String? context}) {
    final lowerError = error.toLowerCase();

    // Network errors
    if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('timeout') ||
        lowerError.contains('socket')) {
      return 'Please check your internet connection and try again.';
    }

    // Storage errors
    if (lowerError.contains('storage') ||
        lowerError.contains('disk') ||
        lowerError.contains('space') ||
        lowerError.contains('full')) {
      return 'Not enough storage space. Please free up space and try again.';
    }

    // Permission errors
    if (lowerError.contains('permission') || lowerError.contains('denied')) {
      return 'Permission denied. Please grant the required permissions in settings.';
    }

    // File errors
    if (lowerError.contains('file') && lowerError.contains('not found')) {
      return 'File not found. The document may have been moved or deleted.';
    }

    // Rate limiting
    if (lowerError.contains('rate limit') || lowerError.contains('too many')) {
      return 'Too many requests. Please wait a moment and try again.';
    }

    // Context-aware messages
    if (context != null) {
      if (context.contains('upload')) {
        return 'Upload failed. Please check your connection and try again.';
      }
      if (context.contains('download')) {
        return 'Download failed. Please check your connection and try again.';
      }
      if (context.contains('sync')) {
        return 'Sync failed. Your data is safe locally. Please try again later.';
      }
    }

    return 'An error occurred: ${error.length > 100 ? error.substring(0, 100) + '...' : error}';
  }

  /// Maps exceptions
  static String _mapException(Exception error, {String? context}) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorString.contains('format') || errorString.contains('parse')) {
      return 'Invalid data format. Please try again.';
    }

    if (errorString.contains('unauthorized') || errorString.contains('401')) {
      return 'Session expired. Please sign in again.';
    }

    if (errorString.contains('forbidden') || errorString.contains('403')) {
      return 'Access denied. You don\'t have permission for this action.';
    }

    if (errorString.contains('not found') || errorString.contains('404')) {
      return 'Resource not found. It may have been deleted.';
    }

    if (errorString.contains('server') || errorString.contains('500')) {
      return 'Server error. Please try again later.';
    }

    return getUserFriendlyMessage(errorString, context: context);
  }

  /// Gets a retry message for an error
  static String getRetryMessage(dynamic error) {
    if (error is NetworkFailure) {
      return 'Retry';
    }

    final errorString = error.toString().toLowerCase();
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return 'Retry';
    }

    return 'Try Again';
  }

  /// Checks if an error is retryable
  static bool isRetryable(dynamic error) {
    if (error is NetworkFailure) {
      return true;
    }

    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('rate limit');
  }
}

