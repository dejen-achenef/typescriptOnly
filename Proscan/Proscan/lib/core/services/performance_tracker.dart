import 'package:thyscan/core/services/app_logger.dart';

class PerformanceTracker {
  const PerformanceTracker._();

  static Future<T> track<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    final sw = Stopwatch()..start();
    try {
      return await action();
    } finally {
      sw.stop();
      AppLogger.performance(operation, sw.elapsed);
      if (sw.elapsed > const Duration(seconds: 5)) {
        AppLogger.warning(
          'Slow operation detected',
          data: {
            'operation': operation,
            'durationMs': sw.elapsed.inMilliseconds,
          },
          error: null,
        );
      }
    }
  }
}
