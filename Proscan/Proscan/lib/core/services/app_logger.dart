import 'dart:convert';
import 'dart:developer' as developer;

/// Production-ready logging service with structured logging and optional crash reporting.
///
/// **Features:**
/// - Structured JSON logging for easy parsing
/// - Optional crash reporting integration (Firebase Crashlytics/Sentry)
/// - Performance tracking
/// - Error categorization
///
/// **Crash Reporting Setup:**
/// To enable crash reporting, uncomment the relevant sections and add dependencies:
///
/// **Firebase Crashlytics:**
/// ```yaml
/// dependencies:
///   firebase_core: ^3.0.0
///   firebase_crashlytics: ^4.0.0
/// ```
///
/// **Sentry:**
/// ```yaml
/// dependencies:
///   sentry_flutter: ^8.0.0
/// ```
class AppLogger {
  const AppLogger._();

  // Uncomment and initialize in main.dart to enable crash reporting
  // static FirebaseCrashlytics? _crashlytics;
  // static SentryClient? _sentry;

  // /// Initialize crash reporting (call in main.dart)
  // static Future<void> initializeCrashReporting() async {
  //   // Firebase Crashlytics
  //   // await Firebase.initializeApp();
  //   // _crashlytics = FirebaseCrashlytics.instance;
  //   // FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  //   // PlatformDispatcher.instance.onError = (error, stack) {
  //   //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  //   //   return true;
  //   // };
  //
  //   // Sentry
  //   // await SentryFlutter.init(
  //   //   (options) {
  //   //     options.dsn = 'YOUR_SENTRY_DSN';
  //   //   },
  //   //   appRunner: () => runApp(MyApp()),
  //   // );
  // }

  /// Formats log data as structured JSON
  static String _formatLogData({
    required String message,
    required String level,
    Object? error,
    StackTrace? stack,
    Map<String, dynamic>? data,
  }) {
    final logData = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'level': level,
      'message': message,
    };

    if (error != null) {
      logData['error'] = error.toString();
      if (error is Exception) {
        logData['errorType'] = error.runtimeType.toString();
      }
    }

    if (stack != null) {
      logData['stackTrace'] = stack.toString();
    }

    if (data != null && data.isNotEmpty) {
      logData['data'] = data;
    }

    return jsonEncode(logData);
  }

  /// Logs an info message
  static void info(String message, {Map<String, dynamic>? data}) {
    final formatted = _formatLogData(
      message: message,
      level: 'INFO',
      data: data,
    );
    developer.log(formatted, level: 800, name: 'ThyScan');

    // Uncomment to send to crash reporting service
    // _crashlytics?.log('INFO: $message');
    // _sentry?.captureMessage('INFO: $message', level: SentryLevel.info);
  }

  /// Logs a warning message
  static void warning(
    String message, {
    Map<String, dynamic>? data,
    Object? error,
  }) {
    final formatted = _formatLogData(
      message: message,
      level: 'WARNING',
      error: error,
      data: data,
    );
    developer.log(formatted, level: 900, name: 'ThyScan');

    // Uncomment to send to crash reporting service
    // _crashlytics?.log('WARNING: $message');
    // if (error != null) {
    //   _crashlytics?.recordError(error, null, reason: message, fatal: false);
    // }
    // _sentry?.captureMessage('WARNING: $message', level: SentryLevel.warning);
  }

  /// Logs an error message with optional stack trace
  static void error(
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, dynamic>? data,
  }) {
    final formatted = _formatLogData(
      message: message,
      level: 'ERROR',
      error: error,
      stack: stack,
      data: data,
    );
    developer.log(formatted, level: 1000, name: 'ThyScan');

    // Uncomment to send to crash reporting service
    // _crashlytics?.recordError(
    //   error ?? Exception(message),
    //   stack,
    //   reason: message,
    //   fatal: false,
    // );
    // _sentry?.captureException(
    //   error ?? Exception(message),
    //   stackTrace: stack,
    //   hint: Hint.withMap({'message': message, ...?data}),
    // );
  }

  /// Logs a performance metric
  static void performance(
    String operation,
    Duration duration, {
    Map<String, dynamic>? data,
  }) {
    final perfData = <String, dynamic>{
      'operation': operation,
      'durationMs': duration.inMilliseconds,
      'durationSeconds': duration.inSeconds,
      ...?data,
    };
    final formatted = _formatLogData(
      message: 'Performance: $operation',
      level: 'PERFORMANCE',
      data: perfData,
    );
    developer.log(formatted, level: 700, name: 'ThyScan::Performance');

    // Uncomment to send to performance monitoring
    // _crashlytics?.log('Performance: $operation took ${duration.inMilliseconds}ms');
    // FirebasePerformance.instance.newTrace(operation).stop();
  }

  /// Logs a critical error (should be reported to crash reporting service)
  static void critical(
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, dynamic>? data,
  }) {
    final formatted = _formatLogData(
      message: message,
      level: 'CRITICAL',
      error: error,
      stack: stack,
      data: data,
    );
    developer.log(formatted, level: 1200, name: 'ThyScan::CRITICAL');

    // Uncomment to send to crash reporting service (fatal)
    // _crashlytics?.recordError(
    //   error ?? Exception(message),
    //   stack,
    //   reason: message,
    //   fatal: true,
    // );
    // _sentry?.captureException(
    //   error ?? Exception(message),
    //   stackTrace: stack,
    //   hint: Hint.withMap({'message': message, ...?data}),
    // );
  }
}
