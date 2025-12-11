// core/services/circuit_breaker_service.dart
import 'dart:async';

import 'package:thyscan/core/services/app_logger.dart';

/// Circuit breaker states
enum CircuitState {
  closed, // Normal operation - requests pass through
  open, // Circuit is open - requests are rejected immediately
  halfOpen, // Testing if service has recovered
}

/// Circuit breaker service for external API calls
/// 
/// Prevents cascading failures by stopping requests when a service is failing.
/// Implements the circuit breaker pattern with configurable thresholds.
class CircuitBreakerService {
  CircuitBreakerService._();
  static final CircuitBreakerService instance = CircuitBreakerService._();

  // Circuit breaker configurations per service
  final Map<String, _CircuitBreaker> _circuits = {};

  /// Default configuration
  static const int defaultFailureThreshold = 5;
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration defaultRecoveryTimeout = Duration(seconds: 60);

  /// Executes a function with circuit breaker protection
  /// 
  /// Returns the result of the function if successful, or throws an exception
  /// if the circuit is open or the function fails.
  Future<T> execute<T>({
    required String serviceName,
    required Future<T> Function() operation,
    int? failureThreshold,
    Duration? timeout,
    Duration? recoveryTimeout,
  }) async {
    final circuit = _getOrCreateCircuit(
      serviceName,
      failureThreshold ?? defaultFailureThreshold,
      timeout ?? defaultTimeout,
      recoveryTimeout ?? defaultRecoveryTimeout,
    );

    // Check circuit state
    if (circuit.state == CircuitState.open) {
      // Check if recovery timeout has passed
      if (DateTime.now().difference(circuit.lastFailureTime) >= circuit.recoveryTimeout) {
        circuit.state = CircuitState.halfOpen;
        AppLogger.info(
          'Circuit breaker entering half-open state',
          data: {'service': serviceName},
        );
      } else {
        throw CircuitBreakerException(
          'Circuit breaker is open for $serviceName. Service is unavailable.',
        );
      }
    }

    try {
      // Execute operation with timeout
      final result = await operation().timeout(
        circuit.timeout,
        onTimeout: () {
          throw TimeoutException(
            'Operation timed out after ${circuit.timeout.inSeconds} seconds',
          );
        },
      );

      // Success - reset failure count if in half-open state
      if (circuit.state == CircuitState.halfOpen) {
        circuit.state = CircuitState.closed;
        circuit.failureCount = 0;
        AppLogger.info(
          'Circuit breaker closed - service recovered',
          data: {'service': serviceName},
        );
      } else if (circuit.failureCount > 0) {
        // Reset failure count on success
        circuit.failureCount = 0;
      }

      return result;
    } catch (e) {
      // Record failure
      circuit.failureCount++;
      circuit.lastFailureTime = DateTime.now();

      AppLogger.warning(
        'Circuit breaker recorded failure',
        error: e,
        data: {
          'service': serviceName,
          'failureCount': circuit.failureCount,
          'threshold': circuit.failureThreshold,
        },
      );

      // Check if threshold exceeded
      if (circuit.failureCount >= circuit.failureThreshold) {
        circuit.state = CircuitState.open;
        AppLogger.error(
          'Circuit breaker opened - too many failures',
          error: null,
          data: {
            'service': serviceName,
            'failureCount': circuit.failureCount,
            'threshold': circuit.failureThreshold,
          },
        );
      }

      // Re-throw the exception
      rethrow;
    }
  }

  /// Gets the current state of a circuit
  CircuitState getState(String serviceName) {
    final circuit = _circuits[serviceName];
    return circuit?.state ?? CircuitState.closed;
  }

  /// Manually resets a circuit breaker
  void reset(String serviceName) {
    final circuit = _circuits[serviceName];
    if (circuit != null) {
      circuit.state = CircuitState.closed;
      circuit.failureCount = 0;
      AppLogger.info(
        'Circuit breaker manually reset',
        data: {'service': serviceName},
      );
    }
  }

  /// Gets statistics for a circuit breaker
  Map<String, dynamic> getStatistics(String serviceName) {
    final circuit = _circuits[serviceName];
    if (circuit == null) {
      return {'state': 'closed', 'exists': false};
    }

    return {
      'state': circuit.state.name,
      'failureCount': circuit.failureCount,
      'failureThreshold': circuit.failureThreshold,
      'timeout': circuit.timeout.inSeconds,
      'recoveryTimeout': circuit.recoveryTimeout.inSeconds,
      'lastFailureTime': circuit.lastFailureTime.toIso8601String(),
    };
  }

  _CircuitBreaker _getOrCreateCircuit(
    String serviceName,
    int failureThreshold,
    Duration timeout,
    Duration recoveryTimeout,
  ) {
    return _circuits.putIfAbsent(
      serviceName,
      () => _CircuitBreaker(
        failureThreshold: failureThreshold,
        timeout: timeout,
        recoveryTimeout: recoveryTimeout,
      ),
    );
  }
}

/// Circuit breaker implementation
class _CircuitBreaker {
  CircuitState state = CircuitState.closed;
  int failureCount = 0;
  DateTime lastFailureTime = DateTime.now();
  final int failureThreshold;
  final Duration timeout;
  final Duration recoveryTimeout;

  _CircuitBreaker({
    required this.failureThreshold,
    required this.timeout,
    required this.recoveryTimeout,
  });
}

/// Exception thrown when circuit breaker is open
class CircuitBreakerException implements Exception {
  final String message;

  CircuitBreakerException(this.message);

  @override
  String toString() => 'CircuitBreakerException: $message';
}

