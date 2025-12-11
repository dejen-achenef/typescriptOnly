// core/widgets/error_boundary.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Error boundary widget that catches errors in child widgets
/// Prevents one corrupted widget from crashing the entire screen
/// Used by Notion, WhatsApp - required for Play Store
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
  });

  final Widget child;
  final Widget Function(BuildContext context, Object error, StackTrace stack)?
      fallback;
  final void Function(Object error, StackTrace stack)? onError;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Catch Flutter errors
    FlutterError.onError = (details) {
      if (mounted) {
        setState(() {
          _error = details.exception;
          _stackTrace = details.stack;
          _hasError = true;
        });
        _handleError(details.exception, details.stack);
      }
    };
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    // Log to analytics
    AppLogger.error(
      'Error boundary caught error',
      error: error,
      stack: stackTrace,
    );

    // Call custom error handler
    widget.onError?.call(error, stackTrace ?? StackTrace.current);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _error != null) {
      return widget.fallback?.call(
            context,
            _error!,
            _stackTrace ?? StackTrace.current,
          ) ??
          _defaultFallback(context);
    }

    return _ErrorCatcher(
      onError: (error, stackTrace) {
        if (mounted) {
          setState(() {
            _error = error;
            _stackTrace = stackTrace;
            _hasError = true;
          });
          _handleError(error, stackTrace);
        }
      },
      child: widget.child,
    );
  }

  Widget _defaultFallback(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Something went wrong',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal widget that catches errors using a Builder
class _ErrorCatcher extends StatelessWidget {
  const _ErrorCatcher({
    required this.child,
    required this.onError,
  });

  final Widget child;
  final void Function(Object error, StackTrace stackTrace) onError;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stackTrace) {
          onError(error, stackTrace);
          return const SizedBox.shrink();
        }
      },
    );
  }
}

/// Error boundary for list items (optimized for performance)
class ListItemErrorBoundary extends StatelessWidget {
  const ListItemErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.fallback,
  });

  final Widget child;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final Widget Function(BuildContext context, Object error)? fallback;

  @override
  Widget build(BuildContext context) {
    return _ListItemErrorCatcher(
      onError: (error, stackTrace) {
        // Log to analytics
        AppLogger.error(
          'List item error boundary caught error',
          error: error,
          stack: stackTrace,
        );
        onError?.call(error, stackTrace);
      },
      fallback: fallback,
      child: child,
    );
  }
}

class _ListItemErrorCatcher extends StatefulWidget {
  const _ListItemErrorCatcher({
    required this.child,
    required this.onError,
    this.fallback,
  });

  final Widget child;
  final void Function(Object error, StackTrace stackTrace) onError;
  final Widget Function(BuildContext context, Object error)? fallback;

  @override
  State<_ListItemErrorCatcher> createState() => _ListItemErrorCatcherState();
}

class _ListItemErrorCatcherState extends State<_ListItemErrorCatcher> {
  Object? _error;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError && _error != null) {
      return widget.fallback?.call(context, _error!) ??
          _defaultFallback(context);
    }

    // Use Builder to catch errors during build
    // This catches synchronous errors in the build method
    return Builder(
      builder: (context) {
        try {
          return widget.child;
        } catch (error, stackTrace) {
          // Only set error once to avoid infinite rebuilds
          if (!_hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _error = error;
                  _hasError = true;
                });
                widget.onError(error, stackTrace);
              }
            });
          }
          return widget.fallback?.call(context, error) ??
              _defaultFallback(context);
        }
      },
    );
  }

  Widget _defaultFallback(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Corrupted document',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

